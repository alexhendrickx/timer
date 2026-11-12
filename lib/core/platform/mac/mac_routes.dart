import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../feature/tracker/presentation/popover_screen.dart';
import '../../../feature/tracker/presentation/quick_start_picker.dart';
import 'window_controller.dart';

/// The two Mac-only menu-bar window surfaces (popover, Spotlight-style
/// picker) — routed to only from Mac's window-mode switch (main.dart), never
/// reachable on iOS. Kept out of `core/routing/app_router.dart` so core
/// routing stays free of Mac-only platform-UI imports (`window_manager` via
/// [WindowController]); macOS registers these via [MacPlatformShell].
List<RouteBase> macRoutes(WindowController windowController) => [
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
    ];
