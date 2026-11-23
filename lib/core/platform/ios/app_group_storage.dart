import 'dart:convert';
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

  /// Writes [json] to `<app-group container>/activity_snapshot.json` and asks
  /// the native side to reload the WidgetKit timelines so the widget picks up
  /// the new snapshot. No-op (does not throw) if the native side can't
  /// resolve the container — e.g. running on a build without the entitlement,
  /// or on a platform other than iOS.
  static Future<void> write(String json) async {
    final containerPath = await _channel.invokeMethod<String>('containerPath');
    if (containerPath == null) return;
    final file = File('$containerPath/$_fileName');
    await file.writeAsString(json);
    await _channel.invokeMethod<void>('reloadWidgets');
  }

  static const _stopRequestFileName = 'stop_request.json';

  /// The pending Live Activity stop request (see `StopRequestApplier`), or
  /// null when there is none or the container can't be resolved. Bytes that
  /// are not UTF-8 still come back as text, so the caller can throw the
  /// file away as malformed.
  static Future<String?> readStopRequest() async {
    final file = await _stopRequestFile();
    if (file == null || !await file.exists()) return null;
    return utf8.decode(await file.readAsBytes(), allowMalformed: true);
  }

  /// Removes the stop request. Quiet when it is already gone.
  static Future<void> deleteStopRequest() async {
    final file = await _stopRequestFile();
    if (file == null) return;
    try {
      await file.delete();
    } on PathNotFoundException {
      // Already gone.
    }
  }

  static Future<File?> _stopRequestFile() async {
    final containerPath = await _channel.invokeMethod<String>('containerPath');
    if (containerPath == null) return null;
    return File('$containerPath/$_stopRequestFileName');
  }
}
