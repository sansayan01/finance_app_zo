import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/providers/notification_providers.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final notificationsAsync = ref.watch(allNotificationsProvider);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text('Notifications',
            style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allNotificationsProvider);
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: notificationsAsync.when(
          data: (notifications) {
            if (notifications.isEmpty) {
              return Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.06),
                            shape: BoxShape.circle),
                        child: Icon(Icons.notifications_none_rounded,
                            size: 56,
                            color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      const SizedBox(height: 20),
                      Text('No notifications',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.35))),
                      const SizedBox(height: 6),
                      Text('You\'re all caught up!',
                          style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.2))),
                    ]),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final n = notifications[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _getNotifColor(n['type'] as String? ?? '')
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(_getNotifIcon(n['type'] as String? ?? ''),
                              color: _getNotifColor(n['type'] as String? ?? ''),
                              size: 22),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                n['title'] as String? ?? 'Notification',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                n['message'] as String? ?? '',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _formatTime(n['created_at'] as String?),
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: AppColors.textTertiaryLight),
                        ),
                      ],
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: (index * 100).ms)
                    .slideX(begin: 0.05, end: 0);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
              child: Text('Could not load notifications',
                  style: TextStyle(color: theme.colorScheme.error))),
        ),
      ),
    );
  }

  IconData _getNotifIcon(String type) {
    switch (type) {
      case 'target':
        return Icons.flag_rounded;
      case 'overdue':
        return Icons.warning_amber_rounded;
      case 'sync':
        return Icons.sync_rounded;
      case 'alert':
        return Icons.notifications_active_rounded;
      case 'reminder':
        return Icons.notifications_rounded;
      case 'upi':
        return Icons.qr_code_scanner_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  Color _getNotifColor(String type) {
    switch (type) {
      case 'target':
        return AppColors.success;
      case 'overdue':
        return AppColors.error;
      case 'sync':
        return AppColors.info;
      case 'alert':
        return AppColors.warning;
      case 'reminder':
        return AppColors.primary;
      case 'upi':
        return const Color(0xFF00BFA5);
      default:
        return AppColors.primary;
    }
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      return '${diff.inDays}d';
    } catch (_) {
      return '';
    }
  }
}
