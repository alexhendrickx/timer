import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/platform/ios/stop_request_applier.dart';
import 'package:timer/core/services/database/app_database.dart';
import 'package:timer/feature/activities/data/activity_repository.dart';
import 'package:timer/feature/tracker/data/session_repository.dart';
import 'package:timer/feature/tracker/service/timer_engine.dart';

/// The request file, kept in memory.
class _RequestFile {
  _RequestFile([this.content]);

  String? content;
  int deletes = 0;

  Future<String?> read() async => content;

  Future<void> delete() async {
    deletes++;
    content = null;
  }
}

/// Session storage that cannot close a session.
class _NoCloseSessions extends SessionRepository {
  _NoCloseSessions(super.db);

  @override
  Future<void> closeSession(int sessionId, DateTime end) async {
    throw StateError('disk full');
  }
}

String _request(int sessionId, DateTime endedAt) => jsonEncode({
      'sessionId': sessionId,
      'endedAt': endedAt.toUtc().toIso8601String(),
    });

void main() {
  late AppDatabase db;
  late SessionRepository sessions;
  late TimerEngine engine;
  late DateTime clock;
  late int a;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    sessions = SessionRepository(db);
    a = await ActivityRepository(db).create(name: 'Client A');
    clock = DateTime(2026, 11, 23, 9, 0);
    engine = TimerEngine(sessions, now: () => clock);
  });

  tearDown(() async {
    await engine.stop();
    engine.dispose();
    await db.close();
  });

  StopRequestApplier applierFor(_RequestFile file) => StopRequestApplier(
        engine: engine,
        read: file.read,
        delete: file.delete,
      );

  test('ends the matching running session at exactly endedAt', () async {
    await engine.start(a);
    clock = DateTime(2026, 11, 23, 9, 45);
    final file = _RequestFile(
      _request(engine.running!.id, DateTime(2026, 11, 23, 9, 30)),
    );

    await applierFor(file).applyPending();

    final s = (await db.select(db.sessions).get()).single;
    expect(s.endTime, DateTime(2026, 11, 23, 9, 30));
    expect(s.durationSeconds, 1800);
    expect(engine.running, isNull);
    expect(file.deletes, 1);
    expect(file.content, isNull);
  });

  test('a request for another session is discarded and deleted', () async {
    await engine.start(a);
    final file = _RequestFile(
      _request(engine.running!.id + 1, DateTime(2026, 11, 23, 9, 30)),
    );

    await applierFor(file).applyPending();

    expect(engine.running, isNotNull);
    expect(await sessions.openSession(), isNotNull);
    expect(file.deletes, 1);
  });

  test('a request with no session running is discarded and deleted', () async {
    final file = _RequestFile(_request(1, DateTime(2026, 11, 23, 9, 30)));

    await applierFor(file).applyPending();

    expect(await db.select(db.sessions).get(), isEmpty);
    expect(file.deletes, 1);
  });

  test('a malformed file is ignored and deleted', () async {
    await engine.start(a);
    final id = engine.running!.id;

    for (final raw in [
      'not json',
      '',
      '[]',
      '{"sessionId":"$id","endedAt":"2026-11-23T08:30:00Z"}',
      '{"sessionId":$id}',
      '{"sessionId":$id,"endedAt":"yesterday"}',
      '{"sessionId":$id.5,"endedAt":"2026-11-23T08:30:00Z"}',
    ]) {
      final file = _RequestFile(raw);

      await applierFor(file).applyPending();

      expect(engine.running!.id, id, reason: raw);
      expect(file.deletes, 1, reason: raw);
    }
  });

  test('no file: nothing happens', () async {
    final file = _RequestFile();
    await engine.start(a);

    await applierFor(file).applyPending();

    expect(engine.running, isNotNull);
    expect(file.deletes, 0);
  });

  test('closes a session a killed app left open, before the resume prompt',
      () async {
    final id = await sessions.startSession(
        activityId: a, start: DateTime(2026, 11, 23, 9, 0));
    final file = _RequestFile(_request(id, DateTime(2026, 11, 23, 11, 0)));

    await applierFor(file).applyPending();

    final s = (await db.select(db.sessions).get()).single;
    expect(s.endTime, DateTime(2026, 11, 23, 11, 0));
    expect(s.durationSeconds, 7200);
    expect(await engine.detectOrphan(), isNull);
    expect(file.deletes, 1);
  });

  test('an end time before the session start is discarded and deleted',
      () async {
    await engine.start(a);
    final file = _RequestFile(
      _request(engine.running!.id, DateTime(2026, 11, 23, 8, 59)),
    );

    await applierFor(file).applyPending();

    expect(engine.running, isNotNull);
    expect(await sessions.openSession(), isNotNull);
    expect(file.deletes, 1);
  });

  test('a request that cannot be applied is kept', () async {
    final id = await sessions.startSession(
        activityId: a, start: DateTime(2026, 11, 23, 9, 0));
    final failing = TimerEngine(_NoCloseSessions(db), now: () => clock);
    addTearDown(failing.dispose);
    final file = _RequestFile(_request(id, DateTime(2026, 11, 23, 9, 30)));

    await StopRequestApplier(
      engine: failing,
      read: file.read,
      delete: file.delete,
    ).applyPending();

    expect(file.deletes, 0);
    expect(file.content, isNotNull);
    expect(await sessions.openSession(), isNotNull);
  });

  test('two triggers at once apply the request once', () async {
    await engine.start(a);
    final file = _RequestFile(
      _request(engine.running!.id, DateTime(2026, 11, 23, 9, 30)),
    );
    final applier = applierFor(file);

    await Future.wait([applier.applyPending(), applier.applyPending()]);

    final s = (await db.select(db.sessions).get()).single;
    expect(s.endTime, DateTime(2026, 11, 23, 9, 30));
    expect(file.deletes, 1);
  });

  test('tryParse reads the native format and returns local time', () {
    final r = StopRequest.tryParse(
      '{"sessionId":7,"endedAt":"2026-11-23T08:30:05.250Z"}',
    )!;

    expect(r.sessionId, 7);
    expect(r.endedAt.isUtc, false);
    expect(
      r.endedAt.isAtSameMomentAs(DateTime.utc(2026, 11, 23, 8, 30, 5, 250)),
      true,
    );
  });
}
