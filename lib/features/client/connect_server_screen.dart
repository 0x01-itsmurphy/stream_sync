import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';

import 'remote_media_screen.dart';

class ServerNode {
  final String ip;
  final String name;
  ServerNode(this.ip, this.name);
}

class ConnectServerScreen extends StatefulWidget {
  const ConnectServerScreen({super.key});

  @override
  State<ConnectServerScreen> createState() => _ConnectServerScreenState();
}

class _ConnectServerScreenState extends State<ConnectServerScreen> {
  bool _isScanning = false;
  final List<ServerNode> _servers = [];

  @override
  void initState() {
    super.initState();
    _scanNetwork();
  }

  Future<void> _scanNetwork() async {
    if (!mounted) return;
    setState(() {
      _isScanning = true;
      _servers.clear();
    });

    final info = NetworkInfo();
    final wifiIp = await info.getWifiIP();

    if (wifiIp == null) {
      if (mounted) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get Wi-Fi IP. Are you connected to Wi-Fi?')),
        );
      }
      return;
    }

    final subnet = wifiIp.substring(0, wifiIp.lastIndexOf('.'));
    final futures = <Future<void>>[];

    for (int i = 1; i <= 255; i++) {
      final ip = '$subnet.$i';
      if (ip == wifiIp) continue; // Skip self

      futures.add(() async {
        try {
          // Fast TCP ping on port 8080
          final socket = await Socket.connect(ip, 8080, timeout: const Duration(milliseconds: 500));
          socket.destroy();

          // If port is open, check /info endpoint to verify it's a StreamSync Node
          final response = await http
              .get(Uri.parse('http://$ip:8080/info'))
              .timeout(const Duration(milliseconds: 1000));
              
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['deviceName'] != null) {
              if (mounted) {
                setState(() {
                  _servers.add(ServerNode(ip, data['deviceName']));
                });
              }
            }
          }
        } catch (_) {
          // Ignore timeouts/connection refused
        }
      }());
    }

    await Future.wait(futures);

    if (mounted) {
      setState(() => _isScanning = false);
    }
  }

  void _showManualConnectDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect Manually'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'IP Address',
            hintText: 'e.g. 192.168.1.5',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (controller.text.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RemoteMediaScreen(serverIp: controller.text.trim()),
                  ),
                );
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Server'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_link),
            tooltip: 'Connect Manually',
            onPressed: _showManualConnectDialog,
          ),
          if (!_isScanning)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _scanNetwork,
            ),
        ],
      ),
      body: _isScanning && _servers.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Scanning Wi-Fi Network...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : _servers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No StreamSync hosts found.\nMake sure the other device has the app open.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Scan Again'),
                        onPressed: _scanNetwork,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _servers.length,
                  itemBuilder: (context, index) {
                    final server = _servers[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.deepPurpleAccent,
                        child: Icon(Icons.tv, color: Colors.white),
                      ),
                      title: Text(server.name),
                      subtitle: Text(server.ip),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RemoteMediaScreen(serverIp: server.ip),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
