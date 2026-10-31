import 'package:drift/drift.dart';

import '../../../core/services/database/app_database.dart';

/// Reads and writes activities. Activities are archived, never hard-deleted
/// when they have sessions (spec D7); the picker shows only active ones.
class ActivityRepository {
  ActivityRepository(this._db);

  final AppDatabase _db;

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

  Future<void> update(Activity activity) =>
      _db.update(_db.activities).replace(activity);

  /// Hides an activity from the picker; its sessions and totals are preserved.
  Future<void> archive(int id) {
    return (_db.update(_db.activities)..where((a) => a.id.equals(id)))
        .write(const ActivitiesCompanion(archived: Value(true)));
  }

  /// Active (non-archived) activities, name-sorted.
  Future<List<Activity>> activeActivities() => _activeQuery().get();

  /// Live stream of active activities, name-sorted.
  Stream<List<Activity>> watchActive() => _activeQuery().watch();

  SimpleSelectStatement<$ActivitiesTable, Activity> _activeQuery() {
    return _db.select(_db.activities)
      ..where((a) => a.archived.equals(false))
      ..orderBy([(a) => OrderingTerm(expression: a.name)]);
  }
}
