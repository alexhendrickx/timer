import 'package:drift/drift.dart';

import '../../../core/services/database/app_database.dart';

/// Thrown by [ActivityRepository.delete] when the activity still has
/// sessions — callers archive instead (spec D7).
class ActivityHasSessionsError implements Exception {
  const ActivityHasSessionsError(this.activityId);

  final int activityId;

  @override
  String toString() =>
      'ActivityHasSessionsError: activity $activityId has sessions; archive it instead.';
}

/// Reads and writes activities. Activities are archived, never hard-deleted
/// when they have sessions (spec D7); the picker shows only active ones.
class ActivityRepository {
  ActivityRepository(this._db);

  final AppDatabase _db;

  /// True when [id] has no sessions and can be hard-deleted.
  Future<bool> canDelete(int id) async {
    final count = await (_db.selectOnly(_db.sessions)
          ..addColumns([_db.sessions.id.count()])
          ..where(_db.sessions.activityId.equals(id)))
        .map((row) => row.read(_db.sessions.id.count()) ?? 0)
        .getSingle();
    return count == 0;
  }

  /// Removes [id]. Throws [ActivityHasSessionsError] when it has
  /// sessions — the FK's `onDelete: restrict` is the backstop, but this
  /// check gives a clean error instead of a constraint failure.
  ///
  /// Soft-deletes (sets `deletedAt`) rather than a hard SQL delete, so the
  /// removal propagates to other devices through sync (spec Sync —
  /// Deletes/archive) instead of silently vanishing a row sync never saw.
  Future<void> delete(int id) async {
    if (!await canDelete(id)) {
      throw ActivityHasSessionsError(id);
    }
    final now = DateTime.now();
    await (_db.update(_db.activities)..where((a) => a.id.equals(id))).write(
      ActivitiesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
  }

  /// Inserts a new active activity and returns its id.
  Future<int> create({
    required String name,
    int? color,
    double? hourlyRate,
    String? currencyLabel,
  }) {
    return _db.into(_db.activities).insert(
          ActivitiesCompanion.insert(
            name: name,
            color: Value(color),
            hourlyRate: Value(hourlyRate),
            currencyLabel: Value(currencyLabel),
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> update(Activity activity) {
    final now = DateTime.now();
    return _db
        .update(_db.activities)
        .replace(activity.copyWith(updatedAt: now, dirty: true));
  }

  /// Hides an activity from the picker; its sessions and totals are preserved.
  Future<void> archive(int id) {
    final now = DateTime.now();
    return (_db.update(_db.activities)..where((a) => a.id.equals(id))).write(
      ActivitiesCompanion(
        archived: const Value(true),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
  }

  /// Active (non-archived) activities, name-sorted.
  Future<List<Activity>> activeActivities() => _activeQuery().get();

  /// Live stream of active activities, name-sorted.
  Stream<List<Activity>> watchActive() => _activeQuery().watch();

  SimpleSelectStatement<$ActivitiesTable, Activity> _activeQuery() {
    return _db.select(_db.activities)
      ..where((a) => a.archived.equals(false) & a.deletedAt.isNull())
      ..orderBy([(a) => OrderingTerm(expression: a.name)]);
  }
}
