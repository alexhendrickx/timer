import 'dart:async';
import 'dart:convert';

import '../../../feature/activities/data/activity_repository.dart';
import '../../../feature/tracker/data/session_repository.dart';

/// Writes the per-activity snapshot the WidgetKit extension reads from the
/// app-group container: active activities with today's exact total seconds
/// (view-only; the stored durationSeconds is never touched). Call [sync]
/// whenever activities or today's totals change — the widget has no DB
/// access of its own, only this JSON file.
class WidgetSnapshotWriter {
  WidgetSnapshotWriter({
    required this.activityRepository,
    required this.sessionRepository,
    required this.writeSnapshot,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ActivityRepository activityRepository;
  final SessionRepository sessionRepository;

  /// Persists the JSON string to the app-group container. Real usage wires
  /// this to the `timer/app_group` method channel (see
  /// `app_group_storage.dart`); tests inject an in-memory capture.
  final Future<void> Function(String json) writeSnapshot;

  final DateTime Function() _now;

  final List<StreamSubscription<Object?>> _subs = [];

  /// Starts re-syncing the snapshot whenever activities or today's totals
  /// change, so the widget stays current without the app polling. Call once
  /// at startup (iOS only); pair with [dispose]. An initial [sync] runs via
  /// the streams' first emission.
  void start() {
    _subs.add(activityRepository.watchActive().listen((_) => sync()));
    _subs.add(sessionRepository.watchTodayTotals(_now()).listen((_) => sync()));
  }

  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
  }

  Future<void> sync() async {
    final activities = await activityRepository.activeActivities();
    final totals = await sessionRepository.watchTodayTotals(_now()).first;

    final snapshot = [
      for (final activity in activities)
        {
          'activityId': activity.id,
          'name': activity.name,
          'color': activity.color,
          'todaySeconds': totals[activity.id] ?? 0,
        },
    ];

    await writeSnapshot(jsonEncode(snapshot));
  }
}
