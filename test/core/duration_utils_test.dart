import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/utils/duration_utils.dart';

void main() {
  group('roundToHalfHourSeconds', () {
    test('rounds a 9h12m day down to 9:00', () {
      expect(roundToHalfHourSeconds(33120), 32400); // 9h00
    });
    test('rounds a 9h22m day up to 9:30', () {
      expect(roundToHalfHourSeconds(33720), 34200); // 9h30
    });
    test('ties round up (15 min -> 30 min)', () {
      expect(roundToHalfHourSeconds(900), 1800);
    });
    test('ties round up (45 min -> 60 min)', () {
      expect(roundToHalfHourSeconds(2700), 3600);
    });
    test('zero and negative clamp to zero', () {
      expect(roundToHalfHourSeconds(0), 0);
      expect(roundToHalfHourSeconds(-5), 0);
    });
  });

  group('formatHoursMinutes', () {
    test('formatHoursMinutes of 34200s is 9:30', () {
      expect(formatHoursMinutes(34200), '9:30');
    });
    test('pads minutes (3660s -> 1:01)', () {
      expect(formatHoursMinutes(3660), '1:01');
    });
    test('zero and negative -> 0:00', () {
      expect(formatHoursMinutes(0), '0:00');
      expect(formatHoursMinutes(-10), '0:00');
    });
  });

  group('formatHms', () {
    test('formatHms of 8073s is 2:14:33', () {
      expect(formatHms(8073), '2:14:33');
    });
    test('zero and negative -> 0:00:00', () {
      expect(formatHms(0), '0:00:00');
      expect(formatHms(-1), '0:00:00');
    });
  });
}
