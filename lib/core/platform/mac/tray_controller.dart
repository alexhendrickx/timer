import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';

import '../../../feature/tracker/service/timer_engine.dart';
import '../../utils/duration_utils.dart';

/// The menu-bar status-item title. Running (both [activityName] and
/// [elapsed] given) → `"🕐 H:MM:SS · <activity>"`; otherwise the idle label
/// `"Timer"`, so an idle item never shows a stale time.
String trayTitle({String? activityName, Duration? elapsed}) {
  if (activityName == null || elapsed == null) return 'Timer';
  return '🕐 ${formatHms(elapsed.inSeconds)} · $activityName';
}

/// Resolves an activity id to its display name (null if unknown/archived).
typedef NameResolver = Future<String?> Function(int activityId);

/// Owns the top-right status item: sets the icon (optional) + context menu
/// and, once bound to a [TimerEngine], updates the live title each tick. The
/// actual click/menu actions are injected by the app (wired in main.dart).
class TrayController with TrayListener {
  TrayController({
    required this.onIconClick,
    required this.onStartStop,
    required this.onOpenWindow,
    required this.onQuit,
    this.iconPath,
  });

  /// Left-click on the status item (toggles the popover).
  final VoidCallback onIconClick;

  /// "Start/Stop timer" menu item.
  final VoidCallback onStartStop;

  /// "Open window" menu item.
  final VoidCallback onOpenWindow;

  /// "Quit" menu item.
  final VoidCallback onQuit;

  /// Optional path to a status-item icon asset; title-only when null.
  final String? iconPath;

  TimerEngine? _engine;
  NameResolver? _resolveName;
  int? _cachedActivityId;
  String? _cachedName;
  bool? _menuRunning;

  /// Direct title override — the `PlatformShell.setMenuBarTitle` seam
  /// delegates here. [bindEngine] is the normal live-ticking path; this is
  /// for callers that compute the title themselves.
  void setTitle(String title) => trayManager.setTitle(title);

  Future<void> init() async {
    trayManager.addListener(this);
    if (iconPath != null) {
      await trayManager.setIcon(iconPath!);
    }
    await trayManager.setTitle(trayTitle());
    await _setContextMenu(running: false);
  }

  /// Drives the live title from [engine]; [resolveName] maps the running
  /// session's activity id to a name for the title.
  void bindEngine(TimerEngine engine, {required NameResolver resolveName}) {
    _engine?.removeListener(_onEngineChanged);
    _engine = engine;
    _resolveName = resolveName;
    engine.addListener(_onEngineChanged);
    _onEngineChanged();
  }

  void _onEngineChanged() {
    final engine = _engine;
    if (engine == null) return;
    final running = engine.running;

    if (running == null) {
      _cachedActivityId = null;
      _cachedName = null;
      trayManager.setTitle(trayTitle());
      _syncMenu(running: false);
      return;
    }

    if (running.activityId != _cachedActivityId) {
      _cachedActivityId = running.activityId;
      _cachedName = null;
      // Resolve the name off-tick; the title picks it up on the next tick.
      _resolveName?.call(running.activityId).then((name) => _cachedName = name);
    }
    trayManager.setTitle(trayTitle(
      activityName: _cachedName ?? 'Running',
      elapsed: engine.elapsed,
    ));
    _syncMenu(running: true);
  }

  // Rebuild the context menu only when the running state flips, not each tick.
  void _syncMenu({required bool running}) {
    if (_menuRunning == running) return;
    _setContextMenu(running: running);
  }

  Future<void> _setContextMenu({required bool running}) async {
    _menuRunning = running;
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'start_stop', label: running ? 'Stop timer' : 'Start timer'),
      MenuItem(key: 'open_window', label: 'Open window'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Quit Timer'),
    ]));
  }

  @override
  void onTrayIconMouseDown() => onIconClick();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'start_stop':
        onStartStop();
      case 'open_window':
        onOpenWindow();
      case 'quit':
        onQuit();
    }
  }

  void dispose() {
    _engine?.removeListener(_onEngineChanged);
    trayManager.removeListener(this);
  }
}
