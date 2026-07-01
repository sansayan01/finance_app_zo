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
    DateTime? installmentDate,
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
          if (installmentDate != null)
            'installment_date': _formatDateOnly(installmentDate),
          'amount': amount,
          'upi_vpa': upiVpa,
          'status': 'pending',
        })
        .select()
        .single();
    return UpiPaymentRequest.fromJson(data);
  }

  /// Postgres DATE column accepts YYYY-MM-DD. Strip any time component.
  static String _formatDateOnly(DateTime d) {
    final local = d.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
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
          'org_id': _orgId,
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
    final data = await query.order('created_at', ascending: false).limit(500);
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
  /// Returns the number of requests actually confirmed.
  Future<int> confirmBatch({
    required List<String> requestIds,
    required String confirmedBy,
  }) async {
    if (requestIds.isEmpty) return 0;

    // 1. Fetch all requests being confirmed
    final requestData = await _client
        .from('upi_payment_requests')
        .select()
        .inFilter('id', requestIds)
        .eq('status', 'pending');

    final requests = (requestData as List)
        .map((e) => UpiPaymentRequest.fromJson(e))
        .toList();

    if (requests.isEmpty) return 0;

    // 2. Resolve member_id from customer_id where member_id is null.
    //    customer_id = auth.uid(), member_id = members.id
    //    Chain: auth.uid() -> profiles.user_id -> profiles.id -> members.profile_id -> members.id
    final memberResolveCache = <String, String?>{}; // customer_id -> member_id

    // Collect unique customer_ids that need resolution
    final customerIdsToResolve = <String>{};
    for (final req in requests) {
      if (req.memberId != null && req.memberId!.isNotEmpty) continue;
      final customerId = req.customerId;
      if (customerId.isEmpty) continue;
      customerIdsToResolve.add(customerId);
    }

    if (customerIdsToResolve.isNotEmpty) {
      // Step A: auth.uid() -> profiles.id
      final profileIdMap = <String, String>{}; // user_id -> profile_id
      try {
        final profiles = await _client
            .from('profiles')
            .select('id, user_id')
            .inFilter('user_id', customerIdsToResolve.toList());
        for (final p in (profiles as List)) {
          final uid = p['user_id']?.toString() ?? '';
          final pid = p['id']?.toString() ?? '';
          if (uid.isNotEmpty && pid.isNotEmpty) {
            profileIdMap[uid] = pid;
          }
        }
      } catch (_) {}

      // Step B: profiles.id -> members.id
      final profileIds = profileIdMap.values.toSet().toList();
      if (profileIds.isNotEmpty) {
        try {
          final members = await _client
              .from('members')
              .select('id, profile_id')
              .inFilter('profile_id', profileIds);
          for (final m in (members as List)) {
            final mid = m['id']?.toString() ?? '';
            final pid = m['profile_id']?.toString() ?? '';
            if (mid.isNotEmpty && pid.isNotEmpty) {
              // Find the user_id (customer_id) that maps to this profile
              final userId = profileIdMap.entries
                  .where((e) => e.value == pid)
                  .map((e) => e.key)
                  .firstOrNull;
              if (userId != null) {
                memberResolveCache[userId] = mid;
              }
            }
          }
        } catch (_) {}
      }

      // Fill nulls for any customer_ids we couldn't resolve
      for (final cid in customerIdsToResolve) {
        memberResolveCache.putIfAbsent(cid, () => null);
      }
    }

    // Also look up member names for all resolved member_ids
    final allMemberIds = <String>{};
    for (final req in requests) {
      final memberId = req.memberId ??
          memberResolveCache[req.customerId];
      if (memberId != null && memberId.isNotEmpty) {
        allMemberIds.add(memberId);
      }
    }
    final memberNames = <String, String>{};
    if (allMemberIds.isNotEmpty) {
      final memberData = await _client
          .from('members')
          .select('id, full_name')
          .inFilter('id', allMemberIds.toList());
      for (final m in (memberData as List)) {
        memberNames[m['id']?.toString() ?? ''] =
            m['full_name']?.toString() ?? 'UPI Customer';
      }
    }

    // 3. Look up the confirmer's profile (id, name, role) from profiles
    //    profiles.id ≠ auth.users.id — staff_id FK references profiles.id
    String confirmerProfileId = confirmedBy; // fallback to auth.uid if lookup fails
    String confirmerName = 'UPI Confirmed';
    String confirmerRole = 'executiveAdmin';
    try {
      final profileData = await _client
          .from('profiles')
          .select('id, full_name, role')
          .eq('user_id', confirmedBy)
          .limit(1)
          .maybeSingle();
      if (profileData != null) {
        confirmerProfileId = profileData['id']?.toString() ?? confirmedBy;
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

    // 5. Create collection + transaction records using customer's payment time
    for (final req in requests) {
      final collectionDate = req.createdAt.toIso8601String().substring(0, 10);

      // Resolve member_id: prefer stored value, fall back to lookup from customer_id
      final resolvedMemberId = req.memberId ??
          memberResolveCache[req.customerId];
      final resolvedName = memberNames[resolvedMemberId] ?? 'UPI Customer';

      if (req.isLoanPayment) {
        // 5a. Create transaction (so exec admin / transactions page can see it)
        final txResult = await _client.from('transactions').insert({
          'member_id': resolvedMemberId,
          'member_name': resolvedName,
          'loan_id': req.loanId,
          'amount': req.amount,
          'type': 'emiPayment',
          'payment_mode': 'upi',
          'description': 'Loan EMI paid via UPI',
          'org_id': _orgId,
          'created_at': req.createdAt.toIso8601String(),
          'collected_by_name': confirmerName,
          'collected_by_role': confirmerRole,
          'collected_by_user_id': confirmerProfileId,
        }).select('id').single();
        final transactionId = txResult['id'] as String;

        // 5b. Create collection record (link selected_schedule_id so delete can find the EMI)
        await _client.from('collections').insert({
          'org_id': _orgId,
          'loan_id': req.loanId,
          'member_id': resolvedMemberId,
          'staff_id': confirmerProfileId,
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
          'transaction_id': transactionId,
          if (req.emiScheduleId != null && req.emiScheduleId!.isNotEmpty)
            'selected_schedule_id': req.emiScheduleId,
        });

        // 5c. Mark the EMI schedule row as paid
        //     If emiScheduleId is missing, auto-link to the next unpaid EMI
        String? scheduleIdToPay = req.emiScheduleId;
        if (scheduleIdToPay == null || scheduleIdToPay.isEmpty) {
          try {
            final nextEmi = await _client
                .from('emi_schedule')
                .select('id')
                .eq('loan_id', req.loanId!)
                .eq('is_paid', false)
                .order('due_date', ascending: true)
                .limit(1)
                .maybeSingle();
            if (nextEmi != null) {
              scheduleIdToPay = nextEmi['id']?.toString();
              // Backfill selected_schedule_id on the collection we just created
              if (scheduleIdToPay != null) {
                try {
                  await _client
                      .from('collections')
                      .update({'selected_schedule_id': scheduleIdToPay})
                      .eq('transaction_id', transactionId);
                } catch (_) {}
              }
            }
          } catch (_) {}
        }

        if (scheduleIdToPay != null && scheduleIdToPay.isNotEmpty) {
          try {
            await _client
                .from('emi_schedule')
                .update({
                  'is_paid': true,
                  'paid_date': collectionDate,
                  'paid_on': req.createdAt.toIso8601String(),
                  'amount_paid': req.amount,
                  'status': 'paid',
                })
                .eq('id', scheduleIdToPay);
          } catch (_) {}

          // 5d. Recalculate loan counters (paid_emis + outstanding_amount)
          try {
            await _client.rpc('recalculate_loan_outstanding', params: {
              'p_loan_id': req.loanId,
            });
          } catch (_) {}
        }
      } else if (req.isSavingsPayment) {
        // 5d. Create transaction (so exec admin / transactions page can see it)
        await _client.from('transactions').insert({
          'member_id': resolvedMemberId,
          'member_name': resolvedName,
          'savings_id': req.savingsPlanId,
          'amount': req.amount,
          'type': 'savingsDeposit',
          'payment_mode': 'upi',
          'description': 'Savings deposit via UPI',
          'org_id': _orgId,
          'created_at': req.createdAt.toIso8601String(),
        });

        // 5e. Create savings collection record
        await _client.from('savings_collections').insert({
          'org_id': _orgId,
          'savings_plan_id': req.savingsPlanId,
          'member_id': resolvedMemberId,
          'member_name': resolvedName,
          'amount_expected': req.amount,
          'amount_collected': req.amount,
          'is_partial': false,
          'payment_mode': 'upi',
          'collection_date': collectionDate,
          'collected_at': req.createdAt.toIso8601String(),
          'staff_id': confirmerProfileId,
          'collected_by_name': confirmerName,
          'collected_by_role': confirmerRole,
          'collected_by_user_id': confirmerProfileId,
          'sync_status': 'synced',
        });

        // 5f. Plan balance, installments_paid, last_payment_date, and
        //     next_due_date are now auto-updated by the PostgreSQL trigger
        //     trg_update_savings_plan_on_collection (server-side).
        //     No client-side update needed.
      }
    }
    return requests.length;
  }
}
