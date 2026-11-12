import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/platform/ios/ios_platform_shell.dart';
import 'package:timer/core/routing/app_router.dart';

void main() {
  test('has no menu bar', () {
    final router = buildAppRouter();
    final shell = IosPlatformShell(router);

    expect(shell.hasMenuBar, false);
  });

  test('setMenuBarTitle does not throw', () {
    final router = buildAppRouter();
    final shell = IosPlatformShell(router);

    expect(() => shell.setMenuBarTitle('x'), returnsNormally);
  });

  test('showQuickStartPicker navigates the router to /quick-start', () async {
    final router = buildAppRouter();
    final shell = IosPlatformShell(router);

    await shell.showQuickStartPicker();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/quick-start',
    );
  });
}
