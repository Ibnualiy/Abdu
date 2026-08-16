import 'package:flutter/material.dart';

/// Design tokens matching the reference dashboard: white rounded cards with
/// a colored left accent bar, a dark pill for the active tab, soft teal
/// progress bars. Kept in one place so every screen stays consistent.
class AppColors {
  static const background = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1A1B2E);
  static const textSecondary = Color(0xFF6B7280);

  static const success = Color(0xFF10B981); // Today's Sales
  static const info = Color(0xFF3B82F6); // Net Profit
  static const warning = Color(0xFFF59E0B); // Items Sold
  static const danger = Color(0xFFEF4444); // Low Stock

  static const tabActiveBg = Color(0xFF1A1B2E);
  static const progressTrack = Color(0xFFE5E7EB);
  static const progressFill = Color(0xFF2DD4BF);
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: AppColors.info,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Roboto', // swap for a custom font that supports Amharic
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
    ),
  );
}
