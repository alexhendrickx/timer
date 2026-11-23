/// The single seam between platform-free screens/core and platform-specific
/// UI chrome (menu bar, global hotkey, popover). Screens request
/// capabilities ("show the quick-start picker", "set the menu-bar title")
/// through this interface instead of branching on platform; the concrete
/// implementation (Mac vs. the no-op default) is chosen once at startup and
/// injected via DI.
abstract class PlatformShell {
  /// Wires up whatever native chrome this shell owns (status item, window,
  /// global hotkey). Call once at startup.
  Future<void> init();

  /// Sets the menu-bar status item's title, if this shell has one.
  void setMenuBarTitle(String title);

  /// Shows the Spotlight-style quick-start picker, if this shell has one.
  Future<void> showQuickStartPicker();

  /// Whether this shell has a menu bar (false on iOS / in tests).
  bool get hasMenuBar;
}

/// Default/injected-in-tests shell: every capability is a safe no-op. This is
/// also the iOS placeholder until v0.5 — iOS has no menu bar.
class NoopPlatformShell implements PlatformShell {
  @override
  Future<void> init() async {}

  @override
  void setMenuBarTitle(String title) {}

  @override
  Future<void> showQuickStartPicker() async {}

  @override
  bool get hasMenuBar => false;
}
