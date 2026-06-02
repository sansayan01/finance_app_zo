import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer_notification_preferences.dart';

class CustomerNotificationPreferencesRepository {
  final SupabaseClient _client;
  final String _orgId;

  CustomerNotificationPreferencesRepository(this._client, this._orgId);

  Future<CustomerNotificationPreferences> getForCustomer(
    String customerId,
  ) async {
    final data = await _client
        .from('customer_notification_preferences')
        .select()
        .eq('customer_id', customerId)
        .maybeSingle();
    if (data == null) return CustomerNotificationPreferences.defaults;
    return CustomerNotificationPreferences.fromSupabaseJson(
      Map<String, dynamic>.from(data),
    );
  }

  Future<void> upsert(
    String customerId,
    CustomerNotificationPreferences prefs,
  ) async {
    await _client.from('customer_notification_preferences').upsert({
      'customer_id': customerId,
      'org_id': _orgId,
      ...prefs.toSupabaseJson(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
