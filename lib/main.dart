import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'core/routing/app_router.dart';
import 'core/services/database/app_database.dart';
import 'core/services/storage_location_service.dart';
import 'core/services/tray_controller.dart';
import 'core/services/window_controller.dart';
import 'core/theme/app_theme.dart';
import 'feature/activities/data/activity_repository.dart';
import 'feature/tracker/data/session_repository.dart';
import 'feature/tracker/service/timer_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final storage = StorageLocationService();
  final dbPath = await storage.resolveDbPath();
  final database = openAppDatabase(dbPath);

  final activityRepository = ActivityRepository(database);
  final sessionRepository = SessionRepository(database);
  final timerEngine = TimerEngine(sessionRepository);

  // Closing the main window hides it; the app lives on in the menu bar.
  final windowController = WindowController(
    onMainWindowClose: windowManager.hide,
  );
  final trayController = TrayController(
    onIconClick: windowController.togglePopover,
    // No activity picker in the tray menu: "Start" opens the popover to choose
    // one; "Stop" ends the running timer directly.
    onStartStop: () {
      if (timerEngine.running != null) {
        timerEngine.stop();
      } else {
        windowController.showPopover();
      }
    },
    onOpenWindow: windowController.showMainWindow,
    onQuit: () async {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    },
  );

  // Launch showing the main window so a pending resume decision (D2) surfaces
  // on a visible window rather than behind a hidden one.
  const windowOptions = WindowOptions(
    size: Size(760, 580),
    center: true,
    title: 'Timer',
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setPreventClose(true);
    await windowManager.show();
    await windowManager.focus();
  });

  windowController.init();
  await trayController.init();
  trayController.bindEngine(
    timerEngine,
    resolveName: (id) async {
      final activities = await activityRepository.activeActivities();
      return activities
          .where((a) => a.id == id)
          .map((a) => a.name)
          .firstOrNull;
    },
  );

  runApp(TimerApp(
    storage: storage,
    database: database,
    activityRepository: activityRepository,
    sessionRepository: sessionRepository,
    timerEngine: timerEngine,
    windowController: windowController,
  ));
}

class TimerApp extends StatefulWidget {
  const TimerApp({
    super.key,
    required this.storage,
    required this.database,
    required this.activityRepository,
    required this.sessionRepository,
    required this.timerEngine,
    required this.windowController,
  });

  final StorageLocationService storage;
  final AppDatabase database;
  final ActivityRepository activityRepository;
  final SessionRepository sessionRepository;
  final TimerEngine timerEngine;
  final WindowController windowController;

  @override
  State<TimerApp> createState() => _TimerAppState();
}

class _TimerAppState extends State<TimerApp> {
  @override
  void initState() {
    super.initState();
    widget.windowController.mode.addListener(_onModeChanged);
  }

  @override
  void dispose() {
    widget.windowController.mode.removeListener(_onModeChanged);
    super.dispose();
  }

  // Swap the Flutter content to match the window shape the controller set.
  void _onModeChanged() {
    final isPopover =
        widget.windowController.mode.value == AppWindowMode.popover;
    appRouter.go(isPopover ? '/popover' : '/');
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<StorageLocationService>.value(value: widget.storage),
        Provider<AppDatabase>.value(value: widget.database),
        Provider<ActivityRepository>.value(value: widget.activityRepository),
        Provider<SessionRepository>.value(value: widget.sessionRepository),
        Provider<WindowController>.value(value: widget.windowController),
        ChangeNotifierProvider<TimerEngine>.value(value: widget.timerEngine),
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
