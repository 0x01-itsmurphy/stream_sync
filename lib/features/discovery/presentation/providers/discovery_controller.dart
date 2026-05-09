import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../data/services/discovery_service.dart';
import '../../domain/models/device_node.dart';

class DiscoveryState {
  final bool isScanning;
  final List<DeviceNode> servers;

  DiscoveryState({
    this.isScanning = false,
    this.servers = const [],
  });

  DiscoveryState copyWith({
    bool? isScanning,
    List<DeviceNode>? servers,
  }) {
    return DiscoveryState(
      isScanning: isScanning ?? this.isScanning,
      servers: servers ?? this.servers,
    );
  }
}

final discoveryControllerProvider =
    StateNotifierProvider<DiscoveryController, DiscoveryState>((ref) {
  final service = ref.watch(discoveryServiceProvider);
  return DiscoveryController(service);
});

class DiscoveryController extends StateNotifier<DiscoveryState> {
  final DiscoveryService _service;
  StreamSubscription? _serviceSubscription;

  DiscoveryController(this._service) : super(DiscoveryState()) {
    // Listen to passive discovery (UDP/mDNS)
    _serviceSubscription = _service.onDeviceFound.listen((device) {
      if (!state.servers.any((d) => d.ip == device.ip)) {
        state = state.copyWith(
          servers: [...state.servers, device],
        );
      }
    });
    
    // Auto-start passive discovery
    _service.startDiscovery();
  }

  @override
  void dispose() {
    _serviceSubscription?.cancel();
    _service.stop();
    super.dispose();
  }

  Future<void> scanNetwork() async {
    state = state.copyWith(isScanning: true, servers: []);

    // Also restart passive discovery
    _service.startDiscovery();

    final info = NetworkInfo();
    final wifiIp = await info.getWifiIP();

    if (wifiIp == null) {
      state = state.copyWith(isScanning: false);
      SnackbarUtils.showError(
        'Could not get Wi-Fi IP. Are you connected to Wi-Fi?',
      );
      return;
    }

    final subnet = wifiIp.substring(0, wifiIp.lastIndexOf('.'));
    final futures = <Future<void>>[];

    for (int i = 1; i <= 255; i++) {
      final ip = '$subnet.$i';
      if (ip == wifiIp) continue;

      futures.add(() async {
        try {
          final socket = await Socket.connect(
            ip,
            AppConstants.serverPort,
            timeout: const Duration(
              milliseconds: AppConstants.networkScanTimeoutMs,
            ),
          );
          socket.destroy();

          final response = await http.get(Uri.parse('http://$ip:${AppConstants.serverPort}/info')).timeout(
                const Duration(milliseconds: AppConstants.infoRequestTimeoutMs),
              );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['deviceName'] != null) {
              final newNode = DeviceNode(
                deviceId: data['deviceId'] ?? ip,
                name: data['deviceName'],
                ip: ip,
                port: AppConstants.serverPort,
                platform: data['platform'] ?? 'unknown',
              );
              
              if (!state.servers.any((d) => d.ip == newNode.ip)) {
                state = state.copyWith(
                  servers: [...state.servers, newNode],
                );
              }
            }
          }
        } catch (_) {}
      }());
    }

    await Future.wait(futures);
    state = state.copyWith(isScanning: false);
  }
}
