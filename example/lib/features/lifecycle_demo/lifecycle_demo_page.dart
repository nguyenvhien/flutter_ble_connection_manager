import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_ble_connection_manager/flutter_ble_connection_manager.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import '../../shared/mock/mock_ble_connection_manager.dart';
import 'widgets/timeline_widget.dart';

class LifecycleDemoPage extends StatefulWidget {
  final fbp.BluetoothDevice device;

  const LifecycleDemoPage({super.key, required this.device});

  @override
  State<LifecycleDemoPage> createState() => _LifecycleDemoPageState();
}

class _LifecycleDemoPageState extends State<LifecycleDemoPage> {
  late BleConnectionManager _manager;
  StreamSubscription? _stateSub;
  BleConnectionState _currentState = BleConnectionState.disconnected;

  @override
  void initState() {
    super.initState();
    _initManager();
  }

  void _initManager() {
    if (widget.device is MockBluetoothDevice) {
      _manager = MockBleConnectionManager(
        device: widget.device,
      );
    } else {
      _manager = BleConnectionManager(
        device: widget.device,
        config: ConnectionConfig(
          autoReconnect: true,
          autoDiscoverServices: false, // We will do it manually in onSetup
          onSetup: (device, token) async {
            // 1. Discover Services (Real world requirement)
            await device.discoverServices();
            token.throwIfCancelled();
            
            // 2. Simulated Delay for Demo Purposes
            // This allows you to visually see the "Setup" phase on the timeline
            // before it transitions to "Ready".
            await Future.delayed(const Duration(seconds: 1));
          },
        ),
      );
    }

    _stateSub = _manager.stateStream.listen((state) {
      if (mounted) setState(() => _currentState = state);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lifecycle Walkthrough')),
      body: _buildDemo(),
    );
  }

  Widget _buildDemo() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Device: ${widget.device.advName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 24),
          TimelineWidget(
            events: _manager.events,
            currentState: _currentState,
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _currentState == BleConnectionState.disconnected
                ? () => _manager.connect()
                : (_currentState == BleConnectionState.ready ? () => _manager.disconnect() : null),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: _currentState == BleConnectionState.disconnected ? Colors.green : Colors.red,
            ),
            child: Text(
              _currentState == BleConnectionState.disconnected ? 'Start Connection' : 'Disconnect',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}
