import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer_notification_model.dart';

class CustomerNotificationsRepository {
  final SupabaseClient _client;

  CustomerNotificationsRepository(this._client);

  Future<List<CustomerNotificationModel>> getNotifications(
      String customerId) async {
    try {
      final data = await _client
          .from('customer_notifications')
          .select()
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) =>
              CustomerNotificationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> markAsRead(String notificationId) async {
    await _client.from('customer_notifications').update({
      'is_read': true,
      'read_at': DateTime.now().toIso8601String(),
    }).eq('id', notificationId);
  }

  Future<void> markAllAsRead(String customerId) async {
    await _client.from('customer_notifications').update({
      'is_read': true,
      'read_at': DateTime.now().toIso8601String(),
    }).eq('customer_id', customerId).eq('is_read', false);
  }

  Future<int> getUnreadCount(String customerId) async {
    try {
      final data = await _client
          .from('customer_notifications')
          .select('id')
          .eq('customer_id', customerId)
          .eq('is_read', false);
      return (data as List).length;
    } catch (e) {
      return 0;
    }
  }
}
