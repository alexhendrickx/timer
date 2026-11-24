import 'package:flutter/foundation.dart';

import '../../../feature/activities/data/activity_repository.dart';
import '../../../feature/tracker/data/session_repository.dart';
import '../../../feature/tracker/service/timer_engine.dart';
import 'live_activity_bridge.dart';

/// Mirrors [TimerEngine]'s running session onto the iOS Live Activity. The
/// engine stays the source of truth: this only listens and never writes a
/// session. A start shows it, a switch shows the new session in place, any
/// stop ends it.
class LiveActivityMirror {
  LiveActivityMirror({
    required this.engine,
    required this.activityRepository,
    required this.sessionRepository,
    required this.bridge,
  });

  final TimerEngine engine;
  final ActivityRepository activityRepository;
  final SessionRepository sessionRepository;
  final LiveActivityBridge bridge;

  /// The session the Live Activity was last asked to show.
  int? _shownSessionId;

  /// Whether a Live Activity may be up. True at launch: one can outlive the
  /// previous run of the app, before the engine has adopted its session.
  bool _mayBeShowing = true;

  /// Bridge calls run one after another, in the order the engine changed,
  /// so a slow `end` can never land on a newer activity.
  Future<void> _queue = Future<void>.value();

  void start() => engine.addListener(_onEngineChanged);

  void dispose() => engine.removeListener(_onEngineChanged);

  /// Completes when every bridge call queued so far has been made.
  @visibleForTesting
  Future<void> get settled => _queue;

  /// Launch cleanup: ends a Live Activity that outlived the app when no
  /// session is open any more. An open session is left alone, also one the
  /// resume prompt (D2) has not settled yet. Runs inside the guarded queue,
  /// database read included, because `main()` awaits it before the first
  /// frame and it must never throw there.
  Future<void> endStale() => _enqueue(() async {
        if (await sessionRepository.openSession() != null) return;
        _mayBeShowing = false;
        _shownSessionId = null;
        await bridge.end();
      });

  // Fires on every engine change and on every tick, so it only acts when
  // the running session is a different one than last time.
  void _onEngineChanged() {
    final running = engine.running;
    if (running == null) {
      // Idle in the middle of a switch is not a stop.
      if (engine.isSwitching || !_mayBeShowing) return;
      _mayBeShowing = false;
      _shownSessionId = null;
      _enqueue(bridge.end);
      return;
    }
    if (running.id == _shownSessionId) return;
    _shownSessionId = running.id;
    _mayBeShowing = true;
    _enqueue(() async {
      final activities = await activityRepository.activeActivities();
      final activity =
          activities.where((a) => a.id == running.activityId).firstOrNull;
      await bridge.show(LiveActivityPayload(
        sessionId: running.id,
        activityName: activity?.name ?? 'Timer',
        color: activity?.color,
        startedAt: running.startTime,
      ));
    });
  }

  // The Live Activity is an extra: a failed call is logged and never
  // reaches start/stop.
  Future<void> _enqueue(Future<void> Function() call) {
    return _queue = _queue.then((_) async {
      try {
        await call();
      } catch (error) {
        debugPrint('Live Activity: $error');
      }
    });
  }
}
