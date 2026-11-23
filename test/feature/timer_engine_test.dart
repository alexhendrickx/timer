import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/services/database/app_database.dart';
import 'package:timer/feature/activities/data/activity_repository.dart';
import 'package:timer/feature/tracker/data/session_repository.dart';
import 'package:timer/feature/tracker/service/timer_engine.dart';

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

  test('detectOrphan offers stop-at-lastSeen for a stale open session',
      () async {
    final engine = TimerEngine(repo, now: () => DateTime(2026, 10, 31, 17, 0));
    final id = await repo.startSession(
        activityId: a, start: DateTime(2026, 10, 31, 9, 0));
    await repo.touch(id, DateTime(2026, 10, 31, 17, 0));

    final d = await engine.detectOrphan();
    expect(d!.lastSeenAt, DateTime(2026, 10, 31, 17, 0));
    expect(d.start, DateTime(2026, 10, 31, 9, 0));

    await engine.resumeStopAtLastSeen();
    final s = (await db.select(db.sessions).get()).single;
    expect(s.endTime, DateTime(2026, 10, 31, 17, 0));
    expect(engine.running, isNull);
    engine.dispose();
  });

  test('detectOrphan returns null when no open session', () async {
    final engine = TimerEngine(repo, now: () => DateTime(2026, 10, 31));
    expect(await engine.detectOrphan(), isNull);
    engine.dispose();
  });

  test('stop with no running timer is a no-op', () async {
    final engine = TimerEngine(repo, now: () => DateTime(2026, 10, 31));
    await engine.stop();
    expect(engine.running, isNull);
    engine.dispose();
  });

  test('start records an open session and reports elapsed', () async {
    var clock = DateTime(2026, 10, 31, 9, 0, 0);
    final engine = TimerEngine(repo, now: () => clock);
    await engine.start(a);
    expect(engine.running, isNotNull);
    clock = DateTime(2026, 10, 31, 9, 0, 30);
    expect(engine.elapsed, const Duration(seconds: 30));
    await engine.stop();
    final s = (await db.select(db.sessions).get()).single;
    expect(s.durationSeconds, 30);
    expect(engine.running, isNull);
    engine.dispose();
  });

  test('start while already running throws StateError', () async {
    final engine = TimerEngine(repo, now: () => DateTime(2026, 10, 31, 9, 0));
    await engine.start(a);
    expect(() => engine.start(a), throwsStateError);
    await engine.stop();
    engine.dispose();
  });

  test('detectOrphan acts only once per app run (no re-prompt after resume)',
      () async {
    await repo.startSession(activityId: a, start: DateTime(2026, 10, 31, 9, 0));
    final engine = TimerEngine(repo, now: () => DateTime(2026, 10, 31, 17, 0));

    final first = await engine.detectOrphan();
    expect(first, isNotNull);
    await engine.resumeKeepRunning();

    // A Home remount (navigate away and back) calls detectOrphan again; it
    // must NOT prompt over the live, still-open session.
    expect(await engine.detectOrphan(), isNull);

    await engine.stop();
    engine.dispose();
  });

  test('start refuses to open a second session when one is open in the DB',
      () async {
    await repo.startSession(activityId: a, start: DateTime(2026, 10, 31, 9, 0));
    final engine = TimerEngine(repo, now: () => DateTime(2026, 10, 31, 10, 0));

    // Engine has no in-memory running session, but the DB holds an orphan.
    await expectLater(() => engine.start(a), throwsStateError);
    final openRows = await (db.select(db.sessions)
          ..where((s) => s.endTime.isNull()))
        .get();
    expect(openRows, hasLength(1));
    engine.dispose();
  });

  test('currentSessionId is the running session, then the last stopped one',
      () async {
    final engine = TimerEngine(repo, now: () => DateTime(2026, 10, 31, 9, 0));
    expect(engine.currentSessionId, isNull);
    await engine.start(a);
    final runningId = engine.running!.id;
    expect(engine.currentSessionId, runningId);
    await engine.stop();
    expect(engine.currentSessionId, runningId);
    engine.dispose();
  });

  test('resumeKeepRunning keeps the open session running', () async {
    var clock = DateTime(2026, 10, 31, 17, 0);
    final engine = TimerEngine(repo, now: () => clock);
    await repo.startSession(activityId: a, start: DateTime(2026, 10, 31, 9, 0));
    final d = await engine.detectOrphan();
    expect(d, isNotNull);
    await engine.resumeKeepRunning();
    expect(engine.running, isNotNull);
    expect(await repo.openSession(), isNotNull);
    await engine.stop();
    engine.dispose();
  });
}
