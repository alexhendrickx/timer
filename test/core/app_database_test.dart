import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/services/database/app_database.dart';

void main() {
  test('can open an in-memory db and insert/read an activity', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final id = await db.into(db.activities).insert(
          ActivitiesCompanion.insert(name: 'Client X', createdAt: DateTime(2026)),
        );
    final rows = await db.select(db.activities).get();
    expect(rows.single.id, id);
    expect(rows.single.archived, false);
    await db.close();
  });

  test('schemaVersion is 2', () {
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 2);
    db.close();
  });
}
