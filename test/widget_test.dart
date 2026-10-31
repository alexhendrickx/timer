import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:timer/core/services/database/app_database.dart';
import 'package:timer/core/services/storage_location_service.dart';
import 'package:timer/main.dart';

void main() {
  testWidgets('Home shows the empty state and a Settings action',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      TimerApp(storage: StorageLocationService(), database: database),
    );
    await tester.pumpAndSettle();

    expect(find.text('No timer yet'), findsOneWidget);
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('providers expose the database and storage service',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      TimerApp(storage: StorageLocationService(), database: database),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.text('No timer yet'));
    expect(context.read<AppDatabase>(), same(database));
    expect(context.read<StorageLocationService>(), isNotNull);
  });
}
