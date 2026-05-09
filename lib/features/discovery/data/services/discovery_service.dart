import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../../domain/models/device_node.dart';

final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  return DiscoveryService();
});

class DiscoveryService {
  final MDnsClient _mDnsClient = MDnsClient();
  RawDatagramSocket? _udpSocket;
  Timer? _beaconTimer;

  final StreamController<DeviceNode> _deviceFoundController = StreamController<DeviceNode>.broadcast();
  Stream<DeviceNode> get onDeviceFound => _deviceFoundController.stream;

  Future<void> startAdvertising(int port) async {
    // multicast_dns package doesn't support advertising natively.
    // We implement a simple UDP beacon broadcast as a robust fallback for LAN discovery.
    // In production, we could switch to the `nsd` or `bonsoir` package for true native mDNS advertising.
    
    final info = NetworkInfo();
    final ip = await info.getWifiIP();
    if (ip == null) return;

    _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _udpSocket?.broadcastEnabled = true;

    _beaconTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final payload = jsonEncode({
        'deviceId': 'local_device',
        'name': 'StreamSync Node',
        'ip': ip,
        'port': port,
        'isTv': false, // or logic to determine if TV
      });
      final data = utf8.encode(payload);
      
      try {
        // Broadcast to 255.255.255.255 on port 50000
        _udpSocket?.send(data, InternetAddress('255.255.255.255'), 50000);
      } catch (e) {
        // Ignore network unreachable errors
      }
    });
  }

  Future<void> startDiscovery() async {
    // Listen to our custom UDP beacons
    RawDatagramSocket.bind(InternetAddress.anyIPv4, 50000).then((socket) {
      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            try {
              final payload = utf8.decode(datagram.data);
              final map = jsonDecode(payload);
              
              final device = DeviceNode(
                deviceId: map['deviceId'],
                name: map['name'],
                ip: map['ip'],
                port: map['port'],
                isTv: map['isTv'] ?? false,
              );
              
              _deviceFoundController.add(device);
            } catch (e) {
              // Ignore invalid beacons
            }
          }
        }
      });
    });

    // Also attempt mDNS lookup using multicast_dns just in case we add native mDNS later
    try {
      await _mDnsClient.start();
      _mDnsClient.lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer('_streamsync._tcp.local')).listen((ptr) {
        _mDnsClient.lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName)).listen((srv) {
          // Resolve IP using A record
          _mDnsClient.lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv4(srv.target)).listen((ipRecord) {
             final device = DeviceNode(
                deviceId: srv.target,
                name: srv.target.split('.').first,
                ip: ipRecord.address.address,
                port: srv.port,
                isTv: false,
              );
              _deviceFoundController.add(device);
          });
        });
      });
    } catch (e) {
      print('mDNS discovery failed to start: $e');
    }
  }

  void stop() {
    _beaconTimer?.cancel();
    _udpSocket?.close();
    _mDnsClient.stop();
  }
}
