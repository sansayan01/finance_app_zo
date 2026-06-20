import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/upi_payment_request_model.dart';

class UpiPaymentRepository {
  final SupabaseClient _client;
  final String _orgId;

  UpiPaymentRepository(this._client, this._orgId);

  /// Creates a new pending UPI payment request.
  Future<UpiPaymentRequest> createRequest({
    required String customerId,
    String? memberId,
    String? loanId,
    String? savingsPlanId,
    String? emiScheduleId,
    required double amount,
    required String upiVpa,
  }) async {
    final data = await _client
        .from('upi_payment_requests')
        .insert({
          'org_id': _orgId,
          'customer_id': customerId,
          if (memberId != null) 'member_id': memberId,
          if (loanId != null) 'loan_id': loanId,
          if (savingsPlanId != null) 'savings_plan_id': savingsPlanId,
          if (emiScheduleId != null) 'emi_schedule_id': emiScheduleId,
          'amount': amount,
          'upi_vpa': upiVpa,
          'status': 'pending',
        })
        .select()
        .single();
    return UpiPaymentRequest.fromJson(data);
  }

  /// Checks if a pending payment already exists for this installment.
  Future<bool> checkExistingPending({
    String? emiScheduleId,
    String? savingsPlanId,
    required String customerId,
  }) async {
    var query = _client
        .from('upi_payment_requests')
        .select('id')
        .eq('org_id', _orgId)
        .eq('customer_id', customerId)
        .eq('status', 'pending');

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

  /// Gets pending UPI requests for the org (staff/admin/manager view).
  Future<List<UpiPaymentRequest>> getPendingRequests() async {
    final data = await _client
        .from('upi_payment_requests')
        .select()
        .eq('org_id', _orgId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => UpiPaymentRequest.fromJson(e))
        .toList();
  }

  /// Gets all UPI requests for the org with optional status filter.
  Future<List<UpiPaymentRequest>> getOrgRequests({String? status}) async {
    var query = _client
        .from('upi_payment_requests')
        .select()
        .eq('org_id', _orgId);
    if (status != null) {
      query = query.eq('status', status);
    }
    final data = await query.order('created_at', ascending: false).limit(100);
    return (data as List)
        .map((e) => UpiPaymentRequest.fromJson(e))
        .toList();
  }

  /// Gets UPI requests for a specific customer.
  Future<List<UpiPaymentRequest>> getCustomerRequests(String customerId) async {
    final data = await _client
        .from('upi_payment_requests')
        .select()
        .eq('org_id', _orgId)
        .eq('customer_id', customerId)
        .order('created_at', ascending: false)
        .limit(50);
    return (data as List)
        .map((e) => UpiPaymentRequest.fromJson(e))
        .toList();
  }

  /// Confirms a pending UPI payment request.
  Future<UpiPaymentRequest> confirmPayment({
    required String requestId,
    required String confirmedBy,
    String? transactionRef,
  }) async {
    final data = await _client
        .from('upi_payment_requests')
        .update({
          'status': 'confirmed',
          'confirmed_by': confirmedBy,
          'confirmed_at': DateTime.now().toIso8601String(),
          if (transactionRef != null) 'transaction_ref': transactionRef,
        })
        .eq('id', requestId)
        .eq('status', 'pending')
        .select()
        .single();
    return UpiPaymentRequest.fromJson(data);
  }

  /// Rejects a pending UPI payment request with a reason.
  Future<UpiPaymentRequest> rejectPayment({
    required String requestId,
    required String rejectionReason,
  }) async {
    final data = await _client
        .from('upi_payment_requests')
        .update({
          'status': 'rejected',
          'rejection_reason': rejectionReason,
        })
        .eq('id', requestId)
        .eq('status', 'pending')
        .select()
        .single();
    return UpiPaymentRequest.fromJson(data);
  }
}
