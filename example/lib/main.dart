import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ble_connection_manager/flutter_ble_connection_manager.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'app.dart';

/// Minimal connection-screen integration.
///
/// The full runnable demo starts from [App] below. This widget demonstrates
/// how to bind [BleConnectionManager] to the UI after obtaining a
/// [BluetoothDevice] from a scanning or discovery flow.
class DeviceConnectionScreen extends StatefulWidget {
  const DeviceConnectionScreen({super.key, required this.device});

  final BluetoothDevice device;

  @override
  State<DeviceConnectionScreen> createState() => _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState extends State<DeviceConnectionScreen> {
  late final BleConnectionManager _manager;

  @override
  void initState() {
    super.initState();

    _manager = BleConnectionManager(
      device: widget.device,
      config: ConnectionConfig(
        // 1. Automatic Recovery
        // Retries transient failures using exponential backoff.
        recoveryPolicy: const RecoveryPolicy.exponentialBackoff(maxAttempts: 3),

        onSetup: (device, token) async {
          // 2. Application Readiness
          // A native connection does not mean the device is ready.
          // The manager emits `ready` only after this callback succeeds.
          await device.discoverServices();

          // 3. Cooperative Cancellation
          // Stops setup from continuing if disconnect() was requested
          // while awaiting the native operation above.
          token.throwIfCancelled();

          // TODO: Find required characteristics, enable notifications,
          // and perform any application-level handshake here.
        },
      ),
    );
  }

  @override
  void dispose() {
    // Releases subscriptions and lifecycle resources owned by the manager.
    unawaited(_manager.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceName = widget.device.platformName.isNotEmpty
        ? widget.device.platformName
        : 'BLE Device';

    return Scaffold(
      appBar: AppBar(title: Text(deviceName)),
      body: Center(
        child: StreamBuilder<BleConnectionState>(
          // 4. Reactive UI Binding
          // UI state comes directly from the manager, so manual connection
          // loading flags are not required.
          stream: _manager.stateStream,
          initialData: _manager.state,
          builder: (context, snapshot) {
            final state = snapshot.data ?? _manager.state;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Status: ${state.name.toUpperCase()}',
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(height: 20),
                _buildConnectionControl(state),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildConnectionControl(BleConnectionState state) {
    switch (state) {
      case BleConnectionState.disconnected:
        return ElevatedButton(
          // 5. Concurrency Coordination
          // Concurrent connect() calls are safely handled by the manager.
          onPressed: () => _manager.connect(),
          child: const Text('Connect'),
        );

      case BleConnectionState.connecting:
      case BleConnectionState.disconnecting:
        return const CircularProgressIndicator();

      case BleConnectionState.ready:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 20),
            ElevatedButton(
              // Gracefully disconnects and releases the active BLE connection.
              onPressed: () => _manager.disconnect(),
              child: const Text('Disconnect'),
            ),
          ],
        );
    }
  }
}

// -----------------------------------------------------------------------------
// Full runnable example application
// -----------------------------------------------------------------------------

void main() {
  // Launches the full interactive example application.
  //
  // See:
  // - lib/app.dart
  // - lib/features/home/home_page.dart
  runApp(const App());
}
