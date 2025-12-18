import 'package:flutter/material.dart';

/// Centralized app theme constants to avoid duplication.
/// 
/// Usage: `AppColors.cardBackground`, `AppSizes.cardRadius`, etc.
abstract final class AppColors {
  // Backgrounds
  static const cardBackground = Color(0xFF070707);
  static const surfaceBackground = Color(0xFF0A0A0A);
  static const dialogBackground = Color(0xFF0A0A0A);
  
  // Borders
  static const cardBorder = Color(0x22FFFFFF);
  static const subtleBorder = Color(0x22FFFFFF);
  static const activeBorder = Color(0x44FFFFFF);
  
  // Text
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xAAFFFFFF);
  static const textTertiary = Color(0x88FFFFFF);
  static const textDisabled = Color(0x66FFFFFF);
  
  // Accent colors
  static const accentGreen = Color(0xFF00D17A);
  static const accentOrange = Color(0xFFFFB020);
  static const accentGold = Color(0xFFFFD700);
  static const accentCyan = Color(0xFF00E5FF);
  static const accentPurple = Color(0xFF7C7CFF);
  static const accentRed = Color(0xFFFF4444);
  static const accentPink = Color(0xFFFF4081);
  
  // Status colors
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFFB020);
  static const error = Color(0xFFFF4444);
  static const info = Color(0xFF7C7CFF);
  
  // Streak/celebration
  static const streakOrange = Color(0xFFFF6B35);
}

abstract final class AppSizes {
  // Border radius
  static const double cardRadius = 18.0;
  static const double buttonRadius = 12.0;
  static const double chipRadius = 20.0;
  static const double dialogRadius = 24.0;
  
  // Padding
  static const double cardPadding = 16.0;
  static const double screenPadding = 16.0;
  static const double itemSpacing = 12.0;
  static const double sectionSpacing = 14.0;
  
  // Dynamic Island
  static const double islandBaseHeight = 38.0;
  static const double islandExpandedHeight = 220.0;
  static const double islandCollapsedWidth = 180.0;
  static const double islandMaxWidth = 360.0;
}

abstract final class AppDurations {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 500);
  static const stagger = Duration(milliseconds: 50);
}

/// Convenience extensions for common color operations.
extension ColorOpacity on Color {
  Color get subtle => withOpacity(0.2);
  Color get medium => withOpacity(0.4);
  Color get strong => withOpacity(0.6);
}
