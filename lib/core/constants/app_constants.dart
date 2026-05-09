import 'package:flutter/material.dart';

class AppConstants {
  // Network
  static const int serverPort = 8080;
  static const String defaultIp = '0.0.0.0';
  static const String localhost = '127.0.0.1';
  
  // Media Player
  static const int playerBufferSize = 32 * 1024 * 1024; // 32 MB
  static const String demuxerMaxBytes = '50MiB';
  static const String demuxerMaxBackBytes = '25MiB';
  
  // Background Service
  static const String notificationChannelId = 'streamsync_channel';
  static const String notificationChannelName = 'StreamSync Service';
  static const String notificationTitle = 'StreamSync';
  static const String notificationContent = 'Media server is running in background';
  static const int foregroundNotificationId = 888;
  
  // Handshake
  static const int handshakePollingIntervalSeconds = 2;
  static const int networkScanTimeoutMs = 500;
  static const int infoRequestTimeoutMs = 1000;
}

class AppColors {
  static const Color surface = Color(0xFF121218);
  static const Color cardBackground = Color(0xFF1E1E2E);
  static const Color snackBarBackground = Color(0xFF2A2A3E);
  static const Color primary = Colors.deepPurple;
  static const Color accent = Colors.deepPurpleAccent;
  
  static const Color success = Colors.greenAccent;
  static const Color warning = Colors.orangeAccent;
  static const Color error = Colors.redAccent;
  
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static Color textMuted = Colors.grey[500]!;
}
