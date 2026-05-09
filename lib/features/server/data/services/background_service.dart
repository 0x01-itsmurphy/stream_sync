import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../sources/database_service.dart';
import 'http_server_service.dart';
import '../../../discovery/data/services/discovery_service.dart';

Future<void> initializeBackgroundService() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    AppConstants.notificationChannelId, // id
    AppConstants.notificationChannelName, // title
    description: AppConstants.notificationContent, // description
    importance: Importance.low,
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
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: AppConstants.notificationChannelId,
      initialNotificationTitle: AppConstants.notificationTitle,
      initialNotificationContent: AppConstants.notificationContent,
      foregroundServiceNotificationId: AppConstants.foregroundNotificationId,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
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
  await info.getWifiIP();

  // Start HTTP server
  final server = HttpServerService(dbService, onConnectionRequest: (ip) {
    service.invoke('connection_request', {'ip': ip});
  });
  await server.start(AppConstants.defaultIp, AppConstants.serverPort);

  // Start LAN discovery advertising
  final discovery = DiscoveryService();
  discovery.startAdvertising(AppConstants.serverPort);

  service.on('stopService').listen((event) {
    discovery.stop();
    server.stop();
    service.stopSelf();
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}
