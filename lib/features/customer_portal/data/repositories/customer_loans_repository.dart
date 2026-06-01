import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer_loan_model.dart';
import '../models/customer_emi_model.dart';

class CustomerLoansRepository {
  final SupabaseClient _client;
  final String _orgId;

  CustomerLoansRepository(this._client, this._orgId);

  Future<List<CustomerLoanModel>> getCustomerLoans(String memberId) async {
    try {
      final data = await _client
          .from('loans')
          .select()
          .eq('customer_id', memberId)
          .eq('org_id', _orgId)
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) => CustomerLoanModel.fromJson(e))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<CustomerLoanModel?> getLoanById(String loanId) async {
    try {
      final data = await _client
          .from('loans')
          .select()
          .eq('id', loanId)
          .eq('org_id', _orgId)
          .maybeSingle();
      if (data == null) return null;
      return CustomerLoanModel.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<CustomerEmiModel>> getEmiSchedule(String loanId) async {
    try {
      final data = await _client
          .from('emi_schedule')
          .select()
          .eq('loan_id', loanId)
          .order('emi_number', ascending: true)
          .limit(100);
      return (data as List)
          .map((e) => CustomerEmiModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}
