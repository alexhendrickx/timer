import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'sync_models.dart';

/// The network side of sync — platform-free so [SyncEngine] is unit
/// testable with a fake, never a live Supabase project (spec Sync).
abstract class SyncPort {
  /// Rows from [table] updated (or soft-deleted) after [since], scoped to
  /// the signed-in user by RLS — see `supabase/sync.sql`.
  Future<List<SyncRow>> fetchSince(DateTime since, String table);

  /// Upserts [rows] into [table], matched by `uid` (unique per user — see
  /// `supabase/sync.sql`'s `(user_id, uid)` primary key).
  Future<void> upsert(String table, List<SyncRow> rows);
}

/// Production [SyncPort]: Alex's own Supabase project. `user_id` is never
/// set here — the table's `default auth.uid()` plus RLS fill and guard it.
class SupabaseSyncPort implements SyncPort {
  SupabaseSyncPort(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<List<SyncRow>> fetchSince(DateTime since, String table) async {
    final rows = await _client
        .from(table)
        .select()
        .gt('updated_at', since.toUtc().toIso8601String());
    return rows.map(_toSyncRow).toList();
  }

  @override
  Future<void> upsert(String table, List<SyncRow> rows) async {
    if (rows.isEmpty) return;
    await _client.from(table).upsert(rows.map(_toJson).toList());
  }

  SyncRow _toSyncRow(Map<String, dynamic> json) {
    final fields = Map<String, Object?>.from(json)
      ..remove('uid')
      ..remove('updated_at')
      ..remove('deleted_at')
      ..remove('user_id');
    return SyncRow(
      uid: json['uid'] as String,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.parse(json['deleted_at'] as String),
      fields: fields,
    );
  }

  Map<String, dynamic> _toJson(SyncRow row) {
    return {
      ...row.fields,
      'uid': row.uid,
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'deleted_at': row.deletedAt?.toUtc().toIso8601String(),
    };
  }
}
