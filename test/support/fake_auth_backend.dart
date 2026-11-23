import 'dart:async';

import 'package:timer/feature/sync/service/auth_service.dart';

/// Fake [SyncAuthBackend]: records every call and can be told to throw.
class FakeAuthBackend implements SyncAuthBackend {
  @override
  String? currentUserId;
  @override
  String? currentUserEmail;

  final _controller = StreamController<AuthChange>.broadcast();

  @override
  Stream<AuthChange> get authChanges => _controller.stream;

  /// Thrown by the next backend call, then cleared.
  Object? nextError;

  /// When true (the default), sign-up returns no session.
  bool signUpNeedsConfirmation = true;

  int calls = 0;
  IdTokenProvider? lastProvider;
  String? lastIdToken;
  String? lastAccessToken;
  String? lastNonce;
  String? lastEmail;
  String? lastPassword;
  String? lastRedirect;
  String? lastNewPassword;
  int resendCalls = 0;
  int resetCalls = 0;
  bool signedOutCalled = false;

  void _enter() {
    calls += 1;
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }

  String _signIn(String userId, {String? email}) {
    currentUserId = userId;
    currentUserEmail = email;
    _controller.add(AuthChange(userId: userId));
    return userId;
  }

  /// Simulates a password-reset link being opened.
  void emitPasswordRecovery(String userId) {
    currentUserId = userId;
    _controller.add(AuthChange(userId: userId, passwordRecovery: true));
  }

  /// Simulates a confirmation link being opened.
  void emitSignedIn(String userId, {String? email}) =>
      _signIn(userId, email: email);

  void emitError(Object error) => _controller.addError(error);

  @override
  Future<String> signInWithIdToken({
    required IdTokenProvider provider,
    required String idToken,
    String? accessToken,
    String? nonce,
  }) async {
    _enter();
    lastProvider = provider;
    lastIdToken = idToken;
    lastAccessToken = accessToken;
    lastNonce = nonce;
    return _signIn('user-from-$idToken');
  }

  @override
  Future<String?> signUpWithEmail({
    required String email,
    required String password,
    required String emailRedirectTo,
  }) async {
    _enter();
    lastEmail = email;
    lastPassword = password;
    lastRedirect = emailRedirectTo;
    if (signUpNeedsConfirmation) return null;
    return _signIn('user-$email', email: email);
  }

  @override
  Future<String> signInWithPassword({
    required String email,
    required String password,
  }) async {
    _enter();
    lastEmail = email;
    lastPassword = password;
    return _signIn('user-$email', email: email);
  }

  @override
  Future<void> resendSignUpEmail({
    required String email,
    required String emailRedirectTo,
  }) async {
    _enter();
    resendCalls += 1;
    lastEmail = email;
    lastRedirect = emailRedirectTo;
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    required String redirectTo,
  }) async {
    _enter();
    resetCalls += 1;
    lastEmail = email;
    lastRedirect = redirectTo;
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    _enter();
    lastNewPassword = newPassword;
  }

  @override
  Future<void> signOut() async {
    signedOutCalled = true;
    _enter();
    currentUserId = null;
    currentUserEmail = null;
    _controller.add(const AuthChange(userId: null));
  }
}
