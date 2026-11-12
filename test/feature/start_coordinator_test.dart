import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/services/database/app_database.dart';
import 'package:timer/feature/activities/data/activity_repository.dart';
import 'package:timer/feature/tracker/data/session_repository.dart';
import 'package:timer/feature/tracker/service/start_coordinator.dart';
import 'package:timer/feature/tracker/service/timer_engine.dart';

void main() {
  late AppDatabase db;
  late SessionRepository repo;
  late TimerEngine engine;
  late StartCoordinator coord;
  late int a;
  late int b;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = SessionRepository(db);
    final activityRepo = ActivityRepository(db);
    a = await activityRepo.create(name: 'Client A');
    b = await activityRepo.create(name: 'Client B');
    engine = TimerEngine(repo, now: () => DateTime(2026, 11, 2, 9, 0));
    coord = StartCoordinator(engine);
  });

  tearDown(() async {
    await engine.stop();
    engine.dispose();
    await db.close();
  });

  test('start with nothing running starts immediately', () async {
    final outcome = await coord.requestStart(a);
    expect(outcome.kind, StartKind.started);
    expect(engine.running!.activityId, a);
  });

  test('tapping the running activity is a no-op', () async {
    await coord.requestStart(a); // a running
    final outcome = await coord.requestStart(a);
    expect(outcome.kind, StartKind.alreadyRunning);
    expect(engine.running!.activityId, a);
  });

  test('tapping a different activity asks to switch, then switches on confirm',
      () async {
    await coord.requestStart(a);
    final outcome = await coord.requestStart(b);
    expect(outcome.kind, StartKind.needsSwitchConfirm);
    expect(outcome.runningActivityId, a);
    await coord.confirmSwitch(b);
    expect(engine.running!.activityId, b);
  });

  test('concurrent requestStart does not throw or open two sessions', () async {
    // Two near-simultaneous card taps both observe nothing running before the
    // first start's DB write lands. Must not crash or open a second session.
    final f1 = coord.requestStart(a);
    final f2 = coord.requestStart(b);
    await Future.wait([f1, f2]);

    final open = await (db.select(db.sessions)
          ..where((s) => s.endTime.isNull()))
        .get();
    expect(open, hasLength(1));
  });
}
