import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

/// Owns the single system-wide hotkey that opens the quick-start picker
/// (⌘⇧Space). If the OS refuses to register it (already taken by another
/// app, or missing permission), the app must still run — the menu bar keeps
/// working, the failure is logged once and otherwise silent (Review Focus:
/// "Hotkey package failing to register").
class HotkeyController {
  static final HotKey _hotKey = HotKey(
    key: PhysicalKeyboardKey.space,
    modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
    scope: HotKeyScope.system,
  );

  bool _registered = false;

  /// True once [register] has successfully bound the system hotkey.
  bool get isRegistered => _registered;

  /// Binds the hotkey so [onTrigger] runs on keydown. Never throws: a
  /// registration failure is logged once and the app continues without the
  /// shortcut.
  Future<void> register(VoidCallback onTrigger) async {
    try {
      await hotKeyManager.register(
        _hotKey,
        keyDownHandler: (_) => onTrigger(),
      );
      _registered = true;
    } catch (e) {
      // One-time note; the app (tray, window, everything else) keeps working
      // without the global shortcut.
      debugPrint('Timer: could not register the global hotkey (⌘⇧Space): $e');
      _registered = false;
    }
  }

  Future<void> unregister() async {
    if (!_registered) return;
    await hotKeyManager.unregister(_hotKey);
    _registered = false;
  }
}
