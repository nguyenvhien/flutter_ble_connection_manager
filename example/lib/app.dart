import 'package:flutter/material.dart';
import '../shared/theme/app_theme.dart';
import 'features/home/home_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ble Connection Manager Example',
      theme: AppTheme.darkTheme,
      home: const HomePage(),
    );
  }
}
