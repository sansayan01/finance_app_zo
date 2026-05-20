import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/customer_notifications_providers.dart';
import '../../data/providers/customer_member_provider.dart';
import '../widgets/customer_notification_tile.dart';
import '../widgets/customer_empty_state.dart';

class CustomerNotificationsPage extends ConsumerWidget {
  const CustomerNotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(customerNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () {
              final customerId = ref.read(currentCustomerIdSyncProvider);
              if (customerId != null) {
                ref
                    .read(notificationMarkReadProvider.notifier)
                    .markAllAsRead(customerId);
              }
            },
            child: const Text('Mark All Read'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const CustomerEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No Notifications',
              subtitle: 'You\'re all caught up!',
            );
          }

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(customerNotificationsProvider),
            child: ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Theme.of(context)
                    .dividerColor
                    .withValues(alpha: 0.3),
              ),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return CustomerNotificationTile(
                  notification: notification,
                  onTap: !notification.isRead
                      ? () {
                          ref
                              .read(notificationMarkReadProvider.notifier)
                              .markAsRead(notification.id);
                        }
                      : null,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
