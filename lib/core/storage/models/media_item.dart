import 'package:isar/isar.dart';

part 'media_item.g.dart';

@collection
class MediaItem {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String mediaId;

  late String name;
  
  late String path;
  
  late String type;
  
  late int size;
  
  late int durationMillis; // Duration stored in milliseconds
  
  late String thumbnailPath;

  MediaItem({
    required this.mediaId,
    required this.name,
    required this.path,
    required this.type,
    required this.size,
    this.durationMillis = 0,
    this.thumbnailPath = '',
  });

  MediaItem.empty(); // Required for Isar
  
  @ignore
  Duration get duration => Duration(milliseconds: durationMillis);
}
