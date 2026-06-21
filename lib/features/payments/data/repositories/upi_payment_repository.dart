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

  /// Notifies all staff in the org about a new UPI payment request.
  /// Call once per payment action (not per installment).
  Future<void> notifyStaffUpiPayment({
    required double totalAmount,
    required String typeLabel,
  }) async {
    try {
      final staffData = await _client
          .from('staff_profiles')
          .select('id')
          .eq('org_id', _orgId);

      if ((staffData as List).isEmpty) return;

      for (final staff in staffData) {
        await _client.from('staff_notifications').insert({
          'staff_id': staff['id'],
          'title': 'New UPI Payment',
          'message':
              '₹${totalAmount.toStringAsFixed(2)} $typeLabel payment submitted via UPI. Tap to verify.',
          'type': 'upi',
          'priority': 'high',
          'action_type': 'open_upi_confirmations',
          'action_data': {},
        });
      }
    } catch (_) {
      // Non-critical — don't fail the payment if notification fails
    }
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
    if (status != null && status.isNotEmpty) {
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

  /// Confirms a batch of UPI requests and creates collection records.
  /// Uses each request's created_at as the collection_date (customer's payment time).
  Future<void> confirmBatch({
    required List<String> requestIds,
    required String confirmedBy,
  }) async {
    if (requestIds.isEmpty) return;

    // 1. Fetch all requests being confirmed
    final requestData = await _client
        .from('upi_payment_requests')
        .select()
        .inFilter('id', requestIds)
        .eq('status', 'pending');

    final requests = (requestData as List)
        .map((e) => UpiPaymentRequest.fromJson(e))
        .toList();

    if (requests.isEmpty) return;

    // 2. Look up member names for all unique member_ids
    final memberIds = requests
        .map((r) => r.memberId)
        .where((id) => id != null && id.isNotEmpty)
        .toSet()
        .toList();
    final memberNames = <String, String>{};
    if (memberIds.isNotEmpty) {
      final memberData = await _client
          .from('members')
          .select('id, full_name')
          .inFilter('id', memberIds);
      for (final m in (memberData as List)) {
        memberNames[m['id']?.toString() ?? ''] = m['full_name']?.toString() ?? 'UPI Customer';
      }
    }

    // 3. Look up the confirmer's role and name from profiles
    String confirmerName = 'UPI Confirmed';
    String confirmerRole = 'executiveAdmin';
    try {
      final profileData = await _client
          .from('profiles')
          .select('full_name, role')
          .eq('user_id', confirmedBy)
          .limit(1)
          .maybeSingle();
      if (profileData != null) {
        confirmerName = profileData['full_name']?.toString() ?? confirmerName;
        confirmerRole = profileData['role']?.toString() ?? confirmerRole;
      }
    } catch (_) {
      // Fall back to defaults if profile lookup fails
    }

    // 4. Update all request statuses to confirmed
    for (final req in requests) {
      await _client
          .from('upi_payment_requests')
          .update({
            'status': 'confirmed',
            'confirmed_by': confirmedBy,
            'confirmed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', req.id);
    }

    // 5. Create collection records using customer's payment time
    for (final req in requests) {
      final collectionDate = req.createdAt.toIso8601String().substring(0, 10);
      final resolvedName = memberNames[req.memberId] ?? 'UPI Customer';

      if (req.isLoanPayment) {
        await _client.from('collections').insert({
          'org_id': _orgId,
          'loan_id': req.loanId,
          'member_id': req.memberId,
          'staff_id': confirmedBy,
          'member_name': resolvedName,
          'amount_expected': req.amount,
          'amount_collected': req.amount,
          'is_partial': false,
          'payment_mode': 'upi',
          'collection_date': collectionDate,
          'collection_time': '${req.createdAt.hour.toString().padLeft(2, '0')}:${req.createdAt.minute.toString().padLeft(2, '0')}:${req.createdAt.second.toString().padLeft(2, '0')}',
          'gps_lat': 0.0,
          'gps_lng': 0.0,
          'sync_status': 'synced',
          'remarks': 'UPI payment confirmed — ID: ${req.id}',
        });
      } else if (req.isSavingsPayment) {
        await _client.from('savings_collections').insert({
          'org_id': _orgId,
          'savings_plan_id': req.savingsPlanId,
          'member_id': req.memberId,
          'member_name': resolvedName,
          'amount_expected': req.amount,
          'amount_collected': req.amount,
          'is_partial': false,
          'payment_mode': 'upi',
          'collection_date': collectionDate,
          'collected_at': req.createdAt.toIso8601String(),
          'staff_id': confirmedBy,
          'collected_by_name': confirmerName,
          'collected_by_role': confirmerRole,
          'collected_by_user_id': confirmedBy,
          'sync_status': 'synced',
        });
      }
    }
  }
}
