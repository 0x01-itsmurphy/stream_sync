import 'package:hive/hive.dart';

part 'media_item.g.dart';

@HiveType(typeId: 0)
class MediaItem extends HiveObject {
  @HiveField(0)
  late String mediaId;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late String path;

  @HiveField(3)
  late String type; // 'video', 'audio', 'folder'

  @HiveField(4)
  late int size;

  @HiveField(5)
  late int durationMillis;

  @HiveField(6)
  late String thumbnailPath;

  MediaItem({
    required this.mediaId,
    required this.name,
    required this.path,
    required this.type,
    required this.size,
    required this.durationMillis,
    this.thumbnailPath = '',
  });

  MediaItem copyWith({
    String? mediaId,
    String? name,
    String? path,
    String? type,
    int? size,
    int? durationMillis,
    String? thumbnailPath,
  }) {
    return MediaItem(
      mediaId: mediaId ?? this.mediaId,
      name: name ?? this.name,
      path: path ?? this.path,
      type: type ?? this.type,
      size: size ?? this.size,
      durationMillis: durationMillis ?? this.durationMillis,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }
}
