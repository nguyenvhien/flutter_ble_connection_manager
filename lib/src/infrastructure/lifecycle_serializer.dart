import 'dart:async';

/// Serializes lifecycle operations to prevent concurrent execution.
///
/// This is the core race condition prevention mechanism.
/// It guarantees that [connect] and [disconnect] never execute
/// concurrently, even when called in rapid succession.
///
/// ## How It Works
///
/// - [run]: Queues an operation. If a previous operation is in progress,
///   the new one waits for it to complete before starting.
/// - [runDeduped]: Same as [run], but if an operation with the same key
///   is already running, returns the existing Future instead of queueing
///   a duplicate.
///
/// ## Invariant
///
/// Only one lifecycle operation may execute at a time.
class LifecycleSerializer {
  Future<void>? _currentOperation;

  /// Active deduplication futures, keyed by operation name.
  final Map<String, Future<void>> _dedupedOperations = {};

  /// Run [action] after all previous operations complete.
  ///
  /// If a previous operation is in progress, [action] waits.
  /// Errors from [action] are propagated to the caller and do NOT
  /// block subsequent operations.
  Future<T> run<T>(Future<T> Function() action) async {
    // Wait for current operation to finish (ignore its errors —
    // they belong to the previous caller)
    while (_currentOperation != null) {
      try {
        await _currentOperation;
      } catch (_) {
        // Previous operation failed; we still proceed with ours
      }
    }

    final completer = Completer<void>();
    _currentOperation = completer.future;

    try {
      final result = await action();
      return result;
    } finally {
      completer.complete();
      _currentOperation = null;
    }
  }

  /// Run [action] with deduplication.
  ///
  /// If an operation with the same [key] is already running,
  /// returns the existing Future without starting a new operation.
  /// This is used to deduplicate concurrent [connect] calls.
  Future<void> runDeduped(
    String key,
    Future<void> Function() action,
  ) {
    final existing = _dedupedOperations[key];
    if (existing != null) return existing;

    final future = run(action).whenComplete(() {
      _dedupedOperations.remove(key);
    });

    _dedupedOperations[key] = future;
    return future;
  }
}
