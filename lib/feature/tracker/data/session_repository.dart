import 'package:drift/drift.dart';

import '../../../core/services/database/app_database.dart';

/// Reads and writes work sessions. Stores exact [Session.durationSeconds];
/// rounding is a view only. A session belongs wholly to its start day (D5).
class SessionRepository {
  SessionRepository(this._db);

  final AppDatabase _db;

  /// Inserts an open session (endTime null) and returns its id. [date] is the
  /// start day; [lastSeenAt] seeds to [start] for crash resume (D2).
  Future<int> startSession({
    required int activityId,
    required DateTime start,
  }) {
    return _db.into(_db.sessions).insert(
          SessionsCompanion.insert(
            activityId: activityId,
            date: DateTime(start.year, start.month, start.day),
            startTime: start,
            lastSeenAt: Value(start),
            createdAt: start,
            updatedAt: start,
          ),
        );
  }

  /// Records that the session was still alive at [seenAt] (D2).
  Future<void> touch(int sessionId, DateTime seenAt) {
    return (_db.update(_db.sessions)..where((s) => s.id.equals(sessionId)))
        .write(SessionsCompanion(
      lastSeenAt: Value(seenAt),
      updatedAt: Value(seenAt),
      dirty: const Value(true),
    ));
  }

  /// Closes the session at [end], storing the exact elapsed duration.
  Future<void> closeSession(int sessionId, DateTime end) async {
    final s = await (_db.select(_db.sessions)
          ..where((s) => s.id.equals(sessionId)))
        .getSingle();
    final seconds = end.difference(s.startTime).inSeconds;
    await (_db.update(_db.sessions)..where((s) => s.id.equals(sessionId)))
        .write(SessionsCompanion(
      endTime: Value(end),
      durationSeconds: Value(seconds),
      lastSeenAt: Value(end),
      updatedAt: Value(end),
      dirty: const Value(true),
    ));
  }

  /// Sets the free-text [note] on a session (editing notes is allowed in v1).
  Future<void> setNote(int sessionId, String? note) {
    return (_db.update(_db.sessions)..where((s) => s.id.equals(sessionId)))
        .write(SessionsCompanion(
      note: Value(note),
      updatedAt: Value(DateTime.now()),
      dirty: const Value(true),
    ));
  }

  /// The currently open session (endTime null), if any.
  Future<Session?> openSession() {
    return (_db.select(_db.sessions)..where((s) => s.endTime.isNull()))
        .getSingleOrNull();
  }

  /// Live map of `activityId → summed exact durationSeconds` for closed
  /// sessions whose start day (D5) is the same as [today]. Activities with
  /// no session today are absent from the map.
  Stream<Map<int, int>> watchTodayTotals(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    final total = _db.sessions.durationSeconds.sum();
    final query = _db.selectOnly(_db.sessions)
      ..addColumns([_db.sessions.activityId, total])
      ..where(_db.sessions.date.equals(day) & _db.sessions.endTime.isNotNull())
      ..groupBy([_db.sessions.activityId]);
    return query.watch().map((rows) {
      return {
        for (final row in rows)
          row.read(_db.sessions.activityId)!: row.read(total) ?? 0,
      };
    });
  }
}
