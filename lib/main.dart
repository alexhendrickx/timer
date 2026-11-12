import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'core/platform/mac/hotkey_controller.dart';
import 'core/platform/mac/mac_platform_shell.dart';
import 'core/platform/mac/mac_routes.dart';
import 'core/platform/mac/tray_controller.dart';
import 'core/platform/mac/window_controller.dart';
import 'core/platform/platform_shell.dart';
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

  // NoopPlatformShell is the default (and the iOS placeholder until v0.5);
  // macOS swaps in the real shell below. This is the one seam that branches
  // by platform — screens never do.
  PlatformShell shell = NoopPlatformShell();
  WindowController? windowController;

  if (Platform.isMacOS) {
    await windowManager.ensureInitialized();

    final wc = WindowController(onMainWindowClose: windowManager.hide);
    final tc = TrayController(
      onIconClick: wc.togglePopover,
      // No activity picker in the tray menu: "Start" opens the popover to
      // choose one; "Stop" ends the running timer directly.
      onStartStop: () {
        if (timerEngine.running != null) {
          timerEngine.stop();
        } else {
          wc.showPopover();
        }
      },
      onOpenWindow: wc.showMainWindow,
      onQuit: () async {
        await windowManager.setPreventClose(false);
        await windowManager.destroy();
      },
    );
    final macShell = MacPlatformShell(
      tray: tc,
      window: wc,
      hotkey: HotkeyController(),
    );

    // Launch showing the main window so a pending resume decision (D2)
    // surfaces on a visible window, never behind a hidden one or the popover.
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

    // Wires tray + window + the global hotkey (Review Focus: a hotkey
    // registration failure is logged once inside HotkeyController and must
    // not stop the rest of the shell from working).
    await macShell.init();
    tc.bindEngine(
      timerEngine,
      resolveName: (id) async {
        final activities = await activityRepository.activeActivities();
        return activities.where((a) => a.id == id).map((a) => a.name).firstOrNull;
      },
    );

    shell = macShell;
    windowController = wc;
  }

  // The seam itself: core routing (app_router.dart) carries no platform-UI
  // imports; macOS is the only platform that registers extra routes today.
  final router = buildAppRouter(
    platformRoutes: windowController != null ? macRoutes(windowController) : const [],
  );

  runApp(TimerApp(
    storage: storage,
    database: database,
    activityRepository: activityRepository,
    sessionRepository: sessionRepository,
    timerEngine: timerEngine,
    shell: shell,
    router: router,
    windowController: windowController,
  ));
}

class TimerApp extends StatefulWidget {
  TimerApp({
    super.key,
    required this.storage,
    required this.database,
    required this.activityRepository,
    required this.sessionRepository,
    required this.timerEngine,
    PlatformShell? shell,
    GoRouter? router,
    this.windowController,
  })  : shell = shell ?? NoopPlatformShell(),
        router = router ?? buildAppRouter();

  final StorageLocationService storage;
  final AppDatabase database;
  final ActivityRepository activityRepository;
  final SessionRepository sessionRepository;
  final TimerEngine timerEngine;
  final PlatformShell shell;
  final GoRouter router;

  /// Only set on macOS — drives which face (main / popover / picker) the
  /// single native window shows.
  final WindowController? windowController;

  @override
  State<TimerApp> createState() => _TimerAppState();
}

class _TimerAppState extends State<TimerApp> {
  @override
  void initState() {
    super.initState();
    widget.windowController?.mode.addListener(_onModeChanged);
  }

  @override
  void dispose() {
    widget.windowController?.mode.removeListener(_onModeChanged);
    super.dispose();
  }

  // Swap the Flutter content to match the window shape the controller set.
  void _onModeChanged() {
    switch (widget.windowController!.mode.value) {
      case AppWindowMode.popover:
        widget.router.go('/popover');
      case AppWindowMode.picker:
        widget.router.go('/picker');
      case AppWindowMode.main:
        widget.router.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<StorageLocationService>.value(value: widget.storage),
        Provider<AppDatabase>.value(value: widget.database),
        Provider<ActivityRepository>.value(value: widget.activityRepository),
        Provider<SessionRepository>.value(value: widget.sessionRepository),
        ChangeNotifierProvider<TimerEngine>.value(value: widget.timerEngine),
        Provider<StartCoordinator>.value(
          value: StartCoordinator(widget.timerEngine),
        ),
        Provider<PlatformShell>.value(value: widget.shell),
        if (widget.windowController != null)
          Provider<WindowController>.value(value: widget.windowController!),
      ],
      child: MaterialApp.router(
        title: 'Timer',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        routerConfig: widget.router,
      ),
    );
  }
}
