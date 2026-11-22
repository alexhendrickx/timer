import 'dart:async';

import 'package:go_router/go_router.dart';

import '../../feature/activities/presentation/activities_screen.dart';
import '../../feature/history/presentation/history_screen.dart';
import '../../feature/history/presentation/reports_screen.dart';
import '../../feature/onboarding/data/onboarding_state.dart';
import '../../feature/onboarding/presentation/onboarding_screen.dart';
import '../../feature/settings/presentation/settings_screen.dart';
import '../../feature/sync/presentation/set_password_screen.dart';
import '../../feature/sync/service/auth_service.dart';
import '../../feature/tracker/presentation/break_overlay.dart';
import '../../feature/tracker/presentation/home_screen.dart';
import '../../feature/tracker/presentation/quick_start_picker.dart';
import '../../feature/tracker/presentation/running_screen.dart';

/// App navigation: Home, Running, Activities, Settings, and the shared
/// `/quick-start` chooser (iPhone's Action button / Siri Shortcut / widget
/// tiles land here). Platform-only surfaces (Mac's popover + hotkey picker)
/// are not registered here — they stay behind the platform-shell seam
/// (`platform/mac/mac_routes.dart`) so this file never imports a
/// platform-UI package. Built once in main.dart via [buildAppRouter].
GoRouter buildAppRouter({
  String initialLocation = '/',
  List<RouteBase> platformRoutes = const [],
}) {
  return GoRouter(
    initialLocation: initialLocation,
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
        path: '/history',
        builder: (context, state) => HistoryScreen(
          initialActivityId: state.extra is int ? state.extra as int : null,
        ),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/break',
        builder: (context, state) => const BreakOverlay(),
      ),
      GoRoute(
        path: '/quick-start',
        builder: (context, state) => QuickStartPicker(
          onDismiss: () => context.go('/'),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => OnboardingScreen(
          onFinished: () async {
            await markOnboardingDone();
            if (context.mounted) context.go('/');
          },
        ),
      ),
      GoRoute(
        path: '/set-password',
        builder: (context, state) =>
            SetPasswordScreen(onDone: () => context.go('/')),
      ),
      ...platformRoutes,
    ],
  );
}

/// Sends the user to `/set-password` once a password-reset link has signed
/// them in. [AuthService] latches that event, so a link that resolved before
/// this call is handled by the immediate check at the end. [showWindow]
/// raises the Mac main window first (it may be hidden in the menu bar).
void routePasswordRecovery({
  required AuthService auth,
  required GoRouter router,
  Future<void> Function()? showWindow,
}) {
  Future<void> showSetPassword() async {
    if (!auth.takePasswordRecovery()) return;
    await showWindow?.call();
    router.go('/set-password');
  }

  auth.addListener(showSetPassword);
  unawaited(showSetPassword());
}
