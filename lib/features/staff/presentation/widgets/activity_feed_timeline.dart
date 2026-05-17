import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/staff_providers.dart';

class ActivityFeedTimeline extends ConsumerWidget {
  const ActivityFeedTimeline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activitiesAsync = ref.watch(recentActivitiesProvider);

    return activitiesAsync.when(
      data: (activities) {
        if (activities.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.history_rounded,
                      size: 36,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                  const SizedBox(height: 8),
                  Text('No recent activity',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4))),
                ],
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history_rounded,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Recent Activity',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 16),
              ...activities.take(5).map((activity) {
                final action = activity['action'] as String? ?? '';
                final createdAt = activity['created_at'] as String?;
                final metadata = activity['metadata'] as Map<String, dynamic>?;
                final time =
                    createdAt != null ? DateTime.tryParse(createdAt) : null;

                return _buildActivityRow(theme, action, metadata, time);
              }),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildActivityRow(ThemeData theme, String action,
      Map<String, dynamic>? metadata, DateTime? time) {
    final (icon, label, color) = _getActivityInfo(theme, action, metadata);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (time != null)
            Text(
              _formatTime(time),
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 10),
            ),
        ],
      ),
    );
  }

  (IconData, String, Color) _getActivityInfo(
      ThemeData theme, String action, Map<String, dynamic>? metadata) {
    switch (action) {
      case 'collection_recorded':
      case 'collection':
        return (
          Icons.payments_rounded,
          'Collection recorded',
          AppColors.success
        );
      case 'visit_check_in':
        return (Icons.login_rounded, 'Visit check-in', AppColors.primary);
      case 'visit_check_out':
        return (Icons.logout_rounded, 'Visit completed', AppColors.primary);
      case 'break_start':
        final type = metadata?['break_type'] as String? ?? 'break';
        return (Icons.coffee_outlined, '$type started', Colors.orangeAccent);
      case 'break_end':
        return (Icons.coffee_outlined, 'Break ended', Colors.orangeAccent);
      case 'cash_deposit':
        final amount = metadata?['amount'] as double? ?? 0;
        return (
          Icons.account_balance_outlined,
          '₹${amount.toStringAsFixed(0)} deposited',
          AppColors.indigo
        );
      case 'sync_completed':
        return (Icons.cloud_done_outlined, 'Data synced', AppColors.success);
      default:
        return (
          Icons.circle_outlined,
          action.replaceAll('_', ' '),
          theme.colorScheme.onSurface
        );
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
