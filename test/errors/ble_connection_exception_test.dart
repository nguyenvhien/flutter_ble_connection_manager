import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ble_connection_manager/flutter_ble_connection_manager.dart';

void main() {
  group('BleConnectionException', () {
    test('TransportFailure preserves original error', () {
      final original = Exception('GATT error 133');
      final failure = TransportFailure(
        message: 'BLE connection failed',
        cause: original,
      );
      expect(failure.cause, original);
      expect(failure.message, contains('BLE connection'));
    });

    test('SetupFailure wraps setup callback errors', () {
      final original = StateError('auth failed');
      final failure = SetupFailure(
        message: 'Setup callback threw',
        cause: original,
      );
      expect(failure.cause, isA<StateError>());
    });

    test('TimeoutFailure includes which phase timed out', () {
      const failure = TimeoutFailure(
        message: 'Service discovery timed out',
        phase: ConnectionPhase.serviceDiscovery,
      );
      expect(failure.phase, ConnectionPhase.serviceDiscovery);
    });

    test('CancellationFailure indicates cancelled operation', () {
      const failure = CancellationFailure();
      expect(failure.message, contains('cancel'));
    });

    test('ManagerDisposedError toString contains disposed', () {
      const failure = ManagerDisposedError();
      expect(failure.toString(), contains('disposed'));
    });

    test('sealed class supports exhaustive switch', () {
      const BleConnectionException ex = CancellationFailure();
      final label = switch (ex) {
        TransportFailure() => 'transport',
        SetupFailure() => 'setup',
        TimeoutFailure() => 'timeout',
        CancellationFailure() => 'cancelled',
        ConfigurationError() => 'config',
        ManagerDisposedError() => 'disposed',
      };
      expect(label, 'cancelled');
    });
  });
}
