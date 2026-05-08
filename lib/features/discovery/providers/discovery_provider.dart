import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamsync/features/discovery/services/discovery_service.dart';
import '../../../core/storage/models/device_node.dart';

final discoveredDevicesProvider = StateNotifierProvider<DiscoveredDevicesNotifier, List<DeviceNode>>((ref) {
  final service = ref.watch(discoveryServiceProvider);
  return DiscoveredDevicesNotifier(service);
});

class DiscoveredDevicesNotifier extends StateNotifier<List<DeviceNode>> {
  final DiscoveryService _service;

  DiscoveredDevicesNotifier(this._service) : super([]) {
    _service.onDeviceFound.listen((device) {
      if (!state.any((d) => d.deviceId == device.deviceId)) {
        state = [...state, device];
      }
    });
  }

  void startDiscovery() {
    state = [];
    _service.startDiscovery();
  }

  void stopDiscovery() {
    _service.stop();
  }
  
  @override
  void dispose() {
    _service.stop();
    super.dispose();
  }
}
