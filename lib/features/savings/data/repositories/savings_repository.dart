import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/enums.dart';
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
  }) async {
    // Calculate the first next_due_date based on collection type
    final now = DateTime.now();
    DateTime nextDueDate;
    int? collectionDayOfWeek;
    int? collectionDayOfMonth;

    switch (collectionType) {
      case 'daily':
        nextDueDate = DateTime(now.year, now.month, now.day)
            .add(const Duration(days: 1));
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
        nextDueDate = DateTime(now.year, now.month, now.day)
            .add(const Duration(days: 1));
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
      'next_due_date': nextDueDate.toIso8601String().split('T')[0],
    };

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

      return SavingsSummary(
        totalSavings: 0, // Needs real balance from transactions
        activeAccounts: plans.length,
        averageBalance: 0,
        interestEarned: 0,
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
    await _client.from('savings_plans').update({
      'current_amount': newBalance,
    }).eq('id', savingId);

    // 2. Record transaction
    await _client.from('transactions').insert({
      'member_id': saving.memberId,
      'member_name': saving.memberName,
      'savings_id': savingId,
      'amount': amount,
      'type': TransactionType.savingsDeposit.name,
      'org_id': _orgId,
      'description': 'Deposit into Savings Vault',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateSavingMetadata(
      String id, Map<String, dynamic> data) async {
    await _client.from('savings_plans').update(data).eq('id', id);
  }

  Future<void> deleteSavingPlan(String id) async {
    await _client.from('savings_plans').delete().eq('id', id);
  }

  /// Permanently deletes an RD/savings plan along with all of its
  /// dependent rows. Use with care — this is irreversible and removes
  /// the entire transaction history for the plan.
  Future<void> deleteSavingPlanCascade(String id) async {
    // 1. Detach transactions (FK is ON DELETE SET NULL but we delete
    //    them outright since they belong to this plan's history).
    await _client.from('transactions').delete().eq('savings_id', id);

    // 2. Delete collection records (FK is NO ACTION — must go first).
    await _client.from('savings_collections').delete().eq('savings_plan_id', id);

    // 3. Delete the plan itself.
    await _client.from('savings_plans').delete().eq('id', id);
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
      await _client
          .from('savings_plans')
          .update({'status': 'closed'}).eq('id', id);
    } else {
      await _client.from('savings_plans').delete().eq('id', id);
    }
  }

  Future<void> setSavingStatus(String id, String status) async {
    await _client.from('savings_plans').update({'status': status}).eq('id', id);
  }

  Future<void> recalculateBalance(String savingId) async {
    final rows = await _client
        .from('transactions')
        .select('type, amount')
        .eq('savings_id', savingId);

    double balance = 0;
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

    await _client
        .from('savings_plans')
        .update({'current_amount': balance}).eq('id', savingId);
  }
}
