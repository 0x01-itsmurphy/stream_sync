import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../client/presentation/screens/remote_media_screen.dart';
import '../providers/discovery_controller.dart';

class ConnectServerScreen extends ConsumerStatefulWidget {
  const ConnectServerScreen({super.key});

  @override
  ConsumerState<ConnectServerScreen> createState() => _ConnectServerScreenState();
}

class _ConnectServerScreenState extends ConsumerState<ConnectServerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    // Start scan on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(discoveryControllerProvider.notifier).scanNetwork();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
            style: FilledButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent,
            ),
            onPressed: () {
              Navigator.pop(context);
              if (controller.text.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        RemoteMediaScreen(serverIp: controller.text.trim()),
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
    final state = ref.watch(discoveryControllerProvider);
    final notifier = ref.read(discoveryControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Discover Devices',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_link),
            tooltip: 'Connect Manually',
            onPressed: _showManualConnectDialog,
          ),
          if (!state.isScanning)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => notifier.scanNetwork(),
            ),
        ],
      ),
      body: state.isScanning && state.servers.isEmpty
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
                            color: Colors.deepPurpleAccent.withValues(
                              alpha: 0.1,
                            ),
                            border: Border.all(
                              color: Colors.deepPurpleAccent.withValues(
                                alpha: 0.3,
                              ),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.wifi_find,
                            size: 48,
                            color: Colors.deepPurpleAccent,
                          ),
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
          : state.servers.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.devices_other, size: 72, color: Colors.grey[700]),
                  const SizedBox(height: 16),
                  Text(
                    'No devices found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[500],
                    ),
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
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                    ),
                    onPressed: () => notifier.scanNetwork(),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: state.servers.length,
              itemBuilder: (context, index) {
                final server = state.servers[index];
                return Card(
                  color: AppColors.cardBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getPlatformIcon(server.platform),
                        color: AppColors.accent,
                      ),
                    ),
                    title: Text(
                      server.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      server.ip,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.accent,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              RemoteMediaScreen(serverIp: server.ip),
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
