/// The reason a BLE connection ended.
enum BleDisconnectReason {
  /// The app explicitly called [BleConnectionManager.disconnect].
  userInitiated,

  /// The OS or device terminated the connection unexpectedly.
  unexpected,

  /// The manager was disposed while connected.
  disposed,
}
