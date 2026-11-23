import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/platform/ios/quick_start_intent_handler.dart';
import 'package:timer/core/routing/app_router.dart';
import 'package:timer/core/services/database/app_database.dart';
import 'package:timer/feature/activities/data/activity_repository.dart';
import 'package:timer/feature/tracker/data/session_repository.dart';
import 'package:timer/feature/tracker/service/start_coordinator.dart';
import 'package:timer/feature/tracker/service/timer_engine.dart';

void main() {
  late AppDatabase db;
  late ActivityRepository activityRepository;
  late TimerEngine engine;
  late StartCoordinator coordinator;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    activityRepository = ActivityRepository(db);
    engine = TimerEngine(SessionRepository(db));
    coordinator = StartCoordinator(engine);
  });

  tearDown(() async {
    engine.dispose();
    await db.close();
  });

  QuickStartIntentHandler buildHandler() {
    final router = buildAppRouter();
    return QuickStartIntentHandler(
      router: router,
      coordinator: coordinator,
      activityRepository: activityRepository,
    );
  }

  test('null activityId opens the picker', () async {
    final handler = buildHandler();

    await handler.handle(const QuickStartIntent(activityId: null));

    expect(
      handler.router.routeInformationProvider.value.uri.toString(),
      '/quick-start',
    );
  });

  test('unknown activityId falls back to the picker', () async {
    final handler = buildHandler();

    await handler.handle(const QuickStartIntent(activityId: 999));

    expect(
      handler.router.routeInformationProvider.value.uri.toString(),
      '/quick-start',
    );
  });

  test('valid activityId starts via the coordinator', () async {
    final a = await activityRepository.create(name: 'Client X');
    final handler = buildHandler();

    await handler.handle(QuickStartIntent(activityId: a));

    expect(engine.running!.activityId, a);
    expect(
      handler.router.routeInformationProvider.value.uri.toString(),
      '/running',
    );
  });

  test('archived activityId falls back to the picker, not a bad session',
      () async {
    final a = await activityRepository.create(name: 'Old client');
    await activityRepository.archive(a);
    final handler = buildHandler();

    await handler.handle(QuickStartIntent(activityId: a));

    expect(engine.running, isNull);
    expect(
      handler.router.routeInformationProvider.value.uri.toString(),
      '/quick-start',
    );
  });

  test('activityId that needs a D1 switch confirm falls back to the picker',
      () async {
    final x = await activityRepository.create(name: 'X');
    final y = await activityRepository.create(name: 'Y');
    await engine.start(x);
    final handler = buildHandler();

    await handler.handle(QuickStartIntent(activityId: y));

    // Never silently switches: X is still running, Y did not start.
    expect(engine.running!.activityId, x);
    expect(
      handler.router.routeInformationProvider.value.uri.toString(),
      '/quick-start',
    );
  });
}
