import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/routing/app_router.dart';
import 'core/services/database/app_database.dart';
import 'core/services/storage_location_service.dart';
import 'core/theme/app_theme.dart';
import 'feature/activities/data/activity_repository.dart';
import 'feature/tracker/data/session_repository.dart';
import 'feature/tracker/service/start_coordinator.dart';
import 'feature/tracker/service/timer_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageLocationService();
  final dbPath = await storage.resolveDbPath();
  final database = openAppDatabase(dbPath);

  final activityRepository = ActivityRepository(database);
  final sessionRepository = SessionRepository(database);
  final timerEngine = TimerEngine(sessionRepository);

  runApp(TimerApp(
    storage: storage,
    database: database,
    activityRepository: activityRepository,
    sessionRepository: sessionRepository,
    timerEngine: timerEngine,
  ));
}

class TimerApp extends StatelessWidget {
  const TimerApp({
    super.key,
    required this.storage,
    required this.database,
    required this.activityRepository,
    required this.sessionRepository,
    required this.timerEngine,
  });

  final StorageLocationService storage;
  final AppDatabase database;
  final ActivityRepository activityRepository;
  final SessionRepository sessionRepository;
  final TimerEngine timerEngine;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<StorageLocationService>.value(value: storage),
        Provider<AppDatabase>.value(value: database),
        Provider<ActivityRepository>.value(value: activityRepository),
        Provider<SessionRepository>.value(value: sessionRepository),
        ChangeNotifierProvider<TimerEngine>.value(value: timerEngine),
        Provider<StartCoordinator>.value(
          value: StartCoordinator(timerEngine),
        ),
      ],
      child: MaterialApp.router(
        title: 'Timer',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        routerConfig: appRouter,
      ),
    );
  }
}
