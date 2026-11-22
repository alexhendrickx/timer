import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Text checks on the native config files. `flutter test` runs from the
/// package root, so the paths are relative to it.
void main() {
  String read(String path) => File(path).readAsStringSync();

  const plists = ['ios/Runner/Info.plist', 'macos/Runner/Info.plist'];

  test('Info.plist files take the Google ids from build settings', () {
    for (final path in plists) {
      final plist = read(path);
      expect(plist, contains(r'$(GOOGLE_IOS_CLIENT_ID)'), reason: path);
      expect(plist, contains(r'$(GOOGLE_REVERSED_CLIENT_ID)'), reason: path);
      expect(plist, isNot(contains('apps.googleusercontent.com')), reason: path);
      expect(plist, isNot(contains('com.googleusercontent.apps.')),
          reason: path);
    }
  });

  test('iOS turns off Flutter\'s own deep linking', () {
    expect(
      read('ios/Runner/Info.plist'),
      matches(RegExp(r'<key>FlutterDeepLinkingEnabled</key>\s*<false/>')),
    );
  });

  test('iOS may ask whether Mail can open', () {
    expect(
      read('ios/Runner/Info.plist'),
      matches(RegExp(
        r'<key>LSApplicationQueriesSchemes</key>\s*<array>\s*<string>message</string>',
      )),
    );
  });

  test('macOS registers the timer scheme', () {
    expect(read('macos/Runner/Info.plist'), contains('<string>timer</string>'));
  });

  test('the xcconfig defaults come before the optional include', () {
    const configs = [
      'ios/Flutter/Debug.xcconfig',
      'ios/Flutter/Release.xcconfig',
      'macos/Runner/Configs/AppInfo.xcconfig',
    ];
    for (final path in configs) {
      final config = read(path);
      final placeholder = config.indexOf('GOOGLE_IOS_CLIENT_ID = unconfigured');
      final include = config.indexOf('config/google.xcconfig"');
      expect(placeholder, isNonNegative, reason: path);
      expect(include, greaterThan(placeholder), reason: path);
      expect(config, contains('#include? "'), reason: path);
      expect(config, isNot(contains('apps.googleusercontent.com')),
          reason: path);
    }
  });

  test('the Google xcconfig is gitignored and only the example is committed',
      () {
    expect(
      read('.gitignore').split('\n').map((line) => line.trim()),
      contains('/config/google.xcconfig'),
    );
    final example = File('config/google.xcconfig.example');
    expect(example.existsSync(), true);
    expect(example.readAsStringSync(), contains('<ios-client-id>'));
    expect(
      read('config/dart_defines.example.json'),
      contains('<ios-client-id>.apps.googleusercontent.com'),
    );
  });

  test('both macOS entitlements files carry the Google keychain group', () {
    for (final path in [
      'macos/Runner/DebugProfile.entitlements',
      'macos/Runner/Release.entitlements',
    ]) {
      expect(read(path), contains('com.google.GIDSignIn'), reason: path);
    }
  });
}
