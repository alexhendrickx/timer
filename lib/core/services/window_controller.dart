import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// Which face the single app window is currently showing.
enum AppWindowMode { popover, main }

/// Controls the one native window: a small, frameless, always-on-top popover
/// anchored top-right near the menu-bar item, or the normal titled main window.
/// [mode] lets the app swap the Flutter content to match the window shape.
class WindowController with WindowListener {
  WindowController({this.onMainWindowClose});

  /// Called when the user closes the main window — the app hides it instead of
  /// terminating (it lives on in the menu bar). Wired in main.dart.
  final VoidCallback? onMainWindowClose;

  final ValueNotifier<AppWindowMode> mode =
      ValueNotifier(AppWindowMode.main);

  static const Size _popoverSize = Size(340, 420);
  static const Size _mainSize = Size(760, 580);

  /// Intercepts the native window-close so closing hides rather than quits.
  void init() => windowManager.addListener(this);

  /// Shows the compact popover anchored to the top-right (near the tray icon).
  Future<void> showPopover() async {
    mode.value = AppWindowMode.popover;
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.setMovable(false);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setSize(_popoverSize);
    await windowManager.setAlignment(Alignment.topRight);
    await windowManager.show();
    await windowManager.focus();
  }

  /// Hides the popover window (app keeps running in the menu bar).
  Future<void> hidePopover() => windowManager.hide();

  /// Shows the full main window: titled, centered, not always-on-top.
  Future<void> showMainWindow() async {
    mode.value = AppWindowMode.main;
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setSkipTaskbar(false);
    await windowManager.setMovable(true);
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setSize(_mainSize);
    await windowManager.center();
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onWindowClose() => onMainWindowClose?.call();

  void dispose() => windowManager.removeListener(this);
}
