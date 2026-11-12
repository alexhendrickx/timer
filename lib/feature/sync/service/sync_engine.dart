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

  Future<void> _pushActivities() async {
    final dirty = await (_db.select(_db.activities)
          ..where((a) => a.dirty.equals(true)))
        .get();
    if (dirty.isEmpty) return;
    await _port.upsert('activities', dirty.map(activityToSyncRow).toList());
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
      final local = existing == null ? null : activityToSyncRow(existing);
      final action = resolve(local, remote).action;

      if (action == SyncAction.applyRemote) {
        // Full overwrite — the resolver already decided the remote wins,
        // so every column is applied, not a subset (reviewer I2).
        final companion = ActivitiesCompanion(
          name: Value(remote.fields['name'] as String? ?? existing?.name ?? ''),
          color: Value((remote.fields['color'] as num?)?.toInt()),
          hourlyRate: Value((remote.fields['hourly_rate'] as num?)?.toDouble()),
          currencyLabel: Value(remote.fields['currency_label'] as String?),
          archived: Value(remote.fields['archived'] as bool? ?? false),
          deletedAt: Value(remote.deletedAt),
          updatedAt: Value(remote.updatedAt),
          dirty: const Value(false),
        );
        if (existing == null) {
          await _db.into(_db.activities).insert(companion.copyWith(
                uid: Value(remote.uid),
                createdAt: Value(_remoteCreatedAt(remote)),
              ));
        } else {
          await (_db.update(_db.activities)
                ..where((a) => a.id.equals(existing.id)))
              .write(companion);
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
      // phase (above) is what moves it, not the pull. A remote tombstone
      // with no local row resolves to applyRemoteDelete and is skipped
      // here, so it is never resurrected as a live row (reviewer I1).
    }
  }

  // ---- Sessions ---------------------------------------------------------

  Future<SyncRow> _sessionToRow(Session s) async {
    final activity = await (_db.select(_db.activities)
          ..where((a) => a.id.equals(s.activityId)))
        .getSingleOrNull();
    return sessionToSyncRow(s, activityUid: activity?.uid);
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
      final local = existing == null ? null : await _sessionToRow(existing);
      final action = resolve(local, remote).action;

      if (action == SyncAction.applyRemote) {
        final activityUid = remote.fields['activity_uid'] as String?;
        final activity = activityUid == null
            ? null
            : await (_db.select(_db.activities)
                  ..where((a) => a.uid.equals(activityUid)))
                .getSingleOrNull();
        // No local activity for this session yet — can't attach it; skip
        // until that activity itself has been pulled.
        if (activity == null) continue;

        final endTimeStr = remote.fields['end_time'] as String?;
        final lastSeenStr = remote.fields['last_seen_at'] as String?;
        // Full overwrite of every mutable column (reviewer I2).
        final companion = SessionsCompanion(
          activityId: Value(activity.id),
          date: Value(DateTime.parse(remote.fields['date'] as String)),
          startTime: Value(DateTime.parse(remote.fields['start_time'] as String)),
          endTime: Value(endTimeStr == null ? null : DateTime.parse(endTimeStr)),
          durationSeconds:
              Value(remote.fields['duration_seconds'] as int? ?? 0),
          note: Value(remote.fields['note'] as String?),
          lastSeenAt:
              Value(lastSeenStr == null ? null : DateTime.parse(lastSeenStr)),
          deletedAt: Value(remote.deletedAt),
          updatedAt: Value(remote.updatedAt),
          dirty: const Value(false),
        );
        if (existing == null) {
          await _db.into(_db.sessions).insert(companion.copyWith(
                uid: Value(remote.uid),
                createdAt: Value(_remoteCreatedAt(remote)),
              ));
        } else {
          await (_db.update(_db.sessions)
                ..where((s) => s.id.equals(existing.id)))
              .write(companion);
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

  /// The row's remote `created_at`, falling back to `updatedAt` for a row
  /// serialized before that column was carried.
  DateTime _remoteCreatedAt(SyncRow remote) {
    final createdAt = remote.fields['created_at'];
    return createdAt is String ? DateTime.parse(createdAt) : remote.updatedAt;
  }
}

/// Maps a local [Activity] to its [SyncRow], keyed by the snake_case
/// column names in `supabase/sync.sql` (PostgREST does no camelCase
/// translation) and including the NOT-NULL `created_at` (reviewer C1+C2).
SyncRow activityToSyncRow(Activity a) => SyncRow(
      uid: a.uid,
      updatedAt: a.updatedAt,
      deletedAt: a.deletedAt,
      fields: {
        'name': a.name,
        'color': a.color,
        'hourly_rate': a.hourlyRate,
        'currency_label': a.currencyLabel,
        'archived': a.archived,
        'created_at': a.createdAt.toUtc().toIso8601String(),
      },
    );

/// Maps a local [Session] to its [SyncRow]. [activityUid] is the parent
/// activity's cross-device `uid` (its local id is meaningless on another
/// device). Keys are the snake_case `sessions` columns incl. `created_at`.
SyncRow sessionToSyncRow(Session s, {required String? activityUid}) => SyncRow(
      uid: s.uid,
      updatedAt: s.updatedAt,
      deletedAt: s.deletedAt,
      fields: {
        'activity_uid': activityUid,
        'date': s.date.toUtc().toIso8601String(),
        'start_time': s.startTime.toUtc().toIso8601String(),
        'end_time': s.endTime?.toUtc().toIso8601String(),
        'duration_seconds': s.durationSeconds,
        'note': s.note,
        'last_seen_at': s.lastSeenAt?.toUtc().toIso8601String(),
        'created_at': s.createdAt.toUtc().toIso8601String(),
      },
    );
