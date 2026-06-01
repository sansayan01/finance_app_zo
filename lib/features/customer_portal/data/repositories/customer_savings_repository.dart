import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer_savings_model.dart';
import '../models/customer_transaction_model.dart';

class CustomerSavingsRepository {
  final SupabaseClient _client;
  final String _orgId;

  CustomerSavingsRepository(this._client, this._orgId);

  Future<List<CustomerSavingsModel>> getCustomerSavings(String memberId) async {
    try {
      final data = await _client
          .from('savings_plans')
          .select()
          .eq('member_id', memberId)
          .eq('org_id', _orgId)
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) => CustomerSavingsModel.fromJson(e))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<CustomerSavingsModel?> getSavingsById(String savingsId) async {
    try {
      final data = await _client
          .from('savings_plans')
          .select()
          .eq('id', savingsId)
          .eq('org_id', _orgId)
          .maybeSingle();
      if (data == null) return null;
      return CustomerSavingsModel.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<CustomerTransactionModel>> getSavingsTransactions(
      String savingsId, {String? memberId}) async {
    try {
      var data = await _client
          .from('transactions')
          .select()
          .eq('savings_id', savingsId)
          .order('created_at', ascending: false)
          .limit(100);

      // Fallback: if no results and memberId provided, query by member_id + type
      if ((data as List).isEmpty && memberId != null) {
        data = await _client
            .from('transactions')
            .select()
            .eq('member_id', memberId)
            .inFilter('type', ['savingsDeposit', 'deposit'])
            .order('created_at', ascending: false)
            .limit(100);
      }

      return (data as List)
          .map((e) =>
              CustomerTransactionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}
