/// Defines the retry/reconnect behavior for connection failures.
///
/// This is a pure data class (policy). It does not own timers or
/// scheduling. The internal retry engine consumes this policy.
///
/// Use the named constructors for common strategies:
///
/// ```dart
/// // No retries — fail immediately
/// const RecoveryPolicy.noRetry()
///
/// // Fixed delay between retries
/// const RecoveryPolicy.simple(maxAttempts: 3, delay: Duration(seconds: 2))
///
/// // Exponential backoff (default)
/// const RecoveryPolicy.exponentialBackoff()
/// ```
class RecoveryPolicy {
  /// Maximum number of retry attempts. 0 means no retries.
  final int maxAttempts;

  /// Delay before the first retry.
  final Duration initialDelay;

  /// Maximum delay between retries (caps backoff growth).
  final Duration maxDelay;

  /// Multiplier applied to delay after each failed attempt.
  /// - `1.0` = constant delay
  /// - `2.0` = exponential doubling
  final double backoffMultiplier;

  /// Optional function to determine if a specific error is retryable.
  /// If null, all errors are considered retryable.
  final bool Function(Object error)? _shouldRetryFn;

  /// Creates a [RecoveryPolicy] with full control over all parameters.
  const RecoveryPolicy({
    required this.maxAttempts,
    required this.initialDelay,
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 1.0,
    bool Function(Object error)? shouldRetryFn,
  }) : _shouldRetryFn = shouldRetryFn;

  /// No retry. Fail immediately on first error.
  const RecoveryPolicy.noRetry()
      : maxAttempts = 0,
        initialDelay = Duration.zero,
        maxDelay = Duration.zero,
        backoffMultiplier = 1.0,
        _shouldRetryFn = null;

  /// Constant delay between retries.
  const RecoveryPolicy.simple({
    this.maxAttempts = 3,
    required Duration delay,
  })  : initialDelay = delay,
        maxDelay = delay,
        backoffMultiplier = 1.0,
        _shouldRetryFn = null;

  /// Exponential backoff with configurable parameters.
  ///
  /// Default: 5 attempts, starting at 1s, doubling each time, capped at 30s.
  /// Gives attempts at approximately: 1s, 2s, 4s, 8s, 16s (~31s total).
  const RecoveryPolicy.exponentialBackoff({
    this.maxAttempts = 5,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    bool Function(Object error)? shouldRetryFn,
  }) : _shouldRetryFn = shouldRetryFn;

  /// Whether the given [error] should trigger a retry.
  bool shouldRetry(Object error) => _shouldRetryFn?.call(error) ?? true;

  /// Compute the delay for the given zero-based [attempt] number.
  Duration computeDelay(int attempt) {
    final ms = initialDelay.inMilliseconds * _pow(backoffMultiplier, attempt);
    final capped = ms.clamp(0, maxDelay.inMilliseconds);
    return Duration(milliseconds: capped.toInt());
  }

  static double _pow(double base, int exponent) {
    var result = 1.0;
    for (var i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }
}
