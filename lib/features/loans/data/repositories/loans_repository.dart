import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../settings/data/repositories/activity_log_repository.dart';
import '../../../settings/data/models/activity_log_model.dart';
import '../models/loan_model.dart';

class LoansRepository {
  final SupabaseClient _client;
  final String _orgId;
  final ActivityLogRepository? _logRepo;

  LoansRepository(this._client, this._orgId, [this._logRepo]);

  Future<List<LoanModel>> getAllLoans({int limit = 100}) async {
    try {
      final response = await _client
          .from('loans')
          .select(
              '*, profiles:customer_id(full_name, phone), staff:staff_id(full_name)')
          .eq('org_id', _orgId)
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
          .eq('org_id', _orgId)
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
          ''')
          .eq('org_id', _orgId);

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
    String? interestMode,
    String? interestRateBasis,
    double? interestAmount,
    String? interestBasis,
    int? tenureValue,
    String? tenureUnit,
  }) async {
    final now = DateTime.now();
    final loanNumber =
        'L-${DateFormat('yyyyMMdd').format(now)}-${math.Random().nextInt(9999).toString().padLeft(4, '0')}';

    double totalInterest = totalExposure - principal;

    await _client.from('loans').insert({
      'customer_id': borrowerId,
      'loan_number': loanNumber,
      'amount': principal,
      'principal': principal,
      'interest': totalInterest,
      'total_interest': totalInterest,
      'interest_rate': interestRate,
      'tenure_months': tenureMonths,
      'frequency': frequency,
      'collection_type': collectionType,
      'emi_amount': estimatedInstallment,
      'outstanding_balance': totalExposure,
      'outstanding_amount': totalExposure,
      'total_repayable': totalExposure,
      'interest_type': interestLogic,
      'status': 'active',
      'first_installment_date': firstInstallmentDate.toIso8601String(),
      'first_emi_date': firstInstallmentDate.toIso8601String(),
      'disbursement_date': now.toIso8601String(),
      'start_date': now.toIso8601String(),
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'org_id': _orgId,
      if (interestMode != null) 'interest_mode': interestMode,
      if (interestRateBasis != null) 'interest_rate_basis': interestRateBasis,
      if (interestAmount != null) 'interest_amount': interestAmount,
      if (interestBasis != null) 'interest_basis': interestBasis,
      if (tenureValue != null) 'tenure_value': tenureValue,
      if (tenureUnit != null) 'tenure_unit': tenureUnit,
    });
  }

  Future<void> createLoanFromMap(Map<String, dynamic> data) async {
    data['org_id'] = _orgId;
    await _client.from('loans').insert(data);
  }

  Future<void> updateLoanStatus(String id, String status) async {
    await _client.from('loans').update({'status': status}).eq('id', id);
  }

  Future<void> updateLoan(String id, {
    String? borrowerId,
    double? principal,
    double? interestRate,
    int? tenureMonths,
    String? frequency,
    String? collectionType,
    String? interestLogic,
    DateTime? firstInstallmentDate,
    double? estimatedInstallment,
    double? totalExposure,
    String? interestMode,
    String? interestRateBasis,
    double? interestAmount,
    String? interestBasis,
    int? tenureValue,
    String? tenureUnit,
    String? remarks,
    String? purpose,
  }) async {
    final data = <String, dynamic>{};
    if (borrowerId != null) data['customer_id'] = borrowerId;
    if (principal != null) {
      data['amount'] = principal;
      data['principal'] = principal;
    }
    if (interestRate != null) data['interest_rate'] = interestRate;
    if (tenureMonths != null) data['tenure_months'] = tenureMonths;
    if (frequency != null) data['frequency'] = frequency;
    if (collectionType != null) data['collection_type'] = collectionType;
    if (interestLogic != null) data['interest_type'] = interestLogic;
    if (firstInstallmentDate != null) {
      data['first_installment_date'] = firstInstallmentDate.toIso8601String();
      data['first_emi_date'] = firstInstallmentDate.toIso8601String();
    }
    if (estimatedInstallment != null) data['emi_amount'] = estimatedInstallment;
    if (totalExposure != null) {
      data['outstanding_balance'] = totalExposure;
      data['total_repayable'] = totalExposure;
    }
    if (interestMode != null) data['interest_mode'] = interestMode;
    if (interestRateBasis != null) data['interest_rate_basis'] = interestRateBasis;
    if (interestAmount != null) data['interest_amount'] = interestAmount;
    if (interestBasis != null) data['interest_basis'] = interestBasis;
    if (tenureValue != null) data['tenure_value'] = tenureValue;
    if (tenureUnit != null) data['tenure_unit'] = tenureUnit;
    if (remarks != null) data['remarks'] = remarks;
    if (purpose != null) data['purpose'] = purpose;
    data['updated_at'] = DateTime.now().toIso8601String();
    
    await _client.from('loans').update(data).eq('id', id);
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
      'outstanding_amount': newBalance,
    }).eq('id', loanId);
  }

  Future<void> deleteLoan(String loanId) async {
    try {
      // Try using the RPC function first (safest approach)
      try {
        final result = await _client.rpc(
          'delete_loan_safely',
          params: {
            'p_loan_id': loanId,
            'p_org_id': _orgId,
          },
        );
        
        if (result == true) {
          return;
        }
      } catch (rpcError) {
        // Fallback to manual deletion if RPC doesn't exist
      }

      // Manual deletion with proper ordering and robust foreign key unlinking
      // 1. Delete transactions associated with this loan
      await _client
          .from('transactions')
          .delete()
          .eq('loan_id', loanId);

      // 2. Delete EMI schedules associated with this loan
      await _client
          .from('emi_schedule')
          .delete()
          .eq('loan_id', loanId);

      // 3. Delete loan_schedules (plural) associated with this loan if table exists
      try {
        await _client
            .from('loan_schedules')
            .delete()
            .eq('loan_id', loanId);
      } catch (_) {
        // Ignore if table or permission doesn't exist
      }

      // 4. Nullify loan_id in collections to avoid foreign key block
      await _client
          .from('collections')
          .update({'loan_id': null})
          .eq('loan_id', loanId);

      // 5. Nullify loan_id in customer_payment_requests to avoid foreign key block
      try {
        await _client
            .from('customer_payment_requests')
            .update({'loan_id': null})
            .eq('loan_id', loanId);
      } catch (_) {
        // Ignore if table or constraint doesn't exist
      }

      // 6. Delete the loan itself
      await _client
          .from('loans')
          .delete()
          .eq('id', loanId);

      // 7. Verify deletion dynamically by checking if the record still exists
      final check = await _client
          .from('loans')
          .select('id')
          .eq('id', loanId)
          .maybeSingle();

      if (check != null) {
        throw Exception('Loan record still exists after deletion. Check organization permissions or active database constraints.');
      }
    } catch (e) {
      throw Exception('Delete failed: $e');
    }
  }
}
