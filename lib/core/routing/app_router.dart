import 'package:go_router/go_router.dart';

import '../../feature/activities/presentation/activities_screen.dart';
import '../../feature/settings/presentation/settings_screen.dart';
import '../../feature/tracker/presentation/home_screen.dart';
import '../../feature/tracker/presentation/popover_screen.dart';

/// App navigation: Home, Activities, Settings, and the menu-bar popover.
final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/popover',
      builder: (context, state) => const PopoverScreen(),
    ),
    GoRoute(
      path: '/activities',
      builder: (context, state) => const ActivitiesScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
