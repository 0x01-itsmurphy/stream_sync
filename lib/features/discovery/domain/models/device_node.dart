import 'package:hive/hive.dart';

part 'device_node.g.dart';

@HiveType(typeId: 1)
class DeviceNode extends HiveObject {
  @HiveField(0)
  late String deviceId;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late String ip;

  @HiveField(3)
  late int port;

  @HiveField(4)
  late bool isTv;

  @HiveField(5)
  late bool isApproved;

  DeviceNode({
    required this.deviceId,
    required this.name,
    required this.ip,
    required this.port,
    this.isTv = false,
    this.isApproved = false,
  });
}
