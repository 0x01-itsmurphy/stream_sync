import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../features/server/data/sources/database_service.dart';
import '../features/discovery/domain/models/device_node.dart';
import '../features/server/presentation/screens/shared_media_screen.dart';
import 'tv_app.dart';

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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
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
      theme: AppTheme.darkTheme,
      home: const ResponsiveHomeWrapper(),
    );
  }
}

class ResponsiveHomeWrapper extends StatelessWidget {
  const ResponsiveHomeWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final isLargeScreen = shortestSide > 600;

    if (isLargeScreen) {
      return const TvHomeScreen();
    } else {
      return const SharedMediaScreen();
    }
  }
}
