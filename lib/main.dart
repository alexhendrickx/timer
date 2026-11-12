import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'core/platform/ios/app_group_storage.dart';
import 'core/platform/ios/deep_link_listener.dart';
import 'core/platform/ios/ios_platform_shell.dart';
import 'core/platform/ios/quick_start_intent_handler.dart';
import 'core/platform/ios/widget_snapshot_writer.dart';
import 'core/platform/mac/hotkey_controller.dart';
import 'core/platform/mac/mac_platform_shell.dart';
import 'core/platform/mac/mac_routes.dart';
import 'core/platform/mac/tray_controller.dart';
import 'core/platform/mac/window_controller.dart';
import 'core/platform/platform_shell.dart';
import 'core/routing/app_router.dart';
import 'core/services/database/app_database.dart';
import 'core/services/notifications_service.dart';
import 'core/services/storage_location_service.dart';
import 'core/theme/app_theme.dart';
import 'feature/activities/data/activity_repository.dart';
import 'feature/history/data/history_repository.dart';
import 'feature/settings/data/reminder_settings.dart';
import 'feature/tracker/data/session_repository.dart';
import 'feature/tracker/service/reminder_scheduler.dart';
import 'feature/tracker/service/start_coordinator.dart';
import 'feature/tracker/service/timer_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageLocationService();
  final dbPath = await storage.resolveDbPath();
  final database = openAppDatabase(dbPath);

  final activityRepository = ActivityRepository(database);
  final sessionRepository = SessionRepository(database);
  final historyRepository = HistoryRepository(database);
  final timerEngine = TimerEngine(sessionRepository);
  // Built once and shared (not re-created per rebuild) so its in-flight
  // start guard (D1) actually dedups races — the iOS intent handler below
  // and the UI screens must share this one instance.
  final startCoordinator = StartCoordinator(timerEngine);

  // NoopPlatformShell is the default (and the iOS placeholder until v0.5);
  // macOS swaps in the real shell below. This is the one seam that branches
  // by platform — screens never do.
  PlatformShell shell = NoopPlatformShell();
  WindowController? windowController;
  // Assigned once buildAppRouter runs below; the tray's "Activities…" item
  // (Mac-only) closes over this to navigate after raising the main window.
  late final GoRouter router;

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
      onActivities: () async {
        await wc.showMainWindow();
        router.go('/activities');
      },
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
  router = buildAppRouter(
    platformRoutes: windowController != null ? macRoutes(windowController) : const [],
  );

  // Break reminders: platform-free scheduler + the real notifications
  // adapter. A denied permission never blocks tracking or the in-app
  // overlay (Review Focus) — `init()` just logs and the fallback notification
  // stays silent.
  final reminderSettings = ReminderSettings();
  await reminderSettings.load();
  final notificationsService = NotificationsService();
  await notificationsService.init();

  // Tracks foreground/background so a due break shows the in-app overlay
  // when visible, or an immediate local notification when not (Review
  // Focus: notification permission denied never blocks either path).
  final isForegrounded = ValueNotifier<bool>(true);

  Timer? breakTimer;
  late final ReminderScheduler reminderScheduler;
  reminderScheduler = ReminderScheduler(
    settings: reminderSettings,
    notifications: notificationsService,
    onBreakDue: (firedAt) async {
      // Can the overlay actually be seen right now? On iOS that's the
      // foreground state; on Mac (a menu-bar app that stays "resumed" even
      // with its window hidden) it's whether the single window is visible —
      // otherwise the full-screen overlay would land on an invisible window
      // and the user would get no nudge at all. Fall back to a notification.
      final canShowOverlay = windowController == null
          ? isForegrounded.value
          : await windowManager.isVisible();
      if (canShowOverlay) {
        await windowController?.showMainWindow();
        router.push('/break');
      } else {
        await notificationsService.showNow(
          'Time to stand',
          'You have been tracking for a while — take a short break.',
        );
      }
    },
    // The scheduler itself stays a plain, deterministic object (Task 2); the
    // real-time firing mechanism — a Timer — lives here, re-armed every time
    // the scheduler reports a new due time.
    onNextScheduled: (nextAt) {
      breakTimer?.cancel();
      final delay = nextAt.difference(DateTime.now());
      if (delay > Duration.zero) {
        breakTimer = Timer(delay, () => reminderScheduler.onBreakFired(DateTime.now()));
      }
    },
  );

  // Edge-triggered: TimerEngine.notifyListeners() fires every tick (every
  // second) while running, so only a change in which session is open starts
  // or stops the reminder — never a re-arm on every tick.
  int? lastRunningSessionId;
  timerEngine.addListener(() {
    final running = timerEngine.running;
    if (running != null && running.id != lastRunningSessionId) {
      lastRunningSessionId = running.id;
      reminderScheduler.onTimerStarted(running.startTime);
    } else if (running == null && lastRunningSessionId != null) {
      lastRunningSessionId = null;
      breakTimer?.cancel();
      reminderScheduler.onTimerStopped();
    }
  });

  DeepLinkListener? deepLinkListener;
  if (Platform.isIOS) {
    shell = IosPlatformShell(router);
    final intentHandler = QuickStartIntentHandler(
      router: router,
      coordinator: startCoordinator,
      activityRepository: activityRepository,
    );
    deepLinkListener = DeepLinkListener(intentHandler);

    // Keep the home-/lock-screen widget's shared snapshot current: write it
    // (and reload the WidgetKit timelines) whenever activities or today's
    // totals change. Lives for the app's lifetime, so it is never disposed.
    WidgetSnapshotWriter(
      activityRepository: activityRepository,
      sessionRepository: sessionRepository,
      writeSnapshot: AppGroupStorage.write,
    ).start();
  }

  runApp(TimerApp(
    storage: storage,
    database: database,
    activityRepository: activityRepository,
    sessionRepository: sessionRepository,
    historyRepository: historyRepository,
    timerEngine: timerEngine,
    startCoordinator: startCoordinator,
    reminderSettings: reminderSettings,
    reminderScheduler: reminderScheduler,
    isForegrounded: isForegrounded,
    shell: shell,
    router: router,
    windowController: windowController,
  ));

  // After the first frame — i.e. after DI above and after HomeScreen's own
  // D2 resume-detection has started — so a cold launch from the Action
  // button/Siri/a widget lands on the picker/running screen rather than a
  // blank first frame. (Review Focus: this is a reasonable ordering, not a
  // hard guarantee against racing a pending D2 resume dialog — validated
  // manually on-device, see the Task 5 commit message.)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    deepLinkListener?.processInitialLink();
  });
}

class TimerApp extends StatefulWidget {
  factory TimerApp({
    Key? key,
    required StorageLocationService storage,
    required AppDatabase database,
    required ActivityRepository activityRepository,
    required SessionRepository sessionRepository,
    required HistoryRepository historyRepository,
    required TimerEngine timerEngine,
    StartCoordinator? startCoordinator,
    ReminderSettings? reminderSettings,
    ReminderScheduler? reminderScheduler,
    ValueNotifier<bool>? isForegrounded,
    PlatformShell? shell,
    GoRouter? router,
    WindowController? windowController,
  }) {
    final settings = reminderSettings ?? ReminderSettings();
    return TimerApp._(
      key: key,
      storage: storage,
      database: database,
      activityRepository: activityRepository,
      sessionRepository: sessionRepository,
      historyRepository: historyRepository,
      timerEngine: timerEngine,
      startCoordinator: startCoordinator ?? StartCoordinator(timerEngine),
      reminderSettings: settings,
      reminderScheduler: reminderScheduler ??
          ReminderScheduler(
            settings: settings,
            notifications: NotificationsService(),
            onBreakDue: (_) {},
          ),
      isForegrounded: isForegrounded ?? ValueNotifier<bool>(true),
      shell: shell ?? NoopPlatformShell(),
      router: router ?? buildAppRouter(),
      windowController: windowController,
    );
  }

  const TimerApp._({
    super.key,
    required this.storage,
    required this.database,
    required this.activityRepository,
    required this.sessionRepository,
    required this.historyRepository,
    required this.timerEngine,
    required this.startCoordinator,
    required this.reminderSettings,
    required this.reminderScheduler,
    required this.isForegrounded,
    required this.shell,
    required this.router,
    this.windowController,
  });

  final StorageLocationService storage;
  final AppDatabase database;
  final ActivityRepository activityRepository;
  final SessionRepository sessionRepository;
  final HistoryRepository historyRepository;
  final TimerEngine timerEngine;
  final StartCoordinator startCoordinator;
  final ReminderSettings reminderSettings;
  final ReminderScheduler reminderScheduler;

  /// True when the app is in the foreground — [main]'s reminder wiring reads
  /// this to decide overlay vs. local notification when a break fires.
  final ValueNotifier<bool> isForegrounded;

  final PlatformShell shell;
  final GoRouter router;

  /// Only set on macOS — drives which face (main / popover / picker) the
  /// single native window shows.
  final WindowController? windowController;

  @override
  State<TimerApp> createState() => _TimerAppState();
}

class _TimerAppState extends State<TimerApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    widget.windowController?.mode.addListener(_onModeChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.windowController?.mode.removeListener(_onModeChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.isForegrounded.value = state == AppLifecycleState.resumed;
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
        Provider<HistoryRepository>.value(value: widget.historyRepository),
        ChangeNotifierProvider<TimerEngine>.value(value: widget.timerEngine),
        Provider<StartCoordinator>.value(value: widget.startCoordinator),
        Provider<ReminderSettings>.value(value: widget.reminderSettings),
        Provider<ReminderScheduler>.value(value: widget.reminderScheduler),
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
