import 'package:go_router/go_router.dart';

import '../../feature/activities/presentation/activities_screen.dart';
import '../../feature/settings/presentation/settings_screen.dart';
import '../../feature/tracker/presentation/home_screen.dart';
import '../../feature/tracker/presentation/quick_start_picker.dart';
import '../../feature/tracker/presentation/running_screen.dart';

/// App navigation: Home, Running, Activities, Settings, and the shared
/// `/quick-start` chooser (iPhone's Action button / Siri Shortcut / widget
/// tiles land here). Platform-only surfaces (Mac's popover + hotkey picker)
/// are not registered here — they stay behind the platform-shell seam
/// (`platform/mac/mac_routes.dart`) so this file never imports a
/// platform-UI package. Built once in main.dart via [buildAppRouter].
GoRouter buildAppRouter({List<RouteBase> platformRoutes = const []}) {
  return GoRouter(
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
        path: '/quick-start',
        builder: (context, state) => QuickStartPicker(
          onDismiss: () => context.go('/'),
        ),
      ),
      ...platformRoutes,
    ],
  );
}
