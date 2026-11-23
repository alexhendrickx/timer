import 'sync_models.dart';

/// What [resolve] decided to do about one row's two sides.
enum SyncAction {
  /// Both sides already agree — nothing to do.
  keepLocal,

  /// The remote side wins; write it into local SQLite.
  applyRemote,

  /// The local side wins; push it to the remote table.
  pushLocal,

  /// The remote side's delete wins; soft-delete the local row.
  applyRemoteDelete,
}

class SyncResolution {
  const SyncResolution(this.action);

  final SyncAction action;
}

/// The "has this side changed more recently" clock: a delete is treated as
/// a change at [SyncRow.deletedAt], so a later delete beats an earlier
/// edit — and is never resurrected by an older pull (spec Sync — Deletes).
DateTime _effectiveTime(SyncRow row) {
  final deletedAt = row.deletedAt;
  if (deletedAt == null) return row.updatedAt;
  return deletedAt.isAfter(row.updatedAt) ? deletedAt : row.updatedAt;
}

/// Last-write-wins conflict resolution for one row, matched by `uid`
/// across local and remote (spec Sync — Conflict resolution). A `uid`
/// present on only one side is inserted/pushed; otherwise the side with
/// the later effective time (edit or delete) wins.
SyncResolution resolve(SyncRow? local, SyncRow? remote) {
  if (local == null && remote == null) {
    throw ArgumentError('resolve requires at least one non-null side');
  }
  if (local == null) {
    // A remote row this device has never seen: insert it — unless it is
    // already a tombstone, in which case it must not be resurrected as a
    // live row (reviewer I1). applyRemoteDelete is a no-op when there is
    // no local row to mark, which is exactly the desired "drop it".
    return SyncResolution(
      remote!.deletedAt != null
          ? SyncAction.applyRemoteDelete
          : SyncAction.applyRemote,
    );
  }
  if (remote == null) {
    return const SyncResolution(SyncAction.pushLocal);
  }

  final localTime = _effectiveTime(local);
  final remoteTime = _effectiveTime(remote);

  if (remoteTime.isAfter(localTime)) {
    return SyncResolution(
      remote.deletedAt != null
          ? SyncAction.applyRemoteDelete
          : SyncAction.applyRemote,
    );
  }
  if (localTime.isAfter(remoteTime)) {
    return const SyncResolution(SyncAction.pushLocal);
  }
  return const SyncResolution(SyncAction.keepLocal);
}
