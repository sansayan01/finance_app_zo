import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../settings/data/repositories/activity_log_repository.dart';
import '../../../settings/data/models/activity_log_model.dart';
import '../models/loan_model.dart';
import 'emi_repository.dart';

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
              '*, members:customer_id(full_name, phone), staff:staff_id(full_name)')
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
              '*, members:customer_id(full_name, phone), staff:staff_id(full_name)')
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
      final response = await _client.from('loans').select('''
            status,
            outstanding_amount,
            amount
          ''').eq('org_id', _orgId);

      final loans = response as List;

      int totalLoans = loans.length;
      int activeLoans = 0;
      int defaultLoans = 0;
      double totalOutstanding = 0.0;
      double totalDisbursed = 0.0;
      double overdueAmount = 0.0;

      for (final loan in loans) {
        final status = loan['status'] as String?;
        final outstanding =
            (loan['outstanding_amount'] as num?)?.toDouble() ?? 0.0;
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
              '*, members:customer_id(full_name, phone), staff:staff_id(full_name)')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return LoanModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<String> createLoan({
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
    DateTime? disbursementDate,
  }) async {
    final now = DateTime.now();
    final effectiveDisbursementDate = disbursementDate ?? now;
    final loanNumber =
        'L-${DateFormat('yyyyMMdd').format(now)}-${math.Random().nextInt(9999).toString().padLeft(4, '0')}';

    double totalInterest = totalExposure - principal;

    // Look up the member's branch_id
    final member = await _client
        .from('members')
        .select('branch_id, full_name')
        .eq('id', borrowerId)
        .maybeSingle();
    final branchId = member?['branch_id'] as String?;

    final result = await _client.from('loans').insert({
      'customer_id': borrowerId,
      'member_id': borrowerId,
      if (member?['full_name'] != null) 'member_name': member!['full_name'],
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
      'disbursement_date': effectiveDisbursementDate.toIso8601String(),
      'start_date': now.toIso8601String(),
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'org_id': _orgId,
      if (branchId != null) 'branch_id': branchId,
      if (interestMode != null) 'interest_mode': interestMode,
      if (interestRateBasis != null) 'interest_rate_basis': interestRateBasis,
      if (interestAmount != null) 'interest_amount': interestAmount,
      if (interestBasis != null) 'interest_basis': interestBasis,
      if (tenureValue != null) 'tenure_value': tenureValue,
      if (tenureUnit != null) 'tenure_unit': tenureUnit,
    }).select('id').single();

    final loanId = result['id'] as String;

    await _logRepo?.log(
      action: 'Loan Disbursed',
      details:
          'Amount: ₹$principal, Loan ID: $loanId, Borrower ID: $borrowerId',
      type: ActivityType.financialTransaction,
    );

    return loanId;
  }

  Future<void> createLoanFromMap(Map<String, dynamic> data) async {
    data['org_id'] = _orgId;
    // Ensure member_id is populated (same as customer_id if missing)
    data['member_id'] ??= data['customer_id'];
    await _client.from('loans').insert(data);
  }

  Future<void> updateLoanStatus(String id, String status) async {
    final result = await _client.from('loans').update({'status': status}).eq('id', id).select();
    if (result.isEmpty) {
      throw Exception('Update failed: no rows affected. Check permissions or loan ID.');
    }
  }

  Future<void> updateLoan(
    String id, {
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
    DateTime? disbursementDate,
  }) async {
    final data = <String, dynamic>{};
    if (borrowerId != null) {
      data['customer_id'] = borrowerId;
      data['member_id'] = borrowerId;
      // Also sync denormalized member_name
      try {
        final member = await _client
            .from('members')
            .select('full_name')
            .eq('id', borrowerId)
            .maybeSingle();
        if (member != null && member['full_name'] != null) {
          data['member_name'] = member['full_name'];
        }
      } catch (_) {}
    }
    if (principal != null) {
      data['amount'] = principal;
      data['principal'] = principal;
      // Update outstanding amounts when principal changes
      if (totalExposure == null) {
        data['outstanding_amount'] = principal;
        data['outstanding_balance'] = principal;
        data['total_repayable'] = principal;
      }
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
      data['outstanding_amount'] = totalExposure;
      data['total_repayable'] = totalExposure;
    }
    if (interestMode != null) data['interest_mode'] = interestMode;
    if (interestRateBasis != null) {
      data['interest_rate_basis'] = interestRateBasis;
    }
    if (interestAmount != null) data['interest_amount'] = interestAmount;
    if (interestBasis != null) data['interest_basis'] = interestBasis;
    if (tenureValue != null) data['tenure_value'] = tenureValue;
    if (tenureUnit != null) data['tenure_unit'] = tenureUnit;
    if (remarks != null) data['remarks'] = remarks;
    if (purpose != null) data['purpose'] = purpose;
    if (disbursementDate != null) {
      data['disbursement_date'] = disbursementDate.toIso8601String();
    }
    data['updated_at'] = DateTime.now().toIso8601String();

    final result = await _client.from('loans').update(data).eq('id', id).select();
    if (result.isEmpty) {
      throw Exception('Update failed: no rows affected. Check permissions or loan ID.');
    }

    // Regenerate EMI schedule if key terms changed
    final bool scheduleAffectingChange = principal != null ||
        tenureMonths != null ||
        interestRate != null ||
        firstInstallmentDate != null ||
        estimatedInstallment != null ||
        interestLogic != null ||
        frequency != null;

    if (scheduleAffectingChange) {
      try {
        // Delete old EMI schedule rows for this loan
        await _client.from('emi_schedule').delete().eq('loan_id', id);

        // Fetch the updated loan to get full terms for regeneration
        final updatedRow = result.first;
        final double loanPrincipal = ((updatedRow['amount'] ?? updatedRow['principal']) as num?)?.toDouble() ?? 0.0;
        final double loanInterestRate = (updatedRow['interest_rate'] as num?)?.toDouble() ?? 0.0;
        final int loanTenure = updatedRow['tenure_months'] as int? ?? 12;
        final String loanInterestType = updatedRow['interest_type'] as String? ?? 'flat';
        final double loanEmiAmount = (updatedRow['emi_amount'] as num?)?.toDouble() ?? 0.0;
        final String? memberId = (updatedRow['member_id'] ?? updatedRow['customer_id'])?.toString();
        final String? loanFrequency = updatedRow['frequency'] as String?;
        final DateTime startDate = (updatedRow['first_emi_date'] ?? updatedRow['first_installment_date']) != null
            ? DateTime.parse((updatedRow['first_emi_date'] ?? updatedRow['first_installment_date']) as String)
            : DateTime.now();

        final emiRepo = EMIRepository(_client, _orgId);
        await emiRepo.generateSchedule(
          id,
          principal: loanPrincipal,
          interestRate: loanInterestRate,
          tenureMonths: loanTenure,
          interestType: loanInterestType,
          startDate: startDate,
          emiAmount: loanEmiAmount,
          memberId: memberId,
          frequency: loanFrequency,
        );
      } catch (_) {
        // EMI regeneration failure should not block the loan update
      }
    }
  }

  Future<void> settleLoan(String loanId, double amount) async {
    final loan = await getLoanById(loanId);
    if (loan == null) return;

    final newBalance =
        (loan.outstandingBalance - amount).clamp(0.0, double.infinity);
    final newStatus = newBalance <= 0 ? 'closed' : 'active';

    final result = await _client.from('loans').update({
      'status': newStatus,
      'outstanding_balance': newBalance,
      'outstanding_amount': newBalance,
    }).eq('id', loanId).select();
    if (result.isEmpty) {
      throw Exception('Settle failed: no rows affected. Check permissions or loan ID.');
    }
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

      // Manual deletion with proper ordering
      // 1. Delete transactions
      await _client.from('transactions').delete().eq('loan_id', loanId);

      // 2. Delete EMI schedules (covers all schedule records via streaming)
      await _client.from('emi_schedule').delete().eq('loan_id', loanId);

      // 3. Delete collections (not just nullify)
      await _client.from('collections').delete().eq('loan_id', loanId);

      // 5. Delete the loan itself
      await _client.from('loans').delete().eq('id', loanId);

      // 7. Verify deletion
      final check = await _client
          .from('loans')
          .select('id')
          .eq('id', loanId)
          .maybeSingle();

      if (check != null) {
        throw Exception(
            'Loan record still exists after deletion. Check organization permissions or active database constraints.');
      }
    } catch (e) {
      throw Exception('Delete failed: $e');
    }
  }
}
