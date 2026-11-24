import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../feature/tracker/service/timer_engine.dart';

/// A Stop tapped on the Live Activity, as the native intent wrote it to
/// `<app group>/stop_request.json`:
/// `{"sessionId": 12, "endedAt": "2026-11-23T14:53:05.123Z"}`.
class StopRequest {
  const StopRequest({required this.sessionId, required this.endedAt});

  final int sessionId;

  /// The tap time, in local time like every other session time.
  final DateTime endedAt;

  /// Null for anything that is not exactly that shape.
  static StopRequest? tryParse(String raw) {
    Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (json is! Map) return null;
    final sessionId = json['sessionId'];
    final endedAt = json['endedAt'];
    if (sessionId is! int || endedAt is! String) return null;
    final parsed = DateTime.tryParse(endedAt);
    if (parsed == null) return null;
    return StopRequest(sessionId: sessionId, endedAt: parsed.toLocal());
  }
}

/// Applies the pending stop request, if there is one, through
/// [TimerEngine.stopSessionAt], then deletes the file. A request for a
/// session that is not open any more, or a file that is not a request, is
/// deleted without touching anything. Call it on launch, on resume, and
/// when the native side says a request was written.
class StopRequestApplier {
  StopRequestApplier({
    required this.engine,
    required this.read,
    required this.delete,
  });

  final TimerEngine engine;

  /// The request file's text, or null when there is none. Real usage is
  /// `AppGroupStorage.readStopRequest`; tests keep it in memory.
  final Future<String?> Function() read;

  /// Removes the request file. Real usage is
  /// `AppGroupStorage.deleteStopRequest`.
  final Future<void> Function() delete;

  Future<void> _queue = Future<void>.value();

  /// Never throws. Runs are chained, so several triggers at once apply a
  /// request once.
  Future<void> applyPending() {
    return _queue = _queue.then((_) => _apply());
  }

  Future<void> _apply() async {
    try {
      final raw = await read();
      if (raw == null) return;
      final request = StopRequest.tryParse(raw);
      if (request != null) {
        await engine.stopSessionAt(request.sessionId, request.endedAt);
      }
      await delete();
    } catch (error) {
      // The file stays, so the next launch, resume or notify tries again.
      debugPrint('Stop request not applied: $error');
    }
  }
}
