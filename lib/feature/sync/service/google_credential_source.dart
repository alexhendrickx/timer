import 'package:google_sign_in/google_sign_in.dart';

import 'auth_failure.dart';
import 'auth_service.dart';

/// The Google credential getter for [AuthService], or null unless both
/// client ids were supplied at build time. Null hides the Google button.
GoogleCredentialGetter? googleCredentialSourceFor({
  required String iosClientId,
  required String webClientId,
}) {
  if (iosClientId.isEmpty || webClientId.isEmpty) return null;
  return GoogleCredentialSource(
    iosClientId: iosClientId,
    webClientId: webClientId,
  ).call;
}

/// Runs the native Google sign-in (iOS + macOS) and returns the tokens to
/// exchange with Supabase. Nothing here runs until the user taps the button.
class GoogleCredentialSource {
  GoogleCredentialSource({
    required this.iosClientId,
    required this.webClientId,
  });

  final String iosClientId;
  final String webClientId;

  // google_sign_in allows initialize() once per process and the nonce is
  // fixed there, so there is one raw nonce per app run.
  final String _rawNonce = generateRawNonce();
  Future<void>? _initialized;

  // A failed initialize is dropped, so the next tap tries again instead of
  // replaying the same error for the rest of the run.
  Future<void> _ensureInitialized() async {
    try {
      await (_initialized ??= GoogleSignIn.instance.initialize(
        clientId: iosClientId,
        serverClientId: webClientId,
        nonce: hashNonce(_rawNonce),
      ));
    } catch (_) {
      _initialized = null;
      rethrow;
    }
  }

  Future<GoogleCredential> call() async {
    try {
      await _ensureInitialized();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw StateError('Google did not return an ID token.');
      }
      // Supabase checks the access token against the ID token's at_hash.
      const scopes = ['email', 'profile'];
      final authorization =
          await account.authorizationClient.authorizationForScopes(scopes) ??
              await account.authorizationClient.authorizeScopes(scopes);
      return GoogleCredential(
        idToken: idToken,
        accessToken: authorization.accessToken,
        rawNonce: _rawNonce,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthCancelled();
      }
      rethrow;
    }
  }
}
