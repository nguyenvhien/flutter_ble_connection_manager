import 'package:flutter/material.dart';

/// Centralized design tokens for the Example App.
class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceHighlight = Color(0xFF2D2D2D);
  static const Color consoleBackground = Colors.black;
  
  // Borders
  static const Color border = Colors.white10;
  static const Color borderHighlight = Colors.white24;
  
  // Text
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textMuted = Colors.grey;
  static const Color textDisabled = Colors.white30;

  // Semantic
  static const Color success = Colors.greenAccent;
  static const Color successDark = Colors.green;
  static const Color error = Colors.redAccent;
  static const Color errorDark = Colors.red;
  static const Color warning = Colors.orangeAccent;
  static const Color info = Colors.blueAccent;
  static const Color highlight = Colors.purpleAccent;
}

class AppDimensions {
  // Padding & Margin
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  
  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  
  // Font Sizes
  static const double fontSmall = 12.0;
  static const double fontMedium = 14.0;
  static const double fontLarge = 16.0;
  static const double fontXLarge = 20.0;
}
