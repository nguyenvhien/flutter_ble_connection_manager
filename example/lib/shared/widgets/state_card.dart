import 'package:flutter/material.dart';
import 'package:flutter_ble_connection_manager/flutter_ble_connection_manager.dart';
import '../theme/app_design.dart';

class StateCard extends StatelessWidget {
  final BleConnectionState state;

  const StateCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    IconData icon;

    switch (state) {
      case BleConnectionState.disconnected:
        color = AppColors.error;
        text = 'Disconnected';
        icon = Icons.bluetooth_disabled;
        break;
      case BleConnectionState.connecting:
        color = AppColors.warning;
        text = 'Connecting...';
        icon = Icons.bluetooth_searching;
        break;
      case BleConnectionState.ready:
        color = AppColors.success;
        text = 'Ready';
        icon = Icons.bluetooth_connected;
        break;
      case BleConnectionState.disconnecting:
        color = AppColors.textMuted;
        text = 'Disconnecting...';
        icon = Icons.power_settings_new;
        break;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        side: BorderSide(color: color.withValues(alpha: 0.5), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: AppDimensions.spacingMedium - 4),
            Text(
              text,
              style: TextStyle(
                fontSize: AppDimensions.fontXLarge,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
