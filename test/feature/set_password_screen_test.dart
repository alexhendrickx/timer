import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:timer/feature/sync/presentation/set_password_screen.dart';
import 'package:timer/feature/sync/service/auth_service.dart';

import '../support/fake_auth_backend.dart';

const _field = Key('new-password-field');
const _save = Key('new-password-save');

void main() {
  late FakeAuthBackend backend;
  late AuthService auth;
  var done = 0;

  setUp(() {
    backend = FakeAuthBackend();
    auth = AuthService(backend: backend);
    done = 0;
  });

  tearDown(() => auth.dispose());

  Widget wrap() {
    return ChangeNotifierProvider<AuthService?>.value(
      value: auth,
      child: MaterialApp(home: SetPasswordScreen(onDone: () => done += 1)),
    );
  }

  bool saveEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(_save)).onPressed != null;

  testWidgets('Save is disabled under 8 characters', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.enterText(find.byKey(_field), '1234567');
    await tester.pump();
    expect(saveEnabled(tester), false);

    await tester.enterText(find.byKey(_field), '12345678');
    await tester.pump();
    expect(saveEnabled(tester), true);
    expect(
      tester.widget<TextField>(find.byKey(_field)).autofillHints,
      [AutofillHints.newPassword],
    );
  });

  testWidgets('saving forwards the password and calls onDone', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byKey(_field), 'newpassword1');
    await tester.pump();

    await tester.tap(find.byKey(_save));
    await tester.pumpAndSettle();

    expect(backend.lastNewPassword, 'newpassword1');
    expect(done, 1);
  });

  testWidgets('a failure shows the message and does not call onDone',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.enterText(find.byKey(_field), 'newpassword1');
    await tester.pump();
    backend.nextError = supabase.AuthRetryableFetchException();

    await tester.tap(find.byKey(_save));
    await tester.pumpAndSettle();

    expect(
      find.text('No connection. Your timer still works offline.'),
      findsOneWidget,
    );
    expect(done, 0);
    expect(saveEnabled(tester), true);
  });

  testWidgets('Not now calls onDone without a backend call', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.tap(find.text('Not now'));
    await tester.pump();

    expect(done, 1);
    expect(backend.calls, 0);
  });
}
