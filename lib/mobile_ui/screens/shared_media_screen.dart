import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../../features/shared_library/providers/shared_library_provider.dart';
import '../../features/player/video_player_screen.dart';
import '../../features/client/connect_server_screen.dart';

class SharedMediaScreen extends ConsumerStatefulWidget {
  const SharedMediaScreen({super.key});

  @override
  ConsumerState<SharedMediaScreen> createState() => _SharedMediaScreenState();
}

class _SharedMediaScreenState extends ConsumerState<SharedMediaScreen> {
  String? _localIp;

  @override
  void initState() {
    super.initState();
    _loadIp();
  }

  Future<void> _loadIp() async {
    final info = NetworkInfo();
    final ip = await info.getWifiIP();
    if (mounted) setState(() => _localIp = ip);
  }

  Future<bool> _requestPermission(BuildContext context) async {
    if (Platform.isAndroid) {
      if (!await Permission.manageExternalStorage.request().isGranted) {
        if (!context.mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All Files Access permission is required.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _pickFile(BuildContext context, SharedLibraryNotifier notifier) async {
    if (!await _requestPermission(context)) return;
    if (!context.mounted) return;

    Directory rootDir = Platform.isAndroid
        ? Directory('/storage/emulated/0')
        : Directory('/');

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
      await notifier.addFilesByPaths([path]);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video added successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickFolderAndScan(BuildContext context, SharedLibraryNotifier notifier) async {
    if (!await _requestPermission(context)) return;
    if (!context.mounted) return;

    Directory rootDir = Platform.isAndroid
        ? Directory('/storage/emulated/0')
        : Directory('/');

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

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: const Row(
            children: [
              CircularProgressIndicator(color: Colors.deepPurpleAccent),
              SizedBox(width: 20),
              Text('Scanning for videos...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );

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
          print('Scan error: $e');
        }
      }

      await notifier.addFilesByPaths(paths);

      if (!context.mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${paths.length} video${paths.length == 1 ? '' : 's'}!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showAddOptions(BuildContext context, SharedLibraryNotifier notifier) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.deepPurpleAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.video_file, color: Colors.deepPurpleAccent),
                  ),
                  title: const Text('Add Single Video', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Select a specific video file'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickFile(context, notifier);
                  },
                ),
                const SizedBox(height: 4),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.folder_open, color: Colors.orangeAccent),
                  ),
                  title: const Text('Scan Folder', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Find all videos inside a folder'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickFolderAndScan(context, notifier);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final mediaItems = ref.watch(sharedLibraryProvider);
    final notifier = ref.read(sharedLibraryProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('StreamSync', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.cast_connected),
            tooltip: 'Connect to Server',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConnectServerScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Server status card
          if (_localIp != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurpleAccent.withValues(alpha: 0.2),
                    Colors.deepPurple.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.deepPurpleAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.wifi, color: Colors.greenAccent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Server Active',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        Text(
                          '$_localIp:8080  •  ${mediaItems.length} file${mediaItems.length == 1 ? '' : 's'} shared',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Media list
          Expanded(
            child: mediaItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.video_library_outlined, size: 80, color: Colors.grey[700]),
                        const SizedBox(height: 16),
                        Text(
                          'No videos shared yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey[500], fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the button below to add videos\nfrom your device',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    separatorBuilder: (_, __) => const SizedBox(height: 2),
                    itemCount: mediaItems.length,
                    itemBuilder: (context, index) {
                      final item = mediaItems[index];
                      final isFolder = item.type == 'folder';

                      return Dismissible(
                        key: Key(item.mediaId),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          color: Colors.redAccent.withValues(alpha: 0.3),
                          child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 28),
                        ),
                        onDismissed: (_) => notifier.removeMedia(item.mediaId),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 64,
                              height: 48,
                              child: isFolder
                                  ? Container(
                                      color: Colors.orange.withValues(alpha: 0.1),
                                      child: const Icon(Icons.folder, color: Colors.orangeAccent, size: 28),
                                    )
                                  : item.thumbnailPath.isNotEmpty
                                      ? Image.file(
                                          File(item.thumbnailPath),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: Colors.deepPurple.withValues(alpha: 0.1),
                                            child: const Icon(Icons.play_circle_fill, color: Colors.deepPurpleAccent),
                                          ),
                                        )
                                      : Container(
                                          color: Colors.deepPurple.withValues(alpha: 0.1),
                                          child: const Icon(Icons.play_circle_fill, color: Colors.deepPurpleAccent),
                                        ),
                            ),
                          ),
                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _formatSize(item.size),
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          ),
                          trailing: const Icon(Icons.play_arrow, color: Colors.deepPurpleAccent),
                          onTap: () {
                            if (isFolder) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Delete this legacy folder and re-add to extract videos.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VideoPlayerScreen(
                                  streamUrl: 'http://127.0.0.1:8080/stream/${item.mediaId}',
                                  title: item.name,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOptions(context, notifier),
        icon: const Icon(Icons.add),
        label: const Text('Add Videos', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.deepPurpleAccent,
        foregroundColor: Colors.white,
      ),
    );
  }
}
