import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/sources/database_service.dart';
import '../../domain/models/media_item.dart';

class SharedMediaState {
  final String? localIp;
  final bool isServerRunning;
  final bool isScanning;
  final List<MediaItem> sharedFiles;

  SharedMediaState({
    this.localIp,
    this.isServerRunning = false,
    this.isScanning = false,
    this.sharedFiles = const [],
  });

  SharedMediaState copyWith({
    String? localIp,
    bool? isServerRunning,
    bool? isScanning,
    List<MediaItem>? sharedFiles,
  }) {
    return SharedMediaState(
      localIp: localIp ?? this.localIp,
      isServerRunning: isServerRunning ?? this.isServerRunning,
      isScanning: isScanning ?? this.isScanning,
      sharedFiles: sharedFiles ?? this.sharedFiles,
    );
  }
}

final sharedMediaControllerProvider =
    StateNotifierProvider<SharedMediaController, SharedMediaState>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return SharedMediaController(ref, db);
});

class SharedMediaController extends StateNotifier<SharedMediaState> {
  final DatabaseService _db;

  SharedMediaController(Ref ref, this._db) : super(SharedMediaState()) {
    checkServiceStatus();
    _loadSharedFiles();
  }

  Future<void> _loadSharedFiles() async {
    final items = await _db.getAllMediaItems();
    state = state.copyWith(sharedFiles: items);
  }

  Future<void> checkServiceStatus() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    state = state.copyWith(isServerRunning: isRunning);

    final info = NetworkInfo();
    final ip = await info.getWifiIP();
    state = state.copyWith(localIp: ip);
  }

  Future<void> toggleServer() async {
    final service = FlutterBackgroundService();
    if (state.isServerRunning) {
      service.invoke('stopService');
      await Future.delayed(const Duration(milliseconds: 500));
    } else {
      await service.startService();
      await Future.delayed(const Duration(milliseconds: 500));
    }
    await checkServiceStatus();
  }

  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      if (!await Permission.manageExternalStorage.request().isGranted) {
        SnackbarUtils.showError('All Files Access permission is required.');
        return false;
      }
    }
    return true;
  }

  Future<void> addFilesByPaths(List<String> paths) async {
    final newItems = <MediaItem>[];

    for (final path in paths) {
      final file = File(path);
      if (!file.existsSync()) continue;

      if (state.sharedFiles.any((m) => m.path == path)) continue;

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
          debugPrint('Thumbnail generation failed: $e');
        }
      }

      final stat = file.statSync();
      final item = MediaItem(
        mediaId: DateTime.now().millisecondsSinceEpoch.toString() +
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
      await _loadSharedFiles();
    }
  }

  Future<void> removeMedia(String mediaId) async {
    await _db.removeMediaItem(mediaId);
    await _loadSharedFiles();
  }

  Future<void> pickFile(BuildContext context) async {
    if (!await requestPermission()) return;
    if (!context.mounted) return;

    Directory rootDir =
        Platform.isAndroid ? Directory('/storage/emulated/0') : Directory('/');

    String? path = await FilesystemPicker.open(
      title: 'Pick a Video',
      context: context,
      rootDirectory: rootDir,
      fsType: FilesystemType.file,
      allowedExtensions: ['.mp4', '.mkv', '.mov', '.avi'],
      pickText: 'Add this video',
      folderIconColor: Colors.deepPurpleAccent,
    );

    if (path != null) {
      await addFilesByPaths([path]);
      SnackbarUtils.showSuccess('Video added successfully!');
    }
  }

  Future<void> pickFolderAndScan(BuildContext context) async {
    if (!await requestPermission()) return;
    if (!context.mounted) return;

    Directory rootDir =
        Platform.isAndroid ? Directory('/storage/emulated/0') : Directory('/');

    String? path = await FilesystemPicker.open(
      title: 'Pick a Folder to Scan',
      context: context,
      rootDirectory: rootDir,
      fsType: FilesystemType.folder,
      pickText: 'Add all videos in this folder',
      folderIconColor: Colors.deepPurpleAccent,
    );

    if (path != null) {
      if (!context.mounted) return;

      state = state.copyWith(isScanning: true);
      _showScanDialog(context);

      final folder = Directory(path);
      final paths = <String>[];
      if (folder.existsSync()) {
        try {
          await for (final e in folder.list(recursive: true)) {
            if (e is File) {
              final lower = e.path.toLowerCase();
              if (lower.endsWith('.mp4') ||
                  lower.endsWith('.mkv') ||
                  lower.endsWith('.mov') ||
                  lower.endsWith('.avi')) {
                paths.add(e.path);
              }
            }
          }
        } catch (e) {
          debugPrint('Scan error: $e');
        }
      }

      await addFilesByPaths(paths);
      state = state.copyWith(isScanning: false);
      if (context.mounted) Navigator.pop(context); // Close scan dialog
      SnackbarUtils.showSuccess('Scan complete! Added ${paths.length} videos.');
    }
  }

  void _showScanDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: const [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Scanning for videos...'),
          ],
        ),
      ),
    );
  }
}
