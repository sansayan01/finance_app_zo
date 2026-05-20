import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer_loan_model.dart';
import '../models/customer_savings_model.dart';
import '../models/customer_transaction_model.dart';
import '../models/customer_emi_model.dart';

class CustomerHomeRepository {
  final SupabaseClient _client;
  final String _orgId;

  CustomerHomeRepository(this._client, this._orgId);

  Future<Map<String, dynamic>> getDashboardData(String memberId) async {
    try {
      final results = await Future.wait([
        _client
            .from('loans')
            .select()
            .eq('member_id', memberId)
            .eq('org_id', _orgId),
        _client
            .from('savings_plans')
            .select()
            .eq('member_id', memberId)
            .eq('org_id', _orgId),
        _client
            .from('transactions')
            .select()
            .eq('member_id', memberId)
            .eq('org_id', _orgId)
            .order('transaction_date', ascending: false)
            .limit(5),
        _client
            .from('members')
            .select('full_name, phone, kyc_status, area, village')
            .eq('id', memberId)
            .maybeSingle(),
      ]);

      final loansData = results[0] as List;
      final savingsData = results[1] as List;
      final transactionsData = results[2] as List;
      final memberData = results[3] as Map<String, dynamic>?;

      final loans = loansData
          .map((e) => CustomerLoanModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final savings = savingsData
          .map((e) => CustomerSavingsModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final transactions = transactionsData
          .map((e) => CustomerTransactionModel.fromJson(e))
          .toList();

      final activeLoans = loans.where((l) => l.status == 'active').toList();
      final totalOutstanding =
          activeLoans.fold(0.0, (sum, l) => sum + l.outstandingBalance);
      final totalSavings =
          savings.fold(0.0, (sum, s) => sum + s.currentAmount);

      // Find next EMI due
      CustomerEmiModel? nextEmi;
      for (final loan in activeLoans) {
        try {
          final emiData = await _client
              .from('emi_schedule')
              .select()
              .eq('loan_id', loan.id)
              .eq('is_paid', false)
              .order('due_date', ascending: true)
              .limit(1);
          if (emiData.isNotEmpty) {
            final emi =
                CustomerEmiModel.fromJson(emiData.first);
            if (nextEmi == null ||
                (emi.dueDate != null &&
                    nextEmi.dueDate != null &&
                    emi.dueDate!.isBefore(nextEmi.dueDate!))) {
              nextEmi = emi;
            }
          }
        } catch (_) {}
      }

      return {
        'memberName': memberData?['full_name'] as String? ?? 'Member',
        'memberPhone': memberData?['phone'] as String?,
        'kycStatus': memberData?['kyc_status'] as String?,
        'area': memberData?['area'] as String?,
        'village': memberData?['village'] as String?,
        'activeLoans': activeLoans.length,
        'totalOutstanding': totalOutstanding,
        'totalSavings': totalSavings,
        'nextEmi': nextEmi,
        'recentTransactions': transactions,
        'allLoans': loans,
        'allSavings': savings,
      };
    } catch (e) {
      rethrow;
    }
  }

  Future<List<CustomerTransactionModel>> getRecentTransactions(
      String memberId,
      {int limit = 5}) async {
    try {
      final data = await _client
          .from('transactions')
          .select()
          .eq('member_id', memberId)
          .eq('org_id', _orgId)
          .order('transaction_date', ascending: false)
          .limit(limit);
      return (data as List)
          .map((e) =>
              CustomerTransactionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }
}
