// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_node.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DeviceNodeAdapter extends TypeAdapter<DeviceNode> {
  @override
  final int typeId = 1;

  @override
  DeviceNode read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DeviceNode(
      deviceId: fields[0] as String,
      name: fields[1] as String,
      ip: fields[2] as String,
      port: fields[3] as int,
      platform: fields[6] as String,
      isTv: fields[4] as bool,
      isApproved: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, DeviceNode obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.deviceId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.ip)
      ..writeByte(3)
      ..write(obj.port)
      ..writeByte(4)
      ..write(obj.isTv)
      ..writeByte(5)
      ..write(obj.isApproved)
      ..writeByte(6)
      ..write(obj.platform);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceNodeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
