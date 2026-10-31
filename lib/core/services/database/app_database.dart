import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// The app's local SQLite database. Opened at a user-chosen file path
/// (see StorageLocationService); tests pass an in-memory executor.
@DriftDatabase(tables: [Activities, Sessions])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}

/// Opens the app database at [dbFilePath] (a native SQLite file on disk).
AppDatabase openAppDatabase(String dbFilePath) {
  return AppDatabase(NativeDatabase(File(dbFilePath)));
}
