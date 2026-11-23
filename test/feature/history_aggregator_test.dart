import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/services/database/app_database.dart';
import 'package:timer/feature/history/service/history_aggregator.dart';

Session _session({
  required DateTime date,
  required DateTime start,
  required DateTime end,
  int id = 1,
  int activityId = 1,
}) {
  return Session(
    id: id,
    activityId: activityId,
    date: date,
    startTime: start,
    endTime: end,
    durationSeconds: end.difference(start).inSeconds,
    createdAt: start,
    updatedAt: start,
    uid: 'session-$id',
    dirty: false,
  );
}

void main() {
  final agg = HistoryAggregator();

  test('week() returns 7 zero-filled day buckets summing exact seconds per day', () {
    // Mon 2026-11-02 is the week start.
    final monday = DateTime(2026, 11, 2);
    final sessions = [
      _session(
        date: monday,
        start: DateTime(2026, 11, 2, 9, 0),
        end: DateTime(2026, 11, 2, 10, 0),
      ),
    ];
    final b = agg.week(sessions, monday);
    expect(b.length, 7);
    expect(b.first.date, monday);
    expect(b.first.exactSeconds, 3600); // Mon had one 1h session
    expect(b[1].exactSeconds, 0); // Tue empty
  });

  test('midnight-crossing session buckets on its start day', () {
    final monday = DateTime(2026, 11, 2); // Mon .. Sun (Sat is index 5)
    final saturdayStart = DateTime(2026, 11, 7, 23, 0);
    final sundayEnd = DateTime(2026, 11, 8, 1, 0);
    final sessions = [
      _session(
        date: DateTime(2026, 11, 7),
        start: saturdayStart,
        end: sundayEnd,
      ),
    ];
    final b = agg.week(sessions, monday);
    expect(b[5].exactSeconds, 2 * 3600); // Saturday
    expect(b[6].exactSeconds, 0); // Sunday
  });

  test('month() zero-fills every day of the month', () {
    final b = agg.month([], DateTime(2026, 11, 1));
    expect(b.length, 30); // November has 30 days
    expect(b.every((d) => d.exactSeconds == 0), isTrue);
  });

  test('month() sums multiple activities on the same day', () {
    final day = DateTime(2026, 11, 15);
    final sessions = [
      _session(
        date: day,
        start: DateTime(2026, 11, 15, 9, 0),
        end: DateTime(2026, 11, 15, 10, 0),
        activityId: 1,
      ),
      _session(
        date: day,
        start: DateTime(2026, 11, 15, 11, 0),
        end: DateTime(2026, 11, 15, 11, 30),
        activityId: 2,
        id: 2,
      ),
    ];
    final b = agg.month(sessions, DateTime(2026, 11, 1));
    expect(b[14].exactSeconds, 5400); // day 15 (index 14): 1h + 30m
  });
}
