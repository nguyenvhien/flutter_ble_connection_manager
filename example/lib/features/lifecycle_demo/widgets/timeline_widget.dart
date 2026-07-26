import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_ble_connection_manager/flutter_ble_connection_manager.dart';
import '../../../shared/theme/app_design.dart';

class TimelineWidget extends StatefulWidget {
  final Stream<BleLifecycleEvent> events;
  final BleConnectionState currentState;

  const TimelineWidget({
    super.key,
    required this.events,
    required this.currentState,
  });

  @override
  State<TimelineWidget> createState() => _TimelineWidgetState();
}

class _TimelineWidgetState extends State<TimelineWidget> {
  int _currentStep = 0;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _subscribe();
    _updateStepFromState(widget.currentState);
  }

  @override
  void didUpdateWidget(covariant TimelineWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events) {
      _subscribe();
    }
    if (oldWidget.currentState != widget.currentState) {
      _updateStepFromState(widget.currentState);
    }
  }

  void _subscribe() {
    _sub?.cancel();
    _sub = widget.events.listen((event) {
      if (!mounted) return;
      setState(() {
        if (event is ConnectionAttemptStarted) {
          _currentStep = 1;
        } else if (event is ConnectionEstablished) {
          _currentStep = 2;
        } else if (event is SetupStarted) {
          _currentStep = 3;
        } else if (event is ConnectionReady) {
          _currentStep = 4;
        } else if (event is Disconnected) {
          _currentStep = 0;
        }
      });
    });
  }

  void _updateStepFromState(BleConnectionState state) {
    setState(() {
      if (state == BleConnectionState.disconnected) {
        _currentStep = 0;
      } else if (state == BleConnectionState.ready) {
        _currentStep = 4;
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingMedium),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONNECTION LIFECYCLE',
            style: TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          _buildStep(
            0,
            'Disconnected',
            'No active connection.',
            Icons.power_off,
          ),
          _buildStep(
            1,
            'Connecting',
            'Application called manager.connect()',
            Icons.settings_ethernet,
          ),
          _buildStep(
            2,
            'Native Connected',
            'BLE Link Established',
            Icons.bluetooth_connected,
          ),
          _buildStep(
            3,
            'Running Setup',
            'Discovering services & configuring...',
            Icons.build,
          ),
          _buildStep(
            4,
            'Ready',
            'Application can now safely use the device.',
            Icons.check_circle,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStep(
    int stepIndex,
    String title,
    String subtitle,
    IconData icon, {
    bool isLast = false,
  }) {
    final isActive = _currentStep == stepIndex;
    final isCompleted = _currentStep > stepIndex;
    final color = isActive
        ? AppColors.info
        : (isCompleted
              ? AppColors.successDark
              : AppColors.textMuted.withValues(alpha: 0.5));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isCompleted
                    ? AppColors.successDark
                    : AppColors.textMuted.withValues(alpha: 0.3),
              ),
          ],
        ),
        const SizedBox(width: AppDimensions.spacingMedium),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.spacingSmall),
              Text(
                title,
                style: TextStyle(
                  color: isActive || isCompleted
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: AppDimensions.fontLarge,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: isActive || isCompleted
                      ? AppColors.textSecondary
                      : AppColors.textMuted,
                  fontSize: AppDimensions.fontSmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
