import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../feature/activities/presentation/activities_screen.dart';
import '../../feature/settings/presentation/settings_screen.dart';
import '../../feature/tracker/presentation/home_screen.dart';
import '../../feature/tracker/presentation/popover_screen.dart';
import '../../feature/tracker/presentation/quick_start_picker.dart';
import '../../feature/tracker/presentation/running_screen.dart';
import '../platform/mac/window_controller.dart';

/// App navigation: Home, Running, Activities, Settings, and the two Mac
/// menu-bar surfaces (popover, quick-start picker) — only ever navigated to
/// from Mac's window-mode switch (main.dart), never reachable on iOS.
final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/running',
      builder: (context, state) => const RunningScreen(),
    ),
    GoRoute(
      path: '/activities',
      builder: (context, state) => const ActivitiesScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/popover',
      builder: (context, state) => const PopoverScreen(),
    ),
    GoRoute(
      path: '/picker',
      builder: (context, state) => QuickStartPicker(
        onDismiss: () => context.read<WindowController>().hideQuickStartPicker(),
      ),
    ),
  ],
);
