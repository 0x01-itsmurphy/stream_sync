import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:filesystem_picker/filesystem_picker.dart';

import '../../features/shared_library/providers/shared_library_provider.dart';
import '../../features/player/video_player_screen.dart';
import '../../features/client/connect_server_screen.dart';

class SharedMediaScreen extends ConsumerWidget {
  const SharedMediaScreen({super.key});

  Future<bool> _requestPermission(BuildContext context) async {
    if (Platform.isAndroid) {
      if (!await Permission.manageExternalStorage.request().isGranted) {
        if (!context.mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'All Files Access permission is required to bypass caching.',
            ),
          ),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _pickFile(
    BuildContext context,
    SharedLibraryNotifier notifier,
  ) async {
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
        const SnackBar(content: Text('Video added successfully!')),
      );
    }
  }

  Future<void> _pickFolderAndScan(
    BuildContext context,
    SharedLibraryNotifier notifier,
  ) async {
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
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Scanning folder for videos...'),
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
        SnackBar(content: Text('Successfully added ${paths.length} videos!')),
      );
    }
  }

  Future<void> _showAddOptions(
    BuildContext context,
    SharedLibraryNotifier notifier,
  ) async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.video_file,
                  color: Colors.deepPurpleAccent,
                ),
                title: const Text('Add Single Video'),
                subtitle: const Text('Select a specific video file'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile(context, notifier);
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder, color: Colors.orangeAccent),
                title: const Text('Scan Folder'),
                subtitle: const Text('Find all videos inside a folder'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFolderAndScan(context, notifier);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaItems = ref.watch(sharedLibraryProvider);
    final notifier = ref.read(sharedLibraryProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Media'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cast),
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
      body: mediaItems.isEmpty
          ? const Center(
              child: Text(
                'No media shared yet.\nTap + to add videos.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: mediaItems.length,
              itemBuilder: (context, index) {
                final item = mediaItems[index];
                final isFolder = item.type == 'folder';
                return ListTile(
                  leading: isFolder
                      ? const Icon(
                          Icons.folder,
                          size: 40,
                          color: Colors.orangeAccent,
                        )
                      : (item.thumbnailPath.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.file(
                                  File(item.thumbnailPath),
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(
                                Icons.video_file,
                                size: 40,
                                color: Colors.deepPurpleAccent,
                              )),
                  title: Text(item.name),
                  subtitle: Text(
                    '${(item.size / (1024 * 1024)).toStringAsFixed(2)} MB',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => notifier.removeMedia(item.mediaId),
                  ),
                  onTap: () {
                    if (isFolder) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Delete this legacy folder and re-add it to extract videos.',
                          ),
                        ),
                      );
                      return;
                    }
                    // Play locally for validation
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VideoPlayerScreen(
                          streamUrl:
                              'http://127.0.0.1:8080/stream/${item.mediaId}',
                          title: item.name,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOptions(context, notifier),
        icon: const Icon(Icons.video_library),
        label: const Text('Add Videos'),
        backgroundColor: Colors.deepPurpleAccent,
      ),
    );
  }
}
