import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:timer/core/routing/app_router.dart';
import 'package:timer/feature/sync/service/auth_service.dart';

import '../support/fake_auth_backend.dart';

void main() {
  late FakeAuthBackend backend;
  late AuthService auth;
  late GoRouter router;
  var shown = 0;

  setUp(() {
    backend = FakeAuthBackend();
    auth = AuthService(backend: backend);
    router = buildAppRouter();
    shown = 0;
  });

  tearDown(() => auth.dispose());

  String location() => router.routeInformationProvider.value.uri.toString();

  void wire() => routePasswordRecovery(
        auth: auth,
        router: router,
        showWindow: () async => shown += 1,
      );

  test('a recovery link after wiring goes to /set-password', () async {
    wire();
    expect(location(), '/');

    backend.emitPasswordRecovery('u1');
    await pumpEventQueue();

    expect(location(), '/set-password');
    expect(shown, 1);
  });

  test('a recovery link latched before wiring goes to /set-password',
      () async {
    backend.emitPasswordRecovery('u1');
    await pumpEventQueue();
    expect(location(), '/');

    wire();
    await pumpEventQueue();

    expect(location(), '/set-password');
    expect(shown, 1);
  });

  test('a plain sign-in does not navigate', () async {
    wire();

    backend.emitSignedIn('u1');
    await pumpEventQueue();

    expect(auth.isSignedIn, true);
    expect(location(), '/');
    expect(shown, 0);
  });

  test('one recovery link navigates once', () async {
    wire();
    backend.emitPasswordRecovery('u1');
    await pumpEventQueue();
    expect(location(), '/set-password');

    router.go('/');
    // A later, unrelated auth change.
    backend.emitSignedIn('u2');
    await pumpEventQueue();

    expect(location(), '/');
    expect(shown, 1);
  });
}
