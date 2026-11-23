import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:timer/core/platform/platform_shell.dart';
import 'package:timer/core/services/database/app_database.dart';
import 'package:timer/core/services/storage_location_service.dart';
import 'package:timer/feature/activities/data/activity_repository.dart';
import 'package:timer/feature/history/data/history_repository.dart';
import 'package:timer/feature/tracker/data/session_repository.dart';
import 'package:timer/feature/tracker/service/timer_engine.dart';
import 'package:timer/main.dart';

/// A minimal Mac-like shell for tests that need `hasMenuBar == true`
/// (Home's Mac-only affordances: the Activities shortcut, the data-folder
/// fallback banner).
class _FakeMacShell implements PlatformShell {
  @override
  Future<void> init() async {}

  @override
  void setMenuBarTitle(String title) {}

  @override
  Future<void> showQuickStartPicker() async {}

  @override
  bool get hasMenuBar => true;
}

/// Storage stub that reports a data-folder fallback reason, without touching
/// SharedPreferences (mocking prefs makes the full app's background services
/// spin, which the banner test does not need).
class _FallbackStorage extends StorageLocationService {
  _FallbackStorage(this._reason);

  final String _reason;

  @override
  String? get lastFallbackReason => _reason;
}

TimerApp _buildApp(
  AppDatabase database, {
  StorageLocationService? storage,
  PlatformShell? shell,
}) {
  final sessionRepository = SessionRepository(database);
  return TimerApp(
    storage: storage ?? StorageLocationService(),
    database: database,
    activityRepository: ActivityRepository(database),
    sessionRepository: sessionRepository,
    historyRepository: HistoryRepository(database),
    timerEngine: TimerEngine(sessionRepository),
    shell: shell,
  );
}

/// Unmounts the app so drift's watch streams close, then flushes the
/// zero-duration timer that close schedules (keeps FakeAsync clean).
Future<void> _teardownApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('Home shows the empty state with no activities',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(_buildApp(database));
    await tester.pumpAndSettle();

    expect(find.text('Add your first activity'), findsOneWidget);

    await _teardownApp(tester);
  });

  testWidgets('providers expose database, storage, and timer engine',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(_buildApp(database));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Timer'));
    expect(context.read<AppDatabase>(), same(database));
    expect(context.read<StorageLocationService>(), isNotNull);
    expect(context.read<TimerEngine>(), isNotNull);

    await _teardownApp(tester);
  });

  testWidgets(
      'Home empty state CTA opens the add-activity sheet on iPhone (no menu bar)',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(_buildApp(database));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add your first activity'));
    await tester.pumpAndSettle();

    expect(find.text('Add activity'), findsOneWidget);

    await _teardownApp(tester);
  });

  testWidgets(
      'Home empty state CTA opens the Activities screen on Mac (has menu bar)',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(_buildApp(database, shell: _FakeMacShell()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add your first activity'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Activities'), findsOneWidget);

    await _teardownApp(tester);
  });

  testWidgets(
      'Home shows a dismissible fallback banner when the Mac data folder was missing',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    const reason = 'Data folder "/no/such/dir" was missing; using the default.';
    final storage = _FallbackStorage(reason);

    await tester.pumpWidget(
      _buildApp(database, storage: storage, shell: _FakeMacShell()),
    );
    await tester.pumpAndSettle();

    expect(find.text(reason), findsOneWidget);

    // Dismissible: closing the banner removes it.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text(reason), findsNothing);

    await _teardownApp(tester);
  });
}
