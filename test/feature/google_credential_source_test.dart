import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:timer/feature/sync/service/auth_failure.dart';
import 'package:timer/feature/sync/service/auth_service.dart';
import 'package:timer/feature/sync/service/google_credential_source.dart';

/// Stands in for the native Google SDK. Extending the platform class passes
/// the plugin's own instance check.
class _FakeGoogleSignIn extends GoogleSignInPlatform {
  final List<InitParameters> inits = [];
  int authenticateCalls = 0;
  GoogleSignInException? authenticateError;

  /// Thrown by the next [init], then cleared.
  Object? initError;

  @override
  Future<void> init(InitParameters params) async {
    inits.add(params);
    final error = initError;
    if (error != null) {
      initError = null;
      throw error;
    }
  }

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    authenticateCalls += 1;
    final error = authenticateError;
    if (error != null) throw error;
    return const AuthenticationResults(
      user: GoogleSignInUserData(email: 'a@b.co', id: 'google-user'),
      authenticationTokens: AuthenticationTokenData(idToken: 'google-id-token'),
    );
  }

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async =>
      const ClientAuthorizationTokenData(accessToken: 'google-access-token');

  @override
  Future<AuthenticationResults?>? attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) =>
      null;

  @override
  bool supportsAuthenticate() => true;

  @override
  bool authorizationRequiresUserInteraction() => false;

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async =>
      null;

  @override
  Future<void> signOut(SignOutParams params) async {}

  @override
  Future<void> disconnect(DisconnectParams params) async {}
}

void main() {
  test('googleCredentialSourceFor is null unless both ids are set', () {
    expect(
      googleCredentialSourceFor(iosClientId: '', webClientId: ''),
      isNull,
    );
    expect(
      googleCredentialSourceFor(iosClientId: 'ios', webClientId: ''),
      isNull,
    );
    expect(
      googleCredentialSourceFor(iosClientId: '', webClientId: 'web'),
      isNull,
    );
    // Not called: calling it would start the native Google flow.
    expect(
      googleCredentialSourceFor(iosClientId: 'ios', webClientId: 'web'),
      isNotNull,
    );
  });

  group('GoogleCredentialSource.call', () {
    late _FakeGoogleSignIn platform;
    late GoogleCredentialSource source;

    setUp(() {
      platform = _FakeGoogleSignIn();
      GoogleSignInPlatform.instance = platform;
      source = GoogleCredentialSource(iosClientId: 'ios', webClientId: 'web');
    });

    test('Google gets the SHA-256 of the raw nonce the credential carries',
        () async {
      final credential = await source.call();

      final rawNonce = credential.rawNonce;
      expect(rawNonce, isNotEmpty);
      final init = platform.inits.single;
      expect(init.nonce, hashNonce(rawNonce));
      expect(init.nonce, isNot(rawNonce));
      expect(init.clientId, 'ios');
      expect(init.serverClientId, 'web');
      expect(credential.idToken, 'google-id-token');
      expect(credential.accessToken, 'google-access-token');
    });

    test('init runs once across two calls and the nonce stays the same',
        () async {
      final first = await source.call();
      final second = await source.call();

      expect(platform.inits, hasLength(1));
      expect(platform.authenticateCalls, 2);
      expect(second.rawNonce, first.rawNonce);
      expect(platform.inits.single.nonce, hashNonce(second.rawNonce));
    });

    test('a failed init is retried on the next call', () async {
      platform.initError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
      );

      await expectLater(
        source.call(),
        throwsA(
          isA<GoogleSignInException>().having(
            (e) => e.code,
            'code',
            GoogleSignInExceptionCode.clientConfigurationError,
          ),
        ),
      );
      expect(platform.inits, hasLength(1));
      expect(platform.authenticateCalls, 0);

      final credential = await source.call();

      expect(platform.inits, hasLength(2));
      expect(platform.authenticateCalls, 1);
      expect(credential.idToken, 'google-id-token');
      expect(platform.inits.last.nonce, hashNonce(credential.rawNonce));
    });

    test('closing the Google sheet becomes AuthCancelled', () async {
      platform.authenticateError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );

      await expectLater(source.call(), throwsA(isA<AuthCancelled>()));
    });

    test('any other Google failure is passed on unchanged', () async {
      platform.authenticateError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
      );

      await expectLater(
        source.call(),
        throwsA(
          isA<GoogleSignInException>().having(
            (e) => e.code,
            'code',
            GoogleSignInExceptionCode.clientConfigurationError,
          ),
        ),
      );
    });
  });
}
