import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/device_node.dart';
import 'models/media_item.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  throw UnimplementedError('DatabaseService is not initialized');
});

class DatabaseService {
  late final Isar _isar;

  Isar get isar => _isar;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [DeviceNodeSchema, MediaItemSchema],
      directory: dir.path,
    );
  }

  // DeviceNode operations
  Future<void> saveDevice(DeviceNode device) async {
    await _isar.writeTxn(() async {
      await _isar.deviceNodes.put(device);
    });
  }

  Future<List<DeviceNode>> getAllDevices() async {
    return await _isar.deviceNodes.where().findAll();
  }

  Future<void> clearDevices() async {
    await _isar.writeTxn(() async {
      await _isar.deviceNodes.clear();
    });
  }

  // MediaItem operations
  Future<void> saveMediaItems(List<MediaItem> items) async {
    await _isar.writeTxn(() async {
      await _isar.mediaItems.putAll(items);
    });
  }

  Future<List<MediaItem>> getAllMediaItems() async {
    return await _isar.mediaItems.where().findAll();
  }
  
  Future<void> removeMediaItem(int id) async {
    await _isar.writeTxn(() async {
      await _isar.mediaItems.delete(id);
    });
  }
}
