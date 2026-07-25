import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide DisconnectReason;
import 'package:mocktail/mocktail.dart';
import 'package:flutter_ble_connection_manager/flutter_ble_connection_manager.dart';

class MockBluetoothDevice extends Mock implements BluetoothDevice {}

void main() {
  late MockBluetoothDevice mockDevice;
  late StreamController<BluetoothConnectionState> connStateCtrl;

  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    mockDevice = MockBluetoothDevice();
    connStateCtrl =
        StreamController<BluetoothConnectionState>.broadcast();

    when(() => mockDevice.connectionState)
        .thenAnswer((_) => connStateCtrl.stream);
    when(() => mockDevice.isConnected).thenReturn(false);
    when(() => mockDevice.remoteId)
        .thenReturn(const DeviceIdentifier('AA:BB:CC:DD:EE:FF'));
  });

  tearDown(() {
    connStateCtrl.close();
  });

  // -------------------------------------------------------------------------
  // Initial State
  // -------------------------------------------------------------------------

  group('initial state', () {
    test('starts in disconnected state', () {
      final manager = BleConnectionManager(
        device: mockDevice,
        config: const ConnectionConfig(
          recoveryPolicy: RecoveryPolicy.noRetry(),
        ),
      );
      expect(manager.state, BleConnectionState.disconnected);
      expect(manager.isReady, false);
      manager.dispose();
    });

    test('exposes the raw device without wrapping', () {
      final manager = BleConnectionManager(
        device: mockDevice,
        config: const ConnectionConfig(
          recoveryPolicy: RecoveryPolicy.noRetry(),
        ),
      );
      expect(manager.device, same(mockDevice));
      manager.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // Connect
  // -------------------------------------------------------------------------

  group('connect', () {
    test('transitions through connecting to ready on success', () async {
      when(() => mockDevice.connect(
            timeout: any(named: 'timeout'),
            autoConnect: false,
          )).thenAnswer((_) async {
        connStateCtrl.add(BluetoothConnectionState.connected);
      });
      when(() => mockDevice.discoverServices())
          .thenAnswer((_) async => <BluetoothService>[]);

      final manager = BleConnectionManager(
        device: mockDevice,
        config: const ConnectionConfig(
          recoveryPolicy: RecoveryPolicy.noRetry(),
        ),
      );

      final states = <BleConnectionState>[];
      manager.stateStream.listen(states.add);

      await manager.connect();

      expect(manager.state, BleConnectionState.ready);
      expect(manager.isReady, true);
      expect(states, contains(BleConnectionState.connecting));
      expect(states, contains(BleConnectionState.ready));

      await manager.dispose();
    });

    test('returns immediately when already ready', () async {
      when(() => mockDevice.connect(
            timeout: any(named: 'timeout'),
            autoConnect: false,
          )).thenAnswer((_) async {
        connStateCtrl.add(BluetoothConnectionState.connected);
      });
      when(() => mockDevice.discoverServices())
          .thenAnswer((_) async => <BluetoothService>[]);

      final manager = BleConnectionManager(
        device: mockDevice,
        config: const ConnectionConfig(
          recoveryPolicy: RecoveryPolicy.noRetry(),
        ),
      );

      await manager.connect();
      expect(manager.isReady, true);

      // Second connect should return immediately
      await manager.connect();
      expect(manager.isReady, true);

      // device.connect should have been called only once
      verify(() => mockDevice.connect(
            timeout: any(named: 'timeout'),
            autoConnect: false,
          )).called(1);

      await manager.dispose();
    });

    test('deduplicates concurrent connect calls', () async {
      var connectCallCount = 0;
      when(() => mockDevice.connect(
            timeout: any(named: 'timeout'),
            autoConnect: false,
          )).thenAnswer((_) async {
        connectCallCount++;
        await Future.delayed(const Duration(milliseconds: 50));
        connStateCtrl.add(BluetoothConnectionState.connected);
      });
      when(() => mockDevice.discoverServices())
          .thenAnswer((_) async => <BluetoothService>[]);

      final manager = BleConnectionManager(
        device: mockDevice,
        config: const ConnectionConfig(
          recoveryPolicy: RecoveryPolicy.noRetry(),
        ),
      );

      final f1 = manager.connect();
      final f2 = manager.connect();

      await Future.wait([f1, f2]);

      expect(connectCallCount, 1);
      await manager.dispose();
    });

    test('throws ManagerDisposedError after dispose', () async {
      final manager = BleConnectionManager(
        device: mockDevice,
        config: const ConnectionConfig(
          recoveryPolicy: RecoveryPolicy.noRetry(),
        ),
      );

      await manager.dispose();

      await expectLater(
        () => manager.connect(),
        throwsA(isA<ManagerDisposedError>()),
      );
    });

    test('runs onSetup callback and transitions to ready', () async {
      var setupCalled = false;
      when(() => mockDevice.connect(
            timeout: any(named: 'timeout'),
            autoConnect: false,
          )).thenAnswer((_) async {
        connStateCtrl.add(BluetoothConnectionState.connected);
      });
      when(() => mockDevice.discoverServices())
          .thenAnswer((_) async => <BluetoothService>[]);

      final manager = BleConnectionManager(
        device: mockDevice,
        config: ConnectionConfig(
          recoveryPolicy: const RecoveryPolicy.noRetry(),
          onSetup: (device, token) async {
            setupCalled = true;
          },
        ),
      );

      await manager.connect();

      expect(setupCalled, true);
      expect(manager.isReady, true);
      await manager.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // Disconnect
  // -------------------------------------------------------------------------

  group('disconnect', () {
    test('transitions to disconnected from ready', () async {
      when(() => mockDevice.connect(
            timeout: any(named: 'timeout'),
            autoConnect: false,
          )).thenAnswer((_) async {
        connStateCtrl.add(BluetoothConnectionState.connected);
      });
      when(() => mockDevice.discoverServices())
          .thenAnswer((_) async => <BluetoothService>[]);
      when(() => mockDevice.disconnect()).thenAnswer((_) async {
        connStateCtrl.add(BluetoothConnectionState.disconnected);
      });

      final manager = BleConnectionManager(
        device: mockDevice,
        config: const ConnectionConfig(
          recoveryPolicy: RecoveryPolicy.noRetry(),
          autoReconnect: false,
        ),
      );

      await manager.connect();
      expect(manager.state, BleConnectionState.ready);

      await manager.disconnect();
      expect(manager.state, BleConnectionState.disconnected);
      expect(manager.isReady, false);

      await manager.dispose();
    });

    test('returns immediately when already disconnected', () async {
      final manager = BleConnectionManager(
        device: mockDevice,
        config: const ConnectionConfig(
          recoveryPolicy: RecoveryPolicy.noRetry(),
        ),
      );

      // Already disconnected — should return immediately
      await manager.disconnect();
      expect(manager.state, BleConnectionState.disconnected);

      await manager.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // Lifecycle Events
  // -------------------------------------------------------------------------

  group('lifecycle events', () {
    test('emits events in correct order on successful connect', () async {
      when(() => mockDevice.connect(
            timeout: any(named: 'timeout'),
            autoConnect: false,
          )).thenAnswer((_) async {
        connStateCtrl.add(BluetoothConnectionState.connected);
      });
      when(() => mockDevice.discoverServices())
          .thenAnswer((_) async => <BluetoothService>[]);

      final manager = BleConnectionManager(
        device: mockDevice,
        config: const ConnectionConfig(
          recoveryPolicy: RecoveryPolicy.noRetry(),
        ),
      );

      final eventTypes = <Type>[];
      manager.events.listen((e) => eventTypes.add(e.runtimeType));

      await manager.connect();

      expect(eventTypes, [
        ConnectionAttemptStarted,
        ConnectionEstablished,
        ServiceDiscoveryStarted,
        ServiceDiscoveryCompleted,
        ConnectionReady,
      ]);

      await manager.dispose();
    });

    test('emits setup events when onSetup is provided', () async {
      when(() => mockDevice.connect(
            timeout: any(named: 'timeout'),
            autoConnect: false,
          )).thenAnswer((_) async {
        connStateCtrl.add(BluetoothConnectionState.connected);
      });
      when(() => mockDevice.discoverServices())
          .thenAnswer((_) async => <BluetoothService>[]);

      final manager = BleConnectionManager(
        device: mockDevice,
        config: ConnectionConfig(
          recoveryPolicy: const RecoveryPolicy.noRetry(),
          onSetup: (_, __) async {},
        ),
      );

      final eventTypes = <Type>[];
      manager.events.listen((e) => eventTypes.add(e.runtimeType));

      await manager.connect();

      expect(eventTypes, [
        ConnectionAttemptStarted,
        ConnectionEstablished,
        ServiceDiscoveryStarted,
        ServiceDiscoveryCompleted,
        SetupStarted,
        SetupCompleted,
        ConnectionReady,
      ]);

      await manager.dispose();
    });

    test('emits disconnect events', () async {
      when(() => mockDevice.connect(
            timeout: any(named: 'timeout'),
            autoConnect: false,
          )).thenAnswer((_) async {
        connStateCtrl.add(BluetoothConnectionState.connected);
      });
      when(() => mockDevice.discoverServices())
          .thenAnswer((_) async => <BluetoothService>[]);
      when(() => mockDevice.disconnect()).thenAnswer((_) async {
        connStateCtrl.add(BluetoothConnectionState.disconnected);
      });

      final manager = BleConnectionManager(
        device: mockDevice,
        config: const ConnectionConfig(
          recoveryPolicy: RecoveryPolicy.noRetry(),
          autoReconnect: false,
        ),
      );

      await manager.connect();

      final eventTypes = <Type>[];
      manager.events.listen((e) => eventTypes.add(e.runtimeType));

      await manager.disconnect();

      expect(eventTypes, contains(DisconnectionInitiated));
      expect(eventTypes, contains(Disconnected));

      await manager.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // Dispose
  // -------------------------------------------------------------------------

  group('dispose', () {
    test('dispose is idempotent', () async {
      final manager = BleConnectionManager(
        device: mockDevice,
        config: const ConnectionConfig(
          recoveryPolicy: RecoveryPolicy.noRetry(),
        ),
      );

      await manager.dispose();
      await manager.dispose(); // Should not throw
    });

    test('all methods throw after dispose', () async {
      final manager = BleConnectionManager(
        device: mockDevice,
        config: const ConnectionConfig(
          recoveryPolicy: RecoveryPolicy.noRetry(),
        ),
      );

      await manager.dispose();

      await expectLater(
        () => manager.connect(),
        throwsA(isA<ManagerDisposedError>()),
      );

      await expectLater(
        () => manager.disconnect(),
        throwsA(isA<ManagerDisposedError>()),
      );
    });
  });
}
