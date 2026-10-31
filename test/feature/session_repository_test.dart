import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/services/database/app_database.dart';
import 'package:timer/feature/activities/data/activity_repository.dart';
import 'package:timer/feature/tracker/data/session_repository.dart';

void main() {
  late AppDatabase db;
  late SessionRepository repo;
  late int a;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = SessionRepository(db);
    a = await ActivityRepository(db).create(name: 'Client X');
  });

  tearDown(() => db.close());

  test('start writes an open session with date = start day', () async {
    await repo.startSession(activityId: a, start: DateTime(2026, 10, 31, 23, 30));
    final s = await repo.openSession();
    expect(s!.endTime, isNull);
    expect(s.date, DateTime(2026, 10, 31));
    expect(s.lastSeenAt, DateTime(2026, 10, 31, 23, 30));
  });

  test('session across midnight keeps start day and full duration', () async {
    final id = await repo.startSession(
        activityId: a, start: DateTime(2026, 10, 31, 23, 30));
    await repo.closeSession(id, DateTime(2026, 11, 1, 1, 30));
    final s = (await db.select(db.sessions).get()).single;
    expect(s.date, DateTime(2026, 10, 31));
    expect(s.durationSeconds, 2 * 3600);
    expect(s.endTime, DateTime(2026, 11, 1, 1, 30));
  });

  test('openSession returns null when none open', () async {
    final id = await repo.startSession(
        activityId: a, start: DateTime(2026, 10, 31, 9, 0));
    await repo.closeSession(id, DateTime(2026, 10, 31, 10, 0));
    expect(await repo.openSession(), isNull);
  });

  test('touch updates lastSeenAt', () async {
    final id = await repo.startSession(
        activityId: a, start: DateTime(2026, 10, 31, 9, 0));
    await repo.touch(id, DateTime(2026, 10, 31, 9, 30));
    final s = await repo.openSession();
    expect(s!.lastSeenAt, DateTime(2026, 10, 31, 9, 30));
  });
}
