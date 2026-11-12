import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/platform/ios/widget_snapshot_writer.dart';
import 'package:timer/core/services/database/app_database.dart';
import 'package:timer/feature/activities/data/activity_repository.dart';
import 'package:timer/feature/tracker/data/session_repository.dart';

void main() {
  late AppDatabase db;
  late ActivityRepository activities;
  late SessionRepository sessions;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    activities = ActivityRepository(db);
    sessions = SessionRepository(db);
  });

  tearDown(() async => db.close());

  test('writes active activities with today totals, archived excluded',
      () async {
    final a = await activities.create(name: 'Client A', color: 0xFF0000);
    final b = await activities.create(name: 'Client B');
    final archived = await activities.create(name: 'Old client');
    await activities.archive(archived);

    final now = DateTime(2026, 11, 12, 9);
    final sid = await sessions.startSession(activityId: a, start: now);
    await sessions.closeSession(sid, now.add(const Duration(minutes: 30)));

    String? written;
    final writer = WidgetSnapshotWriter(
      activityRepository: activities,
      sessionRepository: sessions,
      writeSnapshot: (json) async => written = json,
      now: () => now,
    );

    await writer.sync();

    final decoded = jsonDecode(written!) as List;
    expect(decoded.length, 2);
    final clientA = decoded.firstWhere((e) => e['activityId'] == a);
    expect(clientA['name'], 'Client A');
    expect(clientA['color'], 0xFF0000);
    expect(clientA['todaySeconds'], 1800);
    final clientB = decoded.firstWhere((e) => e['activityId'] == b);
    expect(clientB['todaySeconds'], 0);
    expect(decoded.any((e) => e['activityId'] == archived), isFalse);
  });

  test('empty activities writes an empty snapshot, not a crash', () async {
    String? written;
    final writer = WidgetSnapshotWriter(
      activityRepository: activities,
      sessionRepository: sessions,
      writeSnapshot: (json) async => written = json,
    );

    await writer.sync();

    expect(jsonDecode(written!), isEmpty);
  });
}
