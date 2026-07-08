import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentGatewayService {
  final SupabaseClient _client;
  final String _orgId;

  PaymentGatewayService(this._client, this._orgId);

  Future<Map<String, dynamic>> getGatewayConfig() async {
    try {
      final data = await _client
          .from('organizations')
          .select('settings')
          .eq('id', _orgId)
          .maybeSingle();
      if (data == null) return <String, dynamic>{};
      final settings =
          data['settings'] as Map<String, dynamic>? ?? <String, dynamic>{};
      return (settings['payment_gateways'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> saveGatewayConfig({
    required String gateway,
    String? apiKey,
    String? apiSecret,
    String? webhookSecret,
    String? sandbox,
    String? saltIndex,
  }) async {
    final data = await _client
        .from('organizations')
        .select('settings')
        .eq('id', _orgId)
        .maybeSingle();
    final settings = Map<String, dynamic>.from(data?['settings'] as Map? ?? {});
    final gateways =
        Map<String, dynamic>.from(settings['payment_gateways'] as Map? ?? {});
    final gwConfig = <String, dynamic>{};
    if (apiKey != null) gwConfig['api_key'] = apiKey;
    if (apiSecret != null) gwConfig['api_secret'] = apiSecret;
    if (webhookSecret != null) gwConfig['webhook_secret'] = webhookSecret;
    if (sandbox != null) gwConfig['sandbox'] = sandbox;
    if (saltIndex != null) gwConfig['salt_index'] = saltIndex;
    gateways[gateway] = gwConfig;
    settings['payment_gateways'] = gateways;
    await _client
        .from('organizations')
        .update({'settings': settings}).eq('id', _orgId);
  }

  Future<void> deleteGatewayConfig(String gateway) async {
    final data = await _client
        .from('organizations')
        .select('settings')
        .eq('id', _orgId)
        .maybeSingle();
    final settings = Map<String, dynamic>.from(data?['settings'] as Map? ?? {});
    final gateways =
        Map<String, dynamic>.from(settings['payment_gateways'] as Map? ?? {});
    gateways.remove(gateway);
    settings['payment_gateways'] = gateways;
    await _client
        .from('organizations')
        .update({'settings': settings}).eq('id', _orgId);
  }

  Future<Map<String, dynamic>?> createPaymentLink({
    required String gateway,
    required double amount,
    String? loanId,
    String? savingsPlanId,
    String? emiScheduleId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? notes,
  }) async {
    try {
      final res = await _client.functions.invoke('create-payment-link', body: {
        'orgId': _orgId,
        'gateway': gateway,
        'amount': amount,
        if (loanId != null) 'loanId': loanId,
        if (savingsPlanId != null) 'savingsPlanId': savingsPlanId,
        if (emiScheduleId != null) 'emiScheduleId': emiScheduleId,
        if (customerName != null) 'customerName': customerName,
        if (customerPhone != null) 'customerPhone': customerPhone,
        if (customerEmail != null) 'customerEmail': customerEmail,
        if (notes != null) 'notes': notes,
      });
      if (res.data != null &&
          (res.data as Map<String, dynamic>)['success'] == true) {
        return res.data as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
