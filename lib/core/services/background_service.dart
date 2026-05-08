import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../storage/database_service.dart';
import '../../features/media_server/http_server_service.dart';

Future<void> initializeBackgroundService() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'streamsync_channel', // id
    'StreamSync Service', // title
    description: 'Runs the local media server in the background.', // description
    importance: Importance.low, // importance must be at low or higher level
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'streamsync_channel',
      initialNotificationTitle: 'StreamSync',
      initialNotificationContent: 'Media server is running in background',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized(); // required for plugins

  // Initialize DB
  final dbService = DatabaseService();
  await dbService.init();

  // Get local IP
  final info = NetworkInfo();
  final ip = await info.getWifiIP();

  // Start HTTP server
  final server = HttpServerService(dbService, onConnectionRequest: (ip) {
    service.invoke('connection_request', {'ip': ip});
  });
  await server.start('0.0.0.0', 8080);

  service.on('stopService').listen((event) {
    server.stop();
    service.stopSelf();
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}
