// ignore_for_file: unused_local_variable, avoid_print

/// Multi-device example
///
/// This example demonstrates how to manage multiple BLE devices simultaneously.
/// The core principle of `flutter_ble_connection_manager` is:
/// **One Manager per Device**.
///
/// By instantiating a separate manager for each device, you ensure that:
/// 1. States are perfectly isolated.
/// 2. Retry policies and timeouts do not interfere with each other.
/// 3. Race conditions are handled per-device.
library;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_connection_manager/flutter_ble_connection_manager.dart';

class FleetManager {
  // Store managers by their device ID (MAC address).
  final Map<String, BleConnectionManager> _managers = {};

  /// Connects to a new device and stores its manager.
  Future<void> connectToDevice(BluetoothDevice device) async {
    final deviceId = device.remoteId.str;

    if (_managers.containsKey(deviceId)) {
      print('Device $deviceId is already being managed.');
      return;
    }

    // 1. Create a dedicated manager for this specific device.
    final manager = BleConnectionManager(
      device: device,
      config: ConnectionConfig(
        timeout: const Duration(seconds: 15),
        recoveryPolicy: const RecoveryPolicy.exponentialBackoff(maxAttempts: 3),
        onSetup: (device, token) async {
          // Setup logic specific to this device...
          token.throwIfCancelled();
        },
      ),
    );

    // 2. Store it.
    _managers[deviceId] = manager;

    // 3. Listen to its isolated state.
    manager.stateStream.listen((state) {
      print('Device [$deviceId] state: $state');
    });

    // 4. Connect!
    try {
      await manager.connect();
      print('Device [$deviceId] is Application Ready!');
    } on BleConnectionException catch (e) {
      print('Device [$deviceId] failed to connect: $e');
      _managers.remove(deviceId);
      await manager.dispose();
    }
  }

  /// Sends a command to all currently ready devices.
  Future<void> broadcastCommand(List<int> payload) async {
    for (final entry in _managers.entries) {
      final id = entry.key;
      final manager = entry.value;

      if (manager.isReady) {
        print('Broadcasting to [$id]...');
        // manager.device.writeCharacteristic(...)
      }
    }
  }

  /// Disconnects and cleans up a specific device.
  Future<void> disconnectDevice(String deviceId) async {
    final manager = _managers.remove(deviceId);
    if (manager != null) {
      print('Disconnecting [$deviceId]...');
      await manager.disconnect();
      await manager.dispose();
    }
  }

  /// Cleans up all devices when the app closes.
  Future<void> disposeAll() async {
    for (final manager in _managers.values) {
      await manager.disconnect();
      await manager.dispose();
    }
    _managers.clear();
  }
}

Future<void> main() async {
  final fleet = FleetManager();

  // Simulated scanned devices
  final device1 = BluetoothDevice.fromId('00:11:22:33:44:55');
  final device2 = BluetoothDevice.fromId('AA:BB:CC:DD:EE:FF');

  // Connect to multiple devices concurrently.
  // Each manager handles its own lifecycle, retries, and setup independently!
  await Future.wait([
    fleet.connectToDevice(device1),
    fleet.connectToDevice(device2),
  ]);

  await fleet.broadcastCommand([0x01, 0x02]);

  await fleet.disposeAll();
}
