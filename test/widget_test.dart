import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:timer/core/services/database/app_database.dart';
import 'package:timer/core/services/storage_location_service.dart';
import 'package:timer/core/services/window_controller.dart';
import 'package:timer/feature/activities/data/activity_repository.dart';
import 'package:timer/feature/tracker/data/session_repository.dart';
import 'package:timer/feature/tracker/service/timer_engine.dart';
import 'package:timer/main.dart';

TimerApp _buildApp(AppDatabase database) {
  final sessionRepository = SessionRepository(database);
  return TimerApp(
    storage: StorageLocationService(),
    database: database,
    activityRepository: ActivityRepository(database),
    sessionRepository: sessionRepository,
    timerEngine: TimerEngine(sessionRepository),
    windowController: WindowController(),
  );
}

/// Unmounts the app so drift's watch streams close, then flushes the
/// zero-duration timer that close schedules (keeps FakeAsync clean).
Future<void> _teardownApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('Home shows the idle state with a disabled Start',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(_buildApp(database));
    await tester.pumpAndSettle();

    expect(find.text('No activities yet — add one to start tracking.'),
        findsOneWidget);
    final start = tester.widget<FilledButton>(find.bySubtype<FilledButton>());
    expect(start.onPressed, isNull);

    await _teardownApp(tester);
  });

  testWidgets('providers expose database, storage, and timer engine',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(_buildApp(database));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Start'));
    expect(context.read<AppDatabase>(), same(database));
    expect(context.read<StorageLocationService>(), isNotNull);
    expect(context.read<TimerEngine>(), isNotNull);

    await _teardownApp(tester);
  });
}
