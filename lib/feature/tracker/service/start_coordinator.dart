import 'timer_engine.dart';

/// What happened (or must happen next) when the Home screen taps a card.
enum StartKind { started, alreadyRunning, needsSwitchConfirm }

/// Result of [StartCoordinator.requestStart]. [runningActivityId] is only
/// set for [StartKind.needsSwitchConfirm] — the activity the UI must offer
/// to stop before switching to the tapped one.
class StartOutcome {
  const StartOutcome(this.kind, {this.runningActivityId});

  final StartKind kind;
  final int? runningActivityId;
}

/// Decides whether tapping a focus card starts, no-ops, or needs the D1
/// switch confirm, and carries out the switch once confirmed. One timer at
/// a time (D1): a cold start has no confirm; switching away from a running
/// activity does.
class StartCoordinator {
  StartCoordinator(this._engine);

  final TimerEngine _engine;

  /// True while a cold [_engine.start] is awaiting its DB write. Guards
  /// against a second near-simultaneous card tap opening a second session
  /// before the first has set [TimerEngine.running].
  bool _startInFlight = false;

  /// Call when a card is tapped. Starts immediately if nothing is running,
  /// no-ops if the tapped activity is already the running one, or returns
  /// [StartKind.needsSwitchConfirm] for the UI to confirm before
  /// [confirmSwitch].
  Future<StartOutcome> requestStart(int activityId) async {
    final running = _engine.running;
    if (running == null) {
      // A start is already landing — treat the racing tap as a no-op rather
      // than opening a duplicate session.
      if (_startInFlight) {
        return const StartOutcome(StartKind.alreadyRunning);
      }
      _startInFlight = true;
      try {
        await _engine.start(activityId);
      } finally {
        _startInFlight = false;
      }
      return const StartOutcome(StartKind.started);
    }
    if (running.activityId == activityId) {
      return const StartOutcome(StartKind.alreadyRunning);
    }
    return StartOutcome(
      StartKind.needsSwitchConfirm,
      runningActivityId: running.activityId,
    );
  }

  /// Stops the currently running activity and starts [activityId]. Call
  /// after the UI's D1 confirm for [StartKind.needsSwitchConfirm].
  Future<void> confirmSwitch(int activityId) async {
    await _engine.stop();
    await _engine.start(activityId);
  }
}
