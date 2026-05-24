import 'package:flutter/material.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_colors.dart';

class CustomerEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? ctaLabel;
  final VoidCallback? onCtaTap;

  const CustomerEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.onCtaTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circular background behind icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                    AppColors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? AppColors.surfaceDark
                        : AppColors.surfaceLight,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(
                          alpha: isDark ? 0.1 : 0.06,
                        ),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                    border: Border.all(
                      color: AppColors.primary.withValues(
                        alpha: isDark ? 0.15 : 0.1,
                      ),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: AppColors.primary.withValues(
                      alpha: isDark ? 0.7 : 0.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Title
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            // Subtitle
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            // Optional CTA button
            if (ctaLabel != null && onCtaTap != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildCtaButton(theme, isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCtaButton(ThemeData theme, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCtaTap,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 4,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.15),
                AppColors.accent.withValues(alpha: isDark ? 0.2 : 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: isDark ? 0.1 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: isDark
                    ? AppColors.primaryDark
                    : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                ctaLabel!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.primaryDark
                      : AppColors.primary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
