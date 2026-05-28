import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../repositories/customer_notifications_repository.dart';
import '../models/customer_notification_model.dart';
import 'customer_member_provider.dart';

final customerNotificationsRepositoryProvider =
    Provider<CustomerNotificationsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return CustomerNotificationsRepository(client);
});

final customerNotificationsProvider =
    FutureProvider<List<CustomerNotificationModel>>((ref) async {
  final customerId = ref.watch(currentCustomerIdSyncProvider);
  if (customerId == null) return [];
  final repository = ref.watch(customerNotificationsRepositoryProvider);
  return repository.getNotifications(customerId);
});

final customerUnreadCountProvider = FutureProvider<int>((ref) async {
  final customerId = ref.watch(currentCustomerIdSyncProvider);
  if (customerId == null) return 0;
  final repository = ref.watch(customerNotificationsRepositoryProvider);
  return repository.getUnreadCount(customerId);
});

class NotificationMarkReadNotifier extends StateNotifier<AsyncValue<void>> {
  final CustomerNotificationsRepository _repository;
  final Ref _ref;

  NotificationMarkReadNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  Future<void> markAsRead(String notificationId) async {
    try {
      await _repository.markAsRead(notificationId);
      _ref.invalidate(customerNotificationsProvider);
      _ref.invalidate(customerUnreadCountProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markAllAsRead(String customerId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.markAllAsRead(customerId);
      _ref.invalidate(customerNotificationsProvider);
      _ref.invalidate(customerUnreadCountProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final notificationMarkReadProvider = StateNotifierProvider<
    NotificationMarkReadNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(customerNotificationsRepositoryProvider);
  return NotificationMarkReadNotifier(repository, ref);
});
