import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/database/app_database.dart';
import '../data/session_repository.dart';

/// Describes an open session found on launch, so the UI can ask whether to
/// keep it running or stop it at the last time the app was seen alive (D2).
class ResumeDecision {
  const ResumeDecision({
    required this.activityId,
    required this.start,
    required this.lastSeenAt,
  });

  final int activityId;
  final DateTime start;
  final DateTime lastSeenAt;
}

/// Owns the single running session. Writes an open row on start, ticks elapsed
/// every second, persists `lastSeenAt` every 30s, and closes the row on stop.
/// One timer at a time (D1) — [start] throws if one is already running; the UI
/// guards this with a confirm dialog.
class TimerEngine extends ChangeNotifier {
  TimerEngine(this._repo, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final SessionRepository _repo;
  final DateTime Function() _now;

  Session? _running;
  int? _lastSessionId;
  Timer? _ticker;
  ResumeDecision? _pendingOrphan;
  bool _resumeChecked = false;

  /// The open session, or null when idle.
  Session? get running => _running;

  /// Id of the running session, or the most recently stopped one — the target
  /// for a quick note added from the popover (running or just-stopped). Null
  /// until a session has been started this run.
  int? get currentSessionId => _running?.id ?? _lastSessionId;

  /// Exact time since the running session started; zero when idle.
  Duration get elapsed =>
      _running == null ? Duration.zero : _now().difference(_running!.startTime);

  /// Starts a new session for [activityId]. Throws [StateError] if one is
  /// already running (D1).
  Future<void> start(int activityId) async {
    if (_running != null) {
      throw StateError('A timer is already running');
    }
    // Guard against a persisted open session the in-memory state doesn't know
    // about (an unresolved orphan) — opening a second would corrupt resume.
    if (await _repo.openSession() != null) {
      throw StateError('An unresolved open session exists');
    }
    await _repo.startSession(activityId: activityId, start: _now());
    _running = await _repo.openSession();
    _lastSessionId = _running?.id;
    _startTicking();
    notifyListeners();
  }

  /// Stops the running session at now. No-op if none running.
  Future<void> stop() async {
    final current = _running;
    if (current == null) return;
    _stopTicking();
    await _repo.closeSession(current.id, _now());
    _running = null;
    notifyListeners();
  }

  /// On launch, if a session was left open, returns a decision for the UI.
  /// Null when there is nothing to resume. Acts at most once per app run and
  /// never while a session is already running, so a Home remount (navigating
  /// away and back) cannot re-prompt over a live timer.
  Future<ResumeDecision?> detectOrphan() async {
    if (_resumeChecked || _running != null) return null;
    _resumeChecked = true;
    final open = await _repo.openSession();
    if (open == null) return null;
    final decision = ResumeDecision(
      activityId: open.activityId,
      start: open.startTime,
      lastSeenAt: open.lastSeenAt ?? open.startTime,
    );
    _pendingOrphan = decision;
    return decision;
  }

  /// Resolves [detectOrphan] by keeping the open session running.
  Future<void> resumeKeepRunning() async {
    if (_pendingOrphan == null) return;
    _running = await _repo.openSession();
    _lastSessionId = _running?.id;
    _pendingOrphan = null;
    if (_running != null) {
      _startTicking();
      notifyListeners();
    }
  }

  /// Resolves [detectOrphan] by closing the open session at its lastSeenAt,
  /// never silently billing the gap since the app was last alive (D2).
  Future<void> resumeStopAtLastSeen() async {
    final orphan = _pendingOrphan;
    if (orphan == null) return;
    final open = await _repo.openSession();
    _pendingOrphan = null;
    if (open == null) return;
    await _repo.closeSession(open.id, orphan.lastSeenAt);
    _running = null;
    notifyListeners();
  }

  void _startTicking() {
    _ticker?.cancel();
    var seconds = 0;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      seconds++;
      if (seconds % 30 == 0 && _running != null) {
        _repo.touch(_running!.id, _now());
      }
      notifyListeners();
    });
  }

  void _stopTicking() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _stopTicking();
    super.dispose();
  }
}
