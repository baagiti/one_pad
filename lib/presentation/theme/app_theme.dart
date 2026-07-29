import 'package:flutter/material.dart';

/// "Sunset coral" palette (2026-07-27, replacing the original cream/blue
/// design doc §14 palette per the user's request for something more
/// vibrant/energetic) — a hand-picked light theme rather than a generated
/// Material seed, so the specific role colors (success/error/premium) stay
/// under our control instead of being algorithmically derived from one
/// seed color.
class AppColors {
  static const background = Color(0xFFFFE8D6);
  static const surface = Color(0xFFFFF6EE);
  static const primary = Color(0xFFE8542A);
  static const onPrimary = Color(0xFFFFFFFF);
  static const secondary = Color(0xFFF2A93B);
  static const success = Color(0xFF3E8E52);
  static const error = Color(0xFFC62828);
  static const textPrimary = Color(0xFF3A2216);
  static const textSecondary = Color(0xFF8A6A57);
  static const outline = Color(0xFFF3D0AC);

  /// Repetition-tier badge colors (design doc, 2026-07-27): "mastered"
  /// reuses [secondary] (amber already reads as gold) rather than adding a
  /// fifth near-duplicate warm hue.
  static const tierBronze = Color(0xFFB87A4A);
  static const tierSilver = Color(0xFF9BA3AA);
  static const tierGold = secondary;
  static const tierPlatinum = Color(0xFF7FA6A3);
  static const tierDiamond = Color(0xFF3FA9CC);

  const AppColors._();
}

class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      error: AppColors.error,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    ).copyWith(surfaceContainerHighest: AppColors.outline);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
            fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        titleLarge: TextStyle(
            fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        titleMedium: TextStyle(
            fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        bodyMedium: TextStyle(color: AppColors.textPrimary),
        bodySmall: TextStyle(color: AppColors.textSecondary),
        labelMedium: TextStyle(color: AppColors.textSecondary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.outline),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.outline,
      ),
    );
  }
}
