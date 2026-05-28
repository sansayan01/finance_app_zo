import 'package:flutter/material.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/customer_emi_model.dart';

class CustomerEmiTile extends StatelessWidget {
  final CustomerEmiModel emi;

  const CustomerEmiTile({super.key, required this.emi});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isOverdue = emi.isOverdue && !emi.isPaid;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      decoration: BoxDecoration(
        // Subtle background for overdue
        color: isOverdue
            ? AppColors.error.withValues(alpha: isDark ? 0.08 : 0.04)
            : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? AppColors.separatorDark
                : AppColors.separatorLight,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // EMI number indicator
          _buildEmiNumber(isDark, isOverdue),
          const SizedBox(width: AppSpacing.sm + 4),
          // Date column
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emi.dueDate != null
                      ? '${_formatMonth(emi.dueDate!.month)} ${emi.dueDate!.day}, ${emi.dueDate!.year}'
                      : '-',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isOverdue
                        ? AppColors.error
                        : (isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight),
                  ),
                ),
                if (emi.isPaid && emi.paidOn != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Paid ${_formatPaidDate(emi.paidOn!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.success.withValues(
                          alpha: isDark ? 0.8 : 0.7,
                        ),
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Amount
          Expanded(
            child: Text(
              '\u20b9${emi.emiAmount.toStringAsFixed(0)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Status badge
          SizedBox(
            width: 74,
            child: _buildStatusBadge(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmiNumber(bool isDark, bool isOverdue) {
    final color = emi.isPaid
        ? AppColors.success
        : isOverdue
            ? AppColors.error
            : AppColors.primary;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSm),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.15),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: emi.isPaid
          ? const Icon(
              Icons.check_rounded,
              size: 18,
              color: AppColors.success,
            )
          : Text(
              '${emi.emiNumber}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
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

  String _formatMonth(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month];
  }

  String _formatPaidDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'today';
    if (dateOnly == today.subtract(const Duration(days: 1))) return 'yesterday';
    return 'on ${_formatMonth(date.month)} ${date.day}';
  }
}
