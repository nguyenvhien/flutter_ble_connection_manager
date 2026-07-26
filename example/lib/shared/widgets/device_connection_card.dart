import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:flutter_ble_connection_manager/flutter_ble_connection_manager.dart';
import '../theme/app_design.dart';
import '../mock/mock_ble_connection_manager.dart';
import 'state_card.dart';

class DeviceConnectionCard extends StatefulWidget {
  final fbp.BluetoothDevice device;
  final BleConnectionManager manager;

  const DeviceConnectionCard({
    super.key,
    required this.device,
    required this.manager,
  });

  @override
  State<DeviceConnectionCard> createState() => _DeviceConnectionCardState();
}

class _DeviceConnectionCardState extends State<DeviceConnectionCard> {
  StreamSubscription? _stateSub;
  StreamSubscription? _eventSub;
  BleConnectionState _currentState = BleConnectionState.disconnected;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _currentState = widget.manager.state;
    _stateSub = widget.manager.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _currentState = state;
        });
      }
    });

    _eventSub = widget.manager.events.listen((event) {
      if (!mounted) return;
      if (event is ConnectionAttemptStarted || event is ReconnectionStarted) {
        if (_lastError != null) {
          setState(() => _lastError = null);
        }
      } else if (event is ConnectionFailed) {
        setState(() => _lastError = event.error.toString());
      } else if (event is Disconnected &&
          event.reason != BleDisconnectReason.userInitiated) {
        setState(() => _lastError = 'Disconnected: ${event.reason.name}');
      }
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _eventSub?.cancel();
    super.dispose();
  }

  void _toggleConnection() {
    setState(() => _lastError = null);
    if (_currentState == BleConnectionState.disconnected) {
      widget.manager.connect();
    } else {
      widget.manager.disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReady = _currentState == BleConnectionState.ready;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMedium,
        vertical: 4,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),

          if (_lastError != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Text(
                _lastError!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),

          if (_currentState != BleConnectionState.disconnected)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: StateCard(state: _currentState),
            ),

          if (isReady)
            Container(
              color: AppColors.surfaceHighlight,
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.settings),
                      label: const Text('Read Config'),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Read triggered for ${widget.device.advName}',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.send),
                      label: const Text('Send Data'),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Write triggered for ${widget.device.advName}',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isReady = _currentState == BleConnectionState.ready;
    final isBusy =
        _currentState != BleConnectionState.disconnected &&
        _currentState != BleConnectionState.ready;
    final isMock = widget.device is MockBluetoothDevice;
    final description = isMock ? mockDescriptions[widget.device.advName] : null;

    final leadingIcon = Icon(
      Icons.bluetooth,
      color: isReady
          ? AppColors.success
          : (_currentState != BleConnectionState.disconnected
                ? AppColors.highlight
                : AppColors.textMuted),
    );

    final title = Text(
      widget.device.advName.isNotEmpty
          ? widget.device.advName
          : 'Unknown Device',
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
    final subtitle = Text(
      widget.device.remoteId.str,
      style: const TextStyle(fontSize: 12),
    );

    final trailingAction = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isBusy)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        if (isBusy) const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _currentState == BleConnectionState.disconnecting
              ? null
              : _toggleConnection,
          style: ElevatedButton.styleFrom(
            backgroundColor: isReady || isBusy
                ? AppColors.error
                : AppColors.highlight,
            foregroundColor: AppColors.surface,
          ),
          child: Text(isReady ? 'Disconnect' : (isBusy ? 'Cancel' : 'Connect')),
        ),
      ],
    );

    if (isMock && description != null) {
      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: leadingIcon,
          title: title,
          subtitle: subtitle,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                description,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                right: 16.0,
                bottom: 8.0,
                top: 8.0,
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: trailingAction,
              ),
            ),
          ],
        ),
      );
    }

    return ListTile(
      leading: leadingIcon,
      title: title,
      subtitle: subtitle,
      trailing: trailingAction,
    );
  }
}
