import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/today_payment_model.dart';

class AutoCollectionService {
  /// Auto-collects an EMI payment directly.
  static Future<void> autoCollectEmi({
    required SupabaseClient client,
    required String orgId,
    required String staffId,
    required TodayPayment payment,
  }) async {
    final now = DateTime.now();
    final today = now.toIso8601String().split('T').first;
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final amount = payment.amountExpected;

    String? staffName;
    String? staffRole;
    try {
      final p = await client
          .from('profiles')
          .select('full_name, role')
          .eq('id', staffId)
          .maybeSingle();
      if (p != null) {
        staffName = p['full_name']?.toString();
        staffRole = p['role']?.toString();
      }
    } catch (_) {}

    // 1. Insert transaction
    final txResult = await client.from('transactions').insert({
      'loan_id': payment.loanId,
      'member_id': payment.memberId,
      'member_name': payment.memberName,
      'type': 'emiPayment',
      'amount': amount,
      'payment_mode': 'cash',
      'description': 'EMI #${payment.emiNumber ?? ""} payment via cash (Auto)',
      'org_id': orgId,
      'created_at': now.toUtc().add(const Duration(hours: 5, minutes: 30)).toIso8601String().replaceFirst('Z', '+05:30'),
      'collected_by_name': staffName,
      'collected_by_role': staffRole,
      'collected_by_user_id': staffId,
    }).select('id').single();
    final transactionId = txResult['id'] as String;

    // 2. Insert collection
    await client.from('collections').insert({
      'org_id': orgId,
      'staff_id': staffId,
      'loan_id': payment.loanId,
      'member_id': payment.memberId,
      'member_name': payment.memberName,
      'member_phone': payment.memberPhone,
      'loan_number': payment.loanNumber,
      'amount_expected': amount,
      'amount_collected': amount,
      'is_partial': false,
      'collection_type': 'emi',
      'payment_mode': 'cash',
      'collection_date': today,
      'collection_time': timeStr,
      'sync_status': 'synced',
      'selected_schedule_id': payment.id,
      'transaction_id': transactionId,
    });

    // 3. Directly mark this EMI as paid in the schedule table.
    //    The SQL trigger `update_schedule_on_collection_v2` should do this,
    //    but may not fire reliably. Updating here ensures the provider sees
    //    `is_paid = true` immediately so the EMI doesn't appear in "Overdue".
    try {
      await client.from('emi_schedule').update({
        'is_paid': true,
        'paid_on': now.toIso8601String(),
        'payment_mode': 'cash',
        'is_overdue': false,
      }).eq('id', payment.id);
    } catch (_) {
      // Non-fatal: the SQL trigger may still handle it
    }
  }

  /// Auto-collects a Savings payment directly.
  static Future<void> autoCollectSavings({
    required SupabaseClient client,
    required String orgId,
    required String staffId,
    required String staffName,
    required String staffRole,
    required TodayPayment payment,
  }) async {
    final now = DateTime.now();
    final today = now.toIso8601String().split('T').first;
    final planId = payment.id.endsWith('_today')
        ? payment.id.substring(0, payment.id.length - 6)
        : payment.id;
    final amount = payment.amountExpected;

    // Fetch details of the savings plan
    final planResp = await client
        .from('savings_plans')
        .select()
        .eq('id', planId)
        .maybeSingle();

    if (planResp == null) {
      throw Exception('Savings plan not found');
    }
    
    // 1. Create transaction
    final txResult = await client.from('transactions').insert({
      'member_id': payment.memberId,
      'member_name': payment.memberName,
      'savings_id': planId,
      'amount': amount,
      'type': 'savingsDeposit',
      'payment_mode': 'cash',
      'description': '1 installment deposited via cash (Auto)',
      'org_id': orgId,
      'created_at': now.toUtc().add(const Duration(hours: 5, minutes: 30)).toIso8601String().replaceFirst('Z', '+05:30'),
    }).select('id').single();
    final transactionId = txResult['id'] as String;

    // 2. Record collection
    final collectedAt = now.toUtc().toIso8601String();
    await client.from('savings_collections').insert({
      'org_id': orgId,
      'savings_plan_id': planId,
      'member_id': payment.memberId,
      'member_name': payment.memberName,
      'amount_expected': amount,
      'amount_collected': amount,
      'is_partial': false,
      'payment_mode': 'cash',
      'collection_date': today,
      'collected_at': collectedAt,
      'staff_id': staffId,
      'collected_by_name': staffName,
      'collected_by_role': staffRole,
      'collected_by_user_id': staffId,
      'sync_status': 'synced',
      'transaction_id': transactionId,
    });

    // 3. Plan balance, installments_paid, last_payment_date, and
    //    next_due_date are now auto-updated by the PostgreSQL trigger
    //    trg_update_savings_plan_on_collection (server-side).
  }
}
