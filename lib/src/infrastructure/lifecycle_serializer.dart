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

  /// The key of the last operation added to the queue (if deduped).
  String? _lastKey;

  /// The future of the last operation added to the queue (if deduped).
  Future<void>? _lastFuture;

  /// Run [action] after all previous operations complete.
  ///
  /// If a previous operation is in progress, [action] waits.
  /// Errors from [action] are propagated to the caller and do NOT
  /// block subsequent operations.
  Future<T> run<T>(Future<T> Function() action) async {
    if (Zone.current[#_lifecycle_serializer] == this) {
      throw StateError(
          'Deadlock detected: lifecycle operation called from within another lifecycle operation.');
    }

    // We clear the dedup state if a non-deduped run is called.
    _lastKey = null;
    _lastFuture = null;

    return runZoned(
      () => _runInternal(action),
      zoneValues: {#_lifecycle_serializer: this},
    );
  }

  Future<T> _runInternal<T>(Future<T> Function() action) async {
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
  /// If an operation with the same [key] was the LAST operation queued,
  /// returns the existing Future without starting a new operation.
  /// This prevents `connect -> disconnect -> connect` from deduplicating
  /// the second connect to the first one.
  Future<void> runDeduped(
    String key,
    Future<void> Function() action,
  ) {
    if (Zone.current[#_lifecycle_serializer] == this) {
      throw StateError(
          'Deadlock detected: lifecycle operation called from within another lifecycle operation.');
    }

    if (_lastKey == key && _lastFuture != null) {
      return _lastFuture!;
    }

    final future = runZoned(
      () => _runInternal(action),
      zoneValues: {#_lifecycle_serializer: this},
    );
    _lastKey = key;
    _lastFuture = future;

    // Once this specific future completes, if it's still the last one, we clear it.
    // This allows subsequent identical keys to run again after completion.
    future.whenComplete(() {
      if (_lastFuture == future) {
        _lastKey = null;
        _lastFuture = null;
      }
    }).catchError(
        (_) {}); // Prevent unhandled error from the whenComplete branch

    return future;
  }
}
