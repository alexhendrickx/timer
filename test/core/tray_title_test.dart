import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/services/tray_controller.dart';

void main() {
  test('running title shows elapsed and activity', () {
    expect(
      trayTitle(activityName: 'Client X', elapsed: const Duration(seconds: 8073)),
      '🕐 2:14:33 · Client X',
    );
  });

  test('idle title is Timer', () => expect(trayTitle(), 'Timer'));

  test('missing elapsed falls back to idle title', () {
    expect(trayTitle(activityName: 'Client X'), 'Timer');
  });
}
