import 'package:flutter/material.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/constants/app_spacing.dart';
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
                  ticket.subject,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildStatusBadge(),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            ticket.message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _buildPriorityChip(theme),
              const Spacer(),
              if (ticket.createdAt != null)
                Text(
                  _formatDate(ticket.createdAt!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final statusType = switch (ticket.status) {
      'open' => StatusType.pending,
      'in_progress' || 'inProgress' => StatusType.warning,
      'resolved' || 'closed' => StatusType.completed,
      _ => StatusType.pending,
    };
    final label = switch (ticket.status) {
      'in_progress' || 'inProgress' => 'In Progress',
      _ => ticket.status[0].toUpperCase() + ticket.status.substring(1),
    };
    return StatusBadge(label: label, type: statusType);
  }

  Widget _buildPriorityChip(ThemeData theme) {
    final color = switch (ticket.priority) {
      'urgent' => Colors.red,
      'high' => Colors.orange,
      'normal' => theme.colorScheme.primary,
      'low' => Colors.grey,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        ticket.priority[0].toUpperCase() + ticket.priority.substring(1),
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
