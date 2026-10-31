import 'package:go_router/go_router.dart';

import '../../feature/settings/presentation/settings_screen.dart';
import '../../feature/tracker/presentation/home_screen.dart';

/// App navigation. Two routes in v0.1.0: Home and Settings.
final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
