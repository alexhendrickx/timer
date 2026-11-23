import 'package:go_router/go_router.dart';

import '../platform_shell.dart';

/// The iOS implementation of the [PlatformShell] seam: no menu bar (iOS has
/// none), and "quick-start" means navigating the already-running app onto
/// the shared `/quick-start` chooser route (the focus-cards picker) — the
/// same landing spot the Action button / Siri Shortcut / widget deep links
/// resolve to (see `quick_start_intent_handler.dart`).
class IosPlatformShell implements PlatformShell {
  IosPlatformShell(this._router);

  final GoRouter _router;

  @override
  Future<void> init() async {}

  @override
  void setMenuBarTitle(String title) {}

  @override
  Future<void> showQuickStartPicker() async {
    _router.go('/quick-start');
  }

  @override
  bool get hasMenuBar => false;
}
