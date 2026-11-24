import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/services/database/app_database.dart';
import 'package:timer/feature/activities/data/activity_repository.dart';
import 'package:timer/feature/tracker/data/session_repository.dart';
import 'package:timer/feature/tracker/service/timer_engine.dart';

/// Session storage that cannot open a new session.
class _NoStartSessions extends SessionRepository {
  _NoStartSessions(super.db);

  @override
  Future<int> startSession({
    required int activityId,
    required DateTime start,
  }) async {
    throw StateError('disk full');
  }
}

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

  test('stopSessionAt closes the running session at the given time, not now',
      () async {
    var clock = DateTime(2026, 11, 23, 9, 0, 0);
    final engine = TimerEngine(repo, now: () => clock);
    await engine.start(a);
    final id = engine.running!.id;
    clock = DateTime(2026, 11, 23, 9, 45, 0);

    final applied =
        await engine.stopSessionAt(id, DateTime(2026, 11, 23, 9, 30));

    expect(applied, true);
    final s = (await db.select(db.sessions).get()).single;
    expect(s.endTime, DateTime(2026, 11, 23, 9, 30));
    expect(s.durationSeconds, 1800);
    expect(engine.running, isNull);
    engine.dispose();
  });

  test('stopSessionAt for another session changes nothing', () async {
    final engine = TimerEngine(repo, now: () => DateTime(2026, 11, 23, 9, 0));
    await engine.start(a);
    final id = engine.running!.id;

    final applied =
        await engine.stopSessionAt(id + 1, DateTime(2026, 11, 23, 9, 30));

    expect(applied, false);
    expect(engine.running!.id, id);
    expect((await repo.openSession())!.id, id);
    await engine.stop();
    engine.dispose();
  });

  test('stopSessionAt with nothing open returns false', () async {
    final engine = TimerEngine(repo, now: () => DateTime(2026, 11, 23, 9, 0));

    final applied =
        await engine.stopSessionAt(1, DateTime(2026, 11, 23, 9, 30));

    expect(applied, false);
    expect(await db.select(db.sessions).get(), isEmpty);
    engine.dispose();
  });

  test(
      'stopSessionAt closes a session the engine has not adopted, and no '
      'resume prompt follows', () async {
    final id = await repo.startSession(
        activityId: a, start: DateTime(2026, 11, 23, 9, 0));
    final engine = TimerEngine(repo, now: () => DateTime(2026, 11, 23, 12, 0));

    final applied =
        await engine.stopSessionAt(id, DateTime(2026, 11, 23, 11, 0));

    expect(applied, true);
    final s = (await db.select(db.sessions).get()).single;
    expect(s.endTime, DateTime(2026, 11, 23, 11, 0));
    expect(s.durationSeconds, 7200);
    expect(await engine.detectOrphan(), isNull);
    engine.dispose();
  });

  test('stopSessionAt refuses an end time before the session start', () async {
    final engine = TimerEngine(repo, now: () => DateTime(2026, 11, 23, 9, 0));
    await engine.start(a);
    final id = engine.running!.id;

    final applied =
        await engine.stopSessionAt(id, DateTime(2026, 11, 23, 8, 59));

    expect(applied, false);
    expect(engine.running!.id, id);
    expect((await repo.openSession())!.id, id);
    await engine.stop();
    engine.dispose();
  });

  test(
      'switchTo closes the old session, opens the new one, and is idle only '
      'while switching', () async {
    final b = await ActivityRepository(db).create(name: 'Client Y');
    final engine = TimerEngine(repo, now: () => DateTime(2026, 11, 23, 9, 0));
    await engine.start(a);
    final switchingWhenIdle = <bool>[];
    engine.addListener(() {
      if (engine.running == null) switchingWhenIdle.add(engine.isSwitching);
    });

    await engine.switchTo(b);

    expect(engine.running!.activityId, b);
    expect(engine.isSwitching, false);
    expect(switchingWhenIdle, [true]);
    final rows = await db.select(db.sessions).get();
    expect(rows, hasLength(2));
    expect(rows.where((s) => s.endTime == null), hasLength(1));
    await engine.stop();
    engine.dispose();
  });

  test('switchTo that cannot start ends idle and says so', () async {
    await repo.startSession(
        activityId: a, start: DateTime(2026, 11, 23, 9, 0));
    final engine = TimerEngine(
      _NoStartSessions(db),
      now: () => DateTime(2026, 11, 23, 10, 0),
    );
    await engine.detectOrphan();
    await engine.resumeKeepRunning();
    final switchingWhenIdle = <bool>[];
    engine.addListener(() {
      if (engine.running == null) switchingWhenIdle.add(engine.isSwitching);
    });

    await expectLater(engine.switchTo(a), throwsStateError);

    expect(engine.running, isNull);
    expect(engine.isSwitching, false);
    expect(switchingWhenIdle.last, false);
    engine.dispose();
  });

  test(
      'a Live Activity stop while the resume prompt is up settles it: '
      'stop-at-last-seen cannot close a session started since', () async {
    final b = await ActivityRepository(db).create(name: 'Client Y');
    final orphanId = await repo.startSession(
        activityId: a, start: DateTime(2026, 11, 23, 9, 0));
    var clock = DateTime(2026, 11, 23, 12, 0);
    final engine = TimerEngine(repo, now: () => clock);

    expect(await engine.detectOrphan(), isNotNull);
    expect(
      await engine.stopSessionAt(orphanId, DateTime(2026, 11, 23, 11, 0)),
      true,
    );
    await engine.start(b);
    final startedId = engine.running!.id;
    clock = DateTime(2026, 11, 23, 12, 30);
    await engine.resumeStopAtLastSeen();

    expect(engine.running!.id, startedId);
    final open = (await repo.openSession())!;
    expect(open.id, startedId);
    expect(open.activityId, b);
    final rows = await db.select(db.sessions).get();
    final orphan = rows.singleWhere((s) => s.id == orphanId);
    expect(orphan.endTime, DateTime(2026, 11, 23, 11, 0));
    expect(orphan.durationSeconds, 7200);
    // Not closed at the orphan's lastSeenAt (a negative duration).
    final started = rows.singleWhere((s) => s.id == startedId);
    expect(started.endTime, isNull);
    expect(started.durationSeconds, 0);
    await engine.stop();
    engine.dispose();
  });

  test('stop-at-last-seen leaves a session the prompt was not about alone',
      () async {
    final orphanId = await repo.startSession(
        activityId: a, start: DateTime(2026, 11, 23, 9, 0));
    final engine = TimerEngine(repo, now: () => DateTime(2026, 11, 23, 12, 0));
    await engine.detectOrphan();
    // Closed and replaced behind the engine's back.
    await repo.closeSession(orphanId, DateTime(2026, 11, 23, 10, 0));
    final otherId = await repo.startSession(
        activityId: a, start: DateTime(2026, 11, 23, 11, 0));

    await engine.resumeStopAtLastSeen();

    final open = (await repo.openSession())!;
    expect(open.id, otherId);
    expect(open.endTime, isNull);
    engine.dispose();
  });

  test('keep-going does not adopt a session the prompt was not about',
      () async {
    final orphanId = await repo.startSession(
        activityId: a, start: DateTime(2026, 11, 23, 9, 0));
    final engine = TimerEngine(repo, now: () => DateTime(2026, 11, 23, 12, 0));
    await engine.detectOrphan();
    await repo.closeSession(orphanId, DateTime(2026, 11, 23, 10, 0));
    await repo.startSession(
        activityId: a, start: DateTime(2026, 11, 23, 11, 0));

    await engine.resumeKeepRunning();

    expect(engine.running, isNull);
    engine.dispose();
  });
}
