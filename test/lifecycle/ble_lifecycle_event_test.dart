import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ble_connection_manager/flutter_ble_connection_manager.dart';

void main() {
  group('BleLifecycleEvent', () {
    test('ConnectionAttemptStarted carries attempt number', () {
      final event = ConnectionAttemptStarted(attemptNumber: 1);
      expect(event.attemptNumber, 1);
      expect(event.timestamp, isA<DateTime>());
    });

    test('ConnectionFailed carries error and willRetry flag', () {
      final error = Exception('GATT 133');
      final event = ConnectionFailed(
        error: error,
        attemptNumber: 2,
        willRetry: true,
      );
      expect(event.error, error);
      expect(event.attemptNumber, 2);
      expect(event.willRetry, true);
    });

    test('Disconnected carries reason', () {
      final event = Disconnected(reason: BleDisconnectReason.userInitiated);
      expect(event.reason, BleDisconnectReason.userInitiated);
    });

    test('Disconnected unexpected carries reason', () {
      final event = Disconnected(reason: BleDisconnectReason.unexpected);
      expect(event.reason, BleDisconnectReason.unexpected);
    });

    test('RetryScheduled carries delay and attempt', () {
      final event = RetryScheduled(
        attemptNumber: 3,
        delay: const Duration(seconds: 4),
      );
      expect(event.delay, const Duration(seconds: 4));
      expect(event.attemptNumber, 3);
    });

    test('all events are subtypes of BleLifecycleEvent', () {
      final events = <BleLifecycleEvent>[
        ConnectionAttemptStarted(attemptNumber: 1),
        ConnectionEstablished(),
        ServiceDiscoveryStarted(),
        ServiceDiscoveryCompleted(),
        SetupStarted(),
        SetupCompleted(),
        ConnectionReady(),
        DisconnectionInitiated(userInitiated: true),
        Disconnected(reason: BleDisconnectReason.userInitiated),
        RetryScheduled(attemptNumber: 1, delay: Duration.zero),
        ReconnectionStarted(),
        ConnectionFailed(error: 'e', attemptNumber: 1, willRetry: false),
      ];
      expect(events, hasLength(12));
    });

    test('sealed class supports exhaustive switch', () {
      final BleLifecycleEvent event = ConnectionReady();
      final label = switch (event) {
        ConnectionAttemptStarted() => 'attempt',
        ConnectionEstablished() => 'established',
        ServiceDiscoveryStarted() => 'disc_start',
        ServiceDiscoveryCompleted() => 'disc_end',
        SetupStarted() => 'setup_start',
        SetupCompleted() => 'setup_end',
        ConnectionReady() => 'ready',
        DisconnectionInitiated() => 'disc_init',
        Disconnected() => 'disconnected',
        RetryScheduled() => 'retry',
        ReconnectionStarted() => 'reconnect',
        ConnectionFailed() => 'failed',
      };
      expect(label, 'ready');
    });
  });
}
