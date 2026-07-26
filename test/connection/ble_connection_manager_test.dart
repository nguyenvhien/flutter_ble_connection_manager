import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide DisconnectReason;
import 'package:mocktail/mocktail.dart';
import 'package:fake_async/fake_async.dart';
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
    connStateCtrl = StreamController<BluetoothConnectionState>.broadcast();

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

  // -------------------------------------------------------------------------
  // Edge Cases & Production Integration Scenarios
  // -------------------------------------------------------------------------

  group('integration & edge cases', () {
    test('rapid spam click sequence', () async {
      var connectCallCount = 0;
      when(() => mockDevice.connect(
            timeout: any(named: 'timeout'),
            autoConnect: false,
          )).thenAnswer((_) async {
        connectCallCount++;
        await Future.delayed(
            const Duration(milliseconds: 10)); // Allow microtasks to clear
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

      final events = <Type>[];
      manager.events.listen((e) => events.add(e.runtimeType));

      final f1 = manager.connect().catchError((_) {});
      final f2 = manager.connect().catchError((_) {});

      await Future.microtask(() {}); // Allow them to queue

      final f3 = manager.disconnect().catchError((_) {});

      await Future.microtask(() {}); // Allow it to queue

      final f4 = manager.connect().catchError((_) {});

      await Future.wait([f1, f2, f3, f4]);

      expect(manager.state, BleConnectionState.ready);
      expect(connectCallCount, 2);

      // Verify no duplicate events for the successful connection
      expect(events.where((e) => e == ConnectionEstablished).length, 1);
      expect(events.where((e) => e == ConnectionReady).length, 1);
      expect(events.where((e) => e == Disconnected).length, 1);

      await manager.dispose();
    });

    test('reentrancy (disconnect inside onSetup)', () async {
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

      late BleConnectionManager manager;
      manager = BleConnectionManager(
        device: mockDevice,
        config: ConnectionConfig(
          recoveryPolicy: const RecoveryPolicy.noRetry(),
          autoReconnect: false,
          onSetup: (device, token) async {
            // Reentrancy: Call disconnect while connecting
            await manager.disconnect();
            // Simulate some delay that would throw CancelledException
            await Future.delayed(const Duration(milliseconds: 50));
            token.throwIfCancelled();
          },
        ),
      );

      try {
        await manager.connect();
        fail('Expected SetupFailure');
      } catch (e) {
        expect(e, isA<SetupFailure>());
      }

      // State should be disconnected, future resolved safely
      expect(manager.state, BleConnectionState.disconnected);
      await manager.dispose();
    });

    test('dispose behavior and stream closing', () async {
      when(() => mockDevice.connect(
            timeout: any(named: 'timeout'),
            autoConnect: false,
          )).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
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
        ),
      );

      final connectFuture = manager.connect().catchError((e) {
        expect(e, isA<TransportFailure>());
      });

      final stateExpectation = expectLater(
          manager.stateStream,
          emitsInOrder([
            BleConnectionState.connecting,
            BleConnectionState.disconnecting,
            BleConnectionState.disconnected,
            emitsDone,
          ]));
      final eventExpectation = expectLater(
          manager.events,
          emitsInOrder([
            isA<DisconnectionInitiated>(),
            isA<Disconnected>(),
            emitsDone,
          ]));

      await manager.dispose();
      await connectFuture;

      // Streams must be closed
      await stateExpectation;
      await eventExpectation;
    });

    test('onSetup throws standard exception', () async {
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
        config: ConnectionConfig(
          recoveryPolicy: const RecoveryPolicy.noRetry(),
          autoReconnect: false,
          onSetup: (_, __) async {
            throw Exception('Some setup error');
          },
        ),
      );

      final states = <BleConnectionState>[];
      manager.stateStream.listen(states.add);

      final events = <Type>[];
      manager.events.listen((e) => events.add(e.runtimeType));

      try {
        await manager.connect();
        fail('Expected SetupFailure');
      } catch (e) {
        expect(e, isA<SetupFailure>());
      }

      expect(manager.state, BleConnectionState.disconnected);
      expect(states, [
        BleConnectionState.disconnected,
        BleConnectionState.connecting,
        BleConnectionState.disconnected
      ]);
      expect(events, containsAllInOrder([SetupStarted, ConnectionFailed]));

      await manager.dispose();
    });

    test('setup timeout', () {
      fakeAsync((async) {
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
          config: ConnectionConfig(
            setupTimeout: const Duration(milliseconds: 100),
            recoveryPolicy: const RecoveryPolicy.noRetry(),
            autoReconnect: false,
            onSetup: (device, token) async {
              await Future.delayed(const Duration(milliseconds: 500));
              token.throwIfCancelled();
            },
          ),
        );

        final events = <Type>[];
        manager.events.listen((e) => events.add(e.runtimeType));

        var threwTimeout = false;
        manager.connect().catchError((e) {
          if (e is TimeoutFailure) threwTimeout = true;
        });

        // Advance past setup timeout
        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        expect(threwTimeout, true);
        expect(manager.state, BleConnectionState.disconnected);
        expect(events, contains(ConnectionFailed));

        manager.dispose();
      });
    });

    test('late subscriber behavior', () async {
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

      // Late subscriber to state
      final lateStateList = <BleConnectionState>[];
      manager.stateStream.listen(lateStateList.add);

      // Late subscriber to events
      final lateEventList = <Type>[];
      manager.events.listen((e) => lateEventList.add(e.runtimeType));

      await Future.microtask(() {}); // Let sync stream yield if needed

      // BehaviorSubject replays the latest state
      expect(lateStateList, [BleConnectionState.ready]);

      // PublishSubject does NOT replay past events
      expect(lateEventList, isEmpty);

      await manager.dispose();
    });

    test('multiple managers independence', () async {
      final mockDevice2 = MockBluetoothDevice();
      final connStateCtrl2 =
          StreamController<BluetoothConnectionState>.broadcast();
      when(() => mockDevice2.connectionState)
          .thenAnswer((_) => connStateCtrl2.stream);
      when(() => mockDevice2.isConnected).thenReturn(false);
      when(() => mockDevice2.remoteId)
          .thenReturn(const DeviceIdentifier('11:22:33:44:55:66'));

      when(() => mockDevice.connect(
          timeout: any(named: 'timeout'),
          autoConnect: false)).thenAnswer((_) async {
        connStateCtrl.add(BluetoothConnectionState.connected);
      });
      when(() => mockDevice.discoverServices())
          .thenAnswer((_) async => <BluetoothService>[]);
      when(() => mockDevice.disconnect()).thenAnswer((_) async {
        connStateCtrl.add(BluetoothConnectionState.disconnected);
      });

      when(() => mockDevice2.connect(
          timeout: any(named: 'timeout'),
          autoConnect: false)).thenAnswer((_) async {
        connStateCtrl2.add(BluetoothConnectionState.connected);
      });
      when(() => mockDevice2.discoverServices())
          .thenAnswer((_) async => <BluetoothService>[]);
      when(() => mockDevice2.disconnect()).thenAnswer((_) async {
        connStateCtrl2.add(BluetoothConnectionState.disconnected);
      });

      final managerA = BleConnectionManager(
        device: mockDevice,
        config: const ConnectionConfig(
            recoveryPolicy: RecoveryPolicy.noRetry(), autoReconnect: false),
      );

      final managerB = BleConnectionManager(
        device: mockDevice2,
        config: const ConnectionConfig(
            recoveryPolicy: RecoveryPolicy.noRetry(), autoReconnect: false),
      );

      // Connect concurrently
      await Future.wait([managerA.connect(), managerB.connect()]);

      expect(managerA.state, BleConnectionState.ready);
      expect(managerB.state, BleConnectionState.ready);

      // Disconnect A
      await managerA.disconnect();

      // B should still be ready
      expect(managerA.state, BleConnectionState.disconnected);
      expect(managerB.state, BleConnectionState.ready);

      await managerA.dispose();
      await managerB.dispose();
      connStateCtrl2.close();
    });
  });
}
