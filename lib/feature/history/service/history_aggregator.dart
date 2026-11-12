import '../../../core/services/database/app_database.dart';

/// One day's summed exact seconds — zero-filled when the day has no
/// sessions, so charts never skip a day.
class DayBucket {
  const DayBucket({required this.date, required this.exactSeconds});

  final DateTime date;
  final int exactSeconds;
}

/// Pure day-bucketing for the week bar chart and month heatmap. Every
/// session is attributed to its start day (spec D5) — a midnight-crossing
/// session's full duration lands on the day it started, never split.
class HistoryAggregator {
  /// 7 zero-filled buckets starting at [weekStart] (inclusive), one per day.
  List<DayBucket> week(List<Session> sessions, DateTime weekStart) {
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final days = List.generate(7, (i) => start.add(Duration(days: i)));
    return _bucket(sessions, days);
  }

  /// One zero-filled bucket per day of the month containing [monthStart].
  List<DayBucket> month(List<Session> sessions, DateTime monthStart) {
    final daysInMonth =
        DateTime(monthStart.year, monthStart.month + 1, 0).day;
    final days = List.generate(
      daysInMonth,
      (i) => DateTime(monthStart.year, monthStart.month, i + 1),
    );
    return _bucket(sessions, days);
  }

  List<DayBucket> _bucket(List<Session> sessions, List<DateTime> days) {
    final totals = <DateTime, int>{};
    for (final s in sessions) {
      final day = DateTime(s.date.year, s.date.month, s.date.day);
      totals[day] = (totals[day] ?? 0) + s.durationSeconds;
    }
    return [
      for (final day in days)
        DayBucket(date: day, exactSeconds: totals[day] ?? 0),
    ];
  }
}
