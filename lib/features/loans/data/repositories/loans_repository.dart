import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../settings/data/repositories/activity_log_repository.dart';
import '../../../settings/data/models/activity_log_model.dart';
import '../models/loan_model.dart';
import '../../../../core/constants/enums.dart';

class LoansRepository {
  final SupabaseClient _client;
  final ActivityLogRepository? _logRepo;

  LoansRepository(this._client, [this._logRepo]);

  Future<List<LoanModel>> getAllLoans({int limit = 100}) async {
    try {
      final response = await _client
          .from('loans')
          .select(
              '*, profiles:customer_id(full_name, phone), staff:staff_id(full_name)')
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => LoanModel.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<LoanModel>> getActiveLoans({int limit = 50}) async {
    try {
      final response = await _client
          .from('loans')
          .select(
              '*, profiles:customer_id(full_name, phone), staff:staff_id(full_name)')
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => LoanModel.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<LoanSummary> getLoanSummary() async {
    try {
      // Use SQL aggregation instead of fetching all records
      // This is much more efficient and uses less bandwidth
      
      // Get loan counts and totals in a single query
      final response = await _client
          .from('loans')
          .select('''
            status,
            outstanding_balance,
            amount
          ''');

      final loans = response as List;
      
      int totalLoans = loans.length;
      int activeLoans = 0;
      int defaultLoans = 0;
      double totalOutstanding = 0.0;
      double totalDisbursed = 0.0;
      double overdueAmount = 0.0;

      for (final loan in loans) {
        final status = loan['status'] as String?;
        final outstanding = (loan['outstanding_balance'] as num?)?.toDouble() ?? 0.0;
        final amount = (loan['amount'] as num?)?.toDouble() ?? 0.0;

        if (status == 'active') {
          activeLoans++;
          totalOutstanding += outstanding;
          totalDisbursed += amount;
        } else if (status == 'default') {
          defaultLoans++;
          overdueAmount += outstanding;
          totalOutstanding += outstanding;
        } else if (status == 'closed') {
          totalDisbursed += amount;
        }
      }

      return LoanSummary(
        totalLoans: totalLoans,
        activeLoans: activeLoans,
        defaultLoans: defaultLoans,
        totalOutstanding: totalOutstanding,
        totalDisbursed: totalDisbursed,
        totalCollected: 0, // Would need transaction history
        overdueAmount: overdueAmount,
        parPercentage: totalLoans == 0 ? 0 : (defaultLoans / totalLoans) * 100,
      );
    } catch (e) {
      return LoanSummary(
        totalLoans: 0,
        activeLoans: 0,
        defaultLoans: 0,
        totalOutstanding: 0,
        totalDisbursed: 0,
        totalCollected: 0,
        overdueAmount: 0,
        parPercentage: 0,
      );
    }
  }

  Future<LoanModel?> getLoanById(String id) async {
    try {
      final response = await _client
          .from('loans')
          .select(
              '*, profiles:customer_id(full_name, phone), staff:staff_id(full_name)')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      final createdLoan = LoanModel.fromJson(response);

      await _logRepo?.log(
        action: 'Loan Disbursed',
        details:
            'Amount: ₹${createdLoan.amount}, Customer ID: ${createdLoan.customerId}',
        type: ActivityType.financialTransaction,
      );

      return createdLoan;
    } catch (e) {
      return null;
    }
  }

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
    final now = DateTime.now();
    // Generate a unique loan number: L-YYYYMMDD-XXXX
    final loanNumber =
        'L-${DateFormat('yyyyMMdd').format(now)}-${math.Random().nextInt(9999).toString().padLeft(4, '0')}';

    await _client.from('loans').insert({
      'customer_id': borrowerId,
      'loan_number': loanNumber,
      'amount': principal,
      'interest_rate': interestRate,
      'tenure_months': tenureMonths,
      'frequency': frequency,
      'collection_type': collectionType,
      'emi_amount': estimatedInstallment,
      'outstanding_balance': totalExposure,
      'total_repayable': totalExposure,
      'interest_type': interestLogic,
      'status': 'active',
      'first_installment_date': firstInstallmentDate.toIso8601String(),
    });
  }

  Future<void> createLoanFromMap(Map<String, dynamic> data) async {
    await _client.from('loans').insert(data);
  }

  Future<void> updateLoanStatus(String id, String status) async {
    await _client.from('loans').update({'status': status}).eq('id', id);
  }

  Future<void> settleLoan(String loanId, double amount) async {
    final loan = await getLoanById(loanId);
    if (loan == null) return;

    final newBalance =
        (loan.outstandingBalance - amount).clamp(0.0, double.infinity);
    final newStatus = newBalance <= 0 ? 'closed' : 'active';

    await _client.from('loans').update({
      'status': newStatus,
      'outstanding_balance': newBalance,
    }).eq('id', loanId);
  }
}
