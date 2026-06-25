import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/utils/formatters.dart' show AppFormatters;
import '../models/savings_model.dart';
import '../models/savings_installment_model.dart';

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
    DateTime? startDate,
    int tenure = 12,
    String? tenureUnit,
    double openingBalance = 0,
    double totalReturnAmount = 0,
    bool freezeEnabled = false,
  }) async {
    // Use provided start date or default to today
    final now = startDate ?? DateTime.now();
    DateTime nextDueDate;
    int? collectionDayOfWeek;
    int? collectionDayOfMonth;

    switch (collectionType) {
      case 'daily':
        nextDueDate = DateTime(now.year, now.month, now.day);
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
        nextDueDate = DateTime(now.year, now.month, now.day);
    }

    // Verify member exists before insert (FK fk_splans_member → members.id)
    final memberExists = await _client
        .from('members')
        .select('id')
        .eq('id', memberId)
        .maybeSingle();
    if (memberExists == null) {
      throw Exception(
          'Selected member no longer exists. Please refresh and try again.');
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
      'target_amount': openingBalance + (installmentAmount * totalInstallments),
      'status': 'active',
      'start_date': now.toIso8601String().split('T')[0],
      'next_due_date': nextDueDate.toIso8601String().split('T')[0],
      'tenure': tenure,
      'opening_balance': openingBalance,
      'current_amount': openingBalance,
      'total_return_amount': totalReturnAmount,
      'freeze_enabled': freezeEnabled,
    };

    if (tenureUnit != null) {
      insertData['tenure_unit'] = tenureUnit;
    }

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
        startDate: json['start_date'] != null
            ? DateTime.tryParse(json['start_date'].toString())
            : null,
        tenureUnit: json['tenure_unit']?.toString(),
        tenure: (json['tenure'] as num?)?.toInt() ?? 12,
        openingBalance: (json['opening_balance'] as num?)?.toDouble() ?? 0,
        totalReturnAmount: (json['total_return_amount'] as num?)?.toDouble() ?? 0,
        installmentsPaid: (json['installments_paid'] as num?)?.toInt() ?? 0,
        lastPaymentDate: json['last_payment_date'] != null
            ? DateTime.tryParse(json['last_payment_date'].toString())
            : null,
        freezeEnabled: json['freeze_enabled'] as bool? ?? false,
        frozenCount: (json['frozen_count'] as num?)?.toInt() ?? 0,
        frozenDates: (json['frozen_dates'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
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
      final totalSavings = plans.fold<double>(0, (sum, p) => sum + p.currentAmount);
      final averageBalance = plans.isEmpty ? 0.0 : totalSavings / plans.length;
      // Estimated interest = sum of (current_amount - opening_balance) across all plans
      final interestEarned = plans.fold<double>(
          0, (sum, p) => sum + (p.currentAmount - p.openingBalance).clamp(0.0, double.infinity));

      return SavingsSummary(
        totalSavings: totalSavings,
        activeAccounts: plans.length,
        averageBalance: averageBalance,
        interestEarned: interestEarned,
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
    final updateResult = await _client.from('savings_plans').update({
      'current_amount': newBalance,
    }).eq('id', savingId).select();
    if (updateResult.isEmpty) {
      throw Exception('Failed to update savings plan balance - not found or access denied');
    }

    // 2. Record transaction
    await _client.from('transactions').insert({
      'member_id': saving.memberId,
      'member_name': saving.memberName,
      'savings_id': savingId,
      'amount': amount,
      'type': TransactionType.savingsDeposit.name,
      'org_id': _orgId,
      'description': 'Deposit into Savings Vault',
      'created_at': AppFormatters.nowIST(),
    });
  }

  Future<void> updateSavingMetadata(
      String id, Map<String, dynamic> data) async {
    final result = await _client.from('savings_plans').update(data).eq('id', id).select();
    if (result.isEmpty) {
      throw Exception('Update failed: no rows affected. Check permissions or saving ID.');
    }
  }

  Future<void> deleteSavingPlan(String id) async {
    final result = await _client.from('savings_plans').delete().eq('id', id).select();
    if (result.isEmpty) {
      throw Exception('Failed to delete savings plan - not found or access denied');
    }
  }

  /// Creates a migrated savings plan with historical data pre-populated.
  ///
  /// Unlike [createSavingsPlan], this accepts the already-known
  /// [installmentsPaid], [lastPaymentDate], and [totalReturnAmount] so the
  /// plan starts with its correct in-progress state rather than from zero.
  ///
  /// Returns the new plan's ID.
  Future<String> createMigrationSavingsPlan({
    required String memberId,
    required double installmentAmount,
    required double totalReturnAmount,
    required DateTime startDate,
    required int tenure,
    required String tenureUnit,
    required String collectionType,
    required double penalty,
    required int installmentsPaid,
    required DateTime lastPaymentDate,
    double openingBalance = 0,
    bool freezeEnabled = false,
  }) async {
    // --- Calculations ---
    final int totalInstallments = _calculateTotalInstallments(
      collectionType,
      tenure,
      tenureUnit,
    );
    final double maturityAmount =
        totalReturnAmount > 0 ? totalReturnAmount : installmentAmount * totalInstallments;
    final DateTime maturityDate = _calculateMaturityDate(
      startDate,
      tenure,
      tenureUnit,
    );
    final double targetAmount =
        openingBalance + (installmentAmount * totalInstallments);

    // Compute current_amount = opening + (installmentsPaid * installmentAmount)
    final double currentAmount =
        openingBalance + (installmentsPaid * installmentAmount);

    // Compute next_due_date based on how many installments are already paid
    final DateTime nextDueDate = _computeNextDueDate(
      startDate: startDate,
      installmentsPaid: installmentsPaid,
      collectionType: collectionType,
    );

    // Verify member exists (FK fk_splans_member → members.id)
    final memberExists = await _client
        .from('members')
        .select('id')
        .eq('id', memberId)
        .maybeSingle();
    if (memberExists == null) {
      throw Exception(
          'Selected member no longer exists. Please refresh and try again.');
    }

    // --- Collection-day helpers ---
    int? collectionDayOfWeek;
    int? collectionDayOfMonth;

    if (collectionType == 'weekly') {
      collectionDayOfWeek = nextDueDate.weekday - 1; // 0=Mon, 6=Sun
    } else if (collectionType == 'monthly') {
      collectionDayOfMonth = startDate.day;
    }

    // --- Insert plan ---
    final insertData = <String, dynamic>{
      'member_id': memberId,
      'org_id': _orgId,
      'monthly_deposit': installmentAmount,
      'maturity_amount': maturityAmount,
      'maturity_date': maturityDate.toIso8601String().split('T')[0],
      'collection_type': collectionType,
      'premature_penalty': penalty,
      'total_installments': totalInstallments,
      'target_amount': targetAmount,
      'status': 'active',
      'start_date': startDate.toIso8601String().split('T')[0],
      'next_due_date': nextDueDate.toIso8601String().split('T')[0],
      'tenure': tenure,
      'tenure_unit': tenureUnit,
      'opening_balance': openingBalance,
      'current_amount': currentAmount,
      // Migration-specific fields
      'total_return_amount': totalReturnAmount,
      'installments_paid': installmentsPaid,
      'last_payment_date': lastPaymentDate.toIso8601String().split('T')[0],
      'freeze_enabled': freezeEnabled,
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
      throw Exception('Failed to create migrated savings plan');
    }

    final planId = response['id'].toString();

    // Create a transaction record for the already-paid balance
    // so deposit history shows up on the detail page
    if (currentAmount > 0) {
      final memberData = await _client
          .from('members')
          .select('full_name')
          .eq('id', memberId)
          .maybeSingle();

      await _client.from('transactions').insert({
        'member_id': memberId,
        'member_name': memberData?['full_name'] as String? ?? '',
        'savings_id': planId,
        'amount': currentAmount,
        'type': 'savingsDeposit',
        'org_id': _orgId,
        'description': 'Migrated balance — pre-existing deposit',
        'created_at': startDate.toUtc().toIso8601String(),
      });
    }

    return planId;
  }

  /// Creates synthetic [savings_collections] records for each installment
  /// that was already paid in a migrated plan.
  ///
  /// Returns the number of collection records created.
  Future<int> createMigrationCollectionRecords({
    required String savingsPlanId,
    required String memberId,
    required double installmentAmount,
    required int installmentsPaid,
    required DateTime startDate,
    required String collectionType,
  }) async {
    if (installmentsPaid <= 0) return 0;

    // Fetch member name for the collection record
    final member = await _client
        .from('members')
        .select('full_name')
        .eq('id', memberId)
        .maybeSingle();
    final memberName = member?['full_name'] as String? ?? '';

    final List<Map<String, dynamic>> records = [];
    for (int i = 0; i < installmentsPaid; i++) {
      final DateTime collectionDate = _computeCollectionDate(
        startDate: startDate,
        offset: i,
        collectionType: collectionType,
      );

      records.add({
        'org_id': _orgId,
        'savings_plan_id': savingsPlanId,
        'member_id': memberId,
        'member_name': memberName,
        'amount_expected': installmentAmount,
        'amount_collected': installmentAmount,
        'is_partial': false,
        'payment_mode': 'cash',
        'collection_date': collectionDate.toIso8601String().split('T')[0],
        'collected_at': DateTime.now().toUtc().toIso8601String(),
        'sync_status': 'synced',
      });
    }

    if (records.isEmpty) return 0;

    await _client.from('savings_collections').insert(records);

    return records.length;
  }

  /// Calculates migration overdue information.
  ///
  /// Given the [startDate], how many [installmentsPaid], and the
  /// [installmentAmount], this computes the expected schedule vs today.
  ///
  /// Returns a map with:
  /// - `daysPaid` (int): total expected collection days from start to now
  /// - `daysOverdue` (int): how many collection days are overdue
  /// - `overdueAmount` (double): amount that should have been collected but wasn't
  /// - `nextDueDate` (DateTime): the next expected collection date
  Map<String, dynamic> calculateMigrationOverdue({
    required DateTime startDate,
    required int installmentsPaid,
    required double installmentAmount,
    DateTime? today,
    String collectionType = 'monthly',
  }) {
    final DateTime now = today ?? DateTime.now();
    final int daysSinceStart = now.difference(startDate).inDays;

    // Calculate expected installments based on collection type
    int expectedInstallments = 0;
    DateTime nextDue;

    switch (collectionType) {
      case 'daily':
        expectedInstallments = daysSinceStart + 1; // inclusive of day 0
        nextDue = startDate.add(Duration(days: expectedInstallments));
        break;
      case 'weekly':
        expectedInstallments = (daysSinceStart ~/ 7) + 1;
        nextDue = startDate.add(Duration(days: expectedInstallments * 7));
        break;
      case 'monthly':
        int months = (now.year - startDate.year) * 12 +
            (now.month - startDate.month);
        if (now.day >= startDate.day) months++;
        expectedInstallments = months;
        nextDue = DateTime(
          startDate.year,
          startDate.month + expectedInstallments,
          startDate.day,
        );
        break;
      default:
        expectedInstallments = daysSinceStart + 1;
        nextDue = startDate.add(Duration(days: expectedInstallments));
    }

    final int daysOverdue =
        (expectedInstallments - installmentsPaid).clamp(0, expectedInstallments);
    final double overdueAmount = daysOverdue * installmentAmount;

    return {
      'daysPaid': expectedInstallments,
      'daysOverdue': daysOverdue,
      'overdueAmount': overdueAmount,
      'nextDueDate': nextDue,
    };
  }

  // ── Private helpers ──────────────────────────────────────────────

  /// Calculates total installments from tenure + unit.
  int _calculateTotalInstallments(
    String collectionType,
    int tenure,
    String tenureUnit,
  ) {
    switch (collectionType) {
      case 'daily':
        switch (tenureUnit) {
          case 'weeks':
            return tenure * 7;
          case 'months':
            return tenure * 30;
          case 'years':
            return tenure * 365;
          default:
            return tenure; // days
        }
      case 'weekly':
        switch (tenureUnit) {
          case 'months':
            return tenure * 4;
          case 'years':
            return tenure * 52;
          default:
            return tenure;
        }
      case 'monthly':
      default:
        switch (tenureUnit) {
          case 'years':
            return tenure * 12;
          default:
            return tenure;
        }
    }
  }

  /// Calculates the maturity date from start + tenure + unit.
  DateTime _calculateMaturityDate(
    DateTime startDate,
    int tenure,
    String tenureUnit,
  ) {
    switch (tenureUnit) {
      case 'days':
        return startDate.add(Duration(days: tenure));
      case 'weeks':
        return startDate.add(Duration(days: tenure * 7));
      case 'months':
        return DateTime(
          startDate.year,
          startDate.month + tenure,
          startDate.day,
        );
      case 'years':
        return DateTime(
          startDate.year + tenure,
          startDate.month,
          startDate.day,
        );
      default:
        return DateTime(
          startDate.year,
          startDate.month + tenure,
          startDate.day,
        );
    }
  }

  /// Computes the next due date given start + number of paid installments.
  DateTime _computeNextDueDate({
    required DateTime startDate,
    required int installmentsPaid,
    required String collectionType,
  }) {
    final int offset = installmentsPaid; // next unpaid index
    return _computeCollectionDate(
      startDate: startDate,
      offset: offset,
      collectionType: collectionType,
    );
  }

  /// Returns the collection date for the given zero-based offset from start.
  DateTime _computeCollectionDate({
    required DateTime startDate,
    required int offset,
    required String collectionType,
  }) {
    switch (collectionType) {
      case 'daily':
        return startDate.add(Duration(days: offset));
      case 'weekly':
        return startDate.add(Duration(days: offset * 7));
      case 'monthly':
        return DateTime(
          startDate.year,
          startDate.month + offset,
          startDate.day,
        );
      default:
        return startDate.add(Duration(days: offset));
    }
  }

  /// Permanently deletes an RD/savings plan along with all of its
  /// dependent rows. Use with care — this is irreversible and removes
  /// the entire transaction history for the plan.
  Future<void> deleteSavingPlanCascade(String id) async {
    // 1. Nullify UPI payment request references (FK blocks plan delete)
    await _client
        .from('upi_payment_requests')
        .update({'savings_plan_id': null}).eq('savings_plan_id', id);

    // 2. Delete collection records first (FK safety — FK is NO ACTION,
    //    must be removed before the parent transaction/plan).
    await _client.from('savings_collections').delete().eq('savings_plan_id', id).select();

    // 3. Delete transactions (belong to this plan's history).
    await _client.from('transactions').delete().eq('savings_id', id).select();

    // 4. Delete the plan itself.
    final result = await _client.from('savings_plans').delete().eq('id', id).select();
    if (result.isEmpty) {
      throw Exception('Failed to delete savings plan cascade - plan not found');
    }
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
      final result = await _client
          .from('savings_plans')
          .update({'status': 'closed'}).eq('id', id).select();
      if (result.isEmpty) {
        throw Exception('Failed to close savings plan - not found or access denied');
      }
    } else {
      final result = await _client.from('savings_plans').delete().eq('id', id).select();
      if (result.isEmpty) {
        throw Exception('Failed to delete savings plan - not found or access denied');
      }
    }
  }

  Future<void> setSavingStatus(String id, String status) async {
    final result = await _client.from('savings_plans').update({'status': status}).eq('id', id).select();
    if (result.isEmpty) {
      throw Exception('Failed to set savings status - not found or access denied');
    }
  }

  Future<void> recalculateBalance(String savingId) async {
    // Prefer the SECURITY DEFINER RPC — it bypasses RLS so the recalc
    // can't silently fail when a manager/agent deletes a transaction.
    try {
      final res = await _client.rpc('recalculate_savings_balance', params: {
        'p_savings_id': savingId,
      });
      final ok = res is Map && res['success'] == true;
      if (ok) return;
    } catch (_) {
      // RPC not deployed yet — fall through to client-side recalc
    }

    // Read plan metadata
    final plan = await _client
        .from('savings_plans')
        .select('''
          opening_balance,
          collection_type,
          start_date
        ''')
        .eq('id', savingId)
        .maybeSingle();
    final openingBalance =
        (plan?['opening_balance'] as num?)?.toDouble() ?? 0;
    final collectionType = plan?['collection_type'] as String? ?? 'monthly';
    final startDateStr = plan?['start_date'] as String?;

    // Recalculate current_amount from remaining transactions
    final rows = await _client
        .from('transactions')
        .select('type, amount')
        .eq('savings_id', savingId);

    double balance = openingBalance;
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

    // Recalculate next_due_date based on remaining collection history
    final lastCollection = await _client
        .from('savings_collections')
        .select('collection_date')
        .eq('savings_plan_id', savingId)
        .order('collection_date', ascending: false)
        .limit(1)
        .maybeSingle();

    DateTime? newNextDue;
    if (lastCollection != null && lastCollection['collection_date'] != null) {
      final lastDate = DateTime.parse(lastCollection['collection_date'] as String);
      switch (collectionType.toLowerCase()) {
        case 'daily':
          newNextDue = lastDate.add(const Duration(days: 1));
          break;
        case 'weekly':
          newNextDue = lastDate.add(const Duration(days: 7));
          break;
        default:
          newNextDue = DateTime(lastDate.year, lastDate.month + 1, lastDate.day);
      }
    } else if (startDateStr != null) {
      // No collections left — revert to start_date
      newNextDue = DateTime.parse(startDateStr);
    }

    final updateData = <String, dynamic>{
      'current_amount': balance,
    };
    if (newNextDue != null) {
      updateData['next_due_date'] = newNextDue.toIso8601String().split('T').first;
    }

    final result = await _client
        .from('savings_plans')
        .update(updateData).eq('id', savingId).select();
    if (result.isEmpty) {
      throw Exception('Failed to recalculate balance - savings plan not found or access denied');
    }
  }

  /// Delete a savings collection by [savingsCollectionId].
  /// Finds the matching transaction and delegates to the RPC (with fallback).
  Future<void> deleteSavingsCollection(String savingsCollectionId) async {
    // Fetch the savings collection to get linked transaction_id and plan info
    final collection = await _client
        .from('savings_collections')
        .select('savings_plan_id, amount_collected, member_id, transaction_id')
        .eq('id', savingsCollectionId)
        .maybeSingle();
    if (collection == null) {
      throw Exception('Savings collection not found');
    }

    final savingsPlanId = collection['savings_plan_id'] as String?;
    final amount = (collection['amount_collected'] as num?)?.toDouble() ?? 0;
    final memberId = collection['member_id'] as String?;
    final linkedTxId = collection['transaction_id'] as String?;

    if (savingsPlanId == null) {
      throw Exception('Savings collection has no savings_plan_id');
    }

    // Find the linked transaction — prefer transaction_id, fall back to amount match
    String? txId = linkedTxId;
    if (txId == null) {
      final tx = await _client
          .from('transactions')
          .select('id')
          .eq('savings_id', savingsPlanId)
          .eq('amount', amount)
          .eq('member_id', memberId ?? '')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      txId = tx?['id'] as String?;
    }

    // Try RPC first (handles collection + transaction + recalc in one shot)
    if (txId != null) {
      try {
        await _client.rpc('delete_savings_transaction', params: {
          'p_transaction_id': txId,
        });
        return;
      } catch (_) {
        // RPC failed — fall through to manual deletion
      }
    }

    // Fallback: delete collection + transaction + recalculate
    await _client
        .from('savings_collections')
        .delete()
        .eq('id', savingsCollectionId);

    if (txId != null) {
      await _client
          .from('transactions')
          .delete()
          .eq('id', txId);
    }

    await recalculateBalance(savingsPlanId);
  }

  // ─── Date Freeze: detect skipped savings installments ───

  /// Detects installments that were skipped between the first and last paid
  /// installment, marks them as frozen, and extends the plan tenure.
  /// Returns the number of newly frozen installments.
  Future<int> detectAndFreezeSkippedInstallments(String planId, {bool force = false}) async {
    try {
      final plan = await _client
          .from('savings_plans')
          .select('*')
          .eq('id', planId)
          .maybeSingle();
      if (plan == null) return 0;

      final planModel = SavingsModel.fromJson(plan);
      if (!planModel.freezeEnabled && !force) return 0;

      // Fetch paid dates
      final paidDates = await _client
          .from('savings_collections')
          .select('collection_date')
          .eq('savings_plan_id', planId);

      final paidSet = <DateTime>{};
      for (final row in paidDates as List) {
        final d = DateTime.parse(row['collection_date'] as String);
        paidSet.add(DateTime(d.year, d.month, d.day));
      }

      // Generate schedule and find frozen installments
      final existingFrozen = planModel.frozenDates.toSet();
      final schedule =
          SavingsScheduleGenerator.generate(plan: planModel, paidDates: paidSet);

      int maxPaidNumber = 0;
      int minPaidNumber = 999999;
      for (final inst in schedule) {
        if (inst.isPaid) {
          if (inst.number > maxPaidNumber) maxPaidNumber = inst.number;
          if (inst.number < minPaidNumber) minPaidNumber = inst.number;
        }
      }
      if (maxPaidNumber == 0) return 0;

      // Freeze installments strictly between min and max paid that aren't paid or already frozen
      final newFrozenDates = <String>{...existingFrozen};
      int count = 0;
      for (final inst in schedule) {
        if (inst.number > minPaidNumber &&
            inst.number < maxPaidNumber &&
            !inst.isPaid &&
            !inst.isFrozen) {
          final dateKey =
              '${inst.dueDate.year}-${inst.dueDate.month.toString().padLeft(2, '0')}-${inst.dueDate.day.toString().padLeft(2, '0')}';
          if (!newFrozenDates.contains(dateKey)) {
            newFrozenDates.add(dateKey);
            count++;
          }
        }
      }

      if (count > 0) {
        // Update plan with frozen dates and extend tenure
        final currentTotal = planModel.totalInstallments;
        final newTotal = currentTotal + count;

        // Extend maturity date
        final collectionType = planModel.collectionType;
        DateTime maturity = planModel.maturityDate;
        for (int i = 0; i < count; i++) {
          switch (collectionType) {
            case 'weekly':
              maturity = maturity.add(const Duration(days: 7));
              break;
            case 'daily':
              maturity = maturity.add(const Duration(days: 1));
              break;
            default: // monthly
              int m = maturity.month + 1;
              int y = maturity.year + ((m - 1) ~/ 12);
              m = ((m - 1) % 12) + 1;
              int d = maturity.day;
              int dim = DateTime(y, m + 1, 0).day;
              if (d > dim) d = dim;
              maturity = DateTime(y, m, d);
          }
        }

        await _client.from('savings_plans').update({
          'frozen_count': planModel.frozenCount + count,
          'frozen_dates': newFrozenDates.toList(),
          'total_installments': newTotal,
          'maturity_date': maturity.toIso8601String().split('T')[0],
        }).eq('id', planId);
      }

      return count;
    } catch (e) {
      debugPrint('detectAndFreezeSkippedInstallments error: $e');
      return 0;
    }
  }

  /// Manually freeze all currently-skipped installments for a savings plan.
  Future<int> manualFreezeSkippedInstallments(String planId) async {
    return detectAndFreezeSkippedInstallments(planId, force: true);
  }

  /// Freeze a single specific savings installment by its date key (e.g. '2026-03-15').
  /// Adds it to frozen_dates, increments frozen_count, extends tenure.
  Future<bool> freezeSingleInstallment(String planId, String dateKey) async {
    try {
      debugPrint('freezeSingleInstallment: planId=$planId, dateKey=$dateKey');

      final plan = await _client
          .from('savings_plans')
          .select('*')
          .eq('id', planId)
          .maybeSingle();
      if (plan == null) {
        debugPrint('freezeSingleInstallment: plan not found');
        return false;
      }

      final planModel = SavingsModel.fromJson(plan);
      debugPrint('freezeSingleInstallment: existing frozen=${planModel.frozenDates}');
      final existingFrozen = planModel.frozenDates.toSet();

      // Already frozen? Skip.
      if (existingFrozen.contains(dateKey)) {
        debugPrint('freezeSingleInstallment: already frozen');
        return false;
      }

      final newFrozenDates = <String>{...existingFrozen, dateKey};
      debugPrint('freezeSingleInstallment: newFrozenDates=$newFrozenDates');

      // Extend tenure by 1
      final collectionType = planModel.collectionType;
      DateTime maturity = planModel.maturityDate;
      switch (collectionType) {
        case 'weekly':
          maturity = maturity.add(const Duration(days: 7));
          break;
        case 'daily':
          maturity = maturity.add(const Duration(days: 1));
          break;
        default: // monthly
          int m = maturity.month + 1;
          int y = maturity.year + ((m - 1) ~/ 12);
          m = ((m - 1) % 12) + 1;
          int d = maturity.day;
          int dim = DateTime(y, m + 1, 0).day;
          if (d > dim) d = dim;
          maturity = DateTime(y, m, d);
      }

      debugPrint('freezeSingleInstallment: updating plan...');
      await _client.from('savings_plans').update({
        'frozen_count': planModel.frozenCount + 1,
        'frozen_dates': newFrozenDates.toList(),
        'total_installments': planModel.totalInstallments + 1,
        'maturity_date': maturity.toIso8601String().split('T')[0],
      }).eq('id', planId);

      debugPrint('freezeSingleInstallment: success');
      return true;
    } catch (e) {
      debugPrint('freezeSingleInstallment error: $e');
      return false;
    }
  }

  /// Unfreeze a single specific savings installment by its date key.
  /// Removes it from frozen_dates, decrements frozen_count, and adjusts tenure.
  Future<bool> unfreezeSingleInstallment(String planId, String dateKey) async {
    try {
      debugPrint('unfreezeSingleInstallment: planId=$planId, dateKey=$dateKey');

      final plan = await _client
          .from('savings_plans')
          .select('*')
          .eq('id', planId)
          .maybeSingle();
      if (plan == null) return false;

      final planModel = SavingsModel.fromJson(plan);
      final existingFrozen = planModel.frozenDates.toSet();

      // Not frozen? Skip.
      if (!existingFrozen.contains(dateKey)) return false;

      final newFrozenDates = <String>{...existingFrozen}..remove(dateKey);

      // Decrement frozen_count
      final currentCount = planModel.frozenCount;

      // Reduce maturity date by 1 period
      final collectionType = planModel.collectionType;
      DateTime maturity = planModel.maturityDate;
      switch (collectionType) {
        case 'weekly':
          maturity = maturity.subtract(const Duration(days: 7));
          break;
        case 'daily':
          maturity = maturity.subtract(const Duration(days: 1));
          break;
        default: // monthly
          int m = maturity.month - 1;
          int y = maturity.year + ((m - 1) ~/ 12);
          m = ((m - 1) % 12) + 1;
          int d = maturity.day;
          int dim = DateTime(y, m + 1, 0).day;
          if (d > dim) d = dim;
          maturity = DateTime(y, m, d);
      }

      await _client.from('savings_plans').update({
        'frozen_count': (currentCount - 1).clamp(0, 999999),
        'frozen_dates': newFrozenDates.toList(),
        'total_installments': planModel.totalInstallments - 1,
        'maturity_date': maturity.toIso8601String().split('T')[0],
      }).eq('id', planId);

      debugPrint('unfreezeSingleInstallment: done');
      return true;
    } catch (e) {
      debugPrint('unfreezeSingleInstallment error: $e');
      return false;
    }
  }
}
