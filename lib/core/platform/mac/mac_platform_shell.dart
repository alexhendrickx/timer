import '../platform_shell.dart';
import 'hotkey_controller.dart';
import 'tray_controller.dart';
import 'window_controller.dart';

/// The Mac implementation of the [PlatformShell] seam: composes the tray
/// (menu-bar status item), window (popover / picker / main), and global
/// hotkey controllers that main.dart constructs and wires to the app's
/// engine/repositories.
class MacPlatformShell implements PlatformShell {
  MacPlatformShell({
    required this.tray,
    required this.window,
    required this.hotkey,
  });

  final TrayController tray;
  final WindowController window;
  final HotkeyController hotkey;

  @override
  Future<void> init() async {
    window.init();
    await tray.init();
    // A failed registration (already taken / missing permission) is logged
    // once by HotkeyController and must not stop the rest of the shell.
    await hotkey.register(() => showQuickStartPicker());
  }

  @override
  void setMenuBarTitle(String title) => tray.setTitle(title);

  @override
  Future<void> showQuickStartPicker() => window.showQuickStartPicker();

  @override
  bool get hasMenuBar => true;
}
