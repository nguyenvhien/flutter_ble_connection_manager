import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ble_connection_manager/flutter_ble_connection_manager.dart';

void main() {
  group('ConnectionConfig', () {
    test('has sensible defaults', () {
      const config = ConnectionConfig();
      expect(config.connectionTimeout, const Duration(seconds: 15));
      expect(config.setupTimeout, const Duration(seconds: 30));
      expect(config.autoDiscoverServices, true);
      expect(config.autoReconnect, true);
      expect(config.onSetup, isNull);
    });

    test('recoveryPolicy defaults to exponentialBackoff', () {
      const config = ConnectionConfig();
      expect(config.recoveryPolicy.maxAttempts, 5);
      expect(config.recoveryPolicy.backoffMultiplier, 2.0);
    });

    test('accepts custom values', () {
      const config = ConnectionConfig(
        connectionTimeout: Duration(seconds: 10),
        setupTimeout: Duration(seconds: 20),
        autoDiscoverServices: false,
        autoReconnect: false,
        recoveryPolicy: RecoveryPolicy.noRetry(),
      );
      expect(config.connectionTimeout, const Duration(seconds: 10));
      expect(config.setupTimeout, const Duration(seconds: 20));
      expect(config.autoDiscoverServices, false);
      expect(config.autoReconnect, false);
      expect(config.recoveryPolicy.maxAttempts, 0);
    });
  });
}
