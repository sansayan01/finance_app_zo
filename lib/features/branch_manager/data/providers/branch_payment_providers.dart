import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../payments/data/models/today_payment_model.dart';
import '../../../payments/data/providers/payment_providers.dart' show TodayPaymentData;

// =====================================================
// BRANCH PAYMENT FILTER STATE
// No branch filter needed — already scoped by family param
// =====================================================

class BranchPaymentFilterState {
  final String searchQuery;
  final String? agentId;
  final DateTime selectedDate;
  final PaymentSortBy sortBy;
  final bool autoRefresh;

  const BranchPaymentFilterState({
    this.searchQuery = '',
    this.agentId,
    required this.selectedDate,
    this.sortBy = PaymentSortBy.statusPriority,
    this.autoRefresh = true,
  });

  BranchPaymentFilterState copyWith({
    String? searchQuery,
    String? agentId,
    DateTime? selectedDate,
    PaymentSortBy? sortBy,
    bool? autoRefresh,
    bool clearAgent = false,
  }) {
    return BranchPaymentFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      agentId: clearAgent ? null : (agentId ?? this.agentId),
      selectedDate: selectedDate ?? this.selectedDate,
      sortBy: sortBy ?? this.sortBy,
      autoRefresh: autoRefresh ?? this.autoRefresh,
    );
  }

  bool get isToday {
    final now = DateTime.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
  }

  String get dateLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final diff = today.difference(selected).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff == -1) return 'Tomorrow';
    if (diff > 0 && diff <= 7) return '$diff days ago';
    return '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}';
  }
}

class BranchPaymentFilterNotifier
    extends StateNotifier<BranchPaymentFilterState> {
  BranchPaymentFilterNotifier()
      : super(BranchPaymentFilterState(selectedDate: DateTime.now()));

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setAgent(String? agentId) {
    if (agentId == null) {
      state = state.copyWith(clearAgent: true);
    } else {
      state = state.copyWith(agentId: agentId);
    }
  }

  void setDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
  }

  void setSortBy(PaymentSortBy sortBy) {
    state = state.copyWith(sortBy: sortBy);
  }

  void toggleAutoRefresh() {
    state = state.copyWith(autoRefresh: !state.autoRefresh);
  }

  void resetFilters() {
    state = BranchPaymentFilterState(selectedDate: DateTime.now());
  }
}

final branchPaymentFilterProvider = StateNotifierProvider<
    BranchPaymentFilterNotifier, BranchPaymentFilterState>((ref) {
  return BranchPaymentFilterNotifier();
});

// =====================================================
// BRANCH STAFF / AGENTS FOR FILTER
// Fetches collection agents & managers assigned to this branch
// =====================================================

final branchPaymentAgentsProvider =
    FutureProvider.family<List<Map<String, String>>, String>(
        (ref, branchId) async {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);

  try {
    final profiles = await client
        .from('profiles')
        .select('id, full_name')
        .eq('org_id', orgId)
        .eq('branch_id', branchId)
        .inFilter('role', ['manager', 'collectionAgent'])
        .eq('status', 'active')
        .order('full_name');

    return (profiles as List)
        .map(
            (p) => {'id': p['id'] as String, 'name': p['full_name'] as String})
        .toList();
  } catch (e) {
    debugPrint('Error fetching branch agents: $e');
    return [];
  }
});

// =====================================================
// MAIN BRANCH-SCOPED PAYMENTS PROVIDER
// Filters EMI dues, collections, and savings by branch_id
// Uses sequential queries (no nested FK joins) per project pattern
// =====================================================

final branchTodayPaymentsProvider =
    FutureProvider.family<TodayPaymentData, String>(
        (ref, branchId) async {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  final filters = ref.watch(branchPaymentFilterProvider);
  final d = filters.selectedDate;
  final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  final List<TodayPayment> payments = [];

  // -------------------------------------------------------
  // 1. EMI DUES — filter loans by branch_id at DB level
  // -------------------------------------------------------
  try {
    // Fetch EMI dues for the selected date
    final emiDues = await client
        .from('emi_schedule')
        .select(
            'id, emi_number, due_date, emi_amount, amount_paid, is_paid, status, penalty_amount, paid_on, payment_mode, loan_id')
        .eq('org_id', orgId)
        .eq('due_date', dateStr)
        .order('due_date', ascending: true);

    // Overdue EMIs (due before selected date, still unpaid)
    List<dynamic> overdueEmis = [];
    try {
      overdueEmis = await client
          .from('emi_schedule')
          .select(
              'id, emi_number, due_date, emi_amount, amount_paid, is_paid, status, penalty_amount, paid_on, payment_mode, loan_id')
          .eq('org_id', orgId)
          .lt('due_date', dateStr)
          .eq('is_paid', false)
          .order('due_date', ascending: true);
    } catch (e) {
      debugPrint('Error fetching overdue EMIs: $e');
    }

    final allEmiDues = [...emiDues, ...overdueEmis];

    // Collect unique loan IDs
    final loanIds = allEmiDues
        .map((e) => e['loan_id'])
        .where((id) => id != null)
        .toSet()
        .toList();

    // Fetch loan details filtered to this branch at DB level
    Map<String, Map<String, dynamic>> loansMap = {};
    if (loanIds.isNotEmpty) {
      final loans = await client
          .from('loans')
          .select('id, loan_number, branch_id, customer_id, agent_id')
          .inFilter('id', loanIds)
          .eq('branch_id', branchId);
      for (final loan in loans) {
        loansMap[loan['id']] = loan;
      }
    }

    // Collect unique customer IDs for member details
    final customerIds = loansMap.values
        .map((l) => l['customer_id'])
        .where((id) => id != null)
        .toSet()
        .toList();

    Map<String, Map<String, dynamic>> membersMap = {};
    if (customerIds.isNotEmpty) {
      final members = await client
          .from('members')
          .select('id, full_name, phone')
          .inFilter('id', customerIds);
      for (final member in members) {
        membersMap[member['id']] = member;
      }
    }

    for (final emi in allEmiDues) {
      final loanId = emi['loan_id'];
      if (loanId == null || loansMap[loanId] == null) continue;

      final loan = loansMap[loanId]!;
      final member = membersMap[loan['customer_id']];

      // Apply agent filter
      if (filters.agentId != null && loan['agent_id'] != filters.agentId) {
        continue;
      }

      final isPaid = emi['is_paid'] == true;
      final dueDate = DateTime.parse(emi['due_date']);
      final isOverdue = !isPaid &&
          dueDate.isBefore(DateTime(filters.selectedDate.year,
              filters.selectedDate.month, filters.selectedDate.day));

      payments.add(TodayPayment(
        id: emi['id'],
        type: PaymentType.emi,
        status: isPaid
            ? PaymentStatus.collected
            : (isOverdue ? PaymentStatus.overdue : PaymentStatus.pending),
        memberName: member?['full_name'] ?? 'Unknown',
        memberPhone: member?['phone'],
        memberId: member?['id'],
        branchId: loan['branch_id'],
        branchName: null,
        agentId: loan['agent_id'],
        agentName: null,
        amountExpected: (emi['emi_amount'] as num?)?.toDouble() ?? 0,
        penaltyAmount: (emi['penalty_amount'] as num?)?.toDouble() ?? 0,
        amountCollected: isPaid
            ? (emi['amount_paid'] as num?)?.toDouble() ??
                (emi['emi_amount'] as num?)?.toDouble()
            : null,
        dueDate: dueDate,
        loanNumber: loan['loan_number'],
        loanId: loan['id'],
        emiNumber: emi['emi_number']?.toString(),
        paymentMode: emi['payment_mode'],
        collectedAt: emi['paid_on'] != null
            ? DateTime.tryParse(emi['paid_on'])
            : null,
      ));
    }
  } catch (e, stack) {
    debugPrint('Error fetching branch EMI dues: $e');
    debugPrint(stack.toString());
  }

  // -------------------------------------------------------
  // 2. COLLECTIONS — sequential query: fetch collections,
  //    then loans for branch filtering (no nested FK join)
  // -------------------------------------------------------
  try {
    final collections = await client
        .from('collections')
        .select(
            'id, amount_expected, amount_collected, collection_type, payment_mode, collection_date, collection_time, member_name, member_phone, loan_number, loan_id, member_id, staff_id, remarks')
        .eq('org_id', orgId)
        .eq('collection_date', dateStr)
        .order('collection_time', ascending: false);

    // Fetch loan branch info for filtering (sequential, not nested join)
    final collectionLoanIds = (collections as List)
        .map((c) => c['loan_id'])
        .where((id) => id != null)
        .toSet()
        .toList();

    Map<String, Map<String, dynamic>> collectionLoansMap = {};
    if (collectionLoanIds.isNotEmpty) {
      final loans = await client
          .from('loans')
          .select('id, branch_id')
          .inFilter('id', collectionLoanIds);
      for (final loan in loans) {
        collectionLoansMap[loan['id']] = loan;
      }
    }

    for (final col in collections) {
      // Filter by branch via loan lookup
      final loanId = col['loan_id'];
      if (loanId == null) continue;
      final loan = collectionLoansMap[loanId];
      if (loan == null || loan['branch_id'] != branchId) continue;

      // Apply agent filter
      if (filters.agentId != null && col['staff_id'] != filters.agentId) {
        continue;
      }

      final existingIdx = payments.indexWhere(
          (p) => p.loanNumber == col['loan_number'] && p.isCollected);

      if (existingIdx == -1) {
        payments.add(TodayPayment(
          id: col['id'],
          type: col['collection_type'] == 'savings'
              ? PaymentType.savings
              : PaymentType.emi,
          status: PaymentStatus.collected,
          memberName: col['member_name'] ?? 'Unknown',
          memberPhone: col['member_phone'],
          memberId: col['member_id'],
          branchId: branchId,
          branchName: null,
          agentId: col['staff_id'],
          agentName: null,
          amountExpected:
              (col['amount_expected'] as num?)?.toDouble() ?? 0,
          amountCollected:
              (col['amount_collected'] as num?)?.toDouble() ?? 0,
          dueDate: DateTime.parse(col['collection_date']),
          loanNumber: col['loan_number'],
          loanId: col['loan_id'],
          paymentMode: col['payment_mode'],
          collectedAt: col['collection_time'] != null
              ? DateTime.tryParse(
                  '${col['collection_date']}T${col['collection_time']}')
              : null,
          remarks: col['remarks'],
        ));
      }
    }
  } catch (e, stack) {
    debugPrint('Error fetching branch collections: $e');
    debugPrint(stack.toString());
  }

  // -------------------------------------------------------
  // 3. SAVINGS — savings_plans has no branch_id,
  //    join with members to filter by branch_id at query level
  // -------------------------------------------------------
  try {
    final selectedDate = filters.selectedDate;
    final dayOfWeek = selectedDate.weekday - 1; // 0=Mon, 6=Sun
    final dayOfMonth = selectedDate.day;

    // Fetch active savings plans with member join for branch filtering
    final allActivePlans = await client
        .from('savings_plans')
        .select(
            'id, plan_name, monthly_deposit, collection_type, collection_day_of_week, collection_day_of_month, next_due_date, member_id, members:member_id(full_name, phone, branch_id, agent_id)')
        .eq('org_id', orgId)
        .eq('status', 'active');

    // Filter to branch via member join result
    final branchPlans = (allActivePlans as List).where((plan) {
      final member = plan['members'] as Map<String, dynamic>?;
      return member?['branch_id'] == branchId;
    }).toList();

    // Fetch savings collections for the selected date
    final collectionsToday = await client
        .from('savings_collections')
        .select(
            'id, savings_plan_id, amount_collected, payment_mode, created_at')
        .eq('org_id', orgId)
        .eq('collection_date', dateStr);

    final collectionsMap = {
      for (final col in collectionsToday as List)
        if (col['savings_plan_id'] != null)
          col['savings_plan_id'] as String: col
    };
    final collectedPlanIds = collectionsMap.keys.toSet();

    // Filter plans that are due on the selected date OR already collected
    final savingsDues = branchPlans.where((plan) {
      final planId = plan['id'] as String;
      if (collectedPlanIds.contains(planId)) return true;

      final nextDue = plan['next_due_date'] as String?;
      final collectionType = plan['collection_type'] ?? 'daily';

      if (nextDue == dateStr) return true;

      if (nextDue != null) {
        final nextDueDate = DateTime.tryParse(nextDue);
        if (nextDueDate != null && !nextDueDate.isAfter(selectedDate)) {
          return true;
        }
        return false;
      }

      switch (collectionType) {
        case 'weekly':
          return plan['collection_day_of_week'] == dayOfWeek;
        case 'monthly':
          return plan['collection_day_of_month'] == dayOfMonth;
        default:
          return true;
      }
    }).toList();

    for (final plan in savingsDues) {
      final member = plan['members'] as Map<String, dynamic>?;
      if (member == null) continue;

      // Apply agent filter
      if (filters.agentId != null && member['agent_id'] != filters.agentId) {
        continue;
      }

      final existingCollection = collectionsMap[plan['id']];
      final isCollected = existingCollection != null;

      final nextDueStr = plan['next_due_date'] as String?;
      final nextDueParsed =
          nextDueStr != null ? DateTime.tryParse(nextDueStr) : null;
      final nextDateOnly = nextDueParsed != null
          ? DateTime(
              nextDueParsed.year, nextDueParsed.month, nextDueParsed.day)
          : null;
      final selectedDateOnly = DateTime(
          selectedDate.year, selectedDate.month, selectedDate.day);
      final isOverdue = !isCollected &&
          nextDateOnly != null &&
          nextDateOnly.isBefore(selectedDateOnly);

      payments.add(TodayPayment(
        id: plan['id'],
        type: PaymentType.savings,
        status: isCollected
            ? PaymentStatus.collected
            : (isOverdue ? PaymentStatus.overdue : PaymentStatus.pending),
        memberName: member['full_name'] ?? 'Unknown',
        memberPhone: member['phone'],
        memberId: member['id'],
        branchId: branchId,
        branchName: null,
        agentId: member['agent_id'],
        agentName: null,
        amountExpected:
            (plan['monthly_deposit'] as num?)?.toDouble() ?? 0,
        amountCollected: isCollected
            ? (existingCollection['amount_collected'] as num?)?.toDouble()
            : null,
        dueDate: isCollected
            ? DateTime.parse(dateStr)
            : (nextDueStr != null
                ? DateTime.parse(nextDueStr)
                : DateTime.parse(dateStr)),
        planName: plan['plan_name'],
        paymentMode: isCollected ? existingCollection['payment_mode'] : null,
        collectedAt: isCollected && existingCollection['created_at'] != null
            ? DateTime.tryParse(existingCollection['created_at'])
            : null,
      ));

      // For daily collections that are overdue, also add a pending entry for today
      if (isOverdue && (plan['collection_type'] ?? 'monthly') == 'daily') {
        payments.add(TodayPayment(
          id: '${plan['id']}_today',
          type: PaymentType.savings,
          status: PaymentStatus.pending,
          memberName: member['full_name'] ?? 'Unknown',
          memberPhone: member['phone'],
          memberId: member['id'],
          branchId: branchId,
          branchName: null,
          agentId: member['agent_id'],
          agentName: null,
          amountExpected:
              (plan['monthly_deposit'] as num?)?.toDouble() ?? 0,
          dueDate: DateTime.parse(dateStr),
          planName: plan['plan_name'],
        ));
      }
    }
  } catch (e, stack) {
    debugPrint('Error fetching branch savings dues: $e');
    debugPrint(stack.toString());
  }

  // -------------------------------------------------------
  // 4. APPLY SEARCH + SORT
  // -------------------------------------------------------
  List<TodayPayment> filtered = payments;
  if (filters.searchQuery.isNotEmpty) {
    final query = filters.searchQuery.toLowerCase();
    filtered = payments.where((p) {
      return p.memberName.toLowerCase().contains(query) ||
          (p.memberPhone?.contains(query) ?? false) ||
          (p.loanNumber?.toLowerCase().contains(query) ?? false) ||
          (p.planName?.toLowerCase().contains(query) ?? false) ||
          (p.agentName?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  _sortPayments(filtered, filters.sortBy);

  return TodayPaymentData(payments: filtered, allPayments: payments);
});

// =====================================================
// SORT HELPER (same logic as admin)
// =====================================================

void _sortPayments(List<TodayPayment> payments, PaymentSortBy sortBy) {
  switch (sortBy) {
    case PaymentSortBy.nameAsc:
      payments.sort((a, b) => a.memberName.compareTo(b.memberName));
    case PaymentSortBy.nameDesc:
      payments.sort((a, b) => b.memberName.compareTo(a.memberName));
    case PaymentSortBy.amountHigh:
      payments.sort((a, b) => b.amountExpected.compareTo(a.amountExpected));
    case PaymentSortBy.amountLow:
      payments.sort((a, b) => a.amountExpected.compareTo(b.amountExpected));
    case PaymentSortBy.dueDateOldest:
      payments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    case PaymentSortBy.dueDateNewest:
      payments.sort((a, b) => b.dueDate.compareTo(a.dueDate));
    case PaymentSortBy.branchAsc:
      payments
          .sort((a, b) => (a.branchName ?? '').compareTo(b.branchName ?? ''));
    case PaymentSortBy.statusPriority:
      payments.sort((a, b) {
        final statusOrder = {
          PaymentStatus.overdue: 0,
          PaymentStatus.pending: 1,
          PaymentStatus.collected: 2,
        };
        final statusCompare = (statusOrder[a.status] ?? 3)
            .compareTo(statusOrder[b.status] ?? 3);
        if (statusCompare != 0) return statusCompare;
        return a.dueDate.compareTo(b.dueDate);
      });
  }
}

// =====================================================
// AUTO-REFRESH TIMER
// Invalidates branchTodayPaymentsProvider every 5 minutes
// when auto-refresh is on and the selected date is today
// =====================================================

final branchAutoRefreshTimerProvider = Provider<Timer?>((ref) {
  final filter = ref.watch(branchPaymentFilterProvider);
  if (!filter.autoRefresh || !filter.isToday) return null;

  final timer = Timer.periodic(const Duration(minutes: 5), (_) {
    ref.invalidate(branchTodayPaymentsProvider);
  });

  ref.onDispose(() => timer.cancel());
  return timer;
});
