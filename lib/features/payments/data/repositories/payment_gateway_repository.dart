import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment_order_model.dart';

class PaymentGatewayRepository {
  final SupabaseClient _client;
  final String _orgId;

  PaymentGatewayRepository(this._client, this._orgId);

  Future<PaymentOrder> createOrder({
    required String gateway,
    required double amount,
    String? loanId,
    String? savingsPlanId,
    String? emiScheduleId,
    Map<String, dynamic>? paymentDetails,
  }) async {
    final data = await _client
        .from('payment_orders')
        .insert({
          'org_id': _orgId,
          'gateway': gateway,
          if (loanId != null) 'loan_id': loanId,
          if (savingsPlanId != null) 'savings_plan_id': savingsPlanId,
          if (emiScheduleId != null) 'emi_schedule_id': emiScheduleId,
          'amount': amount,
          'currency': 'INR',
          'status': 'pending',
          'payment_details': paymentDetails ?? {},
        })
        .select()
        .single();
    return PaymentOrder.fromJson(data);
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
    String? gatewayOrderId,
    String? paymentMethod,
    Map<String, dynamic>? paymentDetails,
    String? confirmedBy,
  }) async {
    final updates = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (gatewayOrderId != null) updates['gateway_order_id'] = gatewayOrderId;
    if (paymentMethod != null) updates['payment_method'] = paymentMethod;
    if (paymentDetails != null) updates['payment_details'] = paymentDetails;
    if (confirmedBy != null) {
      updates['confirmed_by'] = confirmedBy;
      updates['confirmed_at'] = DateTime.now().toIso8601String();
    }
    await _client.from('payment_orders').update(updates).eq('id', orderId);
  }

  Future<List<PaymentOrder>> getOrders({String? status, int limit = 50}) async {
    var query = _client.from('payment_orders').select().eq('org_id', _orgId);
    if (status != null) query = query.eq('status', status);
    final data = await query.order('created_at', ascending: false).limit(limit);
    return (data as List).map((e) => PaymentOrder.fromJson(e)).toList();
  }

  Future<List<PaymentOrder>> getPendingOrders() => getOrders(status: 'pending');

  Future<List<PaymentOrder>> getOrdersForLoan(String loanId) async {
    final data = await _client
        .from('payment_orders')
        .select()
        .eq('org_id', _orgId)
        .eq('loan_id', loanId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => PaymentOrder.fromJson(e)).toList();
  }

  Future<List<PaymentOrder>> getOrdersForSavings(String savingsPlanId) async {
    final data = await _client
        .from('payment_orders')
        .select()
        .eq('org_id', _orgId)
        .eq('savings_plan_id', savingsPlanId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => PaymentOrder.fromJson(e)).toList();
  }
}
