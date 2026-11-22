import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:timer/core/theme/app_theme.dart';
import 'package:timer/feature/sync/presentation/email_sign_in_screen.dart';
import 'package:timer/feature/sync/service/auth_service.dart';
import 'package:timer/feature/sync/service/mail_launcher.dart';

import '../support/fake_auth_backend.dart';

class _NoMail implements MailLauncher {
  @override
  Future<bool> canOpen() async => false;

  @override
  Future<void> open() async {}
}

class _FakeMail implements MailLauncher {
  int opened = 0;

  @override
  Future<bool> canOpen() async => true;

  @override
  Future<void> open() async => opened += 1;
}

const _email = Key('email-field');
const _password = Key('password-field');
const _submit = Key('email-submit');
const _resend = Key('email-resend');

void main() {
  late FakeAuthBackend backend;
  late AuthService auth;
  bool? result;

  setUp(() {
    backend = FakeAuthBackend();
    auth = AuthService(backend: backend);
    result = null;
  });

  tearDown(() => auth.dispose());

  Future<void> open(
    WidgetTester tester, {
    MailLauncher? mail,
    Size size = const Size(800, 1600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await EmailSignInScreen.show(
                  context,
                  auth: auth,
                  mail: mail ?? _NoMail(),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// Unmounts everything, so the sent view's 60 s timer is cancelled.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> fill(
    WidgetTester tester, {
    String email = 'a@b.co',
    String password = 'longenough',
  }) async {
    await tester.enterText(find.byKey(_email), email);
    await tester.enterText(find.byKey(_password), password);
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();
  }

  /// Creates an account that needs confirmation: lands on "Check your email".
  Future<void> reachSentView(WidgetTester tester, {MailLauncher? mail}) async {
    await open(tester, mail: mail);
    await tester.tap(find.text('Create account'));
    await tester.pump();
    await fill(tester);
    await submit(tester);
  }

  bool enabled(WidgetTester tester, Key key) =>
      tester.widget<ButtonStyleButton>(find.byKey(key)).onPressed != null;

  testWidgets('fields are in one AutofillGroup with email and password hints',
      (tester) async {
    await open(tester);

    expect(find.byType(AutofillGroup), findsOneWidget);
    for (final key in [_email, _password]) {
      expect(
        find.descendant(
          of: find.byType(AutofillGroup),
          matching: find.byKey(key),
        ),
        findsOneWidget,
      );
    }
    expect(
      tester.widget<TextField>(find.byKey(_email)).autofillHints,
      [AutofillHints.email],
    );
    expect(
      tester.widget<TextField>(find.byKey(_password)).autofillHints,
      [AutofillHints.password],
    );
    expect(tester.widget<TextField>(find.byKey(_password)).obscureText, true);
    expect(find.text('Sign in with email'), findsOneWidget);

    await tester.tap(find.text('Create account'));
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byKey(_password)).autofillHints,
      [AutofillHints.newPassword],
    );
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('At least 8 characters.'), findsOneWidget);
  });

  testWidgets('create account stays disabled under 8 characters',
      (tester) async {
    await open(tester);
    await tester.tap(find.text('Create account'));
    await tester.pump();

    await fill(tester, password: '1234567');
    expect(enabled(tester, _submit), false);

    await fill(tester, password: '12345678');
    expect(enabled(tester, _submit), true);
    expect(backend.calls, 0);
  });

  testWidgets(
      'create account shows Check your email when confirmation is needed',
      (tester) async {
    await reachSentView(tester);

    expect(find.text('Check your email'), findsOneWidget);
    expect(
      find.text('We sent a link to a@b.co. Open it on this device to finish.'),
      findsOneWidget,
    );
    expect(backend.lastRedirect, 'timer://auth-callback');
    expect(backend.lastPassword, 'longenough');
    expect(auth.isSignedIn, false);
    expect(result, isNull);

    await close(tester);
  });

  testWidgets('resend is locked for 60 seconds, then sends again',
      (tester) async {
    await reachSentView(tester);

    expect(enabled(tester, _resend), false);
    expect(find.text('Resend (available in 60 s)'), findsOneWidget);

    await tester.pump(const Duration(seconds: 59));
    expect(enabled(tester, _resend), false);

    await tester.pump(const Duration(seconds: 1));
    expect(enabled(tester, _resend), true);
    expect(find.text('Resend email'), findsOneWidget);

    await tester.tap(find.byKey(_resend));
    await tester.pump();

    expect(backend.resendCalls, 1);
    expect(backend.lastRedirect, 'timer://auth-callback');
    expect(enabled(tester, _resend), false);

    await close(tester);
  });

  testWidgets('a rate-limited resend shows the message and stays put',
      (tester) async {
    await reachSentView(tester);
    await tester.pump(const Duration(seconds: 60));
    backend.nextError = const supabase.AuthApiException(
      'mail limit',
      statusCode: '429',
      code: 'over_email_send_rate_limit',
    );

    await tester.tap(find.byKey(_resend));
    await tester.pumpAndSettle();

    // The error was consumed, so the resend did reach the backend.
    expect(backend.nextError, isNull);
    expect(
      find.text('Too many attempts. Wait a minute and try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('mail limit'), findsNothing);
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.byKey(_submit), findsNothing);
    expect(result, isNull);

    await close(tester);
  });

  testWidgets('the confirmation link arriving closes the screen with true',
      (tester) async {
    await reachSentView(tester);

    backend.emitSignedIn('u1');
    await tester.pumpAndSettle();

    expect(result, true);
    expect(find.text('Check your email'), findsNothing);

    await close(tester);
  });

  testWidgets('sign in closes the screen with true', (tester) async {
    await open(tester);
    await fill(tester, password: 'pw');

    await submit(tester);

    expect(result, true);
    expect(backend.lastEmail, 'a@b.co');
    expect(backend.lastPassword, 'pw');
    expect(find.byKey(_submit), findsNothing);
  });

  testWidgets('wrong password shows the plain message and stays open',
      (tester) async {
    await open(tester);
    await fill(tester, password: 'wrong');
    backend.nextError = const supabase.AuthApiException(
      'Invalid login credentials',
      statusCode: '400',
      code: 'invalid_credentials',
    );

    await submit(tester);

    expect(find.text('Wrong email or password.'), findsOneWidget);
    expect(find.textContaining('Invalid login'), findsNothing);
    expect(result, isNull);
    expect(auth.isSignedIn, false);
    expect(find.byKey(_submit), findsOneWidget);
  });

  testWidgets('unconfirmed email offers a resend', (tester) async {
    await open(tester);
    await fill(tester, password: 'pw');
    backend.nextError = const supabase.AuthApiException(
      'Email not confirmed',
      statusCode: '400',
      code: 'email_not_confirmed',
    );

    await submit(tester);

    expect(
      find.text('Confirm your email first. Check your inbox.'),
      findsOneWidget,
    );
    const resendConfirmation = Key('email-resend-confirmation');
    expect(find.byKey(resendConfirmation), findsOneWidget);

    await tester.tap(find.byKey(resendConfirmation));
    await tester.pumpAndSettle();

    expect(backend.resendCalls, 1);
    expect(find.text('Check your email'), findsOneWidget);

    await close(tester);
  });

  testWidgets('offline shows the offline message', (tester) async {
    await open(tester);
    await fill(tester, password: 'pw');
    backend.nextError = supabase.AuthRetryableFetchException();

    await submit(tester);

    expect(
      find.text('No connection. Your timer still works offline.'),
      findsOneWidget,
    );
    expect(result, isNull);
  });

  testWidgets('forgot password without an email asks for it', (tester) async {
    await open(tester);

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email first.'), findsOneWidget);
    expect(backend.resetCalls, 0);
  });

  testWidgets('forgot password sends a reset and shows Check your email',
      (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(_email), 'a@b.co');
    await tester.pump();

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(backend.resetCalls, 1);
    expect(backend.lastEmail, 'a@b.co');
    expect(backend.lastRedirect, 'timer://auth-callback');
    expect(find.text('Check your email'), findsOneWidget);

    await close(tester);
  });

  testWidgets('resend after a password reset sends the reset mail again',
      (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(_email), 'a@b.co');
    await tester.pump();
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(backend.resetCalls, 1);

    await tester.pump(const Duration(seconds: 60));
    // Cleared, so the redirect below can only come from the resend.
    backend.lastRedirect = null;
    await tester.tap(find.byKey(_resend));
    await tester.pump();

    expect(backend.resetCalls, 2);
    expect(backend.resendCalls, 0);
    expect(backend.lastRedirect, 'timer://auth-callback');

    await close(tester);
  });

  testWidgets('Open Mail is hidden when Mail cannot open, shown when it can',
      (tester) async {
    await reachSentView(tester);
    expect(find.text('Open Mail'), findsNothing);
    await close(tester);

    final mail = _FakeMail();
    await reachSentView(tester, mail: mail);
    expect(find.text('Open Mail'), findsOneWidget);

    await tester.tap(find.text('Open Mail'));
    await tester.pump();
    expect(mail.opened, 1);

    await close(tester);
  });

  // A layout overflow fails a widget test, so showing each state is the check.
  testWidgets('the form and the sent view fit a small iPhone', (tester) async {
    await open(tester, mail: _FakeMail(), size: const Size(320, 568));
    await fill(tester, password: 'pw');
    backend.nextError = const supabase.AuthApiException(
      'Email not confirmed',
      statusCode: '400',
      code: 'email_not_confirmed',
    );
    await submit(tester);
    expect(find.byKey(_submit), findsOneWidget);

    await tester.tap(find.text('Create account').first);
    await tester.pump();
    await fill(tester);
    await submit(tester);

    expect(find.text('Check your email'), findsOneWidget);
    expect(find.text('Open Mail'), findsOneWidget);

    await close(tester);
  });

  testWidgets('Back to sign in returns to the form', (tester) async {
    await reachSentView(tester);

    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();

    expect(find.byKey(_submit), findsOneWidget);
    expect(find.text('Check your email'), findsNothing);
    expect(find.text('Sign in with email'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(_password)).controller!.text, '');
  });
}
