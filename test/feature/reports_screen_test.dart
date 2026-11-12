import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:timer/core/services/database/app_database.dart';
import 'package:timer/feature/activities/data/activity_repository.dart';
import 'package:timer/feature/history/data/history_repository.dart';
import 'package:timer/feature/history/presentation/reports_screen.dart';
import 'package:timer/feature/tracker/data/session_repository.dart';

void main() {
  late AppDatabase db;
  late int ratedId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final activities = ActivityRepository(db);
    final sessions = SessionRepository(db);
    ratedId = await activities.create(
      name: 'Client X',
      hourlyRate: 75,
      currencyLabel: 'EUR',
    );
    // One 1-hour session today so it falls in the default "Month" period.
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 9, 0);
    final id = await sessions.startSession(activityId: ratedId, start: start);
    await sessions.closeSession(id, start.add(const Duration(hours: 1)));
  });

  tearDown(() => db.close());

  Widget wrap() {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        Provider<ActivityRepository>.value(value: ActivityRepository(db)),
        Provider<HistoryRepository>.value(value: HistoryRepository(db)),
      ],
      child: const MaterialApp(home: ReportsScreen()),
    );
  }

  testWidgets('amount is shown with the activity currency label', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // 1h at 75/h -> amount 75.00, shown with its EUR label.
    expect(find.textContaining('75.00'), findsWidgets);
    expect(find.textContaining('EUR'), findsWidgets);
  });
}
