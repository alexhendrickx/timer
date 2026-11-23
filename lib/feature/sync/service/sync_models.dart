/// One side (local or remote) of a syncable row, keyed by its stable
/// cross-device [uid] — never the local autoincrement id, which differs
/// per device (spec Sync — Conflict resolution).
class SyncRow {
  const SyncRow({
    required this.uid,
    required this.updatedAt,
    this.deletedAt,
    required this.fields,
  });

  final String uid;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// The row's other columns, keyed by local column name — opaque to the
  /// resolver, carried through by [SyncEngine] when it applies a side.
  final Map<String, Object?> fields;
}
