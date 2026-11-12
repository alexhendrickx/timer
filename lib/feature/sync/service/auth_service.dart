import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// The slice of Supabase's auth client [AuthService] needs — narrow enough
/// to fake in tests without a live Supabase project.
abstract class SyncAuthBackend {
  /// The signed-in user's id, or null when signed out.
  String? get currentUserId;

  /// Fires whenever sign-in state changes (sign-in, sign-out, token
  /// refresh included, but [AuthService] only cares about the id).
  Stream<String?> get userIdChanges;

  /// Exchanges an Apple identity token for a Supabase session; returns
  /// the resulting user id.
  Future<String> signInWithIdToken({required String idToken, String? nonce});

  Future<void> signOut();
}

/// Production [SyncAuthBackend]: Supabase's own auth client.
class SupabaseAuthBackend implements SyncAuthBackend {
  SupabaseAuthBackend(this._client);

  final supabase.SupabaseClient _client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Stream<String?> get userIdChanges =>
      _client.auth.onAuthStateChange.map((state) => state.session?.user.id);

  @override
  Future<String> signInWithIdToken({
    required String idToken,
    String? nonce,
  }) async {
    final response = await _client.auth.signInWithIdToken(
      provider: supabase.OAuthProvider.apple,
      idToken: idToken,
      nonce: nonce,
    );
    return response.session!.user.id;
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}

/// The Apple identity credential [AuthService] needs — just enough to
/// exchange for a Supabase session.
class AppleCredential {
  const AppleCredential({required this.identityToken, this.nonce});

  final String identityToken;
  final String? nonce;
}

/// Runs the native "Sign in with Apple" flow (iOS + macOS use the same
/// `sign_in_with_apple` API) and returns the credential to exchange.
Future<AppleCredential> defaultGetAppleCredential() async {
  final credential = await SignInWithApple.getAppleIDCredential(
    scopes: const [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ],
  );
  final identityToken = credential.identityToken;
  if (identityToken == null) {
    throw StateError('Apple did not return an identity token.');
  }
  return AppleCredential(identityToken: identityToken);
}

/// Wraps Sign in with Apple → a Supabase session. Fully optional: with no
/// session, [SyncEngine] stays disabled and the app behaves exactly like
/// v0.8 (spec Sync — Signed out).
class AuthService extends ChangeNotifier {
  AuthService({
    required SyncAuthBackend backend,
    Future<AppleCredential> Function()? getAppleCredential,
  })  : _backend = backend,
        _getAppleCredential = getAppleCredential ?? defaultGetAppleCredential,
        _userId = backend.currentUserId {
    _sub = backend.userIdChanges.listen((userId) {
      if (userId == _userId) return;
      _userId = userId;
      notifyListeners();
    });
  }

  final SyncAuthBackend _backend;
  final Future<AppleCredential> Function() _getAppleCredential;
  late final StreamSubscription<String?> _sub;
  String? _userId;

  bool get isSignedIn => _userId != null;
  String? get userId => _userId;

  /// True exactly on the transitions [isSignedIn] makes — the signal
  /// `SyncEngine` subscribes to, to call `syncNow()` on a successful
  /// sign-in (spec Sync — Direction & timing).
  Stream<bool> get authState =>
      _backend.userIdChanges.map((userId) => userId != null).distinct();

  Future<void> signInWithApple() async {
    final credential = await _getAppleCredential();
    final userId = await _backend.signInWithIdToken(
      idToken: credential.identityToken,
      nonce: credential.nonce,
    );
    if (userId != _userId) {
      _userId = userId;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _backend.signOut();
    if (_userId != null) {
      _userId = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
