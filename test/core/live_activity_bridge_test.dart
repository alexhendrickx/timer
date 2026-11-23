import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/platform/ios/live_activity_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('timer/live_activity');

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    channel.setMethodCallHandler(null);
  });

  /// Delivers `onStopRequest` the way the running app gets it from
  /// AppDelegate.
  Future<void> sendStopRequest() async {
    final data = const StandardMethodCodec()
        .encodeMethodCall(const MethodCall('onStopRequest'));
    await messenger.handlePlatformMessage(channel.name, data, (_) {});
  }

  test('show and end go out on timer/live_activity with the payload map',
      () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    final bridge = LiveActivityChannel();

    await bridge.show(LiveActivityPayload(
      sessionId: 7,
      activityName: 'Client A',
      color: 0xFF2E7D32,
      startedAt: DateTime.fromMillisecondsSinceEpoch(1795424400000),
    ));
    await bridge.end();

    expect(calls.map((c) => c.method), ['show', 'end']);
    expect(calls.first.arguments, {
      'sessionId': 7,
      'activityName': 'Client A',
      'color': 0xFF2E7D32,
      'startedAtMs': 1795424400000,
    });
  });

  test('a native onStopRequest runs the callback', () async {
    var requests = 0;
    LiveActivityChannel().onStopRequest = () async {
      requests++;
    };

    await sendStopRequest();
    await pumpEventQueue();

    expect(requests, 1);
  });

  test('onStopRequest with no callback set does not throw', () async {
    LiveActivityChannel();

    await sendStopRequest();
    await pumpEventQueue();
  });
}
