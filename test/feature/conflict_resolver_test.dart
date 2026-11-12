import 'package:flutter_test/flutter_test.dart';
import 'package:timer/feature/sync/service/conflict_resolver.dart';
import 'package:timer/feature/sync/service/sync_models.dart';

SyncRow _row(int minutesPastEpoch, {DateTime? deletedAt}) {
  final updatedAt = DateTime(2026).add(Duration(minutes: minutesPastEpoch));
  return SyncRow(
    uid: 'u1',
    updatedAt: updatedAt,
    deletedAt: deletedAt,
    fields: const {},
  );
}

SyncRow _localAt(int minutes) => _row(minutes);
SyncRow _remoteAt(int minutes) => _row(minutes);
SyncRow _localDeletedAt(int minutes) =>
    _row(minutes, deletedAt: DateTime(2026).add(Duration(minutes: minutes)));
SyncRow _remoteDeletedAt(int minutes) =>
    _row(minutes, deletedAt: DateTime(2026).add(Duration(minutes: minutes)));
SyncRow _localEditedAt(int minutes) => _row(minutes);
SyncRow _remoteEditedAt(int minutes) => _row(minutes);

void main() {
  test('newer updatedAt wins', () {
    expect(resolve(_localAt(10), _remoteAt(20)).action, SyncAction.applyRemote);
    expect(resolve(_localAt(30), _remoteAt(20)).action, SyncAction.pushLocal);
  });

  test('later delete propagates and is not resurrected', () {
    expect(
      resolve(_localEditedAt(10), _remoteDeletedAt(20)).action,
      SyncAction.applyRemoteDelete,
    );
    expect(
      resolve(_localDeletedAt(20), _remoteEditedAt(10)).action,
      SyncAction.pushLocal,
    );
  });

  test('remote-only uid is inserted; local-only uid is pushed', () {
    expect(resolve(null, _remoteAt(5)).action, SyncAction.applyRemote);
    expect(resolve(_localAt(5), null).action, SyncAction.pushLocal);
  });
}
