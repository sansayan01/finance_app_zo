import 'package:flutter/material.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/customer_notification_model.dart';

class CustomerNotificationTile extends StatelessWidget {
  final CustomerNotificationModel notification;
  final VoidCallback? onTap;

  const CustomerNotificationTile({
    super.key,
    required this.notification,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final typeColor = _getTypeColor();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: typeColor.withValues(alpha: 0.06),
        highlightColor: typeColor.withValues(alpha: 0.03),
        child: Container(
          decoration: BoxDecoration(
            color: notification.isRead
                ? Colors.transparent
                : (isDark
                    ? typeColor.withValues(alpha: 0.06)
                    : typeColor.withValues(alpha: 0.03)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gradient bar on left for unread
              if (!notification.isRead)
                Container(
                  width: 3.5,
                  height: _estimateHeight(),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        typeColor,
                        typeColor.withValues(alpha: 0.4),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(2),
                      bottomRight: Radius.circular(2),
                    ),
                  ),
                ),
              // Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: notification.isRead ? AppSpacing.md : AppSpacing.sm + 2,
                    right: AppSpacing.md,
                    top: AppSpacing.sm + 2,
                    bottom: AppSpacing.sm + 2,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rounded icon container
                      _buildIconContainer(typeColor, isDark),
                      const SizedBox(width: AppSpacing.sm + 2),
                      // Title + message + time
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    notification.title,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: notification.isRead
                                          ? FontWeight.w500
                                          : FontWeight.w700,
                                      letterSpacing: -0.1,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Unread indicator dot
                                if (!notification.isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(left: 8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          typeColor,
                                          typeColor.withValues(alpha: 0.7),
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: typeColor.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 4,
                                          spreadRadius: 0,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notification.message,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (notification.createdAt != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                _formatTime(notification.createdAt!),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? AppColors.textTertiaryDark
                                      : AppColors.textTertiaryLight,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconContainer(Color color, bool isDark) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: isDark ? 0.25 : 0.15),
            color.withValues(alpha: isDark ? 0.12 : 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        _getTypeIcon(),
        color: color,
        size: 18,
      ),
    );
  }

  double _estimateHeight() {
    // Approximate height for the gradient bar
    double h = 12; // padding top
    h += 38; // icon height
    h += 6; // spacing
    return h;
  }

  Color _getTypeColor() {
    return switch (notification.type) {
      'payment_due' || 'emi_reminder' => AppColors.warning,
      'loan_approved' => AppColors.success,
      'savings_update' => AppColors.info,
      'collection_visit' => AppColors.accent,
      'kyc_update' => AppColors.teal,
      _ => AppColors.primaryLight,
    };
  }

  IconData _getTypeIcon() {
    return switch (notification.type) {
      'payment_due' || 'emi_reminder' => Icons.payment_rounded,
      'loan_approved' => Icons.check_circle_rounded,
      'savings_update' => Icons.savings_rounded,
      'collection_visit' => Icons.location_on_rounded,
      'kyc_update' => Icons.verified_user_rounded,
      _ => Icons.notifications_rounded,
    };
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
