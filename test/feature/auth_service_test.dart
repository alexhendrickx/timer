import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:timer/feature/sync/service/auth_failure.dart';
import 'package:timer/feature/sync/service/auth_service.dart';

import '../support/fake_auth_backend.dart';

Matcher throwsFailure(AuthFailureKind kind) =>
    throwsA(isA<AuthFailure>().having((f) => f.kind, 'kind', kind));

const _invalidCredentials = supabase.AuthApiException(
  'Invalid login credentials',
  statusCode: '400',
  code: 'invalid_credentials',
);

void main() {
  late FakeAuthBackend backend;

  setUp(() => backend = FakeAuthBackend());

  AuthService build({
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

  test('isSignedIn is false and userId is null before any sign-in', () {
    final auth = AuthService(backend: FakeAuthBackend());
    expect(auth.isSignedIn, false);
    expect(auth.userId, isNull);
  });

  test('signInWithApple exchanges the Apple credential and becomes signed in',
      () async {
    final backend = FakeAuthBackend();
    final auth = AuthService(
      backend: backend,
      getAppleCredential: (_) async =>
          const AppleCredential(identityToken: 'apple-token-1'),
    );

    var emittedSignedIn = false;
    auth.authState.listen((signedIn) => emittedSignedIn = signedIn);

    await auth.signInWithApple();

    expect(auth.isSignedIn, true);
    expect(auth.userId, 'user-from-apple-token-1');
    await pumpEventQueue();
    expect(emittedSignedIn, true);
  });

  test('signOut returns to signed-out and clears userId', () async {
    final backend = FakeAuthBackend();
    final auth = AuthService(
      backend: backend,
      getAppleCredential: (_) async =>
          const AppleCredential(identityToken: 'apple-token-2'),
    );
    await auth.signInWithApple();
    expect(auth.isSignedIn, true);

    await auth.signOut();

    expect(auth.isSignedIn, false);
    expect(auth.userId, isNull);
    expect(backend.signedOutCalled, true);
  });

  test('Apple gets the SHA-256 of the nonce Supabase gets', () async {
    String? captured;
    final auth = build(
      getAppleCredential: (hashedNonce) async {
        captured = hashedNonce;
        return const AppleCredential(identityToken: 'apple-token');
      },
    );

    await auth.signInWithApple();

    final rawNonce = backend.lastNonce;
    expect(rawNonce, isNotNull);
    expect(rawNonce, isNotEmpty);
    expect(captured, sha256.convert(utf8.encode(rawNonce!)).toString());
    expect(captured, isNot(rawNonce));
    expect(backend.lastProvider, IdTokenProvider.apple);
  });

  test('Apple nonce is new on every sign-in', () async {
    final auth = build();

    await auth.signInWithApple();
    final first = backend.lastNonce;
    await auth.signOut();
    await auth.signInWithApple();
    final second = backend.lastNonce;

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(second, isNot(first));
  });

  test('signInWithGoogle sends the tokens and raw nonce as provider google',
      () async {
    final auth = build(
      getGoogleCredential: () async => const GoogleCredential(
        idToken: 'g',
        accessToken: 'a',
        rawNonce: 'raw',
      ),
    );

    await auth.signInWithGoogle();

    expect(backend.lastProvider, IdTokenProvider.google);
    expect(backend.lastIdToken, 'g');
    expect(backend.lastAccessToken, 'a');
    expect(backend.lastNonce, 'raw');
    expect(auth.isSignedIn, true);
  });

  test(
      'without a Google source: unavailable, and signInWithGoogle fails '
      'without calling the backend', () async {
    final auth = build();

    expect(auth.googleAvailable, false);
    await expectLater(
      auth.signInWithGoogle(),
      throwsFailure(AuthFailureKind.unknown),
    );
    expect(backend.calls, 0);
  });

  test(
      'signUpWithEmail returns confirmationSent and stays signed out when no '
      'session comes back', () async {
    final auth = build();

    final result = await auth.signUpWithEmail(
      email: '  a@b.co ',
      password: 'longenough',
    );

    expect(result, EmailSignUpResult.confirmationSent);
    expect(auth.isSignedIn, false);
    expect(backend.lastRedirect, 'timer://auth-callback');
    expect(backend.lastEmail, 'a@b.co');
  });

  test('signUpWithEmail signs in when a session comes back', () async {
    backend.signUpNeedsConfirmation = false;
    final auth = build();

    final result = await auth.signUpWithEmail(
      email: 'a@b.co',
      password: 'longenough',
    );

    expect(result, EmailSignUpResult.signedIn);
    expect(auth.isSignedIn, true);
  });

  test(
      'signUpWithEmail rejects a 7-character password before any backend call',
      () async {
    final auth = build();

    await expectLater(
      auth.signUpWithEmail(email: 'a@b.co', password: '1234567'),
      throwsFailure(AuthFailureKind.weakPassword),
    );
    expect(backend.calls, 0);
  });

  test('signInWithEmail signs in and exposes the email', () async {
    final auth = build();

    await auth.signInWithEmail(email: 'a@b.co', password: 'pw');

    expect(auth.isSignedIn, true);
    expect(auth.email, 'a@b.co');
  });

  test('sendPasswordReset passes the email and timer://auth-callback',
      () async {
    final auth = build();

    await auth.sendPasswordReset(' a@b.co ');

    expect(backend.resetCalls, 1);
    expect(backend.lastEmail, 'a@b.co');
    expect(backend.lastRedirect, 'timer://auth-callback');
  });

  test('resendConfirmation passes the email and timer://auth-callback',
      () async {
    final auth = build();

    await auth.resendConfirmation(' a@b.co ');

    expect(backend.resendCalls, 1);
    expect(backend.lastEmail, 'a@b.co');
    expect(backend.lastRedirect, 'timer://auth-callback');
  });

  test('updatePassword forwards the password; 7 characters is rejected first',
      () async {
    final auth = build();

    await auth.updatePassword('longenough');
    expect(backend.lastNewPassword, 'longenough');
    final callsBefore = backend.calls;

    await expectLater(
      auth.updatePassword('1234567'),
      throwsFailure(AuthFailureKind.weakPassword),
    );
    expect(backend.calls, callsBefore);
    expect(backend.lastNewPassword, 'longenough');
  });

  test('a password-reset link signs in and latches recovery exactly once',
      () async {
    final auth = build();
    var notified = 0;
    auth.addListener(() => notified += 1);

    backend.emitPasswordRecovery('u1');
    await pumpEventQueue();

    expect(auth.isSignedIn, true);
    expect(notified, 1);
    expect(auth.takePasswordRecovery(), true);
    expect(auth.takePasswordRecovery(), false);
  });

  test('a stream error changes nothing and later events still arrive',
      () async {
    final auth = build();
    final states = <bool>[];
    auth.authState.listen(states.add);

    backend.emitError(const supabase.AuthException('bad link'));
    await pumpEventQueue();

    expect(auth.isSignedIn, false);
    expect(states, isEmpty);

    backend.emitSignedIn('u2');
    await pumpEventQueue();

    expect(auth.isSignedIn, true);
    expect(states, [true]);
  });

  test('a failed sign-in leaves the service signed out', () async {
    final auth = build();
    var notified = 0;
    auth.addListener(() => notified += 1);
    backend.nextError = _invalidCredentials;

    await expectLater(
      auth.signInWithEmail(email: 'a@b.co', password: 'wrong'),
      throwsFailure(AuthFailureKind.invalidCredentials),
    );

    expect(auth.isSignedIn, false);
    expect(notified, 0);
  });

  test('signOut clears state even when the backend throws', () async {
    final auth = build();
    await auth.signInWithEmail(email: 'a@b.co', password: 'pw');
    expect(auth.isSignedIn, true);
    backend.nextError = supabase.AuthRetryableFetchException();

    await auth.signOut();

    expect(auth.isSignedIn, false);
  });

  group('defaultGetAppleCredential', () {
    const channel =
        MethodChannel('com.aboutyou.dart_packages.sign_in_with_apple');

    /// Answers the plugin's native call with [handler] for one test.
    void mockAppleSheet(Future<Object?> Function(MethodCall call) handler) {
      final messenger = TestWidgetsFlutterBinding.ensureInitialized()
          .defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, handler);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }

    test('sends the hashed nonce it was given and returns the identity token',
        () async {
      final requests = <MethodCall>[];
      mockAppleSheet((call) async {
        requests.add(call);
        return <String, Object?>{
          'type': 'appleid',
          'authorizationCode': 'code',
          'identityToken': 'apple-identity-token',
        };
      });
      final hashedNonce = hashNonce('raw-nonce');

      final credential = await defaultGetAppleCredential(hashedNonce);

      expect(credential.identityToken, 'apple-identity-token');
      final call = requests.single;
      expect(call.method, 'performAuthorizationRequest');
      final request = (call.arguments as List).single as Map;
      expect(request['nonce'], hashedNonce);
      expect(request['nonce'], isNot('raw-nonce'));
    });

    test('closing the Apple sheet is rethrown as AuthCancelled', () async {
      mockAppleSheet(
        (_) async => throw PlatformException(
          code: 'authorization-error/canceled',
          message: 'The user canceled the authorization attempt.',
        ),
      );

      await expectLater(
        defaultGetAppleCredential(hashNonce('raw-nonce')),
        throwsA(isA<AuthCancelled>()),
      );
    });
  });

  group('mapAuthError', () {
    final rows = <String, (Object, AuthFailureKind)>{
      'invalid_credentials code': (
        _invalidCredentials,
        AuthFailureKind.invalidCredentials,
      ),
      'invalid login message without a code': (
        const supabase.AuthApiException(
          'Invalid login credentials',
          statusCode: '400',
        ),
        AuthFailureKind.invalidCredentials,
      ),
      'email_not_confirmed': (
        const supabase.AuthApiException(
          'Email not confirmed',
          statusCode: '400',
          code: 'email_not_confirmed',
        ),
        AuthFailureKind.emailNotConfirmed,
      ),
      'over_request_rate_limit': (
        const supabase.AuthApiException(
          'slow down',
          statusCode: '429',
          code: 'over_request_rate_limit',
        ),
        AuthFailureKind.rateLimited,
      ),
      'over_email_send_rate_limit': (
        const supabase.AuthApiException(
          'mail limit',
          statusCode: '429',
          code: 'over_email_send_rate_limit',
        ),
        AuthFailureKind.rateLimited,
      ),
      'a failed fetch with no status': (
        supabase.AuthRetryableFetchException(
          message: 'SocketException: Failed host lookup',
        ),
        AuthFailureKind.offline,
      ),
      'a 502 from the server': (
        supabase.AuthRetryableFetchException(
          message: 'bad gateway',
          statusCode: '502',
        ),
        AuthFailureKind.unknown,
      ),
      'user_already_exists': (
        const supabase.AuthApiException(
          'User already registered',
          statusCode: '422',
          code: 'user_already_exists',
        ),
        AuthFailureKind.emailTaken,
      ),
      'a weak password': (
        supabase.AuthWeakPasswordException(
          message: 'weak',
          statusCode: '422',
          reasons: const ['length'],
        ),
        AuthFailureKind.weakPassword,
      ),
      'an invalid email': (
        const supabase.AuthApiException(
          'Unable to validate email address: invalid format',
          statusCode: '400',
          code: 'validation_failed',
        ),
        AuthFailureKind.invalidEmail,
      ),
      'a non-auth exception': (Exception('boom'), AuthFailureKind.unknown),
    };

    for (final MapEntry(key: name, value: (error, kind)) in rows.entries) {
      test('$name maps to ${kind.name}', () async {
        final auth = build();
        backend.nextError = error;

        await expectLater(
          auth.signInWithEmail(email: 'a@b.co', password: 'pw'),
          throwsFailure(kind),
        );

        expect(auth.isSignedIn, false);
        expect(mapAuthError(error).kind, kind);
      });
    }

    test('offline uses the exact offline message', () {
      final failure = mapAuthError(
        supabase.AuthRetryableFetchException(
          message: 'SocketException: Failed host lookup',
        ),
      );
      expect(failure.message, 'No connection. Your timer still works offline.');
    });

    test('an unknown error never leaks its own text', () {
      final failure = mapAuthError(Exception('boom'));
      expect(failure.kind, AuthFailureKind.unknown);
      expect(failure.message, isNot(contains('boom')));
      expect(failure.message, 'Something went wrong. Try again.');
    });

    test('closing the Apple sheet maps to cancelled', () async {
      final auth = build(
        getAppleCredential: (_) async => throw const AuthCancelled(),
      );

      await expectLater(
        auth.signInWithApple(),
        throwsFailure(AuthFailureKind.cancelled),
      );

      expect(auth.isSignedIn, false);
      expect(backend.calls, 0);
      expect(
        mapAuthError(const AuthCancelled()).kind,
        AuthFailureKind.cancelled,
      );
    });

    test('every failure message is one of the nine fixed strings', () {
      final messages =
          AuthFailureKind.values.map((k) => AuthFailure(k).message).toSet();
      expect(messages.length, AuthFailureKind.values.length);
    });
  });
}
