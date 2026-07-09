import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

/// Build a TextTheme where every style uses our locally bundled Inter font.
/// This replaces GoogleFonts.interTextTheme() which creates a mismatched
/// family name ('Inter_regular') vs the pubspec-registered 'Inter'.
TextTheme interTextTheme([TextTheme? base]) {
  final b = base ?? const TextTheme();
  TextStyle withInter(TextStyle? s) =>
      (s ?? const TextStyle()).copyWith(fontFamily: 'Inter');
  return TextTheme(
    displayLarge: withInter(b.displayLarge),
    displayMedium: withInter(b.displayMedium),
    displaySmall: withInter(b.displaySmall),
    headlineLarge: withInter(b.headlineLarge),
    headlineMedium: withInter(b.headlineMedium),
    headlineSmall: withInter(b.headlineSmall),
    titleLarge: withInter(b.titleLarge),
    titleMedium: withInter(b.titleMedium),
    titleSmall: withInter(b.titleSmall),
    bodyLarge: withInter(b.bodyLarge),
    bodyMedium: withInter(b.bodyMedium),
    bodySmall: withInter(b.bodySmall),
    labelLarge: withInter(b.labelLarge),
    labelMedium: withInter(b.labelMedium),
    labelSmall: withInter(b.labelSmall),
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final baseTextTheme = interTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        tertiary: AppColors.accentLight,
        surface: AppColors.surfaceLight,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimaryLight,
        onError: Colors.white,
        outline: AppColors.separatorLight,
        surfaceContainerHighest: AppColors.fillLight,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
            color: AppColors.textPrimaryLight,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
            height: 1.1),
        displayMedium: baseTextTheme.displayMedium?.copyWith(
            color: AppColors.textPrimaryLight,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
            height: 1.1),
        displaySmall: baseTextTheme.displaySmall?.copyWith(
            color: AppColors.textPrimaryLight,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            height: 1.15),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
            color: AppColors.textPrimaryLight,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            fontSize: 32,
            height: 1.15),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
            color: AppColors.textPrimaryLight,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            fontSize: 26,
            height: 1.2),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
            color: AppColors.textPrimaryLight,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            fontSize: 22,
            height: 1.25),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
            color: AppColors.textPrimaryLight,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
            fontSize: 20,
            height: 1.3),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
            color: AppColors.textPrimaryLight,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            fontSize: 17,
            height: 1.35),
        titleSmall: baseTextTheme.titleSmall?.copyWith(
            color: AppColors.textPrimaryLight,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            fontSize: 15,
            height: 1.4),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
            color: AppColors.textPrimaryLight,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.2,
            height: 1.5),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimaryLight,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.2,
            height: 1.5),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
            color: AppColors.textSecondaryLight,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.1,
            height: 1.5),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
            color: AppColors.textPrimaryLight,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.2,
            height: 1.4),
        labelMedium: baseTextTheme.labelMedium?.copyWith(
            color: AppColors.textSecondaryLight,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
            height: 1.4),
        labelSmall: baseTextTheme.labelSmall?.copyWith(
            color: AppColors.textTertiaryLight,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
            height: 1.4),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: AppColors.textPrimaryLight, size: 24),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimaryLight,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fillLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: const TextStyle(
            color: AppColors.textTertiaryLight,
            fontWeight: FontWeight.w400,
            fontSize: 15),
        labelStyle: const TextStyle(
            color: AppColors.textSecondaryLight,
            fontWeight: FontWeight.w500,
            fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
          shadowColor: AppColors.primary.withValues(alpha: 0.4),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.separatorLight, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.separatorLight,
        thickness: 0.5,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.textTertiaryLight),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.success
                : AppColors.fillLight),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.fillLight,
        thumbColor: Colors.white,
        overlayColor: AppColors.primary.withValues(alpha: 0.15),
        trackHeight: 5,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 14,
          elevation: 4,
          pressedElevation: 10,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimaryLight,
        contentTextStyle: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiaryLight,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        extendedPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.fillLight,
        selectedColor: AppColors.primary.withValues(alpha: 0.12),
        labelStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: -0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: AppColors.textPrimaryLight,
        unselectedLabelColor: AppColors.textTertiaryLight,
        labelStyle: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.3),
        unselectedLabelStyle: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: -0.3),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tileColor: AppColors.cardLight,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        titleTextStyle: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 16, letterSpacing: -0.3),
        subtitleTextStyle: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: AppColors.textSecondaryLight),
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = interTextTheme(ThemeData.dark().textTheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      primaryColor: AppColors.primaryDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryDark,
        secondary: AppColors.accentDark,
        tertiary: AppColors.accentDark,
        surface: AppColors.surfaceDark,
        error: AppColors.errorDark,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimaryDark,
        onError: Colors.white,
        outline: AppColors.separatorDark,
        surfaceContainerHighest: AppColors.fillDark,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
            color: AppColors.textPrimaryDark,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
            height: 1.1),
        displayMedium: baseTextTheme.displayMedium?.copyWith(
            color: AppColors.textPrimaryDark,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
            height: 1.1),
        displaySmall: baseTextTheme.displaySmall?.copyWith(
            color: AppColors.textPrimaryDark,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            height: 1.15),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
            color: AppColors.textPrimaryDark,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            fontSize: 32,
            height: 1.15),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
            color: AppColors.textPrimaryDark,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            fontSize: 26,
            height: 1.2),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
            color: AppColors.textPrimaryDark,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            fontSize: 22,
            height: 1.25),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
            color: AppColors.textPrimaryDark,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
            fontSize: 20,
            height: 1.3),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
            color: AppColors.textPrimaryDark,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            fontSize: 17,
            height: 1.35),
        titleSmall: baseTextTheme.titleSmall?.copyWith(
            color: AppColors.textPrimaryDark,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            fontSize: 15,
            height: 1.4),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
            color: AppColors.textPrimaryDark,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.2,
            height: 1.5),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimaryDark,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.2,
            height: 1.5),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
            color: AppColors.textSecondaryDark,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.1,
            height: 1.5),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
            color: AppColors.textPrimaryDark,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.2,
            height: 1.4),
        labelMedium: baseTextTheme.labelMedium?.copyWith(
            color: AppColors.textSecondaryDark,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
            height: 1.4),
        labelSmall: baseTextTheme.labelSmall?.copyWith(
            color: AppColors.textTertiaryDark,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
            height: 1.4),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: AppColors.textPrimaryDark, size: 24),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimaryDark,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fillDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: AppColors.primaryDark, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.errorDark, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: const TextStyle(
            color: AppColors.textTertiaryDark,
            fontWeight: FontWeight.w400,
            fontSize: 15),
        labelStyle: const TextStyle(
            color: AppColors.textSecondaryDark,
            fontWeight: FontWeight.w500,
            fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
          shadowColor: AppColors.primaryDark.withValues(alpha: 0.3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          side: const BorderSide(color: AppColors.separatorDark, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.separatorDark,
        thickness: 0.5,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.textTertiaryDark),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.successDark
                : AppColors.fillDark),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primaryDark,
        inactiveTrackColor: AppColors.fillDark,
        thumbColor: Colors.white,
        overlayColor: AppColors.primaryDark.withValues(alpha: 0.15),
        trackHeight: 5,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 12,
          elevation: 4,
          pressedElevation: 8,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.elevatedDark,
        contentTextStyle: const TextStyle(
            color: AppColors.textPrimaryDark,
            fontWeight: FontWeight.w500,
            fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.primaryDark,
        unselectedItemColor: AppColors.textTertiaryDark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 4,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        extendedPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.fillDark,
        selectedColor: AppColors.primaryDark.withValues(alpha: 0.2),
        labelStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: -0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: AppColors.textPrimaryDark,
        unselectedLabelColor: AppColors.textTertiaryDark,
        labelStyle: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.3),
        unselectedLabelStyle: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: -0.3),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tileColor: AppColors.cardDark,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        titleTextStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: -0.3,
            color: AppColors.textPrimaryDark),
        subtitleTextStyle: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: AppColors.textSecondaryDark),
      ),
    );
  }
}
