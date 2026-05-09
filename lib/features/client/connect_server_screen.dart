import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';

import '../../core/constants/app_constants.dart';
import 'remote_media_screen.dart';

class ServerNode {
  final String ip;
  final String name;
  final String platform;
  ServerNode(this.ip, this.name, this.platform);
}

class ConnectServerScreen extends StatefulWidget {
  const ConnectServerScreen({super.key});

  @override
  State<ConnectServerScreen> createState() => _ConnectServerScreenState();
}

class _ConnectServerScreenState extends State<ConnectServerScreen> with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  final List<ServerNode> _servers = [];
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanNetwork();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _scanNetwork() async {
    if (!mounted) return;
    setState(() {
      _isScanning = true;
      _servers.clear();
    });

    final info = NetworkInfo();
    final wifiIp = await info.getWifiIP();

    if (wifiIp == null) {
      if (mounted) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not get Wi-Fi IP. Are you connected to Wi-Fi?'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final subnet = wifiIp.substring(0, wifiIp.lastIndexOf('.'));
    final futures = <Future<void>>[];

    for (int i = 1; i <= 255; i++) {
      final ip = '$subnet.$i';
      if (ip == wifiIp) continue;

      futures.add(() async {
        try {
          final socket = await Socket.connect(ip, AppConstants.serverPort, timeout: const Duration(milliseconds: AppConstants.networkScanTimeoutMs));
          socket.destroy();

          final response = await http
              .get(Uri.parse('http://$ip:${AppConstants.serverPort}/info'))
              .timeout(const Duration(milliseconds: AppConstants.infoRequestTimeoutMs));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['deviceName'] != null) {
              if (mounted) {
                setState(() {
                  _servers.add(ServerNode(
                    ip,
                    data['deviceName'],
                    data['platform'] ?? 'unknown',
                  ));
                });
              }
            }
          }
        } catch (_) {}
      }());
    }

    await Future.wait(futures);
    if (mounted) setState(() => _isScanning = false);
  }

  void _showManualConnectDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Connect Manually'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'IP Address',
            hintText: 'e.g. 192.168.1.5',
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onSubmitted: (value) {
            Navigator.pop(context);
            if (value.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RemoteMediaScreen(serverIp: value.trim()),
                ),
              );
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
            onPressed: () {
              Navigator.pop(context);
              if (controller.text.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RemoteMediaScreen(serverIp: controller.text.trim()),
                  ),
                );
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return Icons.phone_android;
      case 'ios':
        return Icons.phone_iphone;
      case 'windows':
      case 'linux':
      case 'macos':
        return Icons.computer;
      default:
        return Icons.devices;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Devices', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_link),
            tooltip: 'Connect Manually',
            onPressed: _showManualConnectDialog,
          ),
          if (!_isScanning)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _scanNetwork,
            ),
        ],
      ),
      body: _isScanning && _servers.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, __) {
                      final scale = 1.0 + (_pulseController.value * 0.15);
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.deepPurpleAccent.withValues(alpha: 0.1),
                            border: Border.all(
                              color: Colors.deepPurpleAccent.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: const Icon(Icons.wifi_find, size: 48, color: Colors.deepPurpleAccent),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Scanning Wi-Fi Network...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Looking for StreamSync devices',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            )
          : _servers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.devices_other, size: 72, color: Colors.grey[700]),
                      const SizedBox(height: 16),
                      Text(
                        'No devices found',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Make sure the other device is running\nStreamSync on the same Wi-Fi network',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Scan Again'),
                        style: FilledButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
                        onPressed: _scanNetwork,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: _servers.length,
                  itemBuilder: (context, index) {
                    final server = _servers[index];
                    return Card(
                      color: AppColors.cardBackground,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_getPlatformIcon(server.platform), color: AppColors.accent),
                        ),
                        title: Text(server.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(server.ip, style: TextStyle(color: AppColors.textMuted)),
                        trailing: const Icon(Icons.chevron_right, color: AppColors.accent),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RemoteMediaScreen(serverIp: server.ip),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
