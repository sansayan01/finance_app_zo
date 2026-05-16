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
    final response = await _client
        .from('savings_plans')
        .insert({
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
        })
        .select('id')
        .single();

    return response['id'].toString();
  }

  Future<List<SavingsModel>> getActiveSavingsPlans({int limit = 50}) async {
    try {
      final response = await _client
          .from('savings_plans')
          .select('*, profiles:member_id(full_name)')
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
          .select('*, profiles:member_id(full_name)')
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
        memberName: json['profiles']?['full_name']?.toString() ?? 'Unknown',
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
      );
    }).toList();
  }

  Future<SavingsModel?> getSavingPlanById(String id) async {
    try {
      final response = await _client
          .from('savings_plans')
          .select('*, profiles:member_id(full_name)')
          .eq('id', id)
          .single();

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
}
