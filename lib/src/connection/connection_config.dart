import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide DisconnectReason;

import '../infrastructure/cancellation_token.dart';
import '../recovery/recovery_policy.dart';

/// Signature for the setup callback executed after BLE connection
/// and service discovery.
///
/// The [device] is the connected [BluetoothDevice] with services discovered.
/// The [token] allows cooperative cancellation if the manager needs
/// to abort setup (e.g., user called disconnect).
///
/// Throw an exception to indicate setup failure, which triggers
/// the [RecoveryPolicy].
typedef SetupCallback = Future<void> Function(
  BluetoothDevice device,
  CancellationToken token,
);

/// Configuration for [BleConnectionManager].
///
/// All fields have sensible defaults suitable for most production apps.
///
/// ```dart
/// const config = ConnectionConfig(
///   connectionTimeout: Duration(seconds: 15),
///   onSetup: mySetupFunction,
/// );
/// ```
class ConnectionConfig {
  /// Maximum time to wait for BLE connection establishment.
  ///
  /// Default: 15 seconds. This is passed to flutter_blue_plus's
  /// `device.connect(timeout: ...)`.
  final Duration connectionTimeout;

  /// Maximum time to wait for the [onSetup] callback to complete.
  ///
  /// Default: 30 seconds. If setup takes longer, a [TimeoutFailure]
  /// is thrown and the recovery policy is triggered.
  final Duration setupTimeout;

  /// Whether to call `discoverServices()` automatically after connection.
  ///
  /// Default: true. Set to false only if you need manual control over
  /// service discovery timing.
  final bool autoDiscoverServices;

  /// Whether to automatically reconnect after unexpected disconnection.
  ///
  /// Default: true. When true, the manager will use the [recoveryPolicy]
  /// to attempt reconnection. When false, unexpected disconnections
  /// transition directly to [BleConnectionState.disconnected].
  final bool autoReconnect;

  /// Policy governing retry and reconnect behavior.
  ///
  /// Default: [RecoveryPolicy.exponentialBackoff] (5 attempts, 1s initial,
  /// 2x multiplier, 30s cap).
  final RecoveryPolicy recoveryPolicy;

  /// Optional callback executed after connection and service discovery.
  ///
  /// Use this to perform device-specific initialization:
  /// - Enable notifications on characteristics
  /// - Read initial configuration
  /// - Perform authentication handshakes
  /// - Validate firmware version
  ///
  /// If this callback throws, the error is treated as a connection failure
  /// and the [recoveryPolicy] determines whether to retry.
  final SetupCallback? onSetup;

  /// Creates a [ConnectionConfig] with sensible defaults.
  const ConnectionConfig({
    this.connectionTimeout = const Duration(seconds: 15),
    this.setupTimeout = const Duration(seconds: 30),
    this.autoDiscoverServices = true,
    this.autoReconnect = true,
    this.recoveryPolicy = const RecoveryPolicy.exponentialBackoff(),
    this.onSetup,
  });
}
