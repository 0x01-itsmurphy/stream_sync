import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../player/presentation/screens/video_player_screen.dart';
import '../providers/remote_library_controller.dart';

class RemoteMediaScreen extends ConsumerStatefulWidget {
  final String serverIp;

  const RemoteMediaScreen({super.key, required this.serverIp});

  @override
  ConsumerState<RemoteMediaScreen> createState() => _RemoteMediaScreenState();
}

class _RemoteMediaScreenState extends ConsumerState<RemoteMediaScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waitController;

  @override
  void initState() {
    super.initState();
    _waitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waitController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final state = ref.watch(remoteLibraryControllerProvider(widget.serverIp));
    final notifier =
        ref.read(remoteLibraryControllerProvider(widget.serverIp).notifier);

    // Waiting for approval state
    if (!state.isApproved) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.serverIp)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _waitController,
                builder: (_, __) {
                  final scale = 1.0 + (_waitController.value * 0.1);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.orangeAccent.withValues(alpha: 0.1),
                        border: Border.all(
                          color: Colors.orangeAccent.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.handshake_outlined,
                        size: 48,
                        color: Colors.orangeAccent,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              const Text(
                'Waiting for approval...',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  'Open StreamSync on the host device and tap "Allow" to grant access.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Error state
    if (state.isError) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.serverIp)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 64, color: Colors.grey[700]),
              const SizedBox(height: 16),
              Text(
                'Host seems to be offline',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                ),
                onPressed: () => notifier.retry(),
              ),
            ],
          ),
        ),
      );
    }

    // Connected — show media
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Remote Library',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              widget.serverIp,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => notifier.fetchMedia(),
          ),
        ],
      ),
      body: state.mediaItems.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.video_library_outlined,
                    size: 72,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No media on this host',
                    style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              separatorBuilder: (_, __) => const SizedBox(height: 2),
              itemCount: state.mediaItems.length,
              itemBuilder: (context, index) {
                final item = state.mediaItems[index];
                final isFolder = item['type'] == 'folder';

                return ListTile(
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
                              color: Colors.orange.withValues(alpha: 0.1),
                              child: const Icon(
                                Icons.folder,
                                color: Colors.orangeAccent,
                                size: 28,
                              ),
                            )
                          : (item['thumbnail'] != null &&
                                  item['thumbnail'].toString().isNotEmpty
                              ? Image.network(
                                  'http://${widget.serverIp}:${AppConstants.serverPort}/thumb/${item['id']}',
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
                                )),
                    ),
                  ),
                  title: Text(
                    item['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    AppFormatters.formatSize(item['size']),
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  trailing:
                      const Icon(Icons.play_arrow, color: AppColors.accent),
                  onTap: () {
                    if (isFolder) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VideoPlayerScreen(
                          streamUrl:
                              'http://${widget.serverIp}:${AppConstants.serverPort}/stream/${item['id']}',
                          title: item['name'],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
