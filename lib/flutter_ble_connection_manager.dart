/// A production-grade BLE connection lifecycle manager.
///
/// This package manages the complete lifecycle of a single BLE connection —
/// from initial connection through readiness, including retry, recovery,
/// and graceful teardown — built on top of flutter_blue_plus.
///
/// ## Core Responsibility
///
/// Move a BLE device from Disconnected to Application Ready in a
/// predictable, observable and recoverable way.
///
/// Everything else belongs to the application or flutter_blue_plus.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:flutter_ble_connection_manager/flutter_ble_connection_manager.dart';
///
/// final manager = BleConnectionManager(
///   device: myDevice,
///   config: ConnectionConfig(
///     onSetup: (device, token) async {
///       await device.setNotifyValue(characteristic, true);
///     },
///   ),
/// );
///
/// await manager.connect(); // Completes when ready
/// // Use device directly: manager.device.readCharacteristic(...)
/// await manager.disconnect();
/// await manager.dispose();
/// ```
library;

export 'src/connection/ble_connection_manager.dart';
export 'src/connection/connection_config.dart';
export 'src/lifecycle/ble_connection_state.dart';
export 'src/lifecycle/ble_lifecycle_event.dart';
export 'src/lifecycle/disconnect_reason.dart';
export 'src/recovery/recovery_policy.dart';
export 'src/infrastructure/cancellation_token.dart';
export 'src/errors/ble_connection_exception.dart';
