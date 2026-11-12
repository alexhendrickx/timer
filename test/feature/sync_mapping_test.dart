import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/services/database/app_database.dart';
import 'package:timer/feature/sync/service/sync_engine.dart';
import 'package:timer/feature/sync/service/supabase_sync_port.dart';

Activity _activity() => Activity(
      id: 1,
      name: 'Client X',
      color: 0xFF112233,
      hourlyRate: 75,
      currencyLabel: 'EUR',
      archived: false,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
      uid: 'a-uid',
      dirty: true,
    );

Session _session() => Session(
      id: 1,
      activityId: 1,
      date: DateTime.utc(2026, 1, 1),
      startTime: DateTime.utc(2026, 1, 1, 9),
      endTime: DateTime.utc(2026, 1, 1, 10),
      durationSeconds: 3600,
      note: 'note',
      lastSeenAt: DateTime.utc(2026, 1, 1, 10),
      createdAt: DateTime.utc(2026, 1, 1, 9),
      updatedAt: DateTime.utc(2026, 1, 1, 10),
      uid: 's-uid',
      dirty: true,
    );

void main() {
  // The remote JSON keys must be exactly the snake_case column names from
  // supabase/sync.sql — PostgREST does no camelCase translation, and
  // `created_at` / `activity_uid` are NOT NULL with no default, so a
  // missing key makes every insert fail (reviewer C1 + C2).
  test('activity serializes to the exact snake_case remote columns', () {
    final json = syncRowToJson(activityToSyncRow(_activity()));
    expect(
      json.keys.toSet(),
      {
        'uid',
        'name',
        'color',
        'hourly_rate',
        'currency_label',
        'archived',
        'created_at',
        'updated_at',
        'deleted_at',
      },
    );
    expect(json['hourly_rate'], 75);
    expect(json['currency_label'], 'EUR');
    expect(json['created_at'], isNotNull);
  });

  test('session serializes to the exact snake_case remote columns', () {
    final json =
        syncRowToJson(sessionToSyncRow(_session(), activityUid: 'a-uid'));
    expect(
      json.keys.toSet(),
      {
        'uid',
        'activity_uid',
        'date',
        'start_time',
        'end_time',
        'duration_seconds',
        'note',
        'last_seen_at',
        'created_at',
        'updated_at',
        'deleted_at',
      },
    );
    expect(json['activity_uid'], 'a-uid');
    expect(json['duration_seconds'], 3600);
    expect(json['created_at'], isNotNull);
  });

  test('a serialized row round-trips back through fromJson', () {
    final row = activityToSyncRow(_activity());
    final back = syncRowFromJson(syncRowToJson(row));
    expect(back.uid, 'a-uid');
    expect(back.updatedAt, DateTime.utc(2026, 1, 2));
    expect(back.fields['hourly_rate'], 75);
    expect(back.fields['currency_label'], 'EUR');
  });
}
