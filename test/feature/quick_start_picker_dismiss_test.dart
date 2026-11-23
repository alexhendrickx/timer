import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:timer/core/services/database/app_database.dart';
import 'package:timer/feature/activities/data/activity_repository.dart';
import 'package:timer/feature/tracker/data/session_repository.dart';
import 'package:timer/feature/tracker/presentation/quick_start_picker.dart';
import 'package:timer/feature/tracker/service/start_coordinator.dart';
import 'package:timer/feature/tracker/service/timer_engine.dart';

void main() {
  testWidgets('pressing Escape dismisses the picker without starting anything',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final activities = ActivityRepository(db);
    final sessions = SessionRepository(db);
    final engine = TimerEngine(sessions);
    addTearDown(engine.dispose);
    await activities.create(name: 'Client X');

    var dismissed = false;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ActivityRepository>.value(value: activities),
          Provider<StartCoordinator>.value(value: StartCoordinator(engine)),
        ],
        child: MaterialApp(
          home: QuickStartPicker(onDismiss: () => dismissed = true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
    // Escape must not have started a timer.
    expect(engine.running, isNull);

    // Unmount so drift's watch stream closes, then flush the zero-duration
    // timer that close schedules (keeps FakeAsync clean).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
