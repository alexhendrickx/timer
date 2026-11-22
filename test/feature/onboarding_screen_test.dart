import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timer/core/platform/platform_shell.dart';
import 'package:timer/core/routing/app_router.dart';
import 'package:timer/core/services/database/app_database.dart';
import 'package:timer/core/services/storage_location_service.dart';
import 'package:timer/core/theme/app_theme.dart';
import 'package:timer/feature/activities/data/activity_repository.dart';
import 'package:timer/feature/activities/presentation/widgets/activity_edit_sheet.dart';
import 'package:timer/feature/history/data/history_repository.dart';
import 'package:timer/feature/onboarding/presentation/onboarding_screen.dart';
import 'package:timer/feature/onboarding/presentation/widgets/activities_step.dart';
import 'package:timer/feature/sync/service/auth_service.dart';
import 'package:timer/feature/tracker/data/session_repository.dart';
import 'package:timer/feature/tracker/service/timer_engine.dart';
import 'package:timer/main.dart';

import '../support/fake_auth_backend.dart';

/// A minimal Mac-like shell (`hasMenuBar == true`).
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

/// Fails every [create] while [failCreate] is set.
class _FlakyActivityRepository extends ActivityRepository {
  _FlakyActivityRepository(super.db);

  bool failCreate = true;

  @override
  Future<int> create({
    required String name,
    int? color,
    double? hourlyRate,
    String? currencyLabel,
  }) async {
    if (failCreate) throw StateError('write failed');
    return super.create(
      name: name,
      color: color,
      hourlyRate: hourlyRate,
      currencyLabel: currencyLabel,
    );
  }
}

const _continue = Key('onboarding-continue');
const _iphoneStep3 = 'Start in one tap';
const _syncStep = 'Same timer on all your devices';
const _notNow = 'Not now, keep it on this device';

void main() {
  late AppDatabase db;
  late ActivityRepository repo;
  var finished = 0;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    repo = ActivityRepository(db);
    finished = 0;
  });

  tearDown(() => db.close());

  AuthService buildAuth() {
    final auth = AuthService(
      backend: FakeAuthBackend(),
      getAppleCredential: (_) async =>
          const AppleCredential(identityToken: 'apple-token'),
    );
    addTearDown(auth.dispose);
    return auth;
  }

  Future<void> pumpOnboarding(
    WidgetTester tester, {
    AuthService? auth,
    PlatformShell? shell,
    Size size = const Size(800, 1600),
    Future<void> Function()? onFinished,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ActivityRepository>.value(value: repo),
          Provider<PlatformShell>.value(value: shell ?? NoopPlatformShell()),
          ChangeNotifierProvider<AuthService?>.value(value: auth),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: OnboardingScreen(
            onFinished: onFinished ?? () async => finished += 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Unmounts so drift's watch stream closes, then flushes the zero-duration
  /// timer that close schedules (keeps FakeAsync clean).
  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> tapContinue(WidgetTester tester) async {
    await tester.tap(find.byKey(_continue));
    await tester.pumpAndSettle();
  }

  bool continueEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(_continue)).onPressed != null;

  /// Taps [finder] and returns the error its handler let escape, or null.
  /// The tap runs in its own zone: an uncaught async error in the test zone
  /// ends the test on the spot.
  Future<Object?> tapCatching(WidgetTester tester, Finder finder) async {
    Object? escaped;
    await runZonedGuarded(
      () => tester.tap(finder),
      (error, _) => escaped = error,
    );
    await tester.pumpAndSettle();
    return escaped;
  }

  /// An `onFinished` that throws on its first run and records the later ones.
  Future<void> Function() failingOnce() {
    var attempts = 0;
    return () async {
      attempts += 1;
      if (attempts == 1) throw StateError('finish failed');
      finished += 1;
    };
  }

  Future<List<String>> activeNames() async =>
      (await repo.activeActivities()).map((a) => a.name).toList();

  testWidgets(
      'the first two presets are preselected and Continue creates exactly those',
      (tester) async {
    await pumpOnboarding(tester);

    expect(find.text('What do you track?'), findsOneWidget);
    expect(find.text('Continue · 2 selected'), findsOneWidget);
    for (final preset in onboardingPresets) {
      expect(find.text(preset.name), findsOneWidget);
    }

    await tapContinue(tester);

    final created = await repo.activeActivities();
    expect(created.map((a) => a.name), ['Client work', 'Meetings']);
    expect(created.map((a) => a.color), [
      activitySwatches[0],
      activitySwatches[1],
    ]);

    await teardown(tester);
  });

  test('the five presets have five different colours', () {
    expect(onboardingPresets.map((p) => p.name), [
      'Client work',
      'Meetings',
      'Admin',
      'Deep focus',
      'Learning',
    ]);
    expect(onboardingPresets.map((p) => p.color).toSet().length, 5);
    for (final preset in onboardingPresets) {
      expect(activitySwatches, contains(preset.color));
    }
  });

  testWidgets('ticking a third preset creates three', (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('Deep focus'));
    await tester.pump();
    expect(find.text('Continue · 3 selected'), findsOneWidget);
    await tapContinue(tester);

    expect(await activeNames(), ['Client work', 'Deep focus', 'Meetings']);

    await teardown(tester);
  });

  testWidgets('Continue is disabled with nothing selected', (tester) async {
    await pumpOnboarding(tester);
    expect(continueEnabled(tester), true);

    await tester.tap(find.text('Client work'));
    await tester.tap(find.text('Meetings'));
    await tester.pump();

    expect(continueEnabled(tester), false);
    expect(find.text('Continue · 0 selected'), findsOneWidget);

    await teardown(tester);
  });

  testWidgets('Add your own opens the add-activity sheet', (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('Add your own'));
    await tester.pumpAndSettle();

    expect(find.text('Add activity'), findsOneWidget);

    await teardown(tester);
  });

  testWidgets('an added activity enables Continue with no preset ticked',
      (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.text('Client work'));
    await tester.tap(find.text('Meetings'));
    await tester.pump();

    await tester.tap(find.text('Add your own'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Writing');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Writing'), findsOneWidget);
    expect(find.text('Continue · 1 selected'), findsOneWidget);
    expect(continueEnabled(tester), true);

    await tapContinue(tester);
    expect(await activeNames(), ['Writing']);

    await teardown(tester);
  });

  testWidgets('without AuthService the sync step is skipped', (tester) async {
    await pumpOnboarding(tester, auth: null);

    await tapContinue(tester);

    expect(find.text(_iphoneStep3), findsOneWidget);
    expect(find.text(_syncStep), findsNothing);
    expect(find.text('Sign in with Apple'), findsNothing);
    expect(find.text('Continue with email'), findsNothing);

    await teardown(tester);
  });

  testWidgets('with AuthService the sync step shows, and Not now moves on',
      (tester) async {
    await pumpOnboarding(tester, auth: buildAuth());

    await tapContinue(tester);

    expect(find.text(_syncStep), findsOneWidget);
    expect(find.text('Sign in with Apple'), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);
    // Nothing on this step may promise what the app does not do.
    expect(find.textContaining('Delete your account'), findsNothing);

    await tester.tap(find.text(_notNow));
    await tester.pumpAndSettle();

    expect(find.text(_iphoneStep3), findsOneWidget);
    expect(finished, 0);

    await teardown(tester);
  });

  testWidgets('signing in on the sync step moves on', (tester) async {
    final auth = buildAuth();
    await pumpOnboarding(tester, auth: auth);
    await tapContinue(tester);

    await tester.tap(find.text('Sign in with Apple'));
    await tester.pumpAndSettle();

    expect(auth.isSignedIn, true);
    expect(find.text(_iphoneStep3), findsOneWidget);

    await teardown(tester);
  });

  testWidgets('a sign-in that finishes after Not now does not end onboarding',
      (tester) async {
    final credential = Completer<AppleCredential>();
    final auth = AuthService(
      backend: FakeAuthBackend(),
      getAppleCredential: (_) => credential.future,
    );
    addTearDown(auth.dispose);
    await pumpOnboarding(tester, auth: auth);
    await tapContinue(tester);

    await tester.tap(find.text('Sign in with Apple'));
    await tester.pump();
    await tester.tap(find.text(_notNow));
    await tester.pumpAndSettle();
    expect(find.text(_iphoneStep3), findsOneWidget);

    credential.complete(const AppleCredential(identityToken: 'apple-token'));
    await tester.pumpAndSettle();

    // The late sign-in still lands, but it must not press Done for the user.
    expect(auth.isSignedIn, true);
    expect(find.text(_iphoneStep3), findsOneWidget);
    expect(finished, 0);

    await teardown(tester);
  });

  testWidgets('a user who is already signed in does not get the sync step',
      (tester) async {
    final auth = buildAuth();
    await auth.signInWithApple();
    await pumpOnboarding(tester, auth: auth);

    await tapContinue(tester);

    expect(find.text(_iphoneStep3), findsOneWidget);

    await teardown(tester);
  });

  testWidgets('Skip setup finishes without creating anything', (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('Skip setup'));
    await tester.pumpAndSettle();

    expect(finished, 1);
    expect(await repo.activeActivities(), isEmpty);
    expect(await repo.hasAnyActivity(), false);

    await teardown(tester);
  });

  testWidgets('Done finishes', (tester) async {
    await pumpOnboarding(tester);
    await tapContinue(tester);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(finished, 1);

    await teardown(tester);
  });

  testWidgets('a failed create re-enables Continue and Skip setup',
      (tester) async {
    final flaky = _FlakyActivityRepository(db);
    repo = flaky;
    await pumpOnboarding(tester);

    final error = await tapCatching(tester, find.byKey(_continue));

    expect(error, isA<StateError>());
    expect(find.text('What do you track?'), findsOneWidget);
    expect(await activeNames(), isEmpty);
    expect(continueEnabled(tester), true);
    final skip = find.widgetWithText(TextButton, 'Skip setup');
    expect(tester.widget<TextButton>(skip).onPressed, isNotNull);

    flaky.failCreate = false;
    await tapContinue(tester);

    expect(await activeNames(), ['Client work', 'Meetings']);
    expect(find.text(_iphoneStep3), findsOneWidget);

    await teardown(tester);
  });

  testWidgets('Skip setup works again after finishing failed', (tester) async {
    await pumpOnboarding(tester, onFinished: failingOnce());

    final error = await tapCatching(tester, find.text('Skip setup'));

    expect(error, isA<StateError>());
    expect(finished, 0);

    await tester.tap(find.text('Skip setup'));
    await tester.pumpAndSettle();

    expect(finished, 1);

    await teardown(tester);
  });

  testWidgets('Done works again after finishing failed', (tester) async {
    await pumpOnboarding(tester, onFinished: failingOnce());
    await tapContinue(tester);

    final error = await tapCatching(tester, find.text('Done'));

    expect(error, isA<StateError>());
    expect(finished, 0);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(finished, 1);

    await teardown(tester);
  });

  testWidgets(
      'iPhone shows Action button, Widget and Siri; Mac shows the hotkey',
      (tester) async {
    const iphoneRows = ['Action button', 'Lock Screen widget', 'Siri'];

    await pumpOnboarding(tester);
    await tapContinue(tester);
    for (final title in iphoneRows) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('Say "Start tracking in Timer".'), findsOneWidget);
    // The iPhone page names the Mac hotkey too, as one small row.
    expect(find.text('On your Mac'), findsOneWidget);
    expect(find.text('⌘ ⇧ Space'), findsOneWidget);
    await teardown(tester);

    await pumpOnboarding(tester, shell: _FakeMacShell());
    // Presets from the first run exist already; Continue adds no duplicates.
    await tapContinue(tester);
    expect(find.text('Start with one shortcut'), findsOneWidget);
    expect(find.text('⌘ ⇧ Space'), findsOneWidget);
    expect(find.text('On your Mac'), findsNothing);
    for (final title in iphoneRows) {
      expect(find.text(title), findsNothing);
    }
    expect(await activeNames(), ['Client work', 'Meetings']);
    await teardown(tester);
  });

  // A layout overflow fails a widget test, so walking the steps is the check.
  testWidgets('every step fits a small iPhone and the Mac window',
      (tester) async {
    Future<void> walk(Size size, PlatformShell shell) async {
      final auth = AuthService(
        backend: FakeAuthBackend(),
        getGoogleCredential: () async =>
            const GoogleCredential(idToken: 'g', rawNonce: 'raw'),
      );
      addTearDown(auth.dispose);
      await pumpOnboarding(tester, auth: auth, shell: shell, size: size);
      await tapContinue(tester);
      expect(find.text('Sign in with Google'), findsOneWidget);
      await tester.tap(find.text(_notNow));
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsOneWidget);
      await teardown(tester);
    }

    await walk(const Size(320, 568), NoopPlatformShell());
    // main.dart opens the Mac window at 760x580, title bar included.
    await walk(const Size(760, 540), _FakeMacShell());
  });

  group('through the real route', () {
    TimerApp buildApp({String? initialLocation}) {
      final sessionRepository = SessionRepository(db);
      return TimerApp(
        storage: StorageLocationService(),
        database: db,
        activityRepository: repo,
        sessionRepository: sessionRepository,
        historyRepository: HistoryRepository(db),
        timerEngine: TimerEngine(sessionRepository),
        router: initialLocation == null
            ? null
            : buildAppRouter(initialLocation: initialLocation),
      );
    }

    // Bounded pumps only: mocked prefs plus the full app can keep
    // pumpAndSettle from settling (see test/widget_test.dart).
    testWidgets('Skip setup sets onboarding_done and lands on Home',
        (tester) async {
      await tester.pumpWidget(buildApp(initialLocation: '/onboarding'));
      await tester.pump();

      expect(find.text('Skip setup'), findsOneWidget);
      expect(find.text('Add your first activity'), findsNothing);

      await tester.tap(find.text('Skip setup'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_done'), true);
      expect(find.text('Add your first activity'), findsOneWidget);
      expect(find.text('Skip setup'), findsNothing);

      await teardown(tester);
    });

    testWidgets('an app started at / never shows onboarding', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Skip setup'), findsNothing);
      expect(find.text('Add your first activity'), findsOneWidget);

      await teardown(tester);
    });
  });
}
