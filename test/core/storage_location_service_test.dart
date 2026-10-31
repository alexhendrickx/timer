import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timer/core/services/storage_location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late SharedPreferences fakePrefs;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('timer_docs_');
    SharedPreferences.setMockInitialValues({});
    fakePrefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('defaults to Documents/Timer and creates it when no pref set', () async {
    final svc = StorageLocationService(prefs: fakePrefs, documentsDir: tmp);
    final p = await svc.resolveDbPath();
    expect(p, endsWith('/Timer/timer.sqlite'));
    expect(Directory(p).parent.existsSync(), true);
    expect(svc.lastFallbackReason, isNull);
    expect(svc.currentFolder, endsWith('/Timer'));
  });

  test('uses a chosen folder that exists', () async {
    final chosen = await Directory('${tmp.path}/chosen').create();
    final svc = StorageLocationService(prefs: fakePrefs, documentsDir: tmp);
    await svc.setDataFolder(chosen.path);
    final p = await svc.resolveDbPath();
    expect(p, '${chosen.path}/timer.sqlite');
    expect(svc.lastFallbackReason, isNull);
  });

  test('falls back to default when chosen folder is missing', () async {
    final svc = StorageLocationService(prefs: fakePrefs, documentsDir: tmp);
    await svc.setDataFolder('/no/such/dir');
    final p = await svc.resolveDbPath();
    expect(p, contains('/Timer/'));
    expect(svc.lastFallbackReason, isNotNull);
  });
}
