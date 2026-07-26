import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_design.dart';
import '../mock/mock_ble_connection_manager.dart';

class DeviceSelector extends StatefulWidget {
  final void Function(fbp.BluetoothDevice) onDeviceSelected;
  final bool isMockMode;

  const DeviceSelector({
    super.key, 
    required this.onDeviceSelected,
    required this.isMockMode,
  });

  @override
  State<DeviceSelector> createState() => _DeviceSelectorState();
}

class _DeviceSelectorState extends State<DeviceSelector> {
  bool _isScanning = false;
  final List<fbp.BluetoothDevice> _discoveredDevices = [];
  StreamSubscription? _scanSub;

  @override
  void dispose() {
    _stopScan(isDisposing: true);
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
            MockBluetoothDevice(const fbp.DeviceIdentifier('00:1A:7D:DA:71:13'), 'Smart Thermostat V2'),
            MockBluetoothDevice(const fbp.DeviceIdentifier('F4:5E:AB:12:34:56'), 'Fitness Tracker Pro'),
            MockBluetoothDevice(const fbp.DeviceIdentifier('08:D1:F9:C3:4A:2B'), 'Bluetooth Speaker X1'),
            MockBluetoothDevice(const fbp.DeviceIdentifier('9C:F3:87:A1:B2:C3'), 'Heart Rate Monitor'),
            MockBluetoothDevice(const fbp.DeviceIdentifier('A4:C1:38:F4:D5:E6'), 'Smart Lock Alpha'),
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
        _discoveredDevices.addAll(results.where((r) => r.device.advName.isNotEmpty).map((r) => r.device));
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(AppDimensions.spacingMedium),
          child: Text(
            'Prerequisite: Select a device',
            style: TextStyle(color: AppColors.textSecondary, fontSize: AppDimensions.fontMedium),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMedium),
          child: ElevatedButton.icon(
            icon: Icon(_isScanning ? Icons.stop : Icons.search),
            onPressed: _isScanning ? _stopScan : _startScan,
            label: Text(_isScanning ? 'Stop Scan' : 'Scan for Devices'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingMedium),
        Expanded(
          child: ListView.builder(
            itemCount: _discoveredDevices.length,
            itemBuilder: (context, index) {
              final device = _discoveredDevices[index];
              final isMock = device is MockBluetoothDevice;
              final description = isMock ? mockDescriptions[device.advName] : null;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMedium, vertical: 4),
                child: isMock && description != null
                    ? Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          leading: const Icon(Icons.bluetooth, color: AppColors.highlight),
                          title: Text(device.advName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(device.remoteId.str, style: const TextStyle(fontSize: 12)),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(description, style: const TextStyle(color: AppColors.textSecondary)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  onPressed: () {
                                    _stopScan();
                                    widget.onDeviceSelected(device);
                                  },
                                  child: const Text('Connect'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListTile(
                        leading: const Icon(Icons.bluetooth, color: AppColors.highlight),
                        title: Text(device.advName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(device.remoteId.str, style: const TextStyle(fontSize: 12)),
                        trailing: ElevatedButton(
                          onPressed: () {
                            _stopScan();
                            widget.onDeviceSelected(device);
                          },
                          child: const Text('Connect'),
                        ),
                      ),
              );
            },
          ),
        )
      ],
    );
  }
}
