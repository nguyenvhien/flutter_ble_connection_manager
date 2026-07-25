/// A cooperative cancellation mechanism for async operations.
///
/// The [BleConnectionManager] passes this token to the setup callback.
/// When the manager needs to abort setup (e.g., the user called
/// [BleConnectionManager.disconnect]), it calls [cancel] on the token.
///
/// The setup callback should check [isCancelled] periodically or call
/// [throwIfCancelled] to cooperatively exit.
///
/// ```dart
/// config: ConnectionConfig(
///   onSetup: (device, token) async {
///     await device.setNotifyValue(characteristic, true);
///     token.throwIfCancelled(); // Exit early if cancelled
///     await readInitialState(device);
///   },
/// )
/// ```
class CancellationToken {
  bool _isCancelled = false;

  /// Whether cancellation has been requested.
  bool get isCancelled => _isCancelled;

  /// Request cancellation. Idempotent — calling multiple times is safe.
  void cancel() => _isCancelled = true;

  /// Throws [CancelledException] if cancellation has been requested.
  void throwIfCancelled() {
    if (_isCancelled) {
      throw const CancelledException();
    }
  }
}

/// Thrown when an operation is cancelled via [CancellationToken].
class CancelledException implements Exception {
  /// Creates a [CancelledException].
  const CancelledException();

  @override
  String toString() => 'CancelledException: Operation was cancelled.';
}
