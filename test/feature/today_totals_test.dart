import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/services/database/app_database.dart';
import 'package:timer/feature/activities/data/activity_repository.dart';
import 'package:timer/feature/tracker/data/session_repository.dart';
import 'package:timer/feature/tracker/presentation/widgets/focus_card.dart';
import 'package:timer/feature/tracker/service/timer_engine.dart';

void main() {
  late AppDatabase db;
  late SessionRepository repo;
  late int a;
  late int b;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = SessionRepository(db);
    final activityRepo = ActivityRepository(db);
    a = await activityRepo.create(name: 'Client A');
    b = await activityRepo.create(name: 'Client B');
  });

  tearDown(() => db.close());

  test('watchTodayTotals sums closed sessions by activity for the start day',
      () async {
    // activity a: two closed sessions today of 1200s + 600s.
    final s1 = await repo.startSession(
        activityId: a, start: DateTime(2026, 11, 2, 9, 0));
    await repo.closeSession(s1, DateTime(2026, 11, 2, 9, 20));
    final s2 = await repo.startSession(
        activityId: a, start: DateTime(2026, 11, 2, 10, 0));
    await repo.closeSession(s2, DateTime(2026, 11, 2, 10, 10));
    // activity b: 900s today.
    final s3 = await repo.startSession(
        activityId: b, start: DateTime(2026, 11, 2, 11, 0));
    await repo.closeSession(s3, DateTime(2026, 11, 2, 11, 15));
    // one closed session for a dated yesterday (must be excluded).
    final s4 = await repo.startSession(
        activityId: a, start: DateTime(2026, 11, 1, 8, 0));
    await repo.closeSession(s4, DateTime(2026, 11, 1, 9, 0));

    final totals = await repo.watchTodayTotals(DateTime(2026, 11, 2, 10)).first;
    expect(totals[a], 1800);
    expect(totals[b], 900);
  });

  test('midnight-crossing closed session counts on its start day only',
      () async {
    // started 2026-11-01 23:30, closed 2026-11-02 01:30 (date = 2026-11-01).
    final id = await repo.startSession(
        activityId: a, start: DateTime(2026, 11, 1, 23, 30));
    await repo.closeSession(id, DateTime(2026, 11, 2, 1, 30));

    final today = await repo.watchTodayTotals(DateTime(2026, 11, 2, 9)).first;
    expect(today.containsKey(a), isFalse);
  });

  test('ringFraction is the share of total and clamps', () {
    expect(ringFraction(1800, 3600), 0.5);
    expect(ringFraction(0, 0), 0.0);
    expect(ringFraction(5000, 3600), 1.0);
  });

  test('after Stop the session counts once in todayTotals — no double-count',
      () async {
    // A card's live total = closed totals + live elapsed (added only while
    // running). This asserts the data-layer invariant the UI composes on:
    // once stopped, the session lands in watchTodayTotals exactly once, so the
    // card (live part now 0) shows the same seconds — not twice.
    var clock = DateTime(2026, 11, 2, 9, 0, 0);
    final engine = TimerEngine(repo, now: () => clock);
    await engine.start(a);
    clock = DateTime(2026, 11, 2, 9, 10, 0); // 600s elapsed
    await engine.stop();

    final totals = await repo.watchTodayTotals(DateTime(2026, 11, 2, 9)).first;
    expect(totals[a], 600);
    engine.dispose();
  });
}
