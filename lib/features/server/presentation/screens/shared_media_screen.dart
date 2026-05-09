import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../discovery/presentation/screens/connect_server_screen.dart';
import '../../../player/presentation/screens/video_player_screen.dart';
import '../providers/shared_media_controller.dart';

class SharedMediaScreen extends ConsumerWidget {
  const SharedMediaScreen({super.key});

  Future<void> _showAddOptions(
    BuildContext context,
    SharedMediaController controller,
  ) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
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
                    child: const Icon(
                      Icons.video_file,
                      color: Colors.deepPurpleAccent,
                    ),
                  ),
                  title: const Text(
                    'Add Single Video',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Select a specific video file'),
                  onTap: () {
                    Navigator.pop(context);
                    controller.pickFile(context);
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
                    child: const Icon(
                      Icons.folder_open,
                      color: Colors.orangeAccent,
                    ),
                  ),
                  title: const Text(
                    'Scan Folder',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Find all videos inside a folder'),
                  onTap: () {
                    Navigator.pop(context);
                    controller.pickFolderAndScan(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controllerState = ref.watch(sharedMediaControllerProvider);
    final controller = ref.read(sharedMediaControllerProvider.notifier);

    final mediaItems = controllerState.sharedFiles;
    final serverRunning = controllerState.isServerRunning;
    final localIp = controllerState.localIp;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'StreamSync',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
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
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: serverRunning
                    ? [
                        Colors.deepPurpleAccent.withValues(alpha: 0.2),
                        Colors.deepPurple.withValues(alpha: 0.1),
                      ]
                    : [
                        Colors.grey.withValues(alpha: 0.1),
                        Colors.grey.withValues(alpha: 0.05),
                      ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: serverRunning
                    ? Colors.deepPurpleAccent.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: serverRunning
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    serverRunning ? Icons.wifi : Icons.wifi_off,
                    color: serverRunning ? Colors.greenAccent : Colors.grey,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serverRunning ? 'Server Active' : 'Server Off',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        serverRunning
                            ? '${localIp ?? '...'}:${AppConstants.serverPort}  •  ${mediaItems.length} file${mediaItems.length == 1 ? '' : 's'} shared'
                            : 'Tap toggle to start sharing',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: serverRunning,
                  activeThumbColor: AppColors.accent,
                  onChanged: (_) => controller.toggleServer(),
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
                        Icon(
                          Icons.video_library_outlined,
                          size: 80,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No videos shared yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the button below to add videos\nfrom your device',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
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
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                            size: 28,
                          ),
                        ),
                        onDismissed: (_) =>
                            controller.removeMedia(item.mediaId),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 64,
                              height: 48,
                              child: isFolder
                                  ? Container(
                                      color: Colors.orange.withValues(
                                        alpha: 0.1,
                                      ),
                                      child: const Icon(
                                        Icons.folder,
                                        color: Colors.orangeAccent,
                                        size: 28,
                                      ),
                                    )
                                  : item.thumbnailPath.isNotEmpty
                                  ? Image.file(
                                      File(item.thumbnailPath),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.deepPurple.withValues(
                                          alpha: 0.1,
                                        ),
                                        child: const Icon(
                                          Icons.play_circle_fill,
                                          color: Colors.deepPurpleAccent,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.deepPurple.withValues(
                                        alpha: 0.1,
                                      ),
                                      child: const Icon(
                                        Icons.play_circle_fill,
                                        color: Colors.deepPurpleAccent,
                                      ),
                                    ),
                            ),
                          ),
                          title: Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            AppFormatters.formatSize(item.size),
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.play_arrow,
                            color: AppColors.accent,
                          ),
                          onTap: () {
                            if (isFolder) {
                              SnackbarUtils.showMessage(
                                'Delete this legacy folder and re-add to extract videos.',
                              );
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VideoPlayerScreen(
                                  streamUrl:
                                      'http://${AppConstants.localhost}:${AppConstants.serverPort}/stream/${item.mediaId}',
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
        onPressed: () => _showAddOptions(context, controller),
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Videos',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.deepPurpleAccent,
        foregroundColor: Colors.white,
      ),
    );
  }
}
