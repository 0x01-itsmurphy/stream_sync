import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/storage/database_service.dart';
import '../../core/storage/models/media_item.dart';

final httpServerProvider = Provider<HttpServerService>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return HttpServerService(db);
});

class HttpServerService {
  final DatabaseService _db;
  HttpServer? _server;
  final Function(String ip)? onConnectionRequest;

  HttpServerService(this._db, {this.onConnectionRequest});

  Future<void> start(String ip, int port) async {
    final router = Router();
    
    router.get('/info', _infoHandler);
    router.get('/media', _mediaHandler);
    router.get('/stream/<id>', _streamHandler);
    router.get('/folders/<id>', _folderHandler);
    router.get('/stream_folder/<folderId>', _streamFolderHandler);
    router.get('/thumb/<id>', _thumbHandler);

    final handler = Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_securityMiddleware())
        .addHandler(router.call);

    _server = await shelf_io.serve(handler, ip, port, shared: true);
    print('Server running on IP : ${_server!.address.host} On Port : ${_server!.port}');
  }

  Future<void> stop() async {
    await _server?.close(force: true);
  }

  Middleware _securityMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        final connInfo = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
        final remoteIp = connInfo?.remoteAddress.address;

        if (remoteIp != null && remoteIp != '127.0.0.1' && remoteIp != '::1') {
          final devices = await _db.getAllDevices();
          final isApproved = devices.any((d) => d.ip == remoteIp && d.isApproved);
          
          if (!isApproved) {
            onConnectionRequest?.call(remoteIp);
            return Response.forbidden('Pending Approval');
          }
        }
        return innerHandler(request);
      };
    };
  }

  Response _infoHandler(Request request) {
    return Response.ok(jsonEncode({
      'deviceId': 'local_device', // In a real app, generate a unique ID and persist it
      'deviceName': 'StreamSync Node',
      'platform': Platform.operatingSystem,
      'version': '1.0.0'
    }), headers: {'Content-Type': 'application/json'});
  }

  Future<Response> _mediaHandler(Request request) async {
    final media = await _db.getAllMediaItems();
    final jsonList = media.map((m) => {
      'id': m.mediaId,
      'name': m.name,
      'path': m.path,
      'type': m.type,
      'size': m.size,
      'duration': m.durationMillis,
      'thumbnail': m.thumbnailPath,
    }).toList();

    return Response.ok(jsonEncode(jsonList), headers: {'Content-Type': 'application/json'});
  }

  Future<Response> _folderHandler(Request request, String id) async {
    final mediaItems = await _db.getAllMediaItems();
    final item = mediaItems.cast<MediaItem?>().firstWhere((m) => m?.mediaId == id && m?.type == 'folder', orElse: () => null);

    if (item == null || !Directory(item.path).existsSync()) {
      return Response.notFound('Folder not found');
    }

    final dir = Directory(item.path);
    final entities = dir.listSync(recursive: false);
    
    final jsonList = entities.whereType<File>().map((f) {
      final stat = f.statSync();
      final name = f.path.split(Platform.pathSeparator).last;
      String type = 'file';
      if (name.toLowerCase().endsWith('.mp4') || name.toLowerCase().endsWith('.mkv')) type = 'video';
      if (name.toLowerCase().endsWith('.mp3')) type = 'audio';
      
      final relativePath = f.path.replaceFirst(dir.path, '');
      final streamUrl = '/stream_folder/$id?file=${Uri.encodeComponent(relativePath)}';

      return {
        'name': name,
        'path': f.path,
        'type': type,
        'size': stat.size,
        'streamUrl': streamUrl,
      };
    }).toList();

    return Response.ok(jsonEncode(jsonList), headers: {'Content-Type': 'application/json'});
  }

  Future<Response> _streamFolderHandler(Request request, String folderId) async {
    final mediaItems = await _db.getAllMediaItems();
    final item = mediaItems.cast<MediaItem?>().firstWhere((m) => m?.mediaId == folderId && m?.type == 'folder', orElse: () => null);
    
    if (item == null || !Directory(item.path).existsSync()) {
      return Response.notFound('Folder not found');
    }

    final relativeFile = request.url.queryParameters['file'];
    if (relativeFile == null) return Response.notFound('File param missing');

    final decodedFile = Uri.decodeComponent(relativeFile);
    if (decodedFile.contains('..')) return Response.forbidden('Invalid path');

    final file = File('${item.path}$decodedFile');
    
    if (!file.existsSync()) {
      return Response.notFound('File not found in folder');
    }

    return _streamFile(request, file, decodedFile);
  }

  Future<Response> _streamHandler(Request request, String id) async {
    final mediaItems = await _db.getAllMediaItems();
    final item = mediaItems.cast<MediaItem?>().firstWhere((m) => m?.mediaId == id, orElse: () => null);
    
    if (item == null || !File(item.path).existsSync()) {
      return Response.notFound('Media not found');
    }

    return _streamFile(request, File(item.path), item.name);
  }

  Future<Response> _thumbHandler(Request request, String id) async {
    final mediaItems = await _db.getAllMediaItems();
    final item = mediaItems.cast<MediaItem?>().firstWhere((m) => m?.mediaId == id, orElse: () => null);

    if (item == null || item.thumbnailPath.isEmpty || !File(item.thumbnailPath).existsSync()) {
      return Response.notFound('Thumbnail not found');
    }

    final file = File(item.thumbnailPath);
    return Response.ok(file.openRead(), headers: {
      'Content-Type': 'image/jpeg',
      'Content-Length': '${await file.length()}',
    });
  }

  Future<Response> _streamFile(Request request, File file, String fileName) async {
    final fileSize = await file.length();
    final rangeHeader = request.headers['range'];

    String contentType = 'video/mp4';
    if (fileName.toLowerCase().endsWith('.mkv')) contentType = 'video/x-matroska';
    if (fileName.toLowerCase().endsWith('.avi')) contentType = 'video/x-msvideo';
    if (fileName.toLowerCase().endsWith('.mp3')) contentType = 'audio/mpeg';

    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      final range = rangeHeader.substring(6).split('-');
      final start = int.tryParse(range[0]) ?? 0;
      final end = range.length > 1 && range[1].isNotEmpty ? int.tryParse(range[1]) ?? fileSize - 1 : fileSize - 1;

      if (start >= fileSize) {
        return Response(416, headers: {'Content-Range': 'bytes */$fileSize'});
      }

      final stream = file.openRead(start, end + 1);
      return Response(206, body: stream, headers: {
        'Content-Type': contentType,
        'Accept-Ranges': 'bytes',
        'Content-Range': 'bytes $start-$end/$fileSize',
        'Content-Length': '${end - start + 1}',
      });
    }

    return Response.ok(file.openRead(), headers: {
      'Content-Type': contentType,
      'Accept-Ranges': 'bytes',
      'Content-Length': '$fileSize',
    });
  }
}
