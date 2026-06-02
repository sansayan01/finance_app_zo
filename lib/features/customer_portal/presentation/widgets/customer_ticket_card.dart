import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/customer_ticket_model.dart';

class CustomerTicketCard extends StatelessWidget {
  final CustomerTicketModel ticket;
  final VoidCallback? onTap;

  const CustomerTicketCard({
    super.key,
    required this.ticket,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = _getStatusColor();
    final priorityColor = _getPriorityColor();

    return GlassCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gradient header accent
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    statusColor.withValues(alpha: isDark ? 0.3 : 0.15),
                    statusColor.withValues(alpha: isDark ? 0.1 : 0.05),
                  ],
                ),
              ),
              child: Row(
                children: [
                  // Status icon
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.borderRadiusSm),
                    ),
                    child: Icon(
                      _getStatusIcon(),
                      color: statusColor,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _getStatusLabel(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (ticket.createdAt != null)
                    Text(
                      _formatDate(ticket.createdAt!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: statusColor.withValues(alpha: 0.6),
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subject
                  Text(
                    ticket.subject,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Message preview
                  Text(
                    ticket.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Priority chip + assigned info
                  Row(
                    children: [
                      _buildPriorityChip(theme, priorityColor),
                      const Spacer(),
                      if (ticket.assignedTo != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 12,
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Assigned',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiaryLight,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    return switch (ticket.status) {
      'open' => AppColors.warning,
      'in_progress' || 'inProgress' => AppColors.info,
      'resolved' || 'closed' => AppColors.success,
      _ => AppColors.textSecondaryLight,
    };
  }

  IconData _getStatusIcon() {
    return switch (ticket.status) {
      'open' => Icons.mark_email_unread_rounded,
      'in_progress' || 'inProgress' => Icons.hourglass_top_rounded,
      'resolved' || 'closed' => Icons.check_circle_outline_rounded,
      _ => Icons.help_outline_rounded,
    };
  }

  String _getStatusLabel() {
    return switch (ticket.status) {
      'in_progress' || 'inProgress' => 'IN PROGRESS',
      'open' => 'OPEN',
      'resolved' => 'RESOLVED',
      'closed' => 'CLOSED',
      _ => ticket.status.toUpperCase(),
    };
  }

  Color _getPriorityColor() {
    return switch (ticket.priority) {
      'urgent' => AppColors.error,
      'high' => AppColors.orange,
      'normal' => AppColors.primary,
      'low' => AppColors.textTertiaryLight,
      _ => AppColors.textTertiaryLight,
    };
  }

  Widget _buildPriorityChip(ThemeData theme, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getPriorityIcon(),
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            ticket.priority[0].toUpperCase() + ticket.priority.substring(1),
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPriorityIcon() {
    return switch (ticket.priority) {
      'urgent' => Icons.error_outline_rounded,
      'high' => Icons.arrow_upward_rounded,
      'normal' => Icons.remove_rounded,
      'low' => Icons.arrow_downward_rounded,
      _ => Icons.remove_rounded,
    };
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }
}
