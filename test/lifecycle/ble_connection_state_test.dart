import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ble_connection_manager/flutter_ble_connection_manager.dart';

void main() {
  group('BleConnectionState', () {
    test('has exactly four values', () {
      expect(BleConnectionState.values.length, 4);
    });

    test('values are disconnected, connecting, ready, disconnecting', () {
      expect(
        BleConnectionState.values,
        containsAll([
          BleConnectionState.disconnected,
          BleConnectionState.connecting,
          BleConnectionState.ready,
          BleConnectionState.disconnecting,
        ]),
      );
    });

    test('disconnected is the first value (initial state)', () {
      expect(BleConnectionState.values.first, BleConnectionState.disconnected);
    });
  });
}
