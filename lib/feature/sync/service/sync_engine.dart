import 'dart:async';

import 'package:drift/drift.dart';

import '../../../core/services/database/app_database.dart';
import 'auth_service.dart';
import 'conflict_resolver.dart';
import 'sync_models.dart';
import 'supabase_sync_port.dart';

/// Pushes dirty local rows up and pulls remote changes down, resolving
/// per-row with last-write-wins (spec Sync). Local SQLite stays the
/// source of truth and the running `TimerEngine` is untouched — this is
/// a background layer, never on the start/stop path.
class SyncEngine {
  SyncEngine({
    required AppDatabase db,
    required AuthService auth,
    required SyncPort port,
    Duration debounce = const Duration(seconds: 2),
  })  : _db = db,
        _auth = auth,
        _port = port,
        _debounce = debounce;

  final AppDatabase _db;
  final AuthService _auth;
  final SyncPort _port;
  final Duration _debounce;

  Timer? _debounceTimer;
  DateTime _lastPullAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// True only when signed in — with no session, [syncNow] is a safe
  /// no-op and zero network calls happen (spec Sync — Signed out).
  bool get enabled => _auth.isSignedIn;

  /// Debounced trigger for a local write — coalesces bursts of edits into
  /// one `syncNow()` a short while later.
  void notifyLocalChange() {
    if (!enabled) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, syncNow);
  }

  /// Fire-and-forget: connectivity regained, or a just-completed sign-in.
  void onReconnect() {
    unawaited(syncNow());
  }

  /// Pushes every dirty row, then pulls remote changes — never throws:
  /// a network failure here must never block the local-first app; the
  /// next debounced change, reconnect, or sign-in retries it.
  Future<void> syncNow() async {
    if (!enabled) return;
    try {
      await _pushActivities();
      await _pushSessions();
      await _pullActivities();
      await _pullSessions();
      _lastPullAt = DateTime.now();
    } catch (_) {
      // Swallowed by design — see the doc comment above.
    }
  }

  // ---- Activities -----------------------------------------------------

  SyncRow _activityToRow(Activity a) => SyncRow(
        uid: a.uid,
        updatedAt: a.updatedAt,
        deletedAt: a.deletedAt,
        fields: {
          'name': a.name,
          'color': a.color,
          'hourlyRate': a.hourlyRate,
          'currencyLabel': a.currencyLabel,
          'archived': a.archived,
        },
      );

  Future<void> _pushActivities() async {
    final dirty = await (_db.select(_db.activities)
          ..where((a) => a.dirty.equals(true)))
        .get();
    if (dirty.isEmpty) return;
    await _port.upsert('activities', dirty.map(_activityToRow).toList());
    for (final a in dirty) {
      await (_db.update(_db.activities)..where((x) => x.id.equals(a.id)))
          .write(const ActivitiesCompanion(dirty: Value(false)));
    }
  }

  Future<void> _pullActivities() async {
    final remoteRows = await _port.fetchSince(_lastPullAt, 'activities');
    for (final remote in remoteRows) {
      final existing = await (_db.select(_db.activities)
            ..where((a) => a.uid.equals(remote.uid)))
          .getSingleOrNull();
      final local = existing == null ? null : _activityToRow(existing);
      final action = resolve(local, remote).action;

      if (action == SyncAction.applyRemote) {
        if (existing == null) {
          await _db.into(_db.activities).insert(ActivitiesCompanion.insert(
                name: remote.fields['name'] as String? ?? '',
                color: Value(remote.fields['color'] as int?),
                hourlyRate:
                    Value((remote.fields['hourlyRate'] as num?)?.toDouble()),
                currencyLabel: Value(remote.fields['currencyLabel'] as String?),
                archived: Value(remote.fields['archived'] as bool? ?? false),
                createdAt: remote.updatedAt,
                uid: Value(remote.uid),
                updatedAt: Value(remote.updatedAt),
                dirty: const Value(false),
              ));
        } else {
          await (_db.update(_db.activities)
                ..where((a) => a.id.equals(existing.id)))
              .write(ActivitiesCompanion(
            name: Value(remote.fields['name'] as String? ?? existing.name),
            archived:
                Value(remote.fields['archived'] as bool? ?? existing.archived),
            updatedAt: Value(remote.updatedAt),
            dirty: const Value(false),
          ));
        }
      } else if (action == SyncAction.applyRemoteDelete && existing != null) {
        await (_db.update(_db.activities)
              ..where((a) => a.id.equals(existing.id)))
            .write(ActivitiesCompanion(
          deletedAt: Value(remote.deletedAt),
          updatedAt: Value(remote.updatedAt),
          dirty: const Value(false),
        ));
      }
      // pushLocal / keepLocal: local already wins or matches — the push
      // phase (above) is what moves it, not the pull.
    }
  }

  // ---- Sessions ---------------------------------------------------------

  Future<SyncRow> _sessionToRow(Session s) async {
    final activity = await (_db.select(_db.activities)
          ..where((a) => a.id.equals(s.activityId)))
        .getSingleOrNull();
    return SyncRow(
      uid: s.uid,
      updatedAt: s.updatedAt,
      deletedAt: s.deletedAt,
      fields: {
        'activityUid': activity?.uid,
        'date': s.date.toIso8601String(),
        'startTime': s.startTime.toIso8601String(),
        'endTime': s.endTime?.toIso8601String(),
        'durationSeconds': s.durationSeconds,
        'note': s.note,
        'lastSeenAt': s.lastSeenAt?.toIso8601String(),
      },
    );
  }

  Future<void> _pushSessions() async {
    final dirty = await (_db.select(_db.sessions)
          ..where((s) => s.dirty.equals(true)))
        .get();
    if (dirty.isEmpty) return;
    final rows = await Future.wait(dirty.map(_sessionToRow));
    await _port.upsert('sessions', rows);
    for (final s in dirty) {
      await (_db.update(_db.sessions)..where((x) => x.id.equals(s.id)))
          .write(const SessionsCompanion(dirty: Value(false)));
    }
  }

  Future<void> _pullSessions() async {
    final remoteRows = await _port.fetchSince(_lastPullAt, 'sessions');
    for (final remote in remoteRows) {
      final existing = await (_db.select(_db.sessions)
            ..where((s) => s.uid.equals(remote.uid)))
          .getSingleOrNull();
      final local = existing == null
          ? null
          : await _sessionToRow(existing);
      final action = resolve(local, remote).action;

      if (action == SyncAction.applyRemote) {
        final activityUid = remote.fields['activityUid'] as String?;
        final activity = activityUid == null
            ? null
            : await (_db.select(_db.activities)
                  ..where((a) => a.uid.equals(activityUid)))
                .getSingleOrNull();
        // No local activity for this session yet — can't attach it; skip
        // until that activity itself has been pulled.
        if (activity == null) continue;

        final startTime = DateTime.parse(remote.fields['startTime'] as String);
        final date = DateTime.parse(remote.fields['date'] as String);
        final endTimeStr = remote.fields['endTime'] as String?;
        final lastSeenStr = remote.fields['lastSeenAt'] as String?;

        if (existing == null) {
          await _db.into(_db.sessions).insert(SessionsCompanion.insert(
                activityId: activity.id,
                date: date,
                startTime: startTime,
                endTime: Value(endTimeStr == null ? null : DateTime.parse(endTimeStr)),
                durationSeconds:
                    Value(remote.fields['durationSeconds'] as int? ?? 0),
                note: Value(remote.fields['note'] as String?),
                lastSeenAt:
                    Value(lastSeenStr == null ? null : DateTime.parse(lastSeenStr)),
                createdAt: remote.updatedAt,
                updatedAt: remote.updatedAt,
                uid: Value(remote.uid),
                dirty: const Value(false),
              ));
        } else {
          await (_db.update(_db.sessions)..where((s) => s.id.equals(existing.id)))
              .write(SessionsCompanion(
            endTime: Value(endTimeStr == null ? null : DateTime.parse(endTimeStr)),
            durationSeconds:
                Value(remote.fields['durationSeconds'] as int? ?? existing.durationSeconds),
            note: Value(remote.fields['note'] as String?),
            updatedAt: Value(remote.updatedAt),
            dirty: const Value(false),
          ));
        }
      } else if (action == SyncAction.applyRemoteDelete && existing != null) {
        await (_db.update(_db.sessions)..where((s) => s.id.equals(existing.id)))
            .write(SessionsCompanion(
          deletedAt: Value(remote.deletedAt),
          updatedAt: Value(remote.updatedAt),
          dirty: const Value(false),
        ));
      }
    }
  }
}
