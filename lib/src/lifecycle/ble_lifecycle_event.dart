import 'disconnect_reason.dart';

/// Base class for all lifecycle events emitted by [BleConnectionManager].
///
/// Every event includes a [timestamp] recording when it occurred.
///
/// Use Dart 3 exhaustive switch to handle all event types:
///
/// ```dart
/// manager.events.listen((event) {
///   switch (event) {
///     case ConnectionAttemptStarted(:final attemptNumber):
///       log('Attempt $attemptNumber started');
///     case ConnectionEstablished():
///       log('BLE connected');
///     case ServiceDiscoveryStarted():
///       log('Discovering services...');
///     case ServiceDiscoveryCompleted():
///       log('Services discovered');
///     case SetupStarted():
///       log('Running setup...');
///     case SetupCompleted():
///       log('Setup done');
///     case ConnectionReady():
///       log('Device ready!');
///     case DisconnectionInitiated(:final userInitiated):
///       log('Disconnecting (user: $userInitiated)');
///     case Disconnected(:final reason):
///       log('Disconnected: $reason');
///     case RetryScheduled(:final attemptNumber, :final delay):
///       log('Retry #$attemptNumber in $delay');
///     case ReconnectionStarted():
///       log('Reconnecting...');
///     case ConnectionFailed(:final error, :final willRetry):
///       log('Failed: $error, retry: $willRetry');
///   }
/// });
/// ```
sealed class BleLifecycleEvent {
  /// When this event occurred.
  final DateTime timestamp;

  /// Creates a [BleLifecycleEvent] with the current time.
  BleLifecycleEvent() : timestamp = DateTime.now();
}

// ---------------------------------------------------------------------------
// Connection Flow
// ---------------------------------------------------------------------------

/// A connection attempt has started.
class ConnectionAttemptStarted extends BleLifecycleEvent {
  /// The 1-based attempt number.
  final int attemptNumber;

  /// Creates a [ConnectionAttemptStarted] event.
  ConnectionAttemptStarted({required this.attemptNumber});
}

/// BLE transport connection established (GATT connected).
///
/// This is an internal milestone — the device is not yet ready
/// for application use. Service discovery and setup still need to run.
class ConnectionEstablished extends BleLifecycleEvent {
  /// Creates a [ConnectionEstablished] event.
  ConnectionEstablished();
}

/// Service discovery has started.
class ServiceDiscoveryStarted extends BleLifecycleEvent {
  /// Creates a [ServiceDiscoveryStarted] event.
  ServiceDiscoveryStarted();
}

/// Service discovery completed successfully.
class ServiceDiscoveryCompleted extends BleLifecycleEvent {
  /// Creates a [ServiceDiscoveryCompleted] event.
  ServiceDiscoveryCompleted();
}

/// The setup callback has started executing.
class SetupStarted extends BleLifecycleEvent {
  /// Creates a [SetupStarted] event.
  SetupStarted();
}

/// The setup callback completed successfully.
class SetupCompleted extends BleLifecycleEvent {
  /// Creates a [SetupCompleted] event.
  SetupCompleted();
}

/// The device is fully ready for application use.
///
/// This event is emitted after BLE connection, service discovery,
/// and setup have all completed successfully.
class ConnectionReady extends BleLifecycleEvent {
  /// Creates a [ConnectionReady] event.
  ConnectionReady();
}

// ---------------------------------------------------------------------------
// Disconnection Flow
// ---------------------------------------------------------------------------

/// Disconnection process has been initiated.
class DisconnectionInitiated extends BleLifecycleEvent {
  /// Whether the user explicitly requested disconnection.
  final bool userInitiated;

  /// Creates a [DisconnectionInitiated] event.
  DisconnectionInitiated({required this.userInitiated});
}

/// The device is now disconnected.
class Disconnected extends BleLifecycleEvent {
  /// Why the disconnection occurred.
  final BleDisconnectReason reason;

  /// Creates a [Disconnected] event.
  Disconnected({required this.reason});
}

// ---------------------------------------------------------------------------
// Recovery Flow
// ---------------------------------------------------------------------------

/// A retry has been scheduled after a failed attempt.
class RetryScheduled extends BleLifecycleEvent {
  /// The upcoming attempt number (1-based).
  final int attemptNumber;

  /// The delay before the retry begins.
  final Duration delay;

  /// Creates a [RetryScheduled] event.
  RetryScheduled({required this.attemptNumber, required this.delay});
}

/// Automatic reconnection has started after unexpected disconnection.
class ReconnectionStarted extends BleLifecycleEvent {
  /// Creates a [ReconnectionStarted] event.
  ReconnectionStarted();
}

/// A connection attempt failed.
class ConnectionFailed extends BleLifecycleEvent {
  /// The error that caused the failure.
  final Object error;

  /// Which attempt number failed (1-based).
  final int attemptNumber;

  /// Whether the manager will retry this connection.
  final bool willRetry;

  /// Creates a [ConnectionFailed] event.
  ConnectionFailed({
    required this.error,
    required this.attemptNumber,
    required this.willRetry,
  });
}
