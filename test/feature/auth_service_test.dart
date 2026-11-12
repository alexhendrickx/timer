import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:timer/feature/sync/service/auth_service.dart';

/// Fake [SyncAuthBackend] — no live Supabase project involved.
class FakeAuthBackend implements SyncAuthBackend {
  @override
  String? currentUserId;
  final _controller = StreamController<String?>.broadcast();
  bool signedOutCalled = false;

  @override
  Stream<String?> get userIdChanges => _controller.stream;

  @override
  Future<String> signInWithIdToken({
    required String idToken,
    String? nonce,
  }) async {
    currentUserId = 'user-from-$idToken';
    _controller.add(currentUserId);
    return currentUserId!;
  }

  @override
  Future<void> signOut() async {
    signedOutCalled = true;
    currentUserId = null;
    _controller.add(null);
  }
}

void main() {
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
      getAppleCredential: () async =>
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
      getAppleCredential: () async =>
          const AppleCredential(identityToken: 'apple-token-2'),
    );
    await auth.signInWithApple();
    expect(auth.isSignedIn, true);

    await auth.signOut();

    expect(auth.isSignedIn, false);
    expect(auth.userId, isNull);
    expect(backend.signedOutCalled, true);
  });
}
