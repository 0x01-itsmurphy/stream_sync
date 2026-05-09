import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_background_service/flutter_background_service.dart';

import 'core/constants/app_constants.dart';
import 'core/storage/database_service.dart';
import 'core/storage/models/device_node.dart';
import 'core/services/background_service.dart';
import 'mobile_ui/screens/shared_media_screen.dart';
import 'tv_ui/screens/tv_home_screen.dart';

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

final navigatorKey = GlobalKey<NavigatorState>();

class StreamSyncApp extends ConsumerStatefulWidget {
  const StreamSyncApp({super.key});

  @override
  ConsumerState<StreamSyncApp> createState() => _StreamSyncAppState();
}

class _StreamSyncAppState extends ConsumerState<StreamSyncApp> {
  @override
  void initState() {
    super.initState();
    FlutterBackgroundService().on('connection_request').listen((event) {
      if (event != null && event['ip'] != null) {
        _showApprovalDialog(event['ip'] as String);
      }
    });
  }

  void _showApprovalDialog(String ip) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final db = ref.read(databaseServiceProvider);
    final devices = await db.getAllDevices();
    if (devices.any((d) => d.ip == ip && d.isApproved)) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Connection Request'),
        content: Text('Device at $ip wants to connect. Allow?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Deny'),
          ),
          ElevatedButton(
            autofocus: true,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
            onPressed: () async {
              final device = DeviceNode(
                deviceId: 'device_$ip',
                name: 'Remote Device',
                ip: ip,
                port: AppConstants.serverPort,
                isApproved: true,
              );
              await db.saveDevice(device);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Allow'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StreamSync',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.surface,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: AppColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.snackBarBackground,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
        ),
      ),
      home: const ResponsiveHomeWrapper(),
    );
  }
}

class ResponsiveHomeWrapper extends StatelessWidget {
  const ResponsiveHomeWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Basic heuristic: Shortest side > 600 usually means Tablet or TV
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final isLargeScreen = shortestSide > 600;

    if (isLargeScreen) {
      return const TvHomeScreen();
    } else {
      return const SharedMediaScreen();
    }
  }
}
