import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/utils/formatters.dart' show AppFormatters;
import '../models/savings_model.dart';

class SavingsRepository {
  final SupabaseClient _client;
  final String _orgId;
  SavingsRepository(this._client, this._orgId);

  Future<String> createSavingsPlan({
    required String memberId,
    required double installmentAmount,
    required double maturityAmount,
    required DateTime maturityDate,
    required String collectionType,
    required double penalty,
    required int totalInstallments,
    DateTime? startDate,
    int tenure = 12,
    String? tenureUnit,
    double openingBalance = 0,
  }) async {
    // Use provided start date or default to today
    final now = startDate ?? DateTime.now();
    DateTime nextDueDate;
    int? collectionDayOfWeek;
    int? collectionDayOfMonth;

    switch (collectionType) {
      case 'daily':
        nextDueDate = DateTime(now.year, now.month, now.day);
        break;
      case 'weekly':
        nextDueDate = DateTime(now.year, now.month, now.day)
            .add(const Duration(days: 7));
        collectionDayOfWeek = nextDueDate.weekday - 1; // 0=Mon, 6=Sun
        break;
      case 'monthly':
        nextDueDate = DateTime(now.year, now.month + 1, now.day);
        collectionDayOfMonth = now.day;
        break;
      default:
        nextDueDate = DateTime(now.year, now.month, now.day);
    }

    // Verify member exists before insert (FK fk_splans_member → members.id)
    final memberExists = await _client
        .from('members')
        .select('id')
        .eq('id', memberId)
        .maybeSingle();
    if (memberExists == null) {
      throw Exception(
          'Selected member no longer exists. Please refresh and try again.');
    }

    final insertData = <String, dynamic>{
      'member_id': memberId,
      'org_id': _orgId,
      'monthly_deposit': installmentAmount,
      'maturity_amount': maturityAmount,
      'maturity_date': maturityDate.toIso8601String().split('T')[0],
      'collection_type': collectionType,
      'premature_penalty': penalty,
      'total_installments': totalInstallments,
      'target_amount': maturityAmount,
      'status': 'active',
      'start_date': now.toIso8601String().split('T')[0],
      'next_due_date': nextDueDate.toIso8601String().split('T')[0],
      'tenure': tenure,
      'opening_balance': openingBalance,
      'current_amount': openingBalance,
    };

    if (tenureUnit != null) {
      insertData['tenure_unit'] = tenureUnit;
    }

    if (collectionDayOfWeek != null) {
      insertData['collection_day_of_week'] = collectionDayOfWeek;
    }
    if (collectionDayOfMonth != null) {
      insertData['collection_day_of_month'] = collectionDayOfMonth;
    }

    final response = await _client
        .from('savings_plans')
        .insert(insertData)
        .select('id')
        .maybeSingle();

    if (response == null) {
      throw Exception('Failed to create savings plan');
    }

    return response['id'].toString();
  }

  Future<List<SavingsModel>> getActiveSavingsPlans({int limit = 50}) async {
    try {
      final response = await _client
          .from('savings_plans')
          .select('*, members:member_id(full_name)')
          .eq('org_id', _orgId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(limit);

      return _mapSavingsList(response);
    } catch (e) {
      return [];
    }
  }

  Future<List<SavingsModel>> getAllSavingsPlans({int limit = 50}) async {
    try {
      final response = await _client
          .from('savings_plans')
          .select('*, members:member_id(full_name)')
          .eq('org_id', _orgId)
          .order('created_at', ascending: false)
          .limit(limit);

      return _mapSavingsList(response);
    } catch (e) {
      return [];
    }
  }

  List<SavingsModel> _mapSavingsList(dynamic response) {
    return (response as List).map((json) {
      return SavingsModel(
        id: json['id']?.toString() ?? '',
        memberId: json['member_id']?.toString() ?? '',
        memberName: json['members']?['full_name']?.toString() ?? 'Unknown',
        planName: json['plan_name']?.toString() ?? 'Recurring Deposit',
        targetAmount: (json['target_amount'] as num?)?.toDouble() ?? 0,
        currentAmount: (json['current_amount'] as num?)?.toDouble() ?? 0,
        monthlyDeposit: (json['monthly_deposit'] as num?)?.toDouble() ?? 0,
        interestRate: (json['interest_rate'] as num?)?.toDouble() ?? 0,
        maturityDate:
            DateTime.tryParse(json['maturity_date']?.toString() ?? '') ??
                DateTime.now(),
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
        status: json['status']?.toString() ?? 'active',
        collectionType: json['collection_type']?.toString() ?? 'monthly',
        prematurePenalty:
            (json['premature_penalty'] as num?)?.toDouble() ?? 2.0,
        totalInstallments: (json['total_installments'] as num?)?.toInt() ?? 12,
        maturityAmount: (json['maturity_amount'] as num?)?.toDouble() ?? 0.0,
        nextDueDate: json['next_due_date'] != null
            ? DateTime.tryParse(json['next_due_date'].toString())
            : null,
        startDate: json['start_date'] != null
            ? DateTime.tryParse(json['start_date'].toString())
            : null,
        tenureUnit: json['tenure_unit']?.toString(),
        tenure: (json['tenure'] as num?)?.toInt() ?? 12,
        openingBalance: (json['opening_balance'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  Future<List<SavingsModel>> getPlansByMemberId(String memberId) async {
    try {
      final response = await _client
          .from('savings_plans')
          .select('*, members:member_id(full_name)')
          .eq('org_id', _orgId)
          .eq('member_id', memberId)
          .order('created_at', ascending: false);

      return _mapSavingsList(response);
    } catch (e) {
      return [];
    }
  }

  Future<SavingsModel?> getSavingPlanById(String id) async {
    try {
      final response = await _client
          .from('savings_plans')
          .select('*, members:member_id(full_name)')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return _mapSavingsList([response]).first;
    } catch (e) {
      return null;
    }
  }

  Future<SavingsSummary> getSavingsSummary() async {
    try {
      final plans = await getActiveSavingsPlans();
      final totalSavings = plans.fold<double>(0, (sum, p) => sum + p.currentAmount);
      final averageBalance = plans.isEmpty ? 0.0 : totalSavings / plans.length;
      // Estimated interest = sum of (current_amount - opening_balance) across all plans
      final interestEarned = plans.fold<double>(
          0, (sum, p) => sum + (p.currentAmount - p.openingBalance).clamp(0.0, double.infinity));

      return SavingsSummary(
        totalSavings: totalSavings,
        activeAccounts: plans.length,
        averageBalance: averageBalance,
        interestEarned: interestEarned,
      );
    } catch (e) {
      return SavingsSummary(
        totalSavings: 0,
        activeAccounts: 0,
        averageBalance: 0,
        interestEarned: 0,
      );
    }
  }

  Future<List<SavingsModel>> getPendingDeposits({int limit = 10}) async {
    // For now, return same as active since we don't have a separate table for collection schedule
    return getActiveSavingsPlans(limit: limit);
  }

  Future<void> recordDeposit(String savingId, double amount) async {
    final saving = await getSavingPlanById(savingId);
    if (saving == null) return;

    final newBalance = saving.currentAmount + amount;

    // 1. Update savings plan balance
    final updateResult = await _client.from('savings_plans').update({
      'current_amount': newBalance,
    }).eq('id', savingId).select();
    if (updateResult.isEmpty) {
      throw Exception('Failed to update savings plan balance - not found or access denied');
    }

    // 2. Record transaction
    await _client.from('transactions').insert({
      'member_id': saving.memberId,
      'member_name': saving.memberName,
      'savings_id': savingId,
      'amount': amount,
      'type': TransactionType.savingsDeposit.name,
      'org_id': _orgId,
      'description': 'Deposit into Savings Vault',
      'created_at': AppFormatters.nowIST(),
    });
  }

  Future<void> updateSavingMetadata(
      String id, Map<String, dynamic> data) async {
    final result = await _client.from('savings_plans').update(data).eq('id', id).select();
    if (result.isEmpty) {
      throw Exception('Update failed: no rows affected. Check permissions or saving ID.');
    }
  }

  Future<void> deleteSavingPlan(String id) async {
    final result = await _client.from('savings_plans').delete().eq('id', id).select();
    if (result.isEmpty) {
      throw Exception('Failed to delete savings plan - not found or access denied');
    }
  }

  /// Permanently deletes an RD/savings plan along with all of its
  /// dependent rows. Use with care — this is irreversible and removes
  /// the entire transaction history for the plan.
  Future<void> deleteSavingPlanCascade(String id) async {
    // 1. Delete collection records first (FK safety — FK is NO ACTION,
    //    must be removed before the parent transaction/plan).
    await _client.from('savings_collections').delete().eq('savings_plan_id', id).select();

    // 2. Delete transactions (belong to this plan's history).
    await _client.from('transactions').delete().eq('savings_id', id).select();

    // 3. Delete the plan itself.
    final result = await _client.from('savings_plans').delete().eq('id', id).select();
    if (result.isEmpty) {
      throw Exception('Failed to delete savings plan cascade - plan not found');
    }
  }

  /// Closes a savings/RD plan.
  ///
  /// Plans with any collection history cannot be hard-deleted (FK from
  /// `savings_collections` would block it), so we soft-close by setting
  /// status = 'closed'. If the plan has no history, we hard-delete to
  /// keep the table clean.
  Future<void> closeSavingPlan(String id) async {
    final collections = await _client
        .from('savings_collections')
        .select('id')
        .eq('savings_plan_id', id)
        .limit(1);

    final hasHistory = (collections as List).isNotEmpty;

    if (hasHistory) {
      final result = await _client
          .from('savings_plans')
          .update({'status': 'closed'}).eq('id', id).select();
      if (result.isEmpty) {
        throw Exception('Failed to close savings plan - not found or access denied');
      }
    } else {
      final result = await _client.from('savings_plans').delete().eq('id', id).select();
      if (result.isEmpty) {
        throw Exception('Failed to delete savings plan - not found or access denied');
      }
    }
  }

  Future<void> setSavingStatus(String id, String status) async {
    final result = await _client.from('savings_plans').update({'status': status}).eq('id', id).select();
    if (result.isEmpty) {
      throw Exception('Failed to set savings status - not found or access denied');
    }
  }

  Future<void> recalculateBalance(String savingId) async {
    // Prefer the SECURITY DEFINER RPC — it bypasses RLS so the recalc
    // can't silently fail when a manager/agent deletes a transaction.
    try {
      final res = await _client.rpc('recalculate_savings_balance', params: {
        'p_savings_id': savingId,
      });
      final ok = res is Map && res['success'] == true;
      if (ok) return;
    } catch (_) {
      // RPC not deployed yet — fall through to client-side recalc
    }

    // Read plan metadata
    final plan = await _client
        .from('savings_plans')
        .select('''
          opening_balance,
          collection_type,
          start_date
        ''')
        .eq('id', savingId)
        .maybeSingle();
    final openingBalance =
        (plan?['opening_balance'] as num?)?.toDouble() ?? 0;
    final collectionType = plan?['collection_type'] as String? ?? 'monthly';
    final startDateStr = plan?['start_date'] as String?;

    // Recalculate current_amount from remaining transactions
    final rows = await _client
        .from('transactions')
        .select('type, amount')
        .eq('savings_id', savingId);

    double balance = openingBalance;
    for (final r in rows as List) {
      final t = r['type'] as String?;
      final amt = (r['amount'] as num?)?.toDouble() ?? 0;
      if (t == TransactionType.savingsWithdrawal.name) {
        balance -= amt;
      } else {
        balance += amt;
      }
    }
    if (balance < 0) balance = 0;

    // Recalculate next_due_date based on remaining collection history
    final lastCollection = await _client
        .from('savings_collections')
        .select('collection_date')
        .eq('savings_plan_id', savingId)
        .order('collection_date', ascending: false)
        .limit(1)
        .maybeSingle();

    DateTime? newNextDue;
    if (lastCollection != null && lastCollection['collection_date'] != null) {
      final lastDate = DateTime.parse(lastCollection['collection_date'] as String);
      switch (collectionType.toLowerCase()) {
        case 'daily':
          newNextDue = lastDate.add(const Duration(days: 1));
          break;
        case 'weekly':
          newNextDue = lastDate.add(const Duration(days: 7));
          break;
        default:
          newNextDue = DateTime(lastDate.year, lastDate.month + 1, lastDate.day);
      }
    } else if (startDateStr != null) {
      // No collections left — revert to start_date
      newNextDue = DateTime.parse(startDateStr);
    }

    final updateData = <String, dynamic>{
      'current_amount': balance,
    };
    if (newNextDue != null) {
      updateData['next_due_date'] = newNextDue.toIso8601String().split('T').first;
    }

    final result = await _client
        .from('savings_plans')
        .update(updateData).eq('id', savingId).select();
    if (result.isEmpty) {
      throw Exception('Failed to recalculate balance - savings plan not found or access denied');
    }
  }

  /// Delete a savings collection by [savingsCollectionId].
  /// Finds the matching transaction and delegates to the RPC (with fallback).
  Future<void> deleteSavingsCollection(String savingsCollectionId) async {
    // Fetch the savings collection to get linked transaction_id and plan info
    final collection = await _client
        .from('savings_collections')
        .select('savings_plan_id, amount_collected, member_id, transaction_id')
        .eq('id', savingsCollectionId)
        .maybeSingle();
    if (collection == null) {
      throw Exception('Savings collection not found');
    }

    final savingsPlanId = collection['savings_plan_id'] as String?;
    final amount = (collection['amount_collected'] as num?)?.toDouble() ?? 0;
    final memberId = collection['member_id'] as String?;
    final linkedTxId = collection['transaction_id'] as String?;

    if (savingsPlanId == null) {
      throw Exception('Savings collection has no savings_plan_id');
    }

    // Find the linked transaction — prefer transaction_id, fall back to amount match
    String? txId = linkedTxId;
    if (txId == null) {
      final tx = await _client
          .from('transactions')
          .select('id')
          .eq('savings_id', savingsPlanId)
          .eq('amount', amount)
          .eq('member_id', memberId ?? '')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      txId = tx?['id'] as String?;
    }

    // Try RPC first (handles collection + transaction + recalc in one shot)
    if (txId != null) {
      try {
        await _client.rpc('delete_savings_transaction', params: {
          'p_transaction_id': txId,
        });
        return;
      } catch (_) {
        // RPC failed — fall through to manual deletion
      }
    }

    // Fallback: delete collection + transaction + recalculate
    await _client
        .from('savings_collections')
        .delete()
        .eq('id', savingsCollectionId);

    if (txId != null) {
      await _client
          .from('transactions')
          .delete()
          .eq('id', txId);
    }

    await recalculateBalance(savingsPlanId);
  }
}
