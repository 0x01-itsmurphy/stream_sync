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
    required this.thumbnailPath,
  });
}
