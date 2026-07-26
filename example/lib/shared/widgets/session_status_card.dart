import 'package:flutter/material.dart';
import 'package:flutter_ble_connection_manager/flutter_ble_connection_manager.dart';
import '../theme/app_design.dart';

class SessionStatusCard extends StatelessWidget {
  final BleConnectionState state;
  final String? lastError;

  const SessionStatusCard({
    super.key,
    required this.state,
    this.lastError,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppDimensions.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SESSION STATUS',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: AppDimensions.fontSmall,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          _buildMetricRow('Current State', state.name.toUpperCase()),
          const SizedBox(height: AppDimensions.spacingSmall + 4),
          _buildMetricRow(
            'Last Error',
            lastError ?? 'None',
            valueColor: lastError != null ? AppColors.error : AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: AppDimensions.fontMedium,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimary,
            fontSize: AppDimensions.fontMedium,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
