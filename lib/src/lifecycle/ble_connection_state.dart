/// The public lifecycle state of a BLE connection.
///
/// This represents the simplified, application-visible state.
/// Internal sub-states (e.g., discovering services, running setup)
/// are communicated via [BleLifecycleEvent] instead.
///
/// ```dart
/// manager.stateStream.listen((state) {
///   switch (state) {
///     case BleConnectionState.disconnected:
///       // Show disconnected UI
///     case BleConnectionState.connecting:
///       // Show spinner
///     case BleConnectionState.ready:
///       // Show device controls
///     case BleConnectionState.disconnecting:
///       // Show disconnecting indicator
///   }
/// });
/// ```
enum BleConnectionState {
  /// Not connected. Initial state and terminal state.
  disconnected,

  /// Connection in progress. Includes BLE connect, service discovery,
  /// and setup execution.
  connecting,

  /// Fully connected, services discovered, setup complete.
  /// The device is usable for GATT operations.
  ready,

  /// User-initiated disconnection in progress.
  disconnecting,
}
