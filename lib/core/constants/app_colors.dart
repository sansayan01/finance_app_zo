import 'package:flutter/material.dart';

/// Premium iOS 18+ color system for MicroFlow Pro.
/// Curated for a luxurious fintech aesthetic with refined depth and warmth.
class AppColors {
  AppColors._();

  // ─── Primary Palette — Deep Indigo Blue ───
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color accent = Color(0xFF7C3AED);
  static const Color accentLight = Color(0xFFA855F7);

  // ─── Semantic Colors — Refined Apple HIG ───
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color orange = Color(0xFFF97316);
  static const Color mint = Color(0xFF14B8A6);
  static const Color teal = Color(0xFF06B6D4);
  static const Color pink = Color(0xFFEC4899);
  static const Color indigo = Color(0xFF6366F1);
  static const Color cyan = Color(0xFF22D3EE);
  static const Color rose = Color(0xFFF43F5E);

  // ─── Light Theme — Warm, luminous, layered ───
  static const Color backgroundLight = Color(0xFFF8F9FB);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color elevatedLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textTertiaryLight = Color(0xFF94A3B8);
  static const Color separatorLight = Color(0xFFE2E8F0);
  static const Color fillLight = Color(0xFFF1F5F9);
  static const Color groupedBgLight = Color(0xFFF8F9FB);
  static const Color secondaryFillLight = Color(0xFFEDF2F7);

  // ─── Dark Theme — Smooth Obsidian & Slate ───
  static const Color backgroundDark =
      Color(0xFF030508); // Ultra-deep — near-black for maximum glassmorphic contrast
  static const Color surfaceDark = Color(0xFF0C1018); // Refined surface depth
  static const Color cardDark = Color(0xFF141824); // Subtly lighter for cards
  static const Color elevatedDark = Color(0xFF1C2030); // Elevated surfaces
  static const Color textPrimaryDark =
      Color(0xFFE2E8F0); // Dimmed slate for smoothness
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Slate 400
  static const Color textTertiaryDark = Color(0xFF64748B); // Slate 500
  static const Color separatorDark = Color(0xFF2E3544); // Muted separator
  static const Color fillDark = Color(0xFF1F2532); // Input/Fill color
  static const Color groupedBgDark = Color(0xFF0F1115);
  static const Color secondaryFillDark = Color(0xFF262B35);

  // ─── Dark Mode Specific Accents (Muted & Desaturated for premium smoothness) ───
  static const Color primaryDark = Color(0xFF7E89F1); // Soft Indigo
  static const Color accentDark = Color(0xFF9B87F5); // Soft Violet
  static const Color successDark = Color(0xFF52D1A4); // Muted Mint
  static const Color warningDark = Color(0xFFF4C45E); // Muted Amber
  static const Color errorDark = Color(0xFFF28B8B); // Soft Coral/Red

  // ─── Legacy aliases (backward compatibility) ───
  static const Color primaryTeal = primary;
  static const Color primaryIndigo = accent;
  static const Color primaryPurple = accentLight;
  static const Color accentCyan = primaryLight;
  static const Color backgroundSlate = surfaceDark;
  static const Color surfaceSlate = elevatedDark;
  static const Color textPrimary = textPrimaryLight;
  static const Color textSecondary = textSecondaryLight;
  static const Color textMuted = textTertiaryLight;
  static const Color textMutedLight = textTertiaryLight;
  static const Color textPrimaryDarkLegacy = textPrimaryDark;
  static const Color textSecondaryDark2 = textSecondaryDark;
  static const Color glassBackground = Color(0x14FFFFFF);
  static const Color glassBorder = Color(0x26FFFFFF);
  static const Color glassHighlight = Color(0x33FFFFFF);
  static const Color glassBackgroundLight = Color(0xB3FFFFFF);
  static const Color glassBorderLight = Color(0x330A84FF);

  // ─── Gradient Presets ───
  static const List<Color> premiumGradient = [
    Color(0xFF4F46E5),
    Color(0xFF7C3AED),
  ];

  static const List<Color> warmGradient = [
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
  ];

  static const List<Color> coolGradient = [
    Color(0xFF22D3EE),
    Color(0xFF4F46E5),
  ];

  static const List<Color> auroraGradient = [
    Color(0xFF4F46E5),
    Color(0xFF7C3AED),
    Color(0xFFA855F7),
    Color(0xFF22D3EE),
  ];

  static const List<Color> successGradient = [
    Color(0xFF10B981),
    Color(0xFF14B8A6),
  ];

  static const List<Color> cardGradient = [
    Color(0x14818CF8),
    Color(0x0A6366F1),
  ];

  static LinearGradient get primaryGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: premiumGradient,
      );

  static LinearGradient get auroraGradientLinear => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: auroraGradient,
      );

  static RadialGradient get radialAurora => const RadialGradient(
        center: Alignment.topLeft,
        radius: 1.5,
        colors: auroraGradient,
      );
}
