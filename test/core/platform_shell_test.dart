import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/platform/platform_shell.dart';

void main() {
  test('NoopPlatformShell is a safe no-op default', () async {
    final shell = NoopPlatformShell();

    await shell.init();
    shell.setMenuBarTitle('x');
    await shell.showQuickStartPicker();

    expect(shell.hasMenuBar, false);
  });
}
