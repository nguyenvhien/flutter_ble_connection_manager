import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ble_connection_manager/flutter_ble_connection_manager.dart';

void main() {
  group('RecoveryPolicy', () {
    test('noRetry has maxAttempts 0', () {
      const policy = RecoveryPolicy.noRetry();
      expect(policy.maxAttempts, 0);
    });

    test('simple has constant delay (multiplier 1.0)', () {
      const policy = RecoveryPolicy.simple(
        maxAttempts: 3,
        delay: Duration(seconds: 2),
      );
      expect(policy.maxAttempts, 3);
      expect(policy.initialDelay, const Duration(seconds: 2));
      expect(policy.backoffMultiplier, 1.0);
    });

    test('exponentialBackoff doubles delay by default', () {
      const policy = RecoveryPolicy.exponentialBackoff();
      expect(policy.backoffMultiplier, 2.0);
      expect(policy.maxAttempts, 5);
      expect(policy.initialDelay, const Duration(seconds: 1));
      expect(policy.maxDelay, const Duration(seconds: 30));
    });

    test('computeDelay for exponential backoff', () {
      const policy = RecoveryPolicy.exponentialBackoff(
        initialDelay: Duration(seconds: 1),
        backoffMultiplier: 2.0,
        maxDelay: Duration(seconds: 30),
      );
      expect(policy.computeDelay(0), const Duration(seconds: 1));
      expect(policy.computeDelay(1), const Duration(seconds: 2));
      expect(policy.computeDelay(2), const Duration(seconds: 4));
      expect(policy.computeDelay(3), const Duration(seconds: 8));
    });

    test('computeDelay respects maxDelay cap', () {
      const policy = RecoveryPolicy.exponentialBackoff(
        initialDelay: Duration(seconds: 4),
        maxDelay: Duration(seconds: 10),
        backoffMultiplier: 3.0,
      );
      // attempt 0: 4s
      expect(policy.computeDelay(0), const Duration(seconds: 4));
      // attempt 1: 12s -> capped to 10s
      expect(policy.computeDelay(1), const Duration(seconds: 10));
    });

    test('shouldRetry defaults to always true', () {
      const policy = RecoveryPolicy.exponentialBackoff();
      expect(policy.shouldRetry(Exception('test')), true);
      expect(policy.shouldRetry(StateError('test')), true);
    });

    test('custom shouldRetry callback is respected', () {
      final policy = RecoveryPolicy.exponentialBackoff(
        shouldRetryFn: (error) => error is! FormatException,
      );
      expect(policy.shouldRetry(Exception('ok')), true);
      expect(policy.shouldRetry(const FormatException('bad')), false);
    });
  });
}
