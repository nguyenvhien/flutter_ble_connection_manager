import 'dart:async';

import 'recovery_policy.dart';

/// Internal engine that executes an async action with retries
/// according to a [RecoveryPolicy].
///
/// This class is the execution counterpart to [RecoveryPolicy].
/// The policy defines the rules; this class executes them.
///
/// Supports cancellation mid-retry via [cancel].
class RetryScheduler {
  /// The policy governing retry behavior.
  final RecoveryPolicy policy;

  Timer? _delayTimer;
  bool _cancelled = false;

  /// Creates a [RetryScheduler] with the given [policy].
  RetryScheduler({required this.policy});

  /// Execute [action] with retries per [policy].
  ///
  /// - [onRetryScheduled] is called before each retry delay with the
  ///   upcoming attempt number and delay duration.
  /// - [onAttemptFailed] is called after each failed attempt with the
  ///   error, attempt number, and whether a retry will occur.
  ///
  /// Returns normally if [action] succeeds on any attempt.
  /// Throws the last error if all attempts are exhausted or if
  /// [RecoveryPolicy.shouldRetry] returns false.
  Future<void> execute({
    required Future<void> Function(int currentAttempt) action,
    required void Function(int attemptNumber, Duration delay) onRetryScheduled,
    required void Function(Object error, int attemptNumber, bool willRetry)
        onAttemptFailed,
  }) async {
    _cancelled = false;
    Object? lastError;

    for (var attempt = 0; attempt <= policy.maxAttempts; attempt++) {
      if (_cancelled) {
        throw lastError ?? Exception('Cancelled');
      }

      try {
        await action(attempt + 1);
        return; // Success — exit immediately
      } catch (e) {
        lastError = e;

        final hasMoreAttempts = attempt < policy.maxAttempts;
        final shouldRetry = hasMoreAttempts && policy.shouldRetry(e);

        onAttemptFailed(e, attempt + 1, shouldRetry);

        if (!shouldRetry) break;

        final delay = policy.computeDelay(attempt);
        onRetryScheduled(attempt + 2, delay);

        await _delayWithCancellation(delay);
      }
    }

    throw lastError!;
  }

  /// Cancel any pending retry delay.
  ///
  /// The current [execute] call will throw on the next iteration check.
  void cancel() {
    _cancelled = true;
    _delayTimer?.cancel();
    _delayTimer = null;
  }

  Future<void> _delayWithCancellation(Duration delay) {
    if (delay == Duration.zero) return Future.value();

    final completer = Completer<void>();
    _delayTimer = Timer(delay, () {
      if (!completer.isCompleted) completer.complete();
    });

    return completer.future.then((_) {
      if (_cancelled) throw Exception('Cancelled during delay');
    });
  }
}
