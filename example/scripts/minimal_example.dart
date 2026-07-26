// ignore_for_file: unused_local_variable, avoid_print

/// Minimal example: Connect → Ready → Disconnect
///
/// This is the simplest possible usage. It uses all default config values.
/// The manager moves the device from Disconnected to Application Ready
/// and back.
library;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_connection_manager/flutter_ble_connection_manager.dart';

Future<void> minimalExample(BluetoothDevice device) async {
  // One manager per device. That's it.
  final manager = BleConnectionManager(device: device);

  try {
    // connect() completes ONLY when the device is Application Ready,
    // not just BLE-connected. Services are already discovered.
    await manager.connect();

    // The device is now ready — use flutter_blue_plus directly.
    // The manager never wraps the device.
    final services = device.servicesList;
    print('Connected & ready. Found ${services.length} services.');

    // ... do your work ...

    await manager.disconnect();
  } on BleConnectionException catch (e) {
    print('Connection failed: $e');
  } finally {
    await manager.dispose();
  }
}
