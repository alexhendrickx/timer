import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// The app's local SQLite database. Opened at a user-chosen file path
/// (see StorageLocationService); tests pass an in-memory executor.
@DriftDatabase(tables: [Activities, Sessions])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v0.9.0 sync columns (uid, deletedAt, dirty) on both tables,
            // plus `updatedAt` on Activities (v1 never had one — Sessions
            // already did). `uid`/`updatedAt` are NOT NULL with no
            // SQL-level default (clientDefault is per-row, Dart-side), so
            // SQLite's ALTER TABLE ADD COLUMN needs a temporary
            // placeholder — overwritten for every existing row below.
            await customStatement(
              "ALTER TABLE activities ADD COLUMN uid TEXT NOT NULL DEFAULT ''",
            );
            await customStatement(
              'ALTER TABLE activities ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
            );
            await m.addColumn(activities, activities.deletedAt);
            await m.addColumn(activities, activities.dirty);
            await customStatement(
              "ALTER TABLE sessions ADD COLUMN uid TEXT NOT NULL DEFAULT ''",
            );
            await m.addColumn(sessions, sessions.deletedAt);
            await m.addColumn(sessions, sessions.dirty);

            const uuid = Uuid();
            for (final activity in await select(activities).get()) {
              await (update(activities)..where((a) => a.id.equals(activity.id)))
                  .write(ActivitiesCompanion(
                uid: Value(uuid.v4()),
                updatedAt: Value(activity.createdAt),
                dirty: const Value(true),
              ));
            }
            for (final session in await select(sessions).get()) {
              await (update(sessions)..where((s) => s.id.equals(session.id)))
                  .write(SessionsCompanion(
                uid: Value(uuid.v4()),
                dirty: const Value(true),
              ));
            }
          }
        },
      );
}

/// Opens the app database at [dbFilePath] (a native SQLite file on disk).
AppDatabase openAppDatabase(String dbFilePath) {
  return AppDatabase(NativeDatabase(File(dbFilePath)));
}
