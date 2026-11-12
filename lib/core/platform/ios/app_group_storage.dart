import 'dart:io';

import 'package:flutter/services.dart';

/// Bridges to the tiny native handler in `ios/Runner/AppDelegate.swift`
/// (channel `timer/app_group`) that resolves the shared app-group
/// container's path via `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`
/// — Dart has no API for that, so this one call is the native surface
/// [WidgetSnapshotWriter] needs. Writes the snapshot file into that
/// container so the WidgetKit extension (same app group, different
/// process) can read it.
class AppGroupStorage {
  static const _channel = MethodChannel('timer/app_group');
  static const _fileName = 'activity_snapshot.json';

  /// Writes [json] to `<app-group container>/activity_snapshot.json`.
  /// No-op (does not throw) if the native side can't resolve the
  /// container — e.g. running on a build without the entitlement, or on
  /// a platform other than iOS.
  static Future<void> write(String json) async {
    final containerPath = await _channel.invokeMethod<String>('containerPath');
    if (containerPath == null) return;
    final file = File('$containerPath/$_fileName');
    await file.writeAsString(json);
  }
}
