import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:timer/core/theme/app_theme.dart';
import 'package:timer/feature/sync/presentation/widgets/sign_in_buttons.dart';
import 'package:timer/feature/sync/service/auth_failure.dart';
import 'package:timer/feature/sync/service/auth_service.dart';

import '../support/fake_auth_backend.dart';

void main() {
  late FakeAuthBackend backend;
  var signedIn = 0;

  setUp(() {
    backend = FakeAuthBackend();
    signedIn = 0;
  });

  AuthService buildAuth({
    AppleCredentialGetter? getAppleCredential,
    GoogleCredentialGetter? getGoogleCredential,
  }) {
    final auth = AuthService(
      backend: backend,
      getAppleCredential: getAppleCredential ??
          (_) async => const AppleCredential(identityToken: 'apple-token'),
      getGoogleCredential: getGoogleCredential,
    );
    addTearDown(auth.dispose);
    return auth;
  }

  Widget wrap(AuthService auth) {
    return MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SignInButtons(auth: auth, onSignedIn: () => signedIn += 1),
      ),
    );
  }

  testWidgets('Google button is hidden without a Google source',
      (tester) async {
    await tester.pumpWidget(wrap(buildAuth()));

    expect(find.text('Sign in with Apple'), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsNothing);
  });

  testWidgets('Google button is shown with a Google source', (tester) async {
    final auth = buildAuth(
      getGoogleCredential: () async =>
          const GoogleCredential(idToken: 'g', rawNonce: 'raw'),
    );
    await tester.pumpWidget(wrap(auth));

    expect(find.text('Sign in with Google'), findsOneWidget);
  });

  testWidgets('the order is Apple, Google, email', (tester) async {
    final auth = buildAuth(
      getGoogleCredential: () async =>
          const GoogleCredential(idToken: 'g', rawNonce: 'raw'),
    );
    await tester.pumpWidget(wrap(auth));

    final apple = tester.getTopLeft(find.text('Sign in with Apple')).dy;
    final google = tester.getTopLeft(find.text('Sign in with Google')).dy;
    final email = tester.getTopLeft(find.text('Continue with email')).dy;
    expect(apple, lessThan(google));
    expect(google, lessThan(email));
  });

  testWidgets('Apple success calls onSignedIn once', (tester) async {
    final auth = buildAuth();
    await tester.pumpWidget(wrap(auth));

    await tester.tap(find.text('Sign in with Apple'));
    await tester.pumpAndSettle();

    expect(signedIn, 1);
    expect(auth.isSignedIn, true);
  });

  testWidgets('Google success calls onSignedIn once', (tester) async {
    final auth = buildAuth(
      getGoogleCredential: () async =>
          const GoogleCredential(idToken: 'g', rawNonce: 'raw'),
    );
    await tester.pumpWidget(wrap(auth));

    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();

    expect(signedIn, 1);
    expect(backend.lastProvider, IdTokenProvider.google);
  });

  testWidgets('cancelling shows no error', (tester) async {
    final auth = buildAuth(
      getAppleCredential: (_) async => throw const AuthCancelled(),
    );
    await tester.pumpWidget(wrap(auth));

    await tester.tap(find.text('Sign in with Apple'));
    await tester.pumpAndSettle();

    for (final kind in AuthFailureKind.values) {
      if (kind == AuthFailureKind.cancelled) continue;
      expect(find.text(AuthFailure(kind).message), findsNothing);
    }
    expect(signedIn, 0);
    expect(auth.isSignedIn, false);
  });

  testWidgets('a failure shows the mapped message', (tester) async {
    final auth = buildAuth();
    backend.nextError = supabase.AuthRetryableFetchException();
    await tester.pumpWidget(wrap(auth));

    await tester.tap(find.text('Sign in with Apple'));
    await tester.pumpAndSettle();

    expect(
      find.text('No connection. Your timer still works offline.'),
      findsOneWidget,
    );
    expect(auth.isSignedIn, false);
    expect(signedIn, 0);
  });
}
