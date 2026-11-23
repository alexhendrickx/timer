import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/database/app_database.dart';
import '../data/session_repository.dart';

/// Describes an open session found on launch, so the UI can ask whether to
/// keep it running or stop it at the last time the app was seen alive (D2).
class ResumeDecision {
  const ResumeDecision({
    required this.sessionId,
    required this.activityId,
    required this.start,
    required this.lastSeenAt,
  });

  /// The open session this decision is about. Resolving it never touches
  /// another session.
  final int sessionId;
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
  bool _switching = false;

  /// The open session, or null when idle.
  Session? get running => _running;

  /// Id of the running session, or the most recently stopped one — the
  /// target for a quick note added from the popover (running or
  /// just-stopped). Null until a session has been started this run.
  int? get currentSessionId => _running?.id ?? _lastSessionId;

  /// Exact time since the running session started; zero when idle.
  Duration get elapsed =>
      _running == null ? Duration.zero : _now().difference(_running!.startTime);

  /// True while [switchTo] is between stopping the old session and starting
  /// the new one. A listener that mirrors the engine somewhere else (the
  /// Live Activity) reads this to tell a switch from a real stop.
  bool get isSwitching => _switching;

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
    await _close(current.id, _now());
  }

  /// Stops session [sessionId] at exactly [endedAt], the moment Stop was
  /// tapped on the Live Activity, if it is still the open session. That is
  /// the running one, or one a quit left open that the resume prompt (D2)
  /// has not settled yet. That prompt is then settled too: its answer can
  /// no longer close or adopt anything. Returns false and changes nothing
  /// when another session or none is open, or when [endedAt] is before its
  /// start.
  Future<bool> stopSessionAt(int sessionId, DateTime endedAt) async {
    final adopted = _running != null;
    final open = _running ?? await _repo.openSession();
    if (open == null || open.id != sessionId) return false;
    if (endedAt.isBefore(open.startTime)) return false;
    await _close(open.id, endedAt);
    if (!adopted) _pendingOrphan = null;
    return true;
  }

  /// Stops the running session and starts [activityId] (the D1 switch).
  /// [isSwitching] is true in between, and listeners are told once more
  /// when it is over, also when the start failed.
  Future<void> switchTo(int activityId) async {
    _switching = true;
    try {
      await stop();
      await start(activityId);
    } finally {
      _switching = false;
      notifyListeners();
    }
  }

  /// The one place [stop] and [stopSessionAt] close a session.
  Future<void> _close(int sessionId, DateTime end) async {
    _stopTicking();
    await _repo.closeSession(sessionId, end);
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
      sessionId: open.id,
      activityId: open.activityId,
      start: open.startTime,
      lastSeenAt: open.lastSeenAt ?? open.startTime,
    );
    _pendingOrphan = decision;
    return decision;
  }

  /// Resolves [detectOrphan] by keeping the open session running. Does
  /// nothing when that session is not the open one any more.
  Future<void> resumeKeepRunning() async {
    final orphan = _pendingOrphan;
    if (orphan == null) return;
    final open = await _repo.openSession();
    _pendingOrphan = null;
    if (open == null || open.id != orphan.sessionId) return;
    _running = open;
    _lastSessionId = open.id;
    _startTicking();
    notifyListeners();
  }

  /// Resolves [detectOrphan] by closing the open session at its lastSeenAt,
  /// never silently billing the gap since the app was last alive (D2).
  /// Does nothing when that session is not the open one any more, so a
  /// session started since is never closed at the old one's lastSeenAt.
  Future<void> resumeStopAtLastSeen() async {
    final orphan = _pendingOrphan;
    if (orphan == null) return;
    final open = await _repo.openSession();
    _pendingOrphan = null;
    if (open == null || open.id != orphan.sessionId) return;
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
