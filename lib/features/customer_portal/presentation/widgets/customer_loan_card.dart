import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/customer_loan_model.dart';

class CustomerLoanCard extends StatelessWidget {
  final CustomerLoanModel loan;
  final VoidCallback? onTap;

  const CustomerLoanCard({
    super.key,
    required this.loan,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = (loan.paidPercentage / 100).clamp(0.0, 1.0);
    final accentColor = loan.isOverdue ? AppColors.error : AppColors.primary;

    return GlassCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      borderRadius: 22,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentColor.withValues(alpha: isDark ? 0.08 : 0.04),
                isDark ? const Color(0xFF1A1F3A).withValues(alpha: 0.3) : Colors.white,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top section: Loan info + Progress ring
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Loan icon
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accentColor.withValues(alpha: isDark ? 0.25 : 0.15),
                            accentColor.withValues(alpha: isDark ? 0.15 : 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        loan.isOverdue
                            ? Icons.warning_rounded
                            : Icons.account_balance_rounded,
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Loan details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  loan.loanNumber ?? 'Loan',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStatusBadge(),
                            ],
                          ),
                          if (loan.purpose != null && loan.purpose!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              loan.purpose!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiaryLight,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Progress ring
                    _buildProgressRing(
                      progress: progress,
                      color: accentColor,
                      isDark: isDark,
                      theme: theme,
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.md),

                // Divider
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Metrics row
                Row(
                  children: [
                    _buildMetric(
                      context,
                      'Amount',
                      _formatCurrency(loan.amount),
                      Icons.receipt_long_rounded,
                      isDark,
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    _buildMetric(
                      context,
                      'Outstanding',
                      _formatCurrency(loan.outstandingBalance),
                      Icons.account_balance_wallet_rounded,
                      isDark,
                      valueColor: loan.outstandingBalance > 0
                          ? (isDark ? AppColors.warning : AppColors.warning)
                          : AppColors.success,
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    _buildMetric(
                      context,
                      'EMI',
                      _formatCurrency(loan.emiAmount),
                      Icons.calendar_month_rounded,
                      isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(56, 56),
            painter: _ProgressRingPainter(
              progress: progress,
              progressColor: color,
              backgroundColor: isDark
                  ? AppColors.fillDark
                  : AppColors.fillLight,
              strokeWidth: 5,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${loan.paidPercentage.toStringAsFixed(0)}%',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontSize: 13,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    bool isDark, {
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 12,
                color: (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)
                    .withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final statusType = switch (loan.status) {
      'active' => StatusType.active,
      'completed' || 'closed' => StatusType.completed,
      'defaultStatus' => StatusType.defaultStatus,
      'approved' => StatusType.pending,
      _ => StatusType.pending,
    };
    return StatusBadge(
      label: loan.status[0].toUpperCase() + loan.status.substring(1),
      type: statusType,
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 10000000) {
      return '\u20b9${(amount / 10000000).toStringAsFixed(2)}Cr';
    }
    if (amount >= 100000) {
      return '\u20b9${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '\u20b9${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '\u20b9${amount.toStringAsFixed(0)}';
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
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress.clamp(0.001, 1.0);

    // Background ring
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    if (progress > 0) {
      // Glow shadow
      final glowPaint = Paint()
        ..color = progressColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 3
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        glowPaint,
      );

      // Progress arc
      final progressPaint = Paint()
        ..shader = SweepGradient(
          colors: [
            progressColor.withValues(alpha: 0.7),
            progressColor,
            progressColor.withValues(alpha: 0.9),
          ],
          stops: const [0.0, 0.5, 1.0],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor;
  }
}
