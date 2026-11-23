import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../../../core/services/database/app_database.dart';
import '../service/totals_calculator.dart';

/// Reads session history for the drill-down views and reports, filtered by
/// activity and/or date range. Range filtering matches a session's start
/// day (spec D5) regardless of time-of-day, so a midnight-crossing session
/// is matched (or excluded) as a whole by the day it started.
class HistoryRepository {
  HistoryRepository(this._db);

  final AppDatabase _db;

  /// Live list of sessions matching [activityId] and/or [range] (by start
  /// day), most recent first.
  Stream<List<Session>> watch({int? activityId, DateTimeRange? range}) {
    return _filtered(activityId: activityId, range: range).watch();
  }

  /// Per-activity totals over [range] (and optionally one [activityId]),
  /// rounded at [stepSeconds] (sum-then-round, spec D4). Activities with no
  /// matching sessions are absent.
  Future<List<ActivityTotal>> totals({
    DateTimeRange? range,
    int? activityId,
    int stepSeconds = 900,
  }) async {
    final sessions =
        await _filtered(activityId: activityId, range: range).get();
    if (sessions.isEmpty) return [];

    final byActivity = <int, List<Session>>{};
    for (final s in sessions) {
      byActivity.putIfAbsent(s.activityId, () => []).add(s);
    }

    final activities = await _db.select(_db.activities).get();
    final activityById = {for (final a in activities) a.id: a};

    return [
      for (final entry in byActivity.entries)
        if (activityById[entry.key] != null)
          TotalsCalculator.forGroup(
            entry.value,
            activityById[entry.key]!,
            stepSeconds: stepSeconds,
          ),
    ];
  }

  /// Edits a session's free-text note (day-list rows are editable).
  Future<void> setNote(int sessionId, String? note) {
    return (_db.update(_db.sessions)..where((s) => s.id.equals(sessionId)))
        .write(SessionsCompanion(
      note: Value(note),
      updatedAt: Value(DateTime.now()),
    ));
  }

  SimpleSelectStatement<$SessionsTable, Session> _filtered({
    int? activityId,
    DateTimeRange? range,
  }) {
    final query = _db.select(_db.sessions)
      ..orderBy([(s) => OrderingTerm.desc(s.date)]);
    if (activityId != null) {
      query.where((s) => s.activityId.equals(activityId));
    }
    if (range != null) {
      final start = DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(range.end.year, range.end.month, range.end.day);
      query.where((s) => s.date.isBetweenValues(start, end));
    }
    return query;
  }
}
