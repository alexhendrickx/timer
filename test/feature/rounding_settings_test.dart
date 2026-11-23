import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timer/core/services/database/app_database.dart';
import 'package:timer/feature/activities/data/activity_repository.dart';
import 'package:timer/feature/history/data/history_repository.dart';
import 'package:timer/feature/settings/data/rounding_settings.dart';
import 'package:timer/feature/tracker/data/session_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to 900 seconds (15 min)', () {
    expect(RoundingSettings().stepSeconds, 900);
  });

  test('save then load round-trips the step', () async {
    final settings = RoundingSettings();
    settings.stepSeconds = 1800;
    await settings.save();

    final reloaded = RoundingSettings();
    await reloaded.load();
    expect(reloaded.stepSeconds, 1800);
  });

  test('changing the step never alters a stored session duration', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final activityId = await ActivityRepository(db).create(name: 'Client X');
    final sessions = SessionRepository(db);
    final id = await sessions.startSession(
        activityId: activityId, start: DateTime(2026, 11, 1, 9, 0));
    await sessions.closeSession(id, DateTime(2026, 11, 1, 10, 7));

    final before = await (db.select(db.sessions)..where((s) => s.id.equals(id)))
        .getSingle();

    final settings = RoundingSettings();
    settings.stepSeconds = 1800;
    await settings.save();

    final after = await (db.select(db.sessions)..where((s) => s.id.equals(id)))
        .getSingle();
    expect(after.durationSeconds, before.durationSeconds);

    // And the repository's totals still carry the exact seconds alongside
    // the newly-stepped rounded total.
    final totals = await HistoryRepository(db).totals(
      activityId: activityId,
      stepSeconds: settings.stepSeconds,
    );
    expect(totals.single.exactSeconds, before.durationSeconds);

    await db.close();
  });
}
