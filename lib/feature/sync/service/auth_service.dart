import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/routing/auth_callback.dart';
import 'auth_failure.dart';

/// Minimum password length when creating an account or setting a new one.
const int minPasswordLength = 8;

/// Which provider issued an ID token.
enum IdTokenProvider { apple, google }

/// One auth-state change from the backend. A password-reset link arrives as
/// a single change that both signs the user in and sets [passwordRecovery].
class AuthChange {
  const AuthChange({required this.userId, this.passwordRecovery = false});

  final String? userId;
  final bool passwordRecovery;
}

enum EmailSignUpResult { signedIn, confirmationSent }

/// The slice of Supabase's auth client [AuthService] needs — narrow enough
/// to fake in tests without a live Supabase project.
abstract class SyncAuthBackend {
  /// The signed-in user's id, or null when signed out.
  String? get currentUserId;

  /// The signed-in user's email, or null.
  String? get currentUserEmail;

  /// Fires on every auth-state change (sign-in, sign-out, token refresh).
  Stream<AuthChange> get authChanges;

  /// Exchanges an Apple or Google ID token for a Supabase session; returns
  /// the user id. [nonce] is the RAW nonce; Supabase hashes it and compares
  /// with the token's nonce claim.
  Future<String> signInWithIdToken({
    required IdTokenProvider provider,
    required String idToken,
    String? accessToken,
    String? nonce,
  });

  /// Creates an account. Returns the user id when a session came back, or
  /// null when the user must confirm their email first.
  Future<String?> signUpWithEmail({
    required String email,
    required String password,
    required String emailRedirectTo,
  });

  Future<String> signInWithPassword({
    required String email,
    required String password,
  });

  Future<void> resendSignUpEmail({
    required String email,
    required String emailRedirectTo,
  });

  Future<void> sendPasswordResetEmail({
    required String email,
    required String redirectTo,
  });

  /// Sets a new password for the current (recovery) session.
  Future<void> updatePassword(String newPassword);

  Future<void> signOut();
}

/// Production [SyncAuthBackend]: Supabase's own auth client.
class SupabaseAuthBackend implements SyncAuthBackend {
  SupabaseAuthBackend(this._client);

  final supabase.SupabaseClient _client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  String? get currentUserEmail => _client.auth.currentUser?.email;

  @override
  Stream<AuthChange> get authChanges => _client.auth.onAuthStateChange.map(
        (state) => AuthChange(
          userId: state.session?.user.id,
          passwordRecovery:
              state.event == supabase.AuthChangeEvent.passwordRecovery,
        ),
      );

  @override
  Future<String> signInWithIdToken({
    required IdTokenProvider provider,
    required String idToken,
    String? accessToken,
    String? nonce,
  }) async {
    final response = await _client.auth.signInWithIdToken(
      provider: switch (provider) {
        IdTokenProvider.apple => supabase.OAuthProvider.apple,
        IdTokenProvider.google => supabase.OAuthProvider.google,
      },
      idToken: idToken,
      accessToken: accessToken,
      nonce: nonce,
    );
    return response.session!.user.id;
  }

  @override
  Future<String?> signUpWithEmail({
    required String email,
    required String password,
    required String emailRedirectTo,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: emailRedirectTo,
    );
    return response.session?.user.id;
  }

  @override
  Future<String> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response.session!.user.id;
  }

  @override
  Future<void> resendSignUpEmail({
    required String email,
    required String emailRedirectTo,
  }) =>
      _client.auth.resend(
        type: supabase.OtpType.signup,
        email: email,
        emailRedirectTo: emailRedirectTo,
      );

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    required String redirectTo,
  }) =>
      _client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);

  @override
  Future<void> updatePassword(String newPassword) =>
      _client.auth.updateUser(supabase.UserAttributes(password: newPassword));

  @override
  Future<void> signOut() => _client.auth.signOut();
}

/// The Apple identity token [AuthService] exchanges for a Supabase session.
class AppleCredential {
  const AppleCredential({required this.identityToken});

  final String identityToken;
}

/// The Google tokens [AuthService] exchanges for a Supabase session.
class GoogleCredential {
  const GoogleCredential({
    required this.idToken,
    this.accessToken,
    required this.rawNonce,
  });

  final String idToken;
  final String? accessToken;

  /// The raw nonce whose SHA-256 was sent to Google.
  final String rawNonce;
}

typedef AppleCredentialGetter = Future<AppleCredential> Function(
  String hashedNonce,
);
typedef GoogleCredentialGetter = Future<GoogleCredential> Function();

/// 32 bytes from the OS random source, URL-safe.
String generateRawNonce() {
  final random = Random.secure();
  return base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256)));
}

/// SHA-256 hex digest: the form Apple and Google embed in the ID token, and
/// what Supabase recomputes from the raw nonce.
String hashNonce(String rawNonce) =>
    sha256.convert(utf8.encode(rawNonce)).toString();

/// Runs the native "Sign in with Apple" flow (iOS + macOS share the API) with
/// [hashedNonce] embedded in the identity token.
Future<AppleCredential> defaultGetAppleCredential(String hashedNonce) async {
  try {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
    final identityToken = credential.identityToken;
    if (identityToken == null) {
      throw StateError('Apple did not return an identity token.');
    }
    return AppleCredential(identityToken: identityToken);
  } on SignInWithAppleAuthorizationException catch (e) {
    if (e.code == AuthorizationErrorCode.canceled) throw const AuthCancelled();
    rethrow;
  }
}

/// The single entry to every sign-in method; each ends in a Supabase session.
/// Fully optional: with no session, [SyncEngine] stays disabled and the app
/// is purely local. Every failure leaves here as an [AuthFailure].
class AuthService extends ChangeNotifier {
  AuthService({
    required SyncAuthBackend backend,
    AppleCredentialGetter? getAppleCredential,
    GoogleCredentialGetter? getGoogleCredential,
    String Function()? generateNonce,
  })  : _backend = backend,
        _getAppleCredential = getAppleCredential ?? defaultGetAppleCredential,
        _getGoogleCredential = getGoogleCredential,
        _generateNonce = generateNonce ?? generateRawNonce,
        _userId = backend.currentUserId {
    // gotrue reports a failed token refresh or a bad auth link as a stream
    // error. That is not a state change, and must never go unhandled.
    _sub = backend.authChanges.listen(_onAuthChange, onError: (Object _) {});
  }

  final SyncAuthBackend _backend;
  final AppleCredentialGetter _getAppleCredential;
  final GoogleCredentialGetter? _getGoogleCredential;
  final String Function() _generateNonce;
  late final StreamSubscription<AuthChange> _sub;
  String? _userId;
  bool _passwordRecoveryPending = false;

  bool get isSignedIn => _userId != null;
  String? get userId => _userId;

  /// The signed-in user's email, for Settings.
  String? get email => _backend.currentUserEmail;

  /// False when the Google client ids were not supplied at build time; the
  /// UI hides the Google button.
  bool get googleAvailable => _getGoogleCredential != null;

  /// True exactly on the transitions [isSignedIn] makes — `main.dart`
  /// subscribes to call `SyncEngine.syncNow()` after a sign-in.
  Stream<bool> get authState => _backend.authChanges
      .handleError((Object _) {})
      .map((change) => change.userId != null)
      .distinct();

  /// True once after a password-reset link signed the user in. Latched, so
  /// a link that resolves before the router exists is not lost.
  bool takePasswordRecovery() {
    if (!_passwordRecoveryPending) return false;
    _passwordRecoveryPending = false;
    return true;
  }

  Future<void> signInWithApple() => _guard(() async {
        final rawNonce = _generateNonce();
        final credential = await _getAppleCredential(hashNonce(rawNonce));
        _setUser(await _backend.signInWithIdToken(
          provider: IdTokenProvider.apple,
          idToken: credential.identityToken,
          nonce: rawNonce,
        ));
      });

  Future<void> signInWithGoogle() => _guard(() async {
        final getCredential = _getGoogleCredential;
        if (getCredential == null) {
          throw StateError('Google sign-in is not configured.');
        }
        final credential = await getCredential();
        _setUser(await _backend.signInWithIdToken(
          provider: IdTokenProvider.google,
          idToken: credential.idToken,
          accessToken: credential.accessToken,
          nonce: credential.rawNonce,
        ));
      });

  Future<EmailSignUpResult> signUpWithEmail({
    required String email,
    required String password,
  }) =>
      _guard(() async {
        _requireStrongEnough(password);
        final userId = await _backend.signUpWithEmail(
          email: email.trim(),
          password: password,
          emailRedirectTo: authCallbackUrl,
        );
        if (userId == null) return EmailSignUpResult.confirmationSent;
        _setUser(userId);
        return EmailSignUpResult.signedIn;
      });

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _guard(() async {
        _setUser(await _backend.signInWithPassword(
          email: email.trim(),
          password: password,
        ));
      });

  Future<void> resendConfirmation(String email) => _guard(
        () => _backend.resendSignUpEmail(
          email: email.trim(),
          emailRedirectTo: authCallbackUrl,
        ),
      );

  Future<void> sendPasswordReset(String email) => _guard(
        () => _backend.sendPasswordResetEmail(
          email: email.trim(),
          redirectTo: authCallbackUrl,
        ),
      );

  Future<void> updatePassword(String newPassword) => _guard(() async {
        _requireStrongEnough(newPassword);
        await _backend.updatePassword(newPassword);
      });

  /// Never throws: Supabase clears the local session before it calls the
  /// server, so a failed revoke (offline) still leaves the user signed out.
  Future<void> signOut() async {
    try {
      await _backend.signOut();
    } catch (_) {}
    _setUser(null);
  }

  void _onAuthChange(AuthChange change) {
    var changed = false;
    if (change.passwordRecovery) {
      _passwordRecoveryPending = true;
      changed = true;
    }
    if (change.userId != _userId) {
      _userId = change.userId;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void _setUser(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    notifyListeners();
  }

  void _requireStrongEnough(String password) {
    if (password.length < minPasswordLength) {
      throw const AuthFailure(AuthFailureKind.weakPassword);
    }
  }

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } catch (error) {
      throw mapAuthError(error);
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
