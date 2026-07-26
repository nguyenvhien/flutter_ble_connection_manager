import 'package:flutter/material.dart';
import '../../shared/theme/app_design.dart';

class ApiReferencePage extends StatelessWidget {
  const ApiReferencePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API Reference')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        children: [
          _buildRefCard(
            title: 'BleConnectionManager',
            code: 'final manager = BleConnectionManager(device: dev, config: cfg);',
            description: 
              'The main facade. Create one instance per device. '
              'It safely handles concurrency, deduplicating connect() calls and '
              'queuing disconnect() calls.',
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          _buildRefCard(
            title: 'ConnectionConfig & RecoveryPolicy',
            code: 'RecoveryPolicy.exponentialBackoff(maxAttempts: 3)',
            description: 
              'Declare how the connection should behave. If the connection drops unexpectedly, '
              'the manager will use the RecoveryPolicy to automatically retry connecting.',
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          _buildRefCard(
            title: 'BleConnectionState & Events',
            code: 'manager.stateStream.listen((state) { ... })',
            description: 
              'Only 4 clear states: disconnected, connecting, ready, disconnecting. '
              'The "ready" state means native connection + your custom onSetup logic both succeeded.',
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          _buildRefCard(
            title: 'CancellationToken',
            code: 'token.throwIfCancelled();',
            description: 
              'Passed to your onSetup callback. You MUST call this periodically during long setup '
              'processes (like discovering services or writing config). It safely aborts the setup '
              'if the user disconnects mid-way or if auto-reconnect kicks in.',
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          _buildRefCard(
            title: 'Error Handling',
            code: 'catch (e) { if (e is SetupFailure) ... }',
            description: 
              'The library throws specific, subclassed exceptions: TimeoutFailure, SetupFailure, '
              'and TransportFailure. This allows you to show precise error messages to the user '
              'rather than a generic "connection failed".',
          ),
        ],
      ),
    );
  }

  Widget _buildRefCard({required String title, required String code, required String description}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary)),
            const SizedBox(height: AppDimensions.spacingSmall),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceHighlight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              ),
              child: Text(code, style: const TextStyle(fontFamily: 'monospace', color: AppColors.success, fontSize: 12)),
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            Text(description, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
