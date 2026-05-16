import 'package:supabase_flutter/supabase_flutter.dart';

class LoanRepository {
  final SupabaseClient _client;
  final String _orgId;
  LoanRepository(this._client, this._orgId);

  Future<void> createLoan({
    required String borrowerId,
    required double principal,
    required double interestRate,
    required int tenureMonths,
    required String frequency,
    required String collectionType,
    required String interestLogic,
    required DateTime firstInstallmentDate,
    required double estimatedInstallment,
    required double totalExposure,
  }) async {
    await _client.from('loans').insert({
      'customer_id': borrowerId,
      'amount': principal,
      'interest_rate': interestRate,
      'tenure_months': tenureMonths,
      'frequency': frequency,
      'collection_type': collectionType,
      'interest_type': interestLogic,
      'first_installment_date': firstInstallmentDate.toIso8601String(),
      'emi_amount': estimatedInstallment,
      'outstanding_balance': totalExposure,
      'outstanding_amount': totalExposure,
      'total_repayable': totalExposure,
      'status': 'active',
      'org_id': _orgId,
    });
  }

  Future<List<Map<String, dynamic>>> getLoans() async {
    final response = await _client
        .from('loans')
        .select('*, profiles:customer_id(full_name)')
        .eq('org_id', _orgId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> settleLoan(String loanId) async {
    await _client.from('loans').update({
      'status': 'closed',
      'outstanding_balance': 0,
      'outstanding_amount': 0,
    }).eq('id', loanId);
  }
}
