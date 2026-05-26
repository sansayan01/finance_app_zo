import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';

/// Shared premium UI helpers for the collection agent portal.
class PremiumHelpers {
  PremiumHelpers._();

  /// Section header with a 4px gradient accent bar + bold title.
  static Widget sectionHeader(
    ThemeData theme,
    String title, {
    IconData? icon,
    Widget? trailing,
  }) {
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primary, AppColors.accent],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  /// Gradient-filled circle icon with glow shadow.
  static Widget gradientIconContainer(
    IconData icon,
    Color color, {
    double size = 40,
    double iconSize = 20,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.7)],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: iconSize),
    );
  }

  /// Wraps a widget with staggered fade-in + slide animation.
  static Widget staggeredAnimation(
    Widget widget, {
    required int index,
    int baseDelay = 60,
  }) {
    return widget
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: baseDelay * index),
          duration: 300.ms,
        )
        .slideY(begin: 0.04, end: 0, duration: 300.ms, curve: Curves.easeOutCubic);
  }
}
