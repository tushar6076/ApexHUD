// lib/styles/theme.dart
import 'package:flutter/material.dart';
import 'color.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      primaryColor: AppColors.primaryNeon,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryNeon,
        secondary: AppColors.cyberpunkCyan,
        error: AppColors.alertRed,
        surface: AppColors.darkBackground,
      ),
      fontFamily: 'Orbitron',
    );
  }
}