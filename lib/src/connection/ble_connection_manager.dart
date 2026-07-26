import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide DisconnectReason;

import '../errors/ble_connection_exception.dart';
import '../infrastructure/cancellation_token.dart';
import '../infrastructure/lifecycle_serializer.dart';
import '../lifecycle/ble_connection_state.dart';
import '../lifecycle/ble_lifecycle_event.dart';
import '../lifecycle/disconnect_reason.dart';
import '../recovery/retry_scheduler.dart';
import 'connection_config.dart';

/// Manages the complete lifecycle of a single BLE connection.
///
/// One manager per device. The manager moves the device from
/// [BleConnectionState.disconnected] to [BleConnectionState.ready]
/// in a predictable, observable, and recoverable way.
///
/// The raw [BluetoothDevice] is always accessible via [device]
/// for direct flutter_blue_plus operations (read, write, notify).
///
/// ## Quick Start
///
/// ```dart
/// final manager = BleConnectionManager(
///   device: myBluetoothDevice,
///   config: ConnectionConfig(
///     onSetup: (device, token) async {
///       await device.setNotifyValue(myCharacteristic, true);
///     },
///   ),
/// );
///
/// // Connect — completes when device is fully ready
/// await manager.connect();
///
/// // Use device directly via flutter_blue_plus
/// final value = await manager.device.readCharacteristic(myCharacteristic);
///
/// // Disconnect
/// await manager.disconnect();
///
/// // Clean up
/// await manager.dispose();
/// ```
///
/// ## Core Invariants
///
/// 1. Lifecycle operations ([connect]/[disconnect]) never execute concurrently.
/// 2. A device cannot become [BleConnectionState.ready] unless setup succeeds.
/// 3. Every lifecycle transition emits an observable [BleLifecycleEvent].
/// 4. The raw [BluetoothDevice] is never wrapped.
class BleConnectionManager {
  /// The managed BLE device.
  ///
  /// Always accessible for direct flutter_blue_plus operations.
  /// The manager does not wrap or intercept device operations.
  final BluetoothDevice device;

  /// The configuration for this manager.
  final ConnectionConfig _config;

  /// Serializes lifecycle operations (race condition prevention).
  final LifecycleSerializer _serializer = LifecycleSerializer();

  /// Current state.
  BleConnectionState _state = BleConnectionState.disconnected;

  /// State stream controller.
  final StreamController<BleConnectionState> _stateController =
      StreamController<BleConnectionState>.broadcast(sync: true);

  /// Lifecycle event stream controller.
  final StreamController<BleLifecycleEvent> _eventController =
      StreamController<BleLifecycleEvent>.broadcast(sync: true);

  /// Subscription to flutter_blue_plus connection state changes.
  StreamSubscription<BluetoothConnectionState>? _connectionStateSub;

  /// Active cancellation token for the current connect operation.
  CancellationToken? _activeCancellationToken;

  /// Active retry scheduler for the current connect/reconnect operation.
  RetryScheduler? _activeRetryScheduler;

  /// Whether this manager has been disposed.
  bool _disposed = false;

  /// Creates a [BleConnectionManager] for the given [device].
  ///
  /// The [config] provides connection timeouts, setup callback,
  /// and recovery policy. All fields have sensible defaults.
  BleConnectionManager({
    required this.device,
    ConnectionConfig config = const ConnectionConfig(),
  }) : _config = config {
    _listenToConnectionState();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// The current connection state (synchronous).
  BleConnectionState get state => _state;

  /// Stream of connection state changes.
  ///
  /// Emits whenever the state transitions. The stream is broadcast —
  /// multiple listeners are supported.
  Stream<BleConnectionState> get stateStream {
    final controller = StreamController<BleConnectionState>(sync: true);
    controller.add(_state);
    final sub = _stateController.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = sub.cancel;
    return controller.stream;
  }

  /// Stream of granular lifecycle events.
  ///
  /// Use this for logging, analytics, debugging, and observing
  /// internal milestones (service discovery, retry scheduling, etc.).
  Stream<BleLifecycleEvent> get events => _eventController.stream;

  /// Whether the device is currently in the [BleConnectionState.ready] state.
  bool get isReady => _state == BleConnectionState.ready;

  /// Connect to the device.
  ///
  /// Returns when the device is fully ready (BLE connected + services
  /// discovered + setup complete).
  ///
  /// **Behavior:**
  /// - If already [BleConnectionState.connecting], returns the existing
  ///   Future (deduplication — no duplicate BLE commands).
  /// - If already [BleConnectionState.ready], returns immediately.
  /// - If [BleConnectionState.disconnecting], waits for disconnection
  ///   to complete, then connects.
  ///
  /// Throws [BleConnectionException] if all connection attempts fail.
  /// Throws [ManagerDisposedError] if called after [dispose].
  Future<void> connect() {
    _throwIfDisposed();

    if (_state == BleConnectionState.ready) {
      return Future.value();
    }

    return _serializer.runDeduped('connect', () => _executeConnect());
  }

  /// Disconnect from the device.
  ///
  /// Cancels any in-progress connection attempts, reconnection timers,
  /// and setup callbacks.
  ///
  /// If already [BleConnectionState.disconnected], returns immediately.
  /// Throws [ManagerDisposedError] if called after [dispose].
  Future<void> disconnect() {
    _throwIfDisposed();

    if (_state == BleConnectionState.disconnected) {
      return Future.value();
    }

    // CRITICAL: Cancel active operations immediately to break deadlocks (reentrancy)
    // If disconnect is called from inside an onSetup callback, waiting for the
    // serializer would cause a deadlock. By cancelling first, the active operation
    // fails and releases the serializer lock.
    _activeCancellationToken?.cancel();
    _activeRetryScheduler?.cancel();

    return _serializer.runDeduped('disconnect',
        () => _executeDisconnect(BleDisconnectReason.userInitiated));
  }

  /// Release all resources.
  ///
  /// Disconnects if currently connected, cancels all timers,
  /// and closes all streams. The manager is unusable after disposal.
  ///
  /// Must be called when the manager is no longer needed to prevent
  /// memory leaks and dangling BLE connections.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    // Cancel any active operations
    _activeCancellationToken?.cancel();
    _activeRetryScheduler?.cancel();

    // Disconnect if connected
    if (_state == BleConnectionState.ready ||
        _state == BleConnectionState.connecting) {
      try {
        await _executeDisconnect(BleDisconnectReason.disposed);
      } catch (_) {
        // Best effort during disposal
      }
    }

    // Clean up subscriptions and streams
    await _connectionStateSub?.cancel();
    _connectionStateSub = null;

    await _stateController.close();
    await _eventController.close();
  }

  // ---------------------------------------------------------------------------
  // Internal — Connection Flow
  // ---------------------------------------------------------------------------

  /// The core connection sequence:
  /// BLE connect → discover services → run setup → ready
  Future<void> _executeConnect() async {
    _setState(BleConnectionState.connecting);

    final retryScheduler = RetryScheduler(policy: _config.recoveryPolicy);
    _activeRetryScheduler = retryScheduler;

    final cancellationToken = CancellationToken();
    _activeCancellationToken = cancellationToken;

    try {
      await retryScheduler.execute(
        action: (attemptNumber) =>
            _singleConnectionAttempt(cancellationToken, attemptNumber),
        onRetryScheduled: (attemptNumber, delay) {
          _emitEvent(RetryScheduled(
            attemptNumber: attemptNumber,
            delay: delay,
          ));
        },
        onAttemptFailed: (error, attemptNumber, willRetry) {
          _emitEvent(ConnectionFailed(
            error: error,
            attemptNumber: attemptNumber,
            willRetry: willRetry,
          ));
        },
      );

      // Success — transition to ready
      _setState(BleConnectionState.ready);
      _emitEvent(ConnectionReady());
    } catch (e) {
      // All attempts exhausted — transition to disconnected
      _setState(BleConnectionState.disconnected);

      if (e is BleConnectionException) rethrow;
      throw TransportFailure(message: e.toString(), cause: e);
    } finally {
      _activeRetryScheduler = null;
      _activeCancellationToken = null;
    }
  }

  /// A single connection attempt: connect → discover → setup.
  ///
  /// Throws on any failure. The caller (RetryScheduler) decides
  /// whether to retry.
  Future<void> _singleConnectionAttempt(
      CancellationToken token, int attemptNumber) async {
    _emitEvent(ConnectionAttemptStarted(attemptNumber: attemptNumber));

    token.throwIfCancelled();

    // Step 1: BLE connect
    try {
      await device
          .connect(
            timeout: _config.connectionTimeout,
            autoConnect: false,
          )
          .timeout(_config.connectionTimeout);
    } catch (e) {
      if (e is CancelledException) rethrow;
      // Clean up partial connection before retry
      try {
        await device.disconnect();
      } catch (_) {}
      throw TransportFailure(
        message: 'BLE connection failed: $e',
        cause: e,
      );
    }

    token.throwIfCancelled();
    _emitEvent(ConnectionEstablished());

    // Step 2: Discover services
    if (_config.autoDiscoverServices) {
      _emitEvent(ServiceDiscoveryStarted());
      try {
        await device.discoverServices().timeout(
              _config.connectionTimeout,
            );
      } catch (e) {
        if (e is CancelledException) rethrow;
        try {
          await device.disconnect();
        } catch (_) {}
        if (e is TimeoutException) {
          throw const TimeoutFailure(
            message: 'Service discovery timed out',
            phase: ConnectionPhase.serviceDiscovery,
          );
        }
        throw TransportFailure(
          message: 'Service discovery failed: $e',
          cause: e,
        );
      }
      token.throwIfCancelled();
      _emitEvent(ServiceDiscoveryCompleted());
    }

    // Step 3: Run setup
    if (_config.onSetup != null) {
      _emitEvent(SetupStarted());
      try {
        await _config.onSetup!(device, token).timeout(_config.setupTimeout);
      } catch (e) {
        if (e is CancelledException) rethrow;
        try {
          await device.disconnect();
        } catch (_) {}
        if (e is TimeoutException) {
          throw const TimeoutFailure(
            message: 'Setup timed out',
            phase: ConnectionPhase.setup,
          );
        }
        throw SetupFailure(
          message: 'Setup callback failed: $e',
          cause: e,
        );
      }
      token.throwIfCancelled();
      _emitEvent(SetupCompleted());
    }
  }

  // ---------------------------------------------------------------------------
  // Internal — Disconnection Flow
  // ---------------------------------------------------------------------------

  Future<void> _executeDisconnect(BleDisconnectReason reason) async {
    // Cancel any in-progress connection/setup
    _activeCancellationToken?.cancel();
    _activeRetryScheduler?.cancel();

    final isUserInitiated = reason == BleDisconnectReason.userInitiated;
    _setState(BleConnectionState.disconnecting);
    _emitEvent(DisconnectionInitiated(userInitiated: isUserInitiated));

    try {
      await device.disconnect();
    } catch (_) {
      // Best effort — the device may already be disconnected
    }

    _setState(BleConnectionState.disconnected);
    _emitEvent(Disconnected(reason: reason));
  }

  // ---------------------------------------------------------------------------
  // Internal — Connection State Monitoring
  // ---------------------------------------------------------------------------

  /// Listen to flutter_blue_plus connection state for unexpected disconnections.
  void _listenToConnectionState() {
    _connectionStateSub = device.connectionState.listen((fbpState) {
      if (fbpState == BluetoothConnectionState.disconnected &&
          _state == BleConnectionState.ready) {
        _handleUnexpectedDisconnection();
      }
    });
  }

  /// Handle unexpected disconnection while in Ready state.
  void _handleUnexpectedDisconnection() {
    _setState(BleConnectionState.disconnected);
    _emitEvent(Disconnected(reason: BleDisconnectReason.unexpected));

    if (_config.autoReconnect && !_disposed) {
      _emitEvent(ReconnectionStarted());
      // Trigger reconnection through the serializer
      _serializer
          .runDeduped('connect', () => _executeConnect())
          .catchError((_) {
        // Reconnection failed — already in disconnected state
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Internal — State & Event Management
  // ---------------------------------------------------------------------------

  void _setState(BleConnectionState newState) {
    if (_state == newState) return;
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  void _emitEvent(BleLifecycleEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw const ManagerDisposedError();
    }
  }
}
