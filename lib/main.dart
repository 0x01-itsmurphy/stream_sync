import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'features/server/data/sources/database_service.dart';
import 'features/server/data/services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Initialize Local Database (Hive)
  final dbService = DatabaseService();
  await dbService.init();

  // Initialize Background Service (starts HTTP server automatically in background isolate)
  await initializeBackgroundService();

  runApp(
    ProviderScope(
      overrides: [databaseServiceProvider.overrideWithValue(dbService)],
      child: const StreamSyncApp(),
    ),
  );
}
