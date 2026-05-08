import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../player/video_player_screen.dart';

class RemoteMediaScreen extends StatefulWidget {
  final String serverIp;

  const RemoteMediaScreen({super.key, required this.serverIp});

  @override
  State<RemoteMediaScreen> createState() => _RemoteMediaScreenState();
}

class _RemoteMediaScreenState extends State<RemoteMediaScreen> {
  bool _isApproved = false;
  bool _isError = false;
  List<dynamic> _mediaItems = [];
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchMedia();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchMedia() async {
    try {
      final response = await http
          .get(Uri.parse('http://${widget.serverIp}:8080/media'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 403) {
        // Pending approval. Poll again.
        if (mounted && !_isApproved) {
          _pollingTimer?.cancel();
          _pollingTimer = Timer(const Duration(seconds: 2), _fetchMedia);
        }
      } else if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (mounted) {
          setState(() {
            _isApproved = true;
            _isError = false;
            _mediaItems = data;
          });
        }
      } else {
        if (mounted) setState(() => _isError = true);
      }
    } catch (e) {
      // Timeout or connection error, maybe server is booting up or still blocking
      if (mounted && !_isApproved) {
        _pollingTimer?.cancel();
        _pollingTimer = Timer(const Duration(seconds: 2), _fetchMedia);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isApproved) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.serverIp)),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  'Waiting for approval...\n\nPlease check the Host device and tap "Allow" to connect.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isError) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.serverIp)),
        body: const Center(
          child: Text('Failed to load media. Host might be offline.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Shared Library')),
      body: _mediaItems.isEmpty
          ? const Center(child: Text('No media available on host.'))
          : ListView.builder(
              itemCount: _mediaItems.length,
              itemBuilder: (context, index) {
                final item = _mediaItems[index];
                final isFolder = item['type'] == 'folder';

                return ListTile(
                  leading: isFolder
                      ? const Icon(Icons.folder, size: 40, color: Colors.orangeAccent)
                      : (item['thumbnail'] != null && item['thumbnail'].toString().isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                'http://${widget.serverIp}:8080/thumb/${item['id']}',
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.video_file, size: 40, color: Colors.deepPurpleAccent),
                              ),
                            )
                          : const Icon(Icons.video_file, size: 40, color: Colors.deepPurpleAccent)),
                  title: Text(item['name']),
                  subtitle: Text('${(item['size'] / (1024 * 1024)).toStringAsFixed(2)} MB'),
                  onTap: () {
                    if (isFolder) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Folder browsing not yet fully supported on client.')),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VideoPlayerScreen(
                          streamUrl: 'http://${widget.serverIp}:8080/stream/${item['id']}',
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
