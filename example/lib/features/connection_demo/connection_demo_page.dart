import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:flutter_ble_connection_manager/flutter_ble_connection_manager.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../shared/theme/app_design.dart';
import '../../shared/widgets/device_connection_card.dart';
import '../../shared/mock/mock_ble_connection_manager.dart';

class ConnectionDemoPage extends StatefulWidget {
  final bool isMockMode;

  const ConnectionDemoPage({super.key, required this.isMockMode});

  @override
  State<ConnectionDemoPage> createState() => _ConnectionDemoPageState();
}

class _ConnectionDemoPageState extends State<ConnectionDemoPage> {
  bool _isScanning = false;
  final List<fbp.BluetoothDevice> _discoveredDevices = [];
  StreamSubscription? _scanSub;

  // The heart of Multi-Device connection: holding managers for multiple devices
  final Map<String, BleConnectionManager> _managers = {};

  @override
  void dispose() {
    _stopScan(isDisposing: true);
    for (final manager in _managers.values) {
      manager.dispose();
    }
    super.dispose();
  }

  void _startScan() async {
    if (widget.isMockMode) {
      setState(() {
        _isScanning = true;
        _discoveredDevices.clear();
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() {
          _isScanning = false;
          _discoveredDevices.addAll([
            MockBluetoothDevice(
              const fbp.DeviceIdentifier('00:1A:7D:DA:71:13'),
              'Smart Thermostat V2',
            ),
            MockBluetoothDevice(
              const fbp.DeviceIdentifier('F4:5E:AB:12:34:56'),
              'Fitness Tracker Pro',
            ),
            MockBluetoothDevice(
              const fbp.DeviceIdentifier('08:D1:F9:C3:4A:2B'),
              'Bluetooth Speaker X1',
            ),
            MockBluetoothDevice(
              const fbp.DeviceIdentifier('9C:F3:87:A1:B2:C3'),
              'Heart Rate Monitor',
            ),
            MockBluetoothDevice(
              const fbp.DeviceIdentifier('A4:C1:38:F4:D5:E6'),
              'Smart Lock Alpha',
            ),
          ]);
        });
      });
      return;
    }

    if (await Permission.bluetoothScan.request().isDenied ||
        await Permission.bluetoothConnect.request().isDenied ||
        await Permission.location.request().isDenied) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _isScanning = true;
      _discoveredDevices.clear();
    });

    _scanSub = fbp.FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      setState(() {
        _discoveredDevices.clear();
        _discoveredDevices.addAll(
          results
              .where((r) => r.device.advName.isNotEmpty)
              .map((r) => r.device),
        );
      });
    });

    await fbp.FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  void _stopScan({bool isDisposing = false}) {
    fbp.FlutterBluePlus.stopScan();
    _scanSub?.cancel();
    if (mounted && !isDisposing) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  BleConnectionManager _getOrCreateManager(fbp.BluetoothDevice device) {
    if (!_managers.containsKey(device.remoteId.str)) {
      if (widget.isMockMode) {
        _managers[device.remoteId.str] = MockBleConnectionManager(
          device: device,
        );
      } else {
        _managers[device.remoteId.str] = BleConnectionManager(
          device: device,
          config: const ConnectionConfig(
            autoReconnect: true,
            autoDiscoverServices: true,
          ),
        );
      }
    }
    return _managers[device.remoteId.str]!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Multi-Device Demo')),
      body: Column(
        children: [
          _buildScanHeader(),
          Expanded(
            child: ListView.builder(
              itemCount: _discoveredDevices.length,
              itemBuilder: (context, index) {
                final device = _discoveredDevices[index];
                final manager = _getOrCreateManager(device);
                return DeviceConnectionCard(
                  key: ValueKey(device.remoteId.str),
                  device: device,
                  manager: manager,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanHeader() {
    return Material(
      color: AppColors.surfaceHighlight,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: Icon(_isScanning ? Icons.stop : Icons.search),
              onPressed: _isScanning ? _stopScan : _startScan,
              label: Text(_isScanning ? 'Stop Scan' : 'Scan for Devices'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
