import 'package:supabase_flutter/supabase_flutter.dart';

class UpiService {
  final SupabaseClient _client;
  final String _orgId;

  UpiService(this._client, this._orgId);

  /// Builds a UPI intent URI for the given payment details.
  ///
  /// Uses minimal encoding per the NPCI UPI QR code specification.
  /// UPI apps expect literal `@` in VPAs and plain merchant names —
  /// full URL encoding (e.g. `%40` for `@`) breaks QR scanning.
  static String buildUpiUri({
    required String vpa,
    required double amount,
    required String merchantName,
    required String transactionNote,
  }) {
    String encode(String s) {
      // Only encode characters that are reserved in query strings.
      // Keep @ (VPA), #, spaces, and other text as-is for UPI app compatibility.
      return s
          .replaceAll('&', '%26')
          .replaceAll('=', '%3D')
          .replaceAll('+', '%2B');
    }

    final params = [
      'pa=${encode(vpa)}',
      'am=${amount.toStringAsFixed(2)}',
      'pn=${encode(merchantName)}',
      'tn=${encode(transactionNote)}',
      'cu=INR',
    ];
    return 'upi://pay?${params.join('&')}';
  }

  /// Basic VPA validation — must contain @
  static bool isValidVpa(String vpa) {
    return vpa.contains('@') && vpa.trim().isNotEmpty;
  }

  /// Reads the org's UPI config from organizations.settings JSONB.
  Future<Map<String, dynamic>?> getOrgVpa() async {
    try {
      final data = await _client
          .from('organizations')
          .select('settings')
          .eq('id', _orgId)
          .maybeSingle();
      if (data == null) return null;
      final settings = data['settings'] as Map<String, dynamic>?;
      if (settings == null) return null;
      final payment = settings['payment'] as Map<String, dynamic>?;
      return payment;
    } catch (_) {
      return null;
    }
  }

  /// Saves UPI config to organizations.settings JSONB under the "payment" key.
  Future<void> saveOrgVpa({
    required String vpa,
    required String merchantName,
  }) async {
    final data = await _client
        .from('organizations')
        .select('settings')
        .eq('id', _orgId)
        .maybeSingle();
    final settings = (data?['settings'] as Map<String, dynamic>?) ?? {};
    final updated = Map<String, dynamic>.from(settings);
    updated['payment'] = {
      'upi_vpa': vpa,
      'merchant_name': merchantName,
    };
    await _client
        .from('organizations')
        .update({'settings': updated}).eq('id', _orgId);
  }

  /// Checks if a pending UPI payment request exists for the given installment.
  Future<bool> hasPendingPayment({
    String? emiScheduleId,
    String? savingsPlanId,
    String? customerId,
  }) async {
    var query = _client
        .from('upi_payment_requests')
        .select('id')
        .eq('org_id', _orgId)
        .eq('status', 'pending');

    if (customerId != null) {
      query = query.eq('customer_id', customerId);
    }

    if (emiScheduleId != null) {
      query = query.eq('emi_schedule_id', emiScheduleId);
    } else if (savingsPlanId != null) {
      query = query.eq('savings_plan_id', savingsPlanId);
    } else {
      return false;
    }

    final data = await query.limit(1);
    return (data as List).isNotEmpty;
  }
}
