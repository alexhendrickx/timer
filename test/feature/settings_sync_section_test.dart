import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:timer/core/services/notifications_service.dart';
import 'package:timer/core/services/storage_location_service.dart';
import 'package:timer/feature/settings/data/reminder_settings.dart';
import 'package:timer/feature/settings/data/rounding_settings.dart';
import 'package:timer/feature/settings/presentation/settings_screen.dart';
import 'package:timer/feature/sync/service/auth_service.dart';
import 'package:timer/feature/tracker/service/reminder_scheduler.dart';

import '../support/fake_auth_backend.dart';

void main() {
  late FakeAuthBackend backend;

  setUp(() => backend = FakeAuthBackend());

  AuthService buildAuth({GoogleCredentialGetter? getGoogleCredential}) {
    final auth = AuthService(
      backend: backend,
      getAppleCredential: (_) async =>
          const AppleCredential(identityToken: 'apple-token'),
      getGoogleCredential: getGoogleCredential,
    );
    addTearDown(auth.dispose);
    return auth;
  }

  Future<void> pumpSettings(WidgetTester tester, AuthService? auth) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = ReminderSettings();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<StorageLocationService>.value(
            value: StorageLocationService(),
          ),
          Provider<ReminderSettings>.value(value: settings),
          Provider<ReminderScheduler>.value(
            value: ReminderScheduler(
              settings: settings,
              notifications: NotificationsService(),
              onBreakDue: (_) {},
            ),
          ),
          Provider<RoundingSettings>.value(value: RoundingSettings()),
          ChangeNotifierProvider<AuthService?>.value(value: auth),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('no AuthService: no Sync section', (tester) async {
    await pumpSettings(tester, null);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Sync'), findsNothing);
    expect(find.text('Sign in with Apple'), findsNothing);
    expect(find.text('Continue with email'), findsNothing);
  });

  testWidgets(
      'signed out: offers Apple and email, and Google only when available',
      (tester) async {
    await pumpSettings(tester, buildAuth());

    expect(find.text('Sync'), findsOneWidget);
    expect(find.text('Sign in with Apple'), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsNothing);
    expect(find.text('Sign out'), findsNothing);

    await pumpSettings(
      tester,
      buildAuth(
        getGoogleCredential: () async =>
            const GoogleCredential(idToken: 'g', rawNonce: 'raw'),
      ),
    );

    expect(find.text('Sign in with Apple'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);
  });

  testWidgets('signed in: shows the email and Sign out; tapping it signs out',
      (tester) async {
    final auth = buildAuth();
    await auth.signInWithEmail(email: 'a@b.co', password: 'pw');
    await pumpSettings(tester, auth);

    expect(find.text('a@b.co'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Sign in with Apple'), findsNothing);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(backend.signedOutCalled, true);
    expect(auth.isSignedIn, false);
    expect(find.text('Sign in with Apple'), findsOneWidget);
    expect(find.text('a@b.co'), findsNothing);
  });
}
