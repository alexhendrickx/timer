import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/services/database/app_database.dart';
import 'package:timer/feature/activities/data/activity_repository.dart';
import 'package:timer/feature/export/service/export_service.dart';
import 'package:timer/feature/history/data/history_repository.dart';
import 'package:timer/feature/settings/data/rounding_settings.dart';
import 'package:timer/feature/tracker/data/session_repository.dart';

void main() {
  late AppDatabase db;
  late ExportService svc;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('timer_export_test_');
    svc = ExportService(
      history: HistoryRepository(db),
      activities: ActivityRepository(db),
      rounding: RoundingSettings(),
      tempDirProvider: () async => tempDir,
    );
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('safeFileName sanitizes and lowercases', () {
    expect(svc.safeFileName('Client X / 2026'), 'client_x_2026');
  });

  test('two activities with the same sanitized name are de-duplicated', () {
    expect(svc.safeFileName('Client!'), 'client_');
    expect(svc.safeFileName('Client?'), 'client__2');
  });

  test('perActivity scope builds one file set per activity', () async {
    final activities = ActivityRepository(db);
    final sessions = SessionRepository(db);
    final a1 = await activities.create(name: 'Client X');
    final a2 = await activities.create(name: 'Client Y');
    for (final activityId in [a1, a2]) {
      final id = await sessions.startSession(
          activityId: activityId, start: DateTime(2026, 11, 1, 9, 0));
      await sessions.closeSession(id, DateTime(2026, 11, 1, 10, 0));
    }

    final files = await svc.buildFiles(
      formats: {ExportFormat.csv},
      scope: ExportScope.perActivity,
    );
    expect(files.length, 2);
  });

  test('combined scope builds one file per requested format', () async {
    final activities = ActivityRepository(db);
    final sessions = SessionRepository(db);
    final a1 = await activities.create(name: 'Client X');
    final id = await sessions.startSession(
        activityId: a1, start: DateTime(2026, 11, 1, 9, 0));
    await sessions.closeSession(id, DateTime(2026, 11, 1, 10, 0));

    final files = await svc.buildFiles(
      formats: {ExportFormat.csv, ExportFormat.html, ExportFormat.pdf},
      scope: ExportScope.combined,
    );
    expect(files.length, 3);
  });

  test('combined scope with mixed currencies omits the grand amount', () async {
    final activities = ActivityRepository(db);
    final sessions = SessionRepository(db);
    final eur = await activities.create(
        name: 'Client EUR', hourlyRate: 75, currencyLabel: 'EUR');
    final usd = await activities.create(
        name: 'Client USD', hourlyRate: 100, currencyLabel: 'USD');
    for (final activityId in [eur, usd]) {
      final id = await sessions.startSession(
          activityId: activityId, start: DateTime(2026, 11, 1, 9, 0));
      await sessions.closeSession(id, DateTime(2026, 11, 1, 10, 0));
    }

    final files = await svc.buildFiles(
      formats: {ExportFormat.html},
      scope: ExportScope.combined,
    );
    final html = await File(files.single.path).readAsString();
    // Per-activity amounts still appear (75.00 EUR, 100.00 USD) but the
    // grand-total line must not sum two currencies into one figure.
    final grandLine = html
        .split('\n')
        .firstWhere((l) => l.contains('Grand total'));
    expect(grandLine, isNot(contains('175.00')));
  });

  test('combined scope with one currency keeps the grand amount', () async {
    final activities = ActivityRepository(db);
    final sessions = SessionRepository(db);
    final a1 = await activities.create(
        name: 'Client A', hourlyRate: 75, currencyLabel: 'EUR');
    final a2 = await activities.create(
        name: 'Client B', hourlyRate: 25, currencyLabel: 'EUR');
    for (final activityId in [a1, a2]) {
      final id = await sessions.startSession(
          activityId: activityId, start: DateTime(2026, 11, 1, 9, 0));
      await sessions.closeSession(id, DateTime(2026, 11, 1, 10, 0));
    }

    final files = await svc.buildFiles(
      formats: {ExportFormat.html},
      scope: ExportScope.combined,
    );
    final html = await File(files.single.path).readAsString();
    final grandLine = html
        .split('\n')
        .firstWhere((l) => l.contains('Grand total'));
    expect(grandLine, contains('100.00')); // 75 + 25, same currency
  });

  test('empty filter yields a well-formed empty CSV, not a crash', () async {
    final files = await svc.buildFiles(
      formats: {ExportFormat.csv},
      scope: ExportScope.combined,
    );
    expect(files.length, 1);
    final content = await File(files.single.path).readAsString();
    expect(content.trim(), 'activity,date,start,end,duration,note');
  });
}
