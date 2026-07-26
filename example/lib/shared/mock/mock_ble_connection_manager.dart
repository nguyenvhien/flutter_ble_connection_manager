import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:flutter_ble_connection_manager/flutter_ble_connection_manager.dart';

class MockBluetoothDevice implements fbp.BluetoothDevice {
  @override
  final fbp.DeviceIdentifier remoteId;

  @override
  final String advName;

  MockBluetoothDevice(this.remoteId, this.advName);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const Map<String, String> mockDescriptions = {
  'Smart Thermostat V2':
      'Happy Path: Connects smoothly without any errors. Best for checking normal states.',
  'Fitness Tracker Pro':
      'Connection Timeout: Simulates a device that fails to respond, throwing a timeout error during connection.',
  'Bluetooth Speaker X1':
      'Setup Failed: Connects successfully but fails during the setup callback (e.g., unsupported firmware).',
  'Heart Rate Monitor':
      'Auto-Reconnect Success: Drops connection after 3s, then successfully reconnects automatically.',
  'Smart Lock Alpha':
      'Auto-Reconnect Failure: Drops connection after 3s, fails to reconnect after 3 attempts, and gives up.',
};

/// A mock implementation of [BleConnectionManager] for UI testing on Emulators.
class MockBleConnectionManager implements BleConnectionManager {
  @override
  final fbp.BluetoothDevice device;

  final StreamController<BleConnectionState> _stateCtrl =
      StreamController<BleConnectionState>.broadcast(sync: true);
  final StreamController<BleLifecycleEvent> _eventCtrl =
      StreamController<BleLifecycleEvent>.broadcast(sync: true);

  BleConnectionState _state = BleConnectionState.disconnected;
  bool _disposed = false;

  MockBleConnectionManager({required this.device}) {
    _stateCtrl.stream.listen((s) => _state = s);
    _stateCtrl.add(BleConnectionState.disconnected);
  }

  @override
  Stream<BleConnectionState> get stateStream {
    final controller = StreamController<BleConnectionState>(sync: true);
    controller.add(_state);
    final sub = _stateCtrl.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = sub.cancel;
    return controller.stream;
  }

  @override
  BleConnectionState get state => _state;

  @override
  Stream<BleLifecycleEvent> get events => _eventCtrl.stream;

  @override
  bool get isReady => _state == BleConnectionState.ready;

  @override
  Future<void> connect() async {
    if (_state != BleConnectionState.disconnected) return;

    _stateCtrl.add(BleConnectionState.connecting);
    _eventCtrl.add(ConnectionAttemptStarted(attemptNumber: 1));
    await Future.delayed(const Duration(seconds: 1));
    if (_disposed) return;

    if (device.advName == 'Fitness Tracker Pro') {
      // Timeout Case
      _eventCtrl.add(
        ConnectionFailed(
          error: Exception('Connection timed out'),
          attemptNumber: 1,
          willRetry: false,
        ),
      );
      _stateCtrl.add(BleConnectionState.disconnected);
      return;
    }

    _eventCtrl.add(ConnectionEstablished());
    await Future.delayed(const Duration(milliseconds: 500));
    if (_disposed) return;

    _eventCtrl.add(ServiceDiscoveryStarted());
    await Future.delayed(const Duration(milliseconds: 500));
    if (_disposed) return;

    _eventCtrl.add(ServiceDiscoveryCompleted());
    _eventCtrl.add(SetupStarted());
    await Future.delayed(const Duration(milliseconds: 500));
    if (_disposed) return;

    if (device.advName == 'Bluetooth Speaker X1') {
      // Setup Failed Case
      _eventCtrl.add(
        ConnectionFailed(
          error: Exception('Setup failed: Unsupported firmware version'),
          attemptNumber: 1,
          willRetry: false,
        ),
      );
      _stateCtrl.add(BleConnectionState.disconnected);
      return;
    }

    _eventCtrl.add(SetupCompleted());
    _eventCtrl.add(ConnectionReady());
    _stateCtrl.add(BleConnectionState.ready);

    // Auto-Reconnect Success Case
    if (device.advName == 'Heart Rate Monitor') {
      Future.delayed(const Duration(seconds: 3), () async {
        if (_state == BleConnectionState.ready && !_disposed) {
          _eventCtrl.add(Disconnected(reason: BleDisconnectReason.unexpected));
          _stateCtrl.add(BleConnectionState.disconnected);

          await Future.delayed(const Duration(seconds: 1));
          if (_disposed) return;
          _eventCtrl.add(ReconnectionStarted());
          _stateCtrl.add(BleConnectionState.connecting);
          _eventCtrl.add(ConnectionAttemptStarted(attemptNumber: 1));

          await Future.delayed(const Duration(seconds: 2));
          if (_disposed) return;
          _eventCtrl.add(ConnectionEstablished());
          _eventCtrl.add(ServiceDiscoveryStarted());
          _eventCtrl.add(ServiceDiscoveryCompleted());
          _eventCtrl.add(SetupStarted());
          _eventCtrl.add(SetupCompleted());
          _eventCtrl.add(ConnectionReady());
          _stateCtrl.add(BleConnectionState.ready);
        }
      });
    }

    // Auto-Reconnect Failure Case
    if (device.advName == 'Smart Lock Alpha') {
      Future.delayed(const Duration(seconds: 3), () async {
        if (_state == BleConnectionState.ready && !_disposed) {
          _eventCtrl.add(Disconnected(reason: BleDisconnectReason.unexpected));
          _stateCtrl.add(BleConnectionState.disconnected);

          await Future.delayed(const Duration(seconds: 1));
          if (_disposed) return;

          _eventCtrl.add(ReconnectionStarted());
          _stateCtrl.add(BleConnectionState.connecting);

          for (int attempt = 1; attempt <= 3; attempt++) {
            _eventCtrl.add(ConnectionAttemptStarted(attemptNumber: attempt));

            await Future.delayed(const Duration(seconds: 1));
            if (_disposed) return;

            _eventCtrl.add(
              ConnectionFailed(
                error: Exception('Device not found (out of range)'),
                attemptNumber: attempt,
                willRetry: attempt < 3,
              ),
            );

            if (attempt < 3) {
              _eventCtrl.add(
                RetryScheduled(
                  attemptNumber: attempt + 1,
                  delay: const Duration(seconds: 2),
                ),
              );
              await Future.delayed(const Duration(seconds: 2));
              if (_disposed) return;
            }
          }
          // Final disconnection state
          _stateCtrl.add(BleConnectionState.disconnected);
        }
      });
    }
  }

  @override
  Future<void> disconnect() async {
    _stateCtrl.add(BleConnectionState.disconnecting);
    _eventCtrl.add(DisconnectionInitiated(userInitiated: true));
    await Future.delayed(const Duration(milliseconds: 500));
    _eventCtrl.add(Disconnected(reason: BleDisconnectReason.userInitiated));
    _stateCtrl.add(BleConnectionState.disconnected);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _stateCtrl.close();
    await _eventCtrl.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
