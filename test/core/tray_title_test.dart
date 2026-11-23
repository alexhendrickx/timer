import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/platform/mac/tray_controller.dart';

void main() {
  test('running title shows elapsed and activity', () {
    expect(
      trayTitle(activityName: 'Client X', elapsed: Duration(seconds: 8073)),
      '🕐 2:14:33 · Client X',
    );
  });

  test('idle title is Timer', () => expect(trayTitle(), 'Timer'));
}
