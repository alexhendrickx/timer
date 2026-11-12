import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/services/database/app_database.dart';
import 'package:timer/feature/activities/data/activity_repository.dart';
import 'package:timer/feature/history/data/history_repository.dart';
import 'package:timer/feature/tracker/data/session_repository.dart';

void main() {
  late AppDatabase db;
  late HistoryRepository history;
  late SessionRepository sessions;
  late int activityId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    history = HistoryRepository(db);
    sessions = SessionRepository(db);
    activityId = await ActivityRepository(db).create(name: 'Client X');
  });

  tearDown(() => db.close());

  Future<void> addSession(DateTime start, DateTime end) async {
    final id = await sessions.startSession(activityId: activityId, start: start);
    await sessions.closeSession(id, end);
  }

  test('totals date range matches by start day only', () async {
    // Started Oct 31 23:30, crosses into Nov 1 -> belongs to Oct 31 (D5).
    await addSession(
      DateTime(2026, 10, 31, 23, 30),
      DateTime(2026, 11, 1, 1, 30),
    );
    final oct31Only = DateTimeRange(
      start: DateTime(2026, 10, 31),
      end: DateTime(2026, 10, 31, 23, 59, 59),
    );
    final totals = await history.totals(range: oct31Only);
    expect(totals.single.exactSeconds, 2 * 3600);
  });

  test('empty filter yields empty totals', () async {
    await addSession(DateTime(2026, 10, 31, 9, 0), DateTime(2026, 10, 31, 10, 0));
    final emptyRange = DateTimeRange(
      start: DateTime(2020, 1, 1),
      end: DateTime(2020, 1, 2),
    );
    expect(await history.totals(range: emptyRange), isEmpty);
  });

  test('totals filters by activityId', () async {
    final other = await ActivityRepository(db).create(name: 'Client Y');
    await addSession(DateTime(2026, 10, 31, 9, 0), DateTime(2026, 10, 31, 10, 0));
    final otherId = await sessions.startSession(
        activityId: other, start: DateTime(2026, 10, 31, 11, 0));
    await sessions.closeSession(otherId, DateTime(2026, 10, 31, 11, 30));

    final totals = await history.totals(activityId: activityId);
    expect(totals.single.activityId, activityId);
    expect(totals.single.exactSeconds, 3600);
  });

  test('setNote delegates to the session', () async {
    final id = await sessions.startSession(
        activityId: activityId, start: DateTime(2026, 10, 31, 9, 0));
    await sessions.closeSession(id, DateTime(2026, 10, 31, 10, 0));
    await history.setNote(id, 'Edited note');
    final s = await (db.select(db.sessions)..where((s) => s.id.equals(id))).getSingle();
    expect(s.note, 'Edited note');
  });

  test('watch streams sessions filtered by activityId and range', () async {
    await addSession(DateTime(2026, 10, 31, 9, 0), DateTime(2026, 10, 31, 10, 0));
    final range = DateTimeRange(
      start: DateTime(2026, 10, 31),
      end: DateTime(2026, 10, 31, 23, 59, 59),
    );
    final result = await history
        .watch(activityId: activityId, range: range)
        .first;
    expect(result.length, 1);
  });
}
