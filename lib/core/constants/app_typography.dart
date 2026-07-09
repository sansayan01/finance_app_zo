import 'package:flutter/material.dart';

/// Legacy typography class. The AppTheme now handles all typography via ThemeData.
/// These are kept as utility styles but should NOT be used for hardcoded colors.
/// Always use Theme.of(context).textTheme instead for theme-aware text.
class AppTypography {
  AppTypography._();

  static TextStyle get _baseStyle => const TextStyle(fontFamily: 'Inter');

  static TextStyle get displayLarge => _baseStyle.copyWith(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
        height: 1.1,
      );

  static TextStyle get displayMedium => _baseStyle.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        height: 1.2,
      );

  static TextStyle get displaySmall => _baseStyle.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.3,
      );

  static TextStyle get headlineLarge => _baseStyle.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.3,
      );

  static TextStyle get headlineMedium => _baseStyle.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );

  static TextStyle get headlineSmall => _baseStyle.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 1.4,
      );

  static TextStyle get titleLarge => _baseStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.5,
      );

  static TextStyle get titleMedium => _baseStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.5,
      );

  static TextStyle get titleSmall => _baseStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.5,
      );

  static TextStyle get bodyLarge => _baseStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle get bodyMedium => _baseStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle get bodySmall => _baseStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle get labelLarge => _baseStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.4,
      );

  static TextStyle get labelMedium => _baseStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.4,
      );

  static TextStyle get labelSmall => _baseStyle.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.4,
      );

  static TextStyle get monoLarge => const TextStyle(
        fontFamily: 'monospace',
        fontSize: 20,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get monoMedium => const TextStyle(
        fontFamily: 'monospace',
        fontSize: 16,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get monoSmall => const TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        fontWeight: FontWeight.w400,
      );
}
