import 'package:go_router/go_router.dart';

import '../../feature/activities/presentation/activities_screen.dart';
import '../../feature/settings/presentation/settings_screen.dart';
import '../../feature/tracker/presentation/home_screen.dart';
import '../../feature/tracker/presentation/running_screen.dart';

/// App navigation: Home, Running, Activities, and Settings.
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
  ],
);
