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

    // 3. Loan balance is updated automatically by the SQL trigger
    //    `update_schedule_on_collection_v2` when collections are inserted.
    //    No client-side update needed.
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
    
    final collectionType = planResp['collection_type']?.toString() ?? 'monthly';
    final currentAmount = (planResp['current_amount'] as num?)?.toDouble() ?? 0.0;
    final installmentsPaid = (planResp['installments_paid'] as num?)?.toInt() ?? 0;

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

    // 3. Update plan balance and next_due_date
    final dueDate = payment.dueDate;
    DateTime nextDue;
    switch (collectionType) {
      case 'weekly':
        nextDue = dueDate.add(const Duration(days: 7));
        break;
      case 'monthly':
        int targetMonth = dueDate.month + 1;
        int targetYear = dueDate.year + ((targetMonth - 1) ~/ 12);
        targetMonth = ((targetMonth - 1) % 12) + 1;
        int targetDay = dueDate.day;
        int daysInMonth = DateTime(targetYear, targetMonth + 1, 0).day;
        if (targetDay > daysInMonth) targetDay = daysInMonth;
        nextDue = DateTime(targetYear, targetMonth, targetDay);
        break;
      default:
        nextDue = dueDate.add(const Duration(days: 1));
    }

    await client.from('savings_plans').update({
      'next_due_date': nextDue.toIso8601String().split('T').first,
      'current_amount': currentAmount + amount,
      'installments_paid': installmentsPaid + 1,
      'last_payment_date': today,
      'updated_at': now.toIso8601String(),
    }).eq('id', planId);
  }
}
