import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/sources/database_service.dart';
import '../../domain/models/media_item.dart';

final sharedLibraryProvider =
    StateNotifierProvider<SharedLibraryNotifier, List<MediaItem>>((ref) {
      final db = ref.watch(databaseServiceProvider);
      return SharedLibraryNotifier(db);
    });

class SharedLibraryNotifier extends StateNotifier<List<MediaItem>> {
  final DatabaseService _db;

  SharedLibraryNotifier(this._db) : super([]) {
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await _db.getAllMediaItems();
    state = items;
  }

  Future<void> addFilesByPaths(List<String> paths) async {
    final newItems = <MediaItem>[];

    for (final path in paths) {
      final file = File(path);
      if (!file.existsSync()) continue;

      if (state.any((m) => m.path == path)) continue; // Already shared

      final name = path.split(Platform.pathSeparator).last;
      final lowerName = name.toLowerCase();
      final mediaType = lowerName.endsWith('.mp4') || lowerName.endsWith('.mkv')
          ? 'video'
          : 'media';

      String thumbnailPath = '';
      if (mediaType == 'video') {
        try {
          final tempDir = await getTemporaryDirectory();
          final thumb = await VideoThumbnail.thumbnailFile(
            video: path,
            thumbnailPath: tempDir.path,
            imageFormat: ImageFormat.JPEG,
            maxHeight: 200,
            quality: 50,
          );
          if (thumb != null) thumbnailPath = thumb;
        } catch (e) {
          print('Thumbnail generation failed: $e');
        }
      }

      final stat = file.statSync();
      final item = MediaItem(
        mediaId:
            DateTime.now().millisecondsSinceEpoch.toString() +
            name.hashCode.toString(),
        name: name,
        path: path,
        type: mediaType,
        size: stat.size,
        durationMillis: 0,
        thumbnailPath: thumbnailPath,
      );
      newItems.add(item);
    }

    if (newItems.isNotEmpty) {
      await _db.saveMediaItems(newItems);
      await _loadItems();
    }
  }

  Future<void> removeMedia(String mediaId) async {
    await _db.removeMediaItem(mediaId);
    await _loadItems();
  }
}
