import 'package:flutter/services.dart';

/// What the Live Activity shows for one running session.
class LiveActivityPayload {
  const LiveActivityPayload({
    required this.sessionId,
    required this.activityName,
    required this.color,
    required this.startedAt,
  });

  /// Local database id of the session. The Stop button sends it back.
  final int sessionId;
  final String activityName;

  /// The activity's ARGB swatch, or null for the default accent.
  final int? color;
  final DateTime startedAt;

  /// The `show` arguments. `ios/Runner/LiveActivityController.swift` reads
  /// these keys by name.
  Map<String, Object?> toMap() => {
        'sessionId': sessionId,
        'activityName': activityName,
        'color': color,
        'startedAtMs': startedAt.millisecondsSinceEpoch,
      };
}

/// The seam to the native Live Activity. `LiveActivityMirror` is the only
/// caller; tests give it a fake.
abstract class LiveActivityBridge {
  /// Shows [payload]: updates the Live Activity in place when one is up,
  /// starts one otherwise.
  Future<void> show(LiveActivityPayload payload);

  /// Ends every Live Activity of this app right away. Fine when none is up.
  Future<void> end();
}

/// The real bridge: the `timer/live_activity` channel handled by
/// `ios/Runner/LiveActivityController.swift`. The same channel carries the
/// native side's `onStopRequest` back (see `ios/Shared/StopTimerIntent.swift`).
class LiveActivityChannel implements LiveActivityBridge {
  LiveActivityChannel() {
    _channel.setMethodCallHandler(_onMethodCall);
  }

  static const _channel = MethodChannel('timer/live_activity');

  /// Runs when the Stop button on the Live Activity has left a stop request
  /// in the app group while the app is alive.
  Future<void> Function()? onStopRequest;

  @override
  Future<void> show(LiveActivityPayload payload) =>
      _channel.invokeMethod<void>('show', payload.toMap());

  @override
  Future<void> end() => _channel.invokeMethod<void>('end');

  Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method == 'onStopRequest') await onStopRequest?.call();
    return null;
  }
}
