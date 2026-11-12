import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:timer/core/services/database/app_database.dart';

void main() {
  test('migrating a v1 db to v2 adds uid/deletedAt/dirty without touching '
      'existing data', () async {
    final file = File(
      '${Directory.systemTemp.path}/timer_migration_test_${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });

    // Build a v1-shaped db by hand (the schema AppDatabase had before this
    // migration) and mark it as schema version 1, exactly like a real
    // on-disk v1 database the app shipped.
    final seed = sqlite3.open(file.path);
    seed.execute('''
      CREATE TABLE activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color INTEGER,
        hourly_rate REAL,
        currency_label TEXT,
        archived INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      );
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        activity_id INTEGER NOT NULL REFERENCES activities(id),
        date INTEGER NOT NULL,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        last_seen_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    final createdAt = DateTime(2026, 1, 1).millisecondsSinceEpoch ~/ 1000;
    seed.execute(
      'INSERT INTO activities (id, name, archived, created_at) VALUES (1, ?, 0, ?)',
      ['Client X', createdAt],
    );
    seed.execute(
      'INSERT INTO sessions (id, activity_id, date, start_time, duration_seconds, created_at, updated_at) '
      'VALUES (1, 1, ?, ?, 3600, ?, ?)',
      [createdAt, createdAt, createdAt, createdAt],
    );
    seed.execute('PRAGMA user_version = 1');
    seed.dispose();

    // Reopen through AppDatabase — schemaVersion is 2, so drift runs
    // onUpgrade(1, 2) against this same file.
    final db = AppDatabase(NativeDatabase(file));
    final activity = await (db.select(db.activities)).getSingle();
    final session = await (db.select(db.sessions)).getSingle();

    expect(activity.uid, isNotEmpty);
    expect(activity.deletedAt, isNull);
    expect(activity.dirty, true);

    expect(session.uid, isNotEmpty);
    expect(session.uid, isNot(activity.uid));
    expect(session.deletedAt, isNull);
    expect(session.dirty, true);
    expect(session.durationSeconds, 3600);
    expect(session.updatedAt.millisecondsSinceEpoch ~/ 1000, createdAt);

    await db.close();
  });
}
