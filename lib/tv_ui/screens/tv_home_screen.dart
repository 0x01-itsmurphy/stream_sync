import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import '../../features/shared_library/providers/shared_library_provider.dart';
import '../../features/player/video_player_screen.dart';
import '../../features/client/connect_server_screen.dart';

class TvHomeScreen extends ConsumerWidget {
  const TvHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaItems = ref.watch(sharedLibraryProvider);

    return Scaffold(
      backgroundColor: Colors.black, // Typical for TV
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'StreamSync TV',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.cast, color: Colors.white),
                  label: const Text('Connect to Server', style: TextStyle(color: Colors.white, fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ConnectServerScreen()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            Expanded(
              child: mediaItems.isEmpty
                  ? const Center(
                      child: Text(
                        'No media shared yet.\nUse the mobile app to add files.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, color: Colors.grey),
                      ),
                    )
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                        childAspectRatio: 16 / 9,
                      ),
                      itemCount: mediaItems.length,
                      itemBuilder: (context, index) {
                        final item = mediaItems[index];
                        final isFolder = item.type == 'folder';
                        
                        return Card(
                          color: Colors.grey[900],
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            autofocus: index == 0, // Auto focus the first item for TV remote
                            onTap: () {
                              if (!isFolder) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => VideoPlayerScreen(
                                      streamUrl: 'http://127.0.0.1:8080/stream/${item.mediaId}',
                                      title: item.name,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (item.thumbnailPath.isNotEmpty)
                                  Expanded(
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: Image.file(File(item.thumbnailPath), fit: BoxFit.cover),
                                    ),
                                  )
                                else
                                  Expanded(
                                    child: Icon(
                                      isFolder ? Icons.folder : Icons.play_circle_fill,
                                      size: 64,
                                      color: isFolder ? Colors.orangeAccent : Colors.deepPurpleAccent,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Text(
                                    item.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
