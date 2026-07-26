import 'package:flutter/material.dart';

import '../connection_demo/connection_demo_page.dart';
import '../lifecycle_demo/lifecycle_demo_page.dart';
import '../api_reference/api_reference_page.dart';
import '../../shared/theme/app_design.dart';
import '../../shared/widgets/device_selector.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isMockMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_ble_connection_manager'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(40),
          child: Padding(
            padding: EdgeInsets.only(bottom: AppDimensions.spacingMedium),
            child: Text(
              'Production BLE Lifecycle Playground',
              style: TextStyle(color: AppColors.textMuted, fontSize: AppDimensions.fontMedium),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacingMedium),
            decoration: BoxDecoration(
              color: AppColors.highlight.withAlpha(25), // ~0.1 opacity
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              border: Border.all(color: AppColors.highlight.withAlpha(76)), // ~0.3 opacity
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💡 Executable Documentation',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.highlight),
                ),
                SizedBox(height: 4),
                Text(
                  'This application is not a complete BLE app, but rather an interactive playground. '
                  'Each section below demonstrates a core concept of the library in isolation.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.4, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          Material(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            child: SwitchListTile(
              title: const Text('Enable Mock Mode (Simulator)'),
              subtitle: const Text('Uses mock devices. No BLE hardware required.', style: TextStyle(fontSize: 12)),
              value: _isMockMode,
              activeThumbColor: AppColors.highlight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                side: const BorderSide(color: AppColors.border),
              ),
              onChanged: (val) {
                setState(() {
                  _isMockMode = val;
                });
              },
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          _buildDemoCard(
            context,
            icon: Icons.flash_on,
            iconColor: AppColors.success,
            title: 'Quick Start',
            subtitle: 'Learn the API in 5 minutes.',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ConnectionDemoPage(isMockMode: _isMockMode)));
            },
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          _buildDemoCard(
            context,
            icon: Icons.timeline,
            iconColor: AppColors.highlight,
            title: 'Lifecycle Walkthrough',
            subtitle: 'Understand why Ready is different from Connected.',
            onTap: () => _navigateToFeature(
              context, 
              (device) => LifecycleDemoPage(device: device),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          _buildDemoCard(
            context,
            icon: Icons.menu_book,
            iconColor: AppColors.textPrimary,
            title: 'API Reference',
            subtitle: 'Core classes and mental model.',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ApiReferencePage()));
            },
          ),
        ],
      ),
    );
  }

  void _navigateToFeature(BuildContext context, Widget Function(dynamic device) pageBuilder) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      appBar: AppBar(title: const Text('Select Device')),
      body: DeviceSelector(
        isMockMode: _isMockMode,
        onDeviceSelected: (device) {
          // Push the demo page on top of the selector so the user can go back to it
          Navigator.push(context, MaterialPageRoute(builder: (_) => pageBuilder(device)));
        },
      ),
    )));
  }

  Widget _buildDemoCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppDimensions.spacingMedium),
        leading: Icon(icon, size: 40, color: iconColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
        onTap: onTap,
      ),
    );
  }
}
