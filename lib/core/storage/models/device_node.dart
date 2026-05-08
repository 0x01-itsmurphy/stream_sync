import 'package:isar/isar.dart';

part 'device_node.g.dart';

@collection
class DeviceNode {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String deviceId;

  late String name;
  
  late String ip;
  
  late int port;
  
  late bool isTv;
  
  late bool isApproved;

  DeviceNode({
    required this.deviceId,
    required this.name,
    required this.ip,
    required this.port,
    this.isTv = false,
    this.isApproved = false,
  });

  DeviceNode.empty(); // Required for Isar
}
