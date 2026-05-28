import 'package:flutter/material.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/progress_gauge.dart';
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

    return GlassCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: loan.isOverdue
                    ? AppColors.error
                    : AppColors.primary,
                width: 3.5,
              ),
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
                    _buildLoanIcon(isDark),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        loan.loanNumber ?? 'Loan',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    _buildStatusBadge(),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Info columns
                Row(
                  children: [
                    _buildInfoColumn(
                      context,
                      'Amount',
                      _formatCurrency(loan.amount),
                      isDark,
                    ),
                    _buildInfoColumn(
                      context,
                      'Outstanding',
                      _formatCurrency(loan.outstandingBalance),
                      isDark,
                    ),
                    _buildInfoColumn(
                      context,
                      'EMI',
                      _formatCurrency(loan.emiAmount),
                      isDark,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressBar(
                    value: loan.paidPercentage / 100,
                    height: 7,
                    backgroundColor: isDark
                        ? AppColors.fillDark
                        : AppColors.fillLight,
                    progressColor: loan.isOverdue
                        ? AppColors.error
                        : AppColors.success,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${loan.paidPercentage.toStringAsFixed(1)}% repaid',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (loan.purpose != null && loan.purpose!.isNotEmpty)
                      Text(
                        loan.purpose!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  Widget _buildLoanIcon(bool isDark) {
    final color = loan.isOverdue ? AppColors.error : AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.2 : 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        loan.isOverdue
            ? Icons.warning_rounded
            : Icons.account_balance_wallet_rounded,
        color: color,
        size: 18,
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

  Widget _buildInfoColumn(
    BuildContext context,
    String label,
    String value,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
              fontWeight: FontWeight.w500,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 100000) {
      return '\u20b9${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '\u20b9${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '\u20b9${amount.toStringAsFixed(0)}';
  }
}
