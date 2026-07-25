// ignore_for_file: unused_local_variable, avoid_print

/// Production example: Full lifecycle with setup, state UI, error handling,
/// and lifecycle event logging.
///
/// This reflects how the package is actually used in a real Flutter app.
library;

import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_connection_manager/flutter_ble_connection_manager.dart';

// ---------------------------------------------------------------------------
// 1. Define your setup callback
// ---------------------------------------------------------------------------

/// Everything that must succeed BEFORE the device is considered "Ready".
///
/// This is the core contract of the package:
///   connect() does NOT resolve at BLE-connected.
///   connect() resolves at Application Ready.
///
/// The [token] enables cooperative cancellation — if the user taps
/// "Disconnect" while setup is running, the manager cancels the token
/// and setup exits cleanly.
Future<void> deviceSetup(BluetoothDevice device, CancellationToken token) async {
  // Step 1: Services are already discovered (autoDiscoverServices: true).
  final services = device.servicesList;

  // Step 2: Find your service & characteristic.
  final myService = services.firstWhere(
    (s) => s.uuid == Guid('0000180a-0000-1000-8000-00805f9b34fb'),
  );
  final dataChar = myService.characteristics.firstWhere(
    (c) => c.uuid == Guid('00002a29-0000-1000-8000-00805f9b34fb'),
  );

  // Step 3: Enable notifications.
  await dataChar.setNotifyValue(true);

  // Check cancellation between async steps.
  token.throwIfCancelled();

  // Step 4: Read initial device state.
  final initialValue = await dataChar.read();
  print('Initial value: $initialValue');

  // If any step above throws, the manager treats it as a SetupFailure
  // and the RecoveryPolicy decides whether to retry.
}

// ---------------------------------------------------------------------------
// 2. Create the manager with a full ConnectionConfig
// ---------------------------------------------------------------------------

BleConnectionManager createManager(BluetoothDevice device) {
  return BleConnectionManager(
    device: device,
    config: ConnectionConfig(
      // BLE connect timeout
      connectionTimeout: const Duration(seconds: 15),

      // Setup callback timeout (separate from connection timeout)
      setupTimeout: const Duration(seconds: 30),

      // Auto-discover services after BLE connect (default: true)
      autoDiscoverServices: true,

      // Auto-reconnect on unexpected disconnection (default: true)
      autoReconnect: true,

      // Recovery strategy: exponential backoff, 3 attempts, 2s→4s→8s
      recoveryPolicy: const RecoveryPolicy.exponentialBackoff(
        maxAttempts: 3,
        initialDelay: Duration(seconds: 2),
        backoffMultiplier: 2.0,
        maxDelay: Duration(seconds: 30),
      ),

      // The setup callback — defines what "Ready" means for your app
      onSetup: deviceSetup,
    ),
  );
}

// ---------------------------------------------------------------------------
// 3. Drive the UI from state stream
// ---------------------------------------------------------------------------

/// In a real app, this would be inside a StatefulWidget or a Provider.
void listenToState(BleConnectionManager manager) {
  manager.stateStream.listen((state) {
    switch (state) {
      case BleConnectionState.disconnected:
        print('UI → Show "Connect" button');
      case BleConnectionState.connecting:
        print('UI → Show loading spinner');
      case BleConnectionState.ready:
        print('UI → Show device controls');
      case BleConnectionState.disconnecting:
        print('UI → Show "Disconnecting..." indicator');
    }
  });
}

// ---------------------------------------------------------------------------
// 4. Observe lifecycle events (logging, analytics, debugging)
// ---------------------------------------------------------------------------

/// Lifecycle events give you fine-grained visibility into what the manager
/// is doing internally, without coupling your UI to implementation details.
void listenToEvents(BleConnectionManager manager) {
  manager.events.listen((event) {
    switch (event) {
      case ConnectionAttemptStarted(:final attemptNumber):
        print('→ Connection attempt #$attemptNumber started');
      case ConnectionEstablished():
        print('→ BLE transport connected');
      case ServiceDiscoveryStarted():
        print('→ Discovering services...');
      case ServiceDiscoveryCompleted():
        print('→ Services discovered');
      case SetupStarted():
        print('→ Running setup callback...');
      case SetupCompleted():
        print('→ Setup complete');
      case ConnectionReady():
        print('→ Device is Application Ready');
      case DisconnectionInitiated(:final userInitiated):
        print('→ Disconnecting (user-initiated: $userInitiated)');
      case Disconnected(:final reason):
        print('→ Disconnected: $reason');
      case RetryScheduled(:final attemptNumber, :final delay):
        print('→ Retry #$attemptNumber scheduled in ${delay.inSeconds}s');
      case ReconnectionStarted():
        print('→ Auto-reconnecting after unexpected disconnection');
      case ConnectionFailed(:final error, :final willRetry):
        print('→ Attempt failed: $error (will retry: $willRetry)');
    }
  });
}

// ---------------------------------------------------------------------------
// 5. Handle errors with structured exceptions
// ---------------------------------------------------------------------------

/// The package normalizes all native BLE errors (Android GATT, iOS CBError)
/// into a small set of typed exceptions. Use exhaustive switch to handle them.
Future<void> connectWithErrorHandling(BleConnectionManager manager) async {
  try {
    await manager.connect();
    print('Device is ready!');
  } on BleConnectionException catch (e) {
    switch (e) {
      case TransportFailure(:final cause):
        // Native BLE error (GATT 133, CBError, etc.)
        // Usually transient — the RecoveryPolicy already retried.
        print('BLE transport error: $cause');

      case SetupFailure(:final cause):
        // Your onSetup callback threw.
        // Check your setup logic.
        print('Setup failed: $cause');

      case TimeoutFailure(:final phase):
        // A phase exceeded its timeout.
        // phase is: connection, serviceDiscovery, or setup.
        print('Timeout during: $phase');

      case CancellationFailure():
        // User called disconnect() while connecting.
        // This is expected — not an error.
        print('Connection cancelled by user');

      case ConfigurationError(:final message):
        // Invalid config. Fix before shipping.
        print('Config error: $message');

      case ManagerDisposedError():
        // Called connect() after dispose(). Bug in your code.
        print('Manager already disposed');
    }
  }
}

// ---------------------------------------------------------------------------
// 6. Recovery policies
// ---------------------------------------------------------------------------

/// Different strategies for different use cases.
void recoveryPolicyExamples() {
  // No retry — fail immediately. Good for one-shot pairing flows.
  const noRetry = RecoveryPolicy.noRetry();

  // Fixed 2-second delay between retries.
  const simple = RecoveryPolicy.simple(
    maxAttempts: 3,
    delay: Duration(seconds: 2),
  );

  // Exponential backoff (default). Best for production.
  // Attempts at approximately: 1s, 2s, 4s, 8s, 16s
  const backoff = RecoveryPolicy.exponentialBackoff(
    maxAttempts: 5,
    initialDelay: Duration(seconds: 1),
    backoffMultiplier: 2.0,
    maxDelay: Duration(seconds: 30),
  );
}

// ---------------------------------------------------------------------------
// 7. Putting it all together
// ---------------------------------------------------------------------------

Future<void> main() async {
  // In a real app, you'd get this from flutter_blue_plus scanning.
  // The example uses a placeholder — replace with your actual device.
  final device = BluetoothDevice.fromId('00:11:22:33:44:55');

  final manager = createManager(device);

  // Subscribe to state and events
  listenToState(manager);
  listenToEvents(manager);

  // Connect with full error handling
  await connectWithErrorHandling(manager);

  // When done, always dispose
  await manager.dispose();
}
