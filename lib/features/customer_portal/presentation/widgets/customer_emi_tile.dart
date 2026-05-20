import 'package:flutter/material.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../data/models/customer_emi_model.dart';

class CustomerEmiTile extends StatelessWidget {
  final CustomerEmiModel emi;

  const CustomerEmiTile({super.key, required this.emi});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '${emi.emiNumber}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: Text(
              emi.dueDate != null
                  ? '${emi.dueDate!.day}/${emi.dueDate!.month}/${emi.dueDate!.year}'
                  : '-',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Text(
              '\u20b9${emi.emiAmount.toStringAsFixed(0)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 70,
            child: _buildStatusBadge(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (emi.isPaid) {
      return const StatusBadge(label: 'Paid', type: StatusType.completed);
    }
    if (emi.isOverdue) {
      return const StatusBadge(label: 'Overdue', type: StatusType.defaultStatus);
    }
    return const StatusBadge(label: 'Upcoming', type: StatusType.pending);
  }
}
