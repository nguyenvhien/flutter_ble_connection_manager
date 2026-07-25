/// The phase of the connection lifecycle where a failure occurred.
enum ConnectionPhase {
  /// BLE transport connection.
  connection,

  /// Service discovery.
  serviceDiscovery,

  /// User-provided setup callback.
  setup,
}

/// Base exception for all connection manager errors.
///
/// Use Dart 3 exhaustive switch to handle all failure types:
///
/// ```dart
/// try {
///   await manager.connect();
/// } on BleConnectionException catch (e) {
///   switch (e) {
///     case TransportFailure(:final cause):
///       log('BLE error: $cause');
///     case SetupFailure(:final cause):
///       log('Setup failed: $cause');
///     case TimeoutFailure(:final phase):
///       log('Timeout during: $phase');
///     case CancellationFailure():
///       log('User cancelled');
///     case ConfigurationError(:final message):
///       log('Bad config: $message');
///     case ManagerDisposedError():
///       log('Manager was disposed');
///   }
/// }
/// ```
sealed class BleConnectionException implements Exception {
  /// Human-readable description.
  final String message;

  /// The original error that caused this failure, if any.
  final Object? cause;

  /// Creates a [BleConnectionException].
  const BleConnectionException({required this.message, this.cause});

  @override
  String toString() => '$runtimeType: $message';
}

/// Platform-level BLE transport error (e.g., Android GATT error 133).
///
/// Usually retryable. The [cause] contains the original platform error.
class TransportFailure extends BleConnectionException {
  /// Creates a [TransportFailure].
  const TransportFailure({required super.message, super.cause});
}

/// The app's setup callback threw an exception.
///
/// Whether this is retryable depends on the app's [RecoveryPolicy.shouldRetry].
class SetupFailure extends BleConnectionException {
  /// Creates a [SetupFailure].
  const SetupFailure({required super.message, super.cause});
}

/// A lifecycle phase exceeded its timeout duration.
class TimeoutFailure extends BleConnectionException {
  /// Which phase timed out.
  final ConnectionPhase phase;

  /// Creates a [TimeoutFailure].
  const TimeoutFailure({required super.message, required this.phase})
      : super(cause: null);
}

/// The operation was cancelled by a user-initiated disconnect.
///
/// Never retryable.
class CancellationFailure extends BleConnectionException {
  /// Creates a [CancellationFailure].
  const CancellationFailure()
      : super(message: 'Operation cancelled by disconnect request.');
}

/// Invalid configuration parameters.
///
/// Never retryable. Fix the configuration.
class ConfigurationError extends BleConnectionException {
  /// Creates a [ConfigurationError].
  const ConfigurationError({required super.message}) : super(cause: null);
}

/// Method called after [BleConnectionManager.dispose].
///
/// Never retryable. The manager cannot be reused after disposal.
class ManagerDisposedError extends BleConnectionException {
  /// Creates a [ManagerDisposedError].
  const ManagerDisposedError()
      : super(message: 'BleConnectionManager has been disposed.');
}
