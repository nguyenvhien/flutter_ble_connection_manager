import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:flutter_ble_connection_manager/flutter_ble_connection_manager.dart';
import 'package:example/shared/mock/mock_ble_connection_manager.dart';
import 'package:fake_async/fake_async.dart';

void main() {
  group('MockBleConnectionManager Smoke Tests', () {
    test('Smart Thermostat V2 - Happy Path', () {
      fakeAsync((async) {
        final device = MockBluetoothDevice(
          const fbp.DeviceIdentifier('00:1A:7D:DA:71:13'),
          'Smart Thermostat V2',
        );
        final manager = MockBleConnectionManager(device: device);

        final states = <BleConnectionState>[];
        manager.stateStream.listen(states.add);

        manager.connect();

        async.elapse(const Duration(seconds: 3));

        expect(states, [
          BleConnectionState.disconnected,
          BleConnectionState.connecting,
          BleConnectionState.ready,
        ]);

        manager.dispose();
      });
    });

    test('Fitness Tracker Pro - Connection Timeout', () {
      fakeAsync((async) {
        final device = MockBluetoothDevice(
          const fbp.DeviceIdentifier('F4:5E:AB:12:34:56'),
          'Fitness Tracker Pro',
        );
        final manager = MockBleConnectionManager(device: device);

        final states = <BleConnectionState>[];
        manager.stateStream.listen(states.add);

        manager.connect();

        async.elapse(const Duration(seconds: 3));

        expect(states, [
          BleConnectionState.disconnected,
          BleConnectionState.connecting,
          BleConnectionState.disconnected,
        ]);

        manager.dispose();
      });
    });

    test('Bluetooth Speaker X1 - Setup Failed', () {
      fakeAsync((async) {
        final device = MockBluetoothDevice(
          const fbp.DeviceIdentifier('08:D1:F9:C3:4A:2B'),
          'Bluetooth Speaker X1',
        );
        final manager = MockBleConnectionManager(device: device);

        final states = <BleConnectionState>[];
        manager.stateStream.listen(states.add);

        manager.connect();

        async.elapse(const Duration(seconds: 4));

        expect(states, [
          BleConnectionState.disconnected,
          BleConnectionState.connecting,
          BleConnectionState.disconnected,
        ]);

        manager.dispose();
      });
    });

    test('Heart Rate Monitor - Auto-Reconnect Success', () {
      fakeAsync((async) {
        final device = MockBluetoothDevice(
          const fbp.DeviceIdentifier('9C:F3:87:A1:B2:C3'),
          'Heart Rate Monitor',
        );
        final manager = MockBleConnectionManager(device: device);

        final states = <BleConnectionState>[];
        manager.stateStream.listen(states.add);

        manager.connect();

        // Initial connection
        async.elapse(const Duration(seconds: 3));
        expect(states.last, BleConnectionState.ready);

        // Wait for unexpected disconnect (after 3s)
        async.elapse(const Duration(seconds: 3));
        expect(states.last, BleConnectionState.disconnected);

        // Wait for auto-reconnect delay (1s) + reconnect time (2s)
        async.elapse(const Duration(seconds: 4));
        expect(states.last, BleConnectionState.ready);

        manager.dispose();
      });
    });

    test('Smart Lock Alpha - Auto-Reconnect Failure', () {
      fakeAsync((async) {
        final device = MockBluetoothDevice(
          const fbp.DeviceIdentifier('A4:C1:38:F4:D5:E6'),
          'Smart Lock Alpha',
        );
        final manager = MockBleConnectionManager(device: device);

        final states = <BleConnectionState>[];
        manager.stateStream.listen(states.add);

        manager.connect();

        // Initial connection
        async.elapse(const Duration(seconds: 3));
        expect(states.last, BleConnectionState.ready);

        // Wait for unexpected disconnect (after 3s)
        async.elapse(const Duration(seconds: 3));
        expect(states.last, BleConnectionState.disconnected);

        // Wait for 3 attempts (each attempt takes 1s + 2s delay = 3s * 3 = 9s)
        // Wait 10s to be safe
        async.elapse(const Duration(seconds: 15));

        // Final state should be disconnected
        expect(states.last, BleConnectionState.disconnected);

        manager.dispose();
      });
    });
  });
}
