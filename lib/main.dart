import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/routing/app_router.dart';
import 'core/services/database/app_database.dart';
import 'core/services/storage_location_service.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageLocationService();
  final dbPath = await storage.resolveDbPath();
  final database = openAppDatabase(dbPath);

  runApp(TimerApp(storage: storage, database: database));
}

class TimerApp extends StatelessWidget {
  const TimerApp({super.key, required this.storage, required this.database});

  final StorageLocationService storage;
  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<StorageLocationService>.value(value: storage),
        Provider<AppDatabase>.value(value: database),
      ],
      child: MaterialApp.router(
        title: 'Timer',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        routerConfig: appRouter,
      ),
    );
  }
}
