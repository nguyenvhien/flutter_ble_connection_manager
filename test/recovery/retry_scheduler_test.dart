import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ble_connection_manager/src/recovery/retry_scheduler.dart';
import 'package:flutter_ble_connection_manager/flutter_ble_connection_manager.dart';

void main() {
  group('RetryScheduler', () {
    test('executes action once on success (no retries needed)', () async {
      var callCount = 0;
      final scheduler = RetryScheduler(
        policy: const RecoveryPolicy.exponentialBackoff(maxAttempts: 3),
      );

      await scheduler.execute(
        action: (_) async {
          callCount++;
        },
        onRetryScheduled: (_, __) {},
        onAttemptFailed: (_, __, ___) {},
      );

      expect(callCount, 1);
    });

    test('retries up to maxAttempts on failure', () async {
      var callCount = 0;
      final scheduler = RetryScheduler(
        policy: const RecoveryPolicy.simple(
          maxAttempts: 3,
          delay: Duration.zero,
        ),
      );

      try {
        await scheduler.execute(
          action: (_) async {
            callCount++;
            throw Exception('fail');
          },
          onRetryScheduled: (_, __) {},
          onAttemptFailed: (_, __, ___) {},
        );
      } on Exception {
        // expected
      }

      // 1 initial + 3 retries = 4 total calls
      expect(callCount, 4);
    });

    test('succeeds on second attempt', () async {
      var callCount = 0;
      final scheduler = RetryScheduler(
        policy: const RecoveryPolicy.simple(
          maxAttempts: 3,
          delay: Duration.zero,
        ),
      );

      await scheduler.execute(
        action: (_) async {
          callCount++;
          if (callCount < 2) throw Exception('transient');
        },
        onRetryScheduled: (_, __) {},
        onAttemptFailed: (_, __, ___) {},
      );

      expect(callCount, 2);
    });

    test('stops immediately when shouldRetry returns false', () async {
      var callCount = 0;
      final scheduler = RetryScheduler(
        policy: RecoveryPolicy.exponentialBackoff(
          maxAttempts: 5,
          initialDelay: Duration.zero,
          shouldRetryFn: (_) => false,
        ),
      );

      try {
        await scheduler.execute(
          action: (_) async {
            callCount++;
            throw Exception('fatal');
          },
          onRetryScheduled: (_, __) {},
          onAttemptFailed: (_, __, ___) {},
        );
      } on Exception {
        // expected
      }

      expect(callCount, 1); // No retries
    });

    test('calls onRetryScheduled before each retry', () async {
      final scheduledAttempts = <int>[];
      final scheduler = RetryScheduler(
        policy: const RecoveryPolicy.simple(
          maxAttempts: 2,
          delay: Duration.zero,
        ),
      );

      try {
        await scheduler.execute(
          action: (_) async => throw Exception('fail'),
          onRetryScheduled: (attemptNumber, _) {
            scheduledAttempts.add(attemptNumber);
          },
          onAttemptFailed: (_, __, ___) {},
        );
      } on Exception {
        // expected
      }

      expect(scheduledAttempts, [2, 3]);
    });

    test('calls onAttemptFailed with correct willRetry flag', () async {
      final failures = <(int, bool)>[];
      final scheduler = RetryScheduler(
        policy: const RecoveryPolicy.simple(
          maxAttempts: 2,
          delay: Duration.zero,
        ),
      );

      try {
        await scheduler.execute(
          action: (_) async => throw Exception('fail'),
          onRetryScheduled: (_, __) {},
          onAttemptFailed: (_, attemptNumber, willRetry) {
            failures.add((attemptNumber, willRetry));
          },
        );
      } on Exception {
        // expected
      }

      expect(failures, [
        (1, true), // attempt 1 failed, will retry
        (2, true), // attempt 2 failed, will retry
        (3, false), // attempt 3 failed, no more retries
      ]);
    });

    test('noRetry policy fails immediately', () async {
      var callCount = 0;
      final scheduler = RetryScheduler(
        policy: const RecoveryPolicy.noRetry(),
      );

      try {
        await scheduler.execute(
          action: (_) async {
            callCount++;
            throw Exception('fail');
          },
          onRetryScheduled: (_, __) {},
          onAttemptFailed: (_, __, ___) {},
        );
      } on Exception {
        // expected
      }

      expect(callCount, 1);
    });

    test('can be cancelled during execution', () async {
      var callCount = 0;
      final scheduler = RetryScheduler(
        policy: const RecoveryPolicy.exponentialBackoff(maxAttempts: 10),
      );

      final future = scheduler.execute(
        action: (_) async {
          callCount++;
          // Simulate work that takes time
          await Future.delayed(const Duration(milliseconds: 50));
          throw Exception('fail');
        },
        onRetryScheduled: (_, __) {},
        onAttemptFailed: (_, __, ___) {},
      );

      // Cancel it shortly after it starts
      await Future.delayed(const Duration(milliseconds: 20));
      scheduler.cancel();

      try {
        await future;
      } catch (_) {
        // The active delay or action will be interrupted/aborted eventually
      }

      // Should not reach 10 attempts
      expect(callCount, lessThan(10));
    });
  });
}
