import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/services/database/app_database.dart';
import 'package:timer/feature/history/service/totals_calculator.dart';

Session _session(int seconds, {int id = 1, int activityId = 1}) {
  final start = DateTime(2026, 11, 2, 9, 0);
  return Session(
    id: id,
    activityId: activityId,
    date: DateTime(2026, 11, 2),
    startTime: start,
    endTime: start.add(Duration(seconds: seconds)),
    durationSeconds: seconds,
    createdAt: start,
    updatedAt: start,
    uid: 'session-$id',
    dirty: false,
  );
}

Activity _activity({int id = 1, double? hourlyRate}) {
  return Activity(
    id: id,
    name: 'Client X',
    archived: false,
    hourlyRate: hourlyRate,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    uid: 'activity-$id',
    dirty: false,
  );
}

void main() {
  test('three 20-min sessions sum-then-round to 1:00 at 15-min step', () {
    final sessions = [_session(1200), _session(1200), _session(1200)];
    final activityNoRate = _activity();
    final t = TotalsCalculator.forGroup(sessions, activityNoRate);
    expect(t.exactSeconds, 3600);
    expect(t.roundedSeconds, 3600);
    expect(t.amount, isNull);
  });

  test('amount uses rounded hours x rate', () {
    // 9h22m -> nearest 15-min mark is 9h15 at the default 900s step.
    final sessions = [_session(33720)];
    final activityRate75 = _activity(hourlyRate: 75);
    final t = TotalsCalculator.forGroup(sessions, activityRate75);
    expect(t.roundedSeconds, 33300); // 9:15
    expect(t.amount, 9.25 * 75);
  });

  test('empty group has zero totals and no amount even with a rate', () {
    final t = TotalsCalculator.forGroup([], _activity(hourlyRate: 50));
    expect(t.exactSeconds, 0);
    expect(t.roundedSeconds, 0);
    expect(t.amount, 0.0);
  });
}
