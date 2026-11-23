import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/services/notifications_service.dart';

void main() {
  test('zero clamps to 1 minute', () {
    expect(clampInterval(Duration.zero), const Duration(minutes: 1));
  });

  test('negative clamps to 1 minute', () {
    expect(
      clampInterval(const Duration(minutes: -5)),
      const Duration(minutes: 1),
    );
  });

  test('a value at or above the minimum passes through', () {
    expect(
      clampInterval(const Duration(minutes: 45)),
      const Duration(minutes: 45),
    );
  });
}
