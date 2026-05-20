import 'package:flutter/material.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/progress_gauge.dart';
import '../../../../core/constants/app_spacing.dart';
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
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  loan.loanNumber ?? 'Loan',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildStatusBadge(),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _buildInfoColumn(context, 'Amount', _formatCurrency(loan.amount)),
              const SizedBox(width: AppSpacing.lg),
              _buildInfoColumn(
                  context, 'Outstanding', _formatCurrency(loan.outstandingBalance)),
              const SizedBox(width: AppSpacing.lg),
              _buildInfoColumn(
                  context, 'EMI', _formatCurrency(loan.emiAmount)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressBar(
            value: loan.paidPercentage / 100,
            height: 6,
            backgroundColor:
                theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            progressColor: loan.isOverdue
                ? Colors.red
                : theme.colorScheme.primary,
          ),
          const SizedBox(height: 4),
          Text(
            '${loan.paidPercentage.toStringAsFixed(1)}% repaid',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
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

  Widget _buildInfoColumn(BuildContext context, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
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
