import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/device_node.dart';
import 'models/media_item.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  throw UnimplementedError('DatabaseService is not initialized');
});

class DatabaseService {
  late final Box<DeviceNode> _deviceBox;
  late final Box<MediaItem> _mediaBox;

  Future<void> init() async {
    await Hive.initFlutter();

    Hive.registerAdapter(MediaItemAdapter());
    Hive.registerAdapter(DeviceNodeAdapter());

    _deviceBox = await Hive.openBox<DeviceNode>('devices');
    _mediaBox = await Hive.openBox<MediaItem>('media');
  }

  // DeviceNode operations
  Future<void> saveDevice(DeviceNode device) async {
    await _deviceBox.put(device.deviceId, device);
  }

  Future<List<DeviceNode>> getAllDevices() async {
    return _deviceBox.values.toList();
  }

  Future<void> clearDevices() async {
    await _deviceBox.clear();
  }

  // MediaItem operations
  Future<void> saveMediaItems(List<MediaItem> items) async {
    for (final item in items) {
      await _mediaBox.put(item.mediaId, item);
    }
  }

  Future<List<MediaItem>> getAllMediaItems() async {
    return _mediaBox.values.toList();
  }

  Future<void> removeMediaItem(String mediaId) async {
    await _mediaBox.delete(mediaId);
  }
}
