import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/services/database/app_database.dart';
import 'package:timer/feature/activities/data/activity_repository.dart';
import 'package:timer/feature/tracker/data/session_repository.dart';

void main() {
  late AppDatabase db;
  late ActivityRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ActivityRepository(db);
  });

  tearDown(() => db.close());

  test('delete throws ActivityHasSessionsError when sessions exist, '
      'and succeeds once they are gone', () async {
    final id = await repo.create(name: 'Client X');
    final sessions = SessionRepository(db);
    final sessionId = await sessions.startSession(
      activityId: id,
      start: DateTime(2026, 11, 2, 9, 0),
    );
    await sessions.closeSession(sessionId, DateTime(2026, 11, 2, 10, 0));

    expect(await repo.canDelete(id), false);
    expect(
      () => repo.delete(id),
      throwsA(isA<ActivityHasSessionsError>()),
    );

    await (db.delete(db.sessions)..where((s) => s.id.equals(sessionId))).go();

    expect(await repo.canDelete(id), true);
    await repo.delete(id);
    expect(await repo.activeActivities(), isEmpty);
  });

  test('create then activeActivities returns it', () async {
    await repo.create(name: 'Client X');
    final active = await repo.activeActivities();
    expect(active, hasLength(1));
    expect(active.single.name, 'Client X');
  });

  test('archive removes it from activeActivities', () async {
    final id = await repo.create(name: 'Client X');
    await repo.archive(id);
    expect(await repo.activeActivities(), isEmpty);
  });

  test('activeActivities is name-sorted', () async {
    await repo.create(name: 'Beta');
    await repo.create(name: 'Alpha');
    final active = await repo.activeActivities();
    expect(active.map((a) => a.name), ['Alpha', 'Beta']);
  });

  test('watchActive emits active activities excluding archived', () async {
    final id = await repo.create(name: 'Keep');
    await repo.create(name: 'Drop');
    await repo.archive((await repo.activeActivities())
        .firstWhere((a) => a.name == 'Drop')
        .id);
    final names = await repo.watchActive().first;
    expect(names.map((a) => a.name), ['Keep']);
    expect(id, isNotNull);
  });
}
