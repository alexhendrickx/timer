import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/platform/ios/app_group_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('timer/app_group');

  late Directory container;

  setUp(() async {
    container = await Directory.systemTemp.createTemp('timer_app_group_');
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'containerPath' ? container.path : null,
    );
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    if (container.existsSync()) await container.delete(recursive: true);
  });

  File requestFile() => File('${container.path}/stop_request.json');

  test('readStopRequest is null when there is no file', () async {
    expect(await AppGroupStorage.readStopRequest(), isNull);
  });

  test('readStopRequest returns the file\'s text', () async {
    await requestFile().writeAsString('{"sessionId":1}');

    expect(await AppGroupStorage.readStopRequest(), '{"sessionId":1}');
  });

  test('readStopRequest returns text for bytes that are not UTF-8', () async {
    await requestFile().writeAsBytes([0xFF, 0xFE, 0x7B]);

    expect(await AppGroupStorage.readStopRequest(), isNotNull);
  });

  test('deleteStopRequest removes the file and is quiet when it is gone',
      () async {
    await requestFile().writeAsString('{"sessionId":1}');

    await AppGroupStorage.deleteStopRequest();

    expect(requestFile().existsSync(), false);
    await expectLater(AppGroupStorage.deleteStopRequest(), completes);
  });

  test('without an app-group container, read is null and delete does nothing',
      () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);

    expect(await AppGroupStorage.readStopRequest(), isNull);
    await expectLater(AppGroupStorage.deleteStopRequest(), completes);
  });
}
