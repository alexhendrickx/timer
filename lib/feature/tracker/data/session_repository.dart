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
    ));
  }

  /// The currently open session (endTime null), if any.
  Future<Session?> openSession() {
    return (_db.select(_db.sessions)..where((s) => s.endTime.isNull()))
        .getSingleOrNull();
  }
}
