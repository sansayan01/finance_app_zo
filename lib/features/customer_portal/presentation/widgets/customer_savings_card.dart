import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/customer_savings_model.dart';

class CustomerSavingsCard extends StatelessWidget {
  final CustomerSavingsModel savings;
  final VoidCallback? onTap;

  const CustomerSavingsCard({
    super.key,
    required this.savings,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = savings.progressPercentage / 100;

    return GlassCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.success.withValues(alpha: isDark ? 0.08 : 0.04),
                AppColors.mint.withValues(alpha: isDark ? 0.04 : 0.02),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    _buildSavingsIcon(isDark),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        savings.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    StatusBadge(
                      label: savings.status[0].toUpperCase() +
                          savings.status.substring(1),
                      type: savings.status == 'active'
                          ? StatusType.active
                          : StatusType.completed,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Balance row with progress ring
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Balance',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\u20b9${savings.currentAmount.toStringAsFixed(0)}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Target: \u20b9${savings.targetAmount.toStringAsFixed(0)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Progress ring mini-gauge
                    _buildProgressRing(
                      progress: progress,
                      color: AppColors.success,
                      isDark: isDark,
                      theme: theme,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                // Monthly deposit info
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(
                      alpha: isDark ? 0.12 : 0.06,
                    ),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.borderRadiusSm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 14,
                        color: AppColors.success.withValues(
                          alpha: isDark ? 0.8 : 0.7,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Monthly: \u20b9${savings.monthlyDeposit.toStringAsFixed(0)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.success.withValues(
                            alpha: isDark ? 0.8 : 0.7,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSavingsIcon(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.success.withValues(alpha: isDark ? 0.25 : 0.15),
            AppColors.mint.withValues(alpha: isDark ? 0.2 : 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: isDark ? 0.2 : 0.12),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.savings_rounded,
        color: AppColors.success,
        size: 20,
      ),
    );
  }

  Widget _buildProgressRing({
    required double progress,
    required Color color,
    required bool isDark,
    required ThemeData theme,
  }) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          CustomPaint(
            size: const Size(64, 64),
            painter: _ProgressRingPainter(
              progress: progress.clamp(0.0, 1.0),
              progressColor: color,
              backgroundColor: isDark
                  ? AppColors.fillDark
                  : AppColors.fillLight,
              strokeWidth: 5,
            ),
          ),
          // Percentage text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${savings.progressPercentage.toStringAsFixed(0)}%',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontSize: 14,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;
  final double strokeWidth;

  _ProgressRingPainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background ring
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor;
  }
}
