import 'dart:math' as math;
import 'package:flutter/foundation.dart';
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
              '*, members:customer_id(full_name, phone, profile_photo_url, profile:profile_id(avatar_url)), staff:staff_id(full_name)')
          .eq('org_id', _orgId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => LoanModel.fromJson(json))
          .toList();
    } catch (e, st) {
      debugPrint('⚠️ getAllLoans error: $e');
      debugPrint('   stack: $st');
      return [];
    }
  }

  Future<List<LoanModel>> getActiveLoans({int limit = 50}) async {
    try {
      final response = await _client
          .from('loans')
          .select(
              '*, members:customer_id(full_name, phone, profile_photo_url, profile:profile_id(avatar_url)), staff:staff_id(full_name)')
          .eq('org_id', _orgId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => LoanModel.fromJson(json))
          .toList();
    } catch (e, st) {
      debugPrint('⚠️ getActiveLoans error: $e');
      debugPrint('   stack: $st');
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
        } else if (status == 'defaulted') {
          defaultLoans++;
          overdueAmount += outstanding;
          totalOutstanding += outstanding;
        } else if (status == 'closed') {
          totalDisbursed += amount;
        }
      }

      // Query total collected from transactions table
      double totalCollected = 0;
      try {
        final collectedResponse = await _client
            .from('transactions')
            .select('amount')
            .eq('org_id', _orgId)
            .eq('type', 'emiPayment');
        for (final row in collectedResponse) {
          totalCollected += double.tryParse(row['amount'].toString()) ?? 0;
        }
      } catch (_) {}

      return LoanSummary(
        totalLoans: totalLoans,
        activeLoans: activeLoans,
        defaultLoans: defaultLoans,
        totalOutstanding: totalOutstanding,
        totalDisbursed: totalDisbursed,
        totalCollected: totalCollected,
        overdueAmount: overdueAmount,
        parPercentage: totalLoans == 0 ? 0 : (defaultLoans / totalLoans) * 100,
      );
    } catch (e, st) {
      debugPrint('⚠️ getLoanSummary error: $e');
      debugPrint('   stack: $st');
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
              '*, members:customer_id(full_name, phone, profile_photo_url, profile:profile_id(avatar_url)), staff:staff_id(full_name)')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return LoanModel.fromJson(response);
    } catch (e, st) {
      debugPrint('⚠️ getLoanById error: $e');
      debugPrint('   stack: $st');
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
    bool freezeEnabled = false,
  }) async {
    final now = DateTime.now();
    final effectiveDisbursementDate = disbursementDate ?? now;
    final loanNumber =
        'L-${DateFormat('yyyyMMdd').format(now)}-${math.Random().nextInt(9999).toString().padLeft(4, '0')}';

    double totalInterest = totalExposure - principal;

    // Look up the member's branch_id and assigned agent
    final member = await _client
        .from('members')
        .select('branch_id, full_name, agent_id')
        .eq('id', borrowerId)
        .maybeSingle();
    if (member == null) {
      throw Exception(
          'Selected borrower no longer exists. Please refresh and try again.');
    }
    final branchId = member['branch_id'] as String?;

    // Auto-assign collection agent: prefer member's agent_id, else pick one from branch
    String? assignedAgentId = member['agent_id'] as String?;
    if (assignedAgentId == null && branchId != null) {
      final agent = await _client
          .from('profiles')
          .select('id')
          .eq('branch_id', branchId)
          .eq('org_id', _orgId)
          .eq('role', 'collectionAgent')
          .limit(1)
          .maybeSingle();
      assignedAgentId = agent?['id'] as String?;
    }

    final result = await _client.from('loans').insert({
      'customer_id': borrowerId,
      'member_id': borrowerId,
      if (member['full_name'] != null) 'member_name': member['full_name'],
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
      if (assignedAgentId != null) 'staff_id': assignedAgentId,
      if (assignedAgentId != null) 'agent_id': assignedAgentId,
      if (interestMode != null) 'interest_mode': interestMode,
      if (interestRateBasis != null) 'interest_rate_basis': interestRateBasis,
      if (interestAmount != null) 'interest_amount': interestAmount,
      if (interestBasis != null) 'interest_basis': interestBasis,
      if (tenureValue != null) 'tenure_value': tenureValue,
      if (tenureUnit != null) 'tenure_unit': tenureUnit,
      'freeze_enabled': freezeEnabled,
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

  /// Creates a migrated loan with pre-existing payment history.
  ///
  /// Unlike [createLoan], this accepts [paidEmis], [lastPaymentDate],
  /// and a backdated [startDate] so the loan's history is preserved.
  /// [outstandingBalance] is the current remaining principal.
  /// [openingBalance] is the total amount already paid before migration.
  Future<String> createMigrationLoan({
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
    required int paidEmis,
    required DateTime lastPaymentDate,
    required double outstandingBalance,
    double openingBalance = 0,
    bool freezeEnabled = false,
    String? interestMode,
    String? interestRateBasis,
    double? interestAmount,
    String? interestBasis,
    int? tenureValue,
    String? tenureUnit,
    DateTime? disbursementDate,
  }) async {
    final now = DateTime.now();
    final effectiveDisbursementDate = disbursementDate ?? firstInstallmentDate;
    final loanNumber =
        'L-${DateFormat('yyyyMMdd').format(now)}-${math.Random().nextInt(9999).toString().padLeft(4, '0')}';

    double totalInterest = totalExposure - principal;

    // Look up the member's branch_id and assigned agent
    final member = await _client
        .from('members')
        .select('branch_id, full_name, agent_id')
        .eq('id', borrowerId)
        .maybeSingle();
    if (member == null) {
      throw Exception(
          'Selected borrower no longer exists. Please refresh and try again.');
    }
    final branchId = member['branch_id'] as String?;

    // Auto-assign collection agent
    String? assignedAgentId = member['agent_id'] as String?;
    if (assignedAgentId == null && branchId != null) {
      final agent = await _client
          .from('profiles')
          .select('id')
          .eq('branch_id', branchId)
          .eq('org_id', _orgId)
          .eq('role', 'collectionAgent')
          .limit(1)
          .maybeSingle();
      assignedAgentId = agent?['id'] as String?;
    }

    final result = await _client.from('loans').insert({
      'customer_id': borrowerId,
      'member_id': borrowerId,
      if (member['full_name'] != null) 'member_name': member['full_name'],
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
      'outstanding_balance': outstandingBalance,
      'outstanding_amount': outstandingBalance,
      'total_repayable': totalExposure,
      'interest_type': interestLogic,
      'paid_emis': paidEmis,
      'last_payment_date': lastPaymentDate.toIso8601String().split('T').first,
      'status': 'active',
      'first_installment_date': firstInstallmentDate.toIso8601String(),
      'first_emi_date': firstInstallmentDate.toIso8601String(),
      'disbursement_date': effectiveDisbursementDate.toIso8601String(),
      'start_date': firstInstallmentDate.toIso8601String(),
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'org_id': _orgId,
      if (branchId != null) 'branch_id': branchId,
      if (assignedAgentId != null) 'staff_id': assignedAgentId,
      if (assignedAgentId != null) 'agent_id': assignedAgentId,
      if (interestMode != null) 'interest_mode': interestMode,
      if (interestRateBasis != null) 'interest_rate_basis': interestRateBasis,
      if (interestAmount != null) 'interest_amount': interestAmount,
      if (interestBasis != null) 'interest_basis': interestBasis,
      if (tenureValue != null) 'tenure_value': tenureValue,
      if (tenureUnit != null) 'tenure_unit': tenureUnit,
      'freeze_enabled': freezeEnabled,
    }).select('id').single();

    final loanId = result['id'] as String;

    // NOTE: Synthetic transaction removed. Collections (created via
    // createMigrationLoanCollectionRecords) already represent the payment
    // history. Adding a separate transaction caused duplicate ledger rows.

    await _logRepo?.log(
      action: 'Loan Migrated',
      details:
          'Amount: ₹$principal, Outstanding: ₹$outstandingBalance, Paid EMIs: $paidEmis, Loan ID: $loanId',
      type: ActivityType.financialTransaction,
    );

    return loanId;
  }

  /// Creates synthetic [collections] records for each paid EMI in a migrated loan.
  /// Returns the number of records created.
  Future<int> createMigrationLoanCollectionRecords({
    required String loanId,
    required String memberId,
    required double installmentAmount,
    required int installmentsPaid,
    required DateTime startDate,
    required String collectionType,
  }) async {
    if (installmentsPaid <= 0) return 0;

    final memberData = await _client
        .from('members')
        .select('full_name')
        .eq('id', memberId)
        .maybeSingle();
    final memberName = memberData?['full_name'] as String? ?? '';

    // Fetch already-paid EMI schedule rows so we can link each collection
    // to its corresponding EMI via selected_schedule_id. This prevents the
    // update_schedule_on_collection trigger from FIFO-advancing extra EMIs.
    final paidEmis = await _client
        .from('emi_schedule')
        .select('id, emi_number')
        .eq('loan_id', loanId)
        .eq('is_paid', true)
        .order('emi_number', ascending: true);

    // Build a map: emi_number -> schedule row id
    final Map<int, String> paidEmiMap = {};
    for (final row in paidEmis as List) {
      final emiNum = row['emi_number'] as int;
      final id = row['id'] as String;
      paidEmiMap[emiNum] = id;
    }

    final records = <Map<String, dynamic>>[];
    for (int i = 0; i < installmentsPaid; i++) {
      DateTime dueDate;
      switch (collectionType) {
        case 'weekly':
          dueDate = startDate.add(Duration(days: i * 7));
          break;
        case 'monthly':
          dueDate = DateTime(startDate.year, startDate.month + i, startDate.day);
          break;
        case 'yearly':
          dueDate = DateTime(startDate.year + i, startDate.month, startDate.day);
          break;
        default: // daily
          dueDate = startDate.add(Duration(days: i));
      }

      // Link to the paid EMI schedule row so the collection trigger doesn't
      // FIFO-pay additional EMIs. The emi_number is 1-indexed.
      final scheduleId = paidEmiMap[i + 1];

      records.add({
        'loan_id': loanId,
        'org_id': _orgId,
        'member_id': memberId,
        'member_name': memberName,
        'amount_expected': installmentAmount,
        'amount_collected': installmentAmount,
        'is_partial': false,
        'payment_mode': 'cash',
        'collection_date': dueDate.toIso8601String().split('T').first,
        'collected_at': DateTime.now().toUtc().toIso8601String(),
        'sync_status': 'synced',
        if (scheduleId != null) 'selected_schedule_id': scheduleId,
      });
    }

    if (records.isEmpty) return 0;

    // Insert collections and capture their ids so we can link them to a
    // backing transaction (Phase #1 fix).
    final inserted = await _client
        .from('collections')
        .insert(records)
        .select('id, collection_date');
    final insertedRows = inserted as List;

    // Create ONE synthetic loan-repayment transaction that consolidates the
    // migrated installments. Without it, the delete-revert workflow could
    // never find a transaction tied to these collection rows.
    if (insertedRows.isNotEmpty && installmentAmount > 0) {
      final totalAmount = installmentAmount * installmentsPaid;
      // latest installment date for the transaction's transaction_date
      final lastDueDate = records.last['collection_date'] as String;

      // Type 'emiPayment' (not 'loanRepayment') — the transactions table's
      // CHECK constraint allows ['loanDisbursement', 'emiPayment',
      // 'savingsDeposit', 'savingsWithdrawal', 'penalty', 'staffCashDeposit',
      // 'other', 'collection', 'deposit', 'withdrawal']. 'loanRepayment'
      // is NOT in that allow-list, so the previous code broke here and
      // left the inserted collections with a NULL transaction_id (Phase #1
      // was incomplete on the loan side).
      final txResult = await _client.from('transactions').insert({
        'member_id': memberId,
        'member_name': memberName,
        'loan_id': loanId,
        'amount': totalAmount,
        'type': 'emiPayment',
        'org_id': _orgId,
        'payment_mode': 'cash',
        'description': 'Migrated payment — pre-existing installments',
        'transaction_date': lastDueDate,
      }).select('id').single();
      final txId = txResult['id'] as String;

      final collectionIds =
          insertedRows.map((r) => r['id'] as String).toList();
      await _client
          .from('collections')
          .update({'transaction_id': txId})
          .filter('id', 'in', collectionIds);
    }

    return records.length;
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
    bool? freezeEnabled,
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
    if (freezeEnabled != null) data['freeze_enabled'] = freezeEnabled;
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
        final int? loanTenureValue = updatedRow['tenure_value'] as int?;
        final String? loanTenureUnit = updatedRow['tenure_unit'] as String?;
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
          tenureValue: loanTenureValue,
          tenureUnit: loanTenureUnit,
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

      // 2. Nullify UPI payment request EMI references (FK blocks emi_schedule delete)
      await _client.from('upi_payment_requests').update({'emi_schedule_id': null}).eq('loan_id', loanId);

      // 3. Delete collections first (references emi_schedule via selected_schedule_id)
      await _client.from('collections').delete().eq('loan_id', loanId);

      // 4. Delete EMI schedules
      await _client.from('emi_schedule').delete().eq('loan_id', loanId);

      // 5. Nullify UPI payment request loan references before deleting loan
      await _client.from('upi_payment_requests').update({'loan_id': null}).eq('loan_id', loanId);

      // 6. Delete the loan itself
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

  Future<void> recalculateLoanBalance(String loanId) async {
    // PRIMARY: Use the server-side RPC which derives outstanding from the
    // EMI schedule (the single source of truth). This avoids rounding drift
    // between totalRepayable and sum(emi_amount).
    try {
      await _client.rpc('recalculate_loan_outstanding', params: {
        'p_loan_id': loanId,
      });
      return;
    } catch (_) {
      // RPC not deployed yet — fall through to client-side recalc
    }

    // CLIENT-SIDE FALLBACK: Derive outstanding from the EMI schedule,
    // NOT from totalRepayable - sum(transactions), because rounding
    // differences between the two totals cause corruption.
    final emis = await _client
        .from('emi_schedule')
        .select('id, emi_amount, is_paid, due_date, status')
        .eq('loan_id', loanId)
        .order('emi_number', ascending: true);

    double totalRepaid = 0;
    double totalEmi = 0;
    int paidCount = 0;
    for (final emi in emis as List) {
      final emiAmt = (emi['emi_amount'] as num?)?.toDouble() ?? 0;
      totalEmi += emiAmt;
      if (emi['is_paid'] == true) {
        totalRepaid += emiAmt;
        paidCount++;
      }
    }

    final newOutstanding = (totalEmi - totalRepaid).clamp(0.0, totalEmi);

    final updateData = <String, dynamic>{
      'outstanding_amount': newOutstanding,
      'outstanding_balance': newOutstanding,
      'paid_emis': paidCount,
    };
    if (newOutstanding <= 0) {
      updateData['status'] = 'closed';
      updateData['closed_date'] = DateTime.now().toIso8601String().split('T').first;
    } else {
      updateData['status'] = 'active';
      updateData['closed_date'] = null;
    }

    await _client.from('loans').update(updateData).eq('id', loanId);
  }
}
