import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../models/today_payment_model.dart';

// Filter state
class PaymentFilterState {
  final String searchQuery;
  final String? branchId;
  final String? agentId;
  final DateTime selectedDate;
  final PaymentSortBy sortBy;
  final bool autoRefresh;

  const PaymentFilterState({
    this.searchQuery = '',
    this.branchId,
    this.agentId,
    required this.selectedDate,
    this.sortBy = PaymentSortBy.statusPriority,
    this.autoRefresh = true,
  });

  PaymentFilterState copyWith({
    String? searchQuery,
    String? branchId,
    String? agentId,
    DateTime? selectedDate,
    PaymentSortBy? sortBy,
    bool? autoRefresh,
    bool clearBranch = false,
    bool clearAgent = false,
  }) {
    return PaymentFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      branchId: clearBranch ? null : (branchId ?? this.branchId),
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
    final selected = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final diff = today.difference(selected).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff == -1) return 'Tomorrow';
    if (diff > 0 && diff <= 7) return '$diff days ago';
    return '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}';
  }
}

class PaymentFilterNotifier extends StateNotifier<PaymentFilterState> {
  PaymentFilterNotifier()
      : super(PaymentFilterState(selectedDate: DateTime.now()));

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setBranch(String? branchId) {
    if (branchId == null) {
      state = state.copyWith(clearBranch: true);
    } else {
      state = state.copyWith(branchId: branchId);
    }
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
    state = PaymentFilterState(selectedDate: DateTime.now());
  }
}

final paymentFilterProvider =
    StateNotifierProvider<PaymentFilterNotifier, PaymentFilterState>((ref) {
  return PaymentFilterNotifier();
});

// Available branches for filter
final paymentBranchesProvider =
    FutureProvider<List<Map<String, String>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.orgId == null) return [];

  try {
    final client = Supabase.instance.client;
    final branches = await client
        .from('branches')
        .select('id, name')
        .eq('org_id', user.orgId!)
        .eq('status', 'active')
        .order('name');

    return (branches as List)
        .map((b) => {'id': b['id'] as String, 'name': b['name'] as String})
        .toList();
  } catch (e) {
    debugPrint('Error fetching branches: $e');
    return [];
  }
});

// Available agents for filter
final paymentAgentsProvider =
    FutureProvider<List<Map<String, String>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.orgId == null) return [];

  try {
    final client = Supabase.instance.client;
    final profiles = await client
        .from('profiles')
        .select('id, full_name')
        .eq('org_id', user.orgId!)
        .inFilter('role', ['manager', 'collectionAgent'])
        .eq('status', 'active')
        .order('full_name');

    return (profiles as List)
        .map((p) => {'id': p['id'] as String, 'name': p['full_name'] as String})
        .toList();
  } catch (e) {
    debugPrint('Error fetching agents: $e');
    return [];
  }
});

// Main payments data provider
final todayPaymentsProvider =
    FutureProvider<TodayPaymentData>((ref) async {
  final user = ref.watch(currentUserProvider);
  debugPrint('todayPaymentsProvider: user = $user');
  debugPrint('todayPaymentsProvider: user.orgId = ${user?.orgId}');
  if (user == null || user.orgId == null) {
    debugPrint('todayPaymentsProvider: user or orgId is null, returning empty payments');
    return const TodayPaymentData(payments: []);
  }

  final client = Supabase.instance.client;
  final orgId = user.orgId!;
  final filters = ref.watch(paymentFilterProvider);
  final d = filters.selectedDate;
  final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  debugPrint('todayPaymentsProvider: orgId = $orgId, dateStr = $dateStr');

  final List<TodayPayment> payments = [];

  try {
    // 1. Fetch EMI dues for the selected date (due on that day + overdue)
    final emiDues = await client
        .from('emi_schedule')
        .select('id, emi_number, due_date, emi_amount, amount_paid, is_paid, status, penalty_amount, paid_on, payment_mode, loan_id')
        .eq('org_id', orgId)
        .eq('due_date', dateStr)
        .order('due_date', ascending: true);

    // Also fetch overdue EMIs (due before selected date, still unpaid)
    List<dynamic> overdueEmis = [];
    try {
      overdueEmis = await client
          .from('emi_schedule')
          .select('id, emi_number, due_date, emi_amount, amount_paid, is_paid, status, penalty_amount, paid_on, payment_mode, loan_id')
          .eq('org_id', orgId)
          .lt('due_date', dateStr)
          .eq('is_paid', false)
          .order('due_date', ascending: true);
    } catch (e) {
      debugPrint('Error fetching overdue EMIs: $e');
    }

    // Combine both lists
    final allEmiDues = [...emiDues, ...overdueEmis];

    // Collect unique loan IDs
    final loanIds = allEmiDues.map((e) => e['loan_id']).where((id) => id != null).toSet().toList();

    // Fetch loan details
    Map<String, Map<String, dynamic>> loansMap = {};
    if (loanIds.isNotEmpty) {
      final loans = await client
          .from('loans')
          .select('id, loan_number, branch_id, customer_id, agent_id')
          .inFilter('id', loanIds);
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

    // Fetch member details
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

      // Apply branch filter
      if (filters.branchId != null && loan['branch_id'] != filters.branchId) {
        continue;
      }

      // Apply agent filter
      if (filters.agentId != null && loan['agent_id'] != filters.agentId) {
        continue;
      }

      final isPaid = emi['is_paid'] == true;
      final dueDate = DateTime.parse(emi['due_date']);
      final isOverdue = !isPaid && dueDate.isBefore(
          DateTime(filters.selectedDate.year, filters.selectedDate.month,
              filters.selectedDate.day));

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
    debugPrint('Error fetching EMI dues: $e');
    debugPrint(stack.toString());
  }

  // Map to track collection IDs by loan_number for EMI revert support
  final Map<String, String> collectionIdByLoanNumber = {};

  try {
    // 2. Fetch collections for the selected date
    final collections = await client
        .from('collections')
        .select('id, amount_expected, amount_collected, collection_type, payment_mode, collection_date, collection_time, member_name, member_phone, loan_number, loan_id, member_id, staff_id, remarks')
        .eq('org_id', orgId)
        .eq('collection_date', dateStr)
        .order('collection_time', ascending: false);

    for (final col in collections) {
      // Apply agent filter
      if (filters.agentId != null && col['staff_id'] != filters.agentId) {
        continue;
      }

      // Track collection ID for loan_number lookup
      final loanNum = col['loan_number'] as String?;
      if (loanNum != null && col['id'] != null) {
        collectionIdByLoanNumber[loanNum] = col['id'] as String;
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
          branchId: null,
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
              ? DateTime.tryParse('${col['collection_date']}T${col['collection_time']}')
              : null,
          remarks: col['remarks'],
          collectionId: col['id'] as String?,
        ));
      }
    }
  } catch (e, stack) {
    debugPrint('Error fetching collections: $e');
    debugPrint(stack.toString());
  }

  // Backfill collectionId for collected EMIs that were deduplicated
  // (their id is emi_schedule.id, but delete needs collections.id)
  for (int i = 0; i < payments.length; i++) {
    final p = payments[i];
    if (p.isCollected && p.collectionId == null && p.loanNumber != null) {
      final cid = collectionIdByLoanNumber[p.loanNumber!];
      if (cid != null) {
        payments[i] = TodayPayment(
          id: p.id,
          type: p.type,
          status: p.status,
          memberName: p.memberName,
          memberPhone: p.memberPhone,
          memberId: p.memberId,
          branchId: p.branchId,
          branchName: p.branchName,
          agentId: p.agentId,
          agentName: p.agentName,
          amountExpected: p.amountExpected,
          amountCollected: p.amountCollected,
          penaltyAmount: p.penaltyAmount,
          dueDate: p.dueDate,
          loanNumber: p.loanNumber,
          loanId: p.loanId,
          emiNumber: p.emiNumber,
          planName: p.planName,
          paymentMode: p.paymentMode,
          collectedAt: p.collectedAt,
          remarks: p.remarks,
          collectionId: cid,
        );
      }
    }
  }

  // 3. Fetch savings plans due on the selected date
  try {
    final selectedDate = filters.selectedDate;
    final dayOfWeek = selectedDate.weekday - 1; // 0=Mon, 6=Sun
    final dayOfMonth = selectedDate.day;

    // First fetch savings plans
    final allActivePlans = await client
        .from('savings_plans')
        .select('id, plan_name, monthly_deposit, collection_type, collection_day_of_week, collection_day_of_month, next_due_date, member_id')
        .eq('org_id', orgId)
        .eq('status', 'active');

    // Fetch all savings collections for the selected date
    final collectionsToday = await client
        .from('savings_collections')
        .select('id, savings_plan_id, amount_collected, payment_mode, created_at')
        .eq('org_id', orgId)
        .eq('collection_date', dateStr);

    final collectionsMap = {
      for (final col in collectionsToday as List)
        if (col['savings_plan_id'] != null)
          col['savings_plan_id'] as String: col
    };
    final collectedPlanIds = collectionsMap.keys.toSet();

    // Filter plans that are due on the selected date OR were already collected today
    final savingsDues = (allActivePlans as List).where((plan) {
      final planId = plan['id'] as String;
      if (collectedPlanIds.contains(planId)) return true;

      final nextDue = plan['next_due_date'] as String?;
      final collectionType = plan['collection_type'] ?? 'daily';

      // If next_due_date matches exactly, it's due
      if (nextDue == dateStr) return true;

      // If next_due_date is before or on the selected date, it's overdue/due
      if (nextDue != null) {
        final nextDueDate = DateTime.tryParse(nextDue);
        if (nextDueDate != null) {
          // Compare date-only to avoid timezone skew (DB dates are UTC midnight,
          // selectedDate is local midnight which can differ by hours)
          final nextDateOnly = DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);
          final selectedDateOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
          if (!nextDateOnly.isAfter(selectedDateOnly)) {
            return true;
          }
        }
        return false;
      }

      // If next_due_date is null, determine by collection schedule
      switch (collectionType) {
        case 'weekly':
          return plan['collection_day_of_week'] == dayOfWeek;
        case 'monthly':
          return plan['collection_day_of_month'] == dayOfMonth;
        default: // daily
          return true;
      }
    }).toList();

    // Fetch member details in bulk for each plan
    final memberIds = savingsDues
        .map((p) => p['member_id'])
        .where((id) => id != null)
        .toSet()
        .toList();

    final Map<String, Map<String, dynamic>> savingsMembersMap = {};
    if (memberIds.isNotEmpty) {
      final members = await client
          .from('members')
          .select('id, full_name, phone, branch_id, agent_id')
          .inFilter('id', memberIds);
      for (final member in members) {
        savingsMembersMap[member['id']] = member;
      }
    }

    for (final plan in savingsDues) {
      final memberId = plan['member_id'];
      if (memberId == null || savingsMembersMap[memberId] == null) continue;

      final member = savingsMembersMap[memberId]!;

      // Apply branch filter
      if (filters.branchId != null && member['branch_id'] != filters.branchId) {
        continue;
      }

      // Apply agent filter
      if (filters.agentId != null && member['agent_id'] != filters.agentId) {
        continue;
      }

      final existingCollection = collectionsMap[plan['id']];
      final isCollected = existingCollection != null;

      // Determine if overdue (next_due_date is before today's date)
      final nextDueStr = plan['next_due_date'] as String?;
      final nextDueParsed = nextDueStr != null ? DateTime.tryParse(nextDueStr) : null;
      final nextDateOnly = nextDueParsed != null
          ? DateTime(nextDueParsed.year, nextDueParsed.month, nextDueParsed.day)
          : null;
      final selectedDateOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
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
        branchId: member['branch_id'],
        branchName: null,
        agentId: member['agent_id'],
        agentName: null,
        amountExpected: (plan['monthly_deposit'] as num?)?.toDouble() ?? 0,
        amountCollected: isCollected
            ? (existingCollection['amount_collected'] as num?)?.toDouble()
            : null,
        dueDate: isCollected
            ? DateTime.parse(dateStr)
            : (nextDueStr != null ? DateTime.parse(nextDueStr) : DateTime.parse(dateStr)),
        planName: plan['plan_name'],
        paymentMode: isCollected ? existingCollection['payment_mode'] : null,
        collectedAt: isCollected && existingCollection['created_at'] != null
            ? DateTime.tryParse(existingCollection['created_at'])
            : null,
        collectionId: isCollected
            ? existingCollection['id'] as String?
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
          branchId: member['branch_id'],
          branchName: null,
          agentId: member['agent_id'],
          agentName: null,
          amountExpected: (plan['monthly_deposit'] as num?)?.toDouble() ?? 0,
          dueDate: DateTime.parse(dateStr),
          planName: plan['plan_name'],
        ));
      }
    }
  } catch (e, stack) {
    debugPrint('Error fetching savings dues: $e');
    debugPrint(stack.toString());
  }

  // Apply search filter
  List<TodayPayment> filtered = payments;
  if (filters.searchQuery.isNotEmpty) {
    final query = filters.searchQuery.toLowerCase();
    filtered = payments.where((p) {
      return p.memberName.toLowerCase().contains(query) ||
          (p.memberPhone?.contains(query) ?? false) ||
          (p.loanNumber?.toLowerCase().contains(query) ?? false) ||
          (p.planName?.toLowerCase().contains(query) ?? false) ||
          (p.branchName?.toLowerCase().contains(query) ?? false) ||
          (p.agentName?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  // Apply sorting
  _sortPayments(filtered, filters.sortBy);

  return TodayPaymentData(payments: filtered, allPayments: payments);
});

void _sortPayments(List<TodayPayment> payments, PaymentSortBy sortBy) {
  switch (sortBy) {
    case PaymentSortBy.nameAsc:
      payments.sort((a, b) => a.memberName.compareTo(b.memberName));
    case PaymentSortBy.nameDesc:
      payments.sort((a, b) => b.memberName.compareTo(a.memberName));
    case PaymentSortBy.amountHigh:
      payments.sort(
          (a, b) => b.amountExpected.compareTo(a.amountExpected));
    case PaymentSortBy.amountLow:
      payments.sort(
          (a, b) => a.amountExpected.compareTo(b.amountExpected));
    case PaymentSortBy.dueDateOldest:
      payments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    case PaymentSortBy.dueDateNewest:
      payments.sort((a, b) => b.dueDate.compareTo(a.dueDate));
    case PaymentSortBy.branchAsc:
      payments.sort(
          (a, b) => (a.branchName ?? '').compareTo(b.branchName ?? ''));
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

class TodayPaymentData {
  final List<TodayPayment> payments;
  final List<TodayPayment> allPayments;

  const TodayPaymentData({required this.payments, List<TodayPayment>? allPayments})
      : allPayments = allPayments ?? payments;

  TodayPaymentSummary get summary =>
      TodayPaymentSummary.fromPayments(allPayments);

  List<TodayPayment> get pendingPayments =>
      payments.where((p) => p.isPending).toList();

  List<TodayPayment> get collectedPayments =>
      payments.where((p) => p.isCollected).toList();

  List<TodayPayment> get overduePayments =>
      payments.where((p) => p.isOverdue).toList();

  List<BranchSummary> get branchSummaries {
    final Map<String, BranchSummary> map = {};
    for (final p in allPayments) {
      final branchId = p.branchId ?? 'unknown';
      final branchName = p.branchName ?? 'Unknown Branch';
      if (!map.containsKey(branchId)) {
        map[branchId] = BranchSummary(
          branchId: branchId,
          branchName: branchName,
          totalDue: 0,
          totalCollected: 0,
          countDue: 0,
          countCollected: 0,
          countPending: 0,
        );
      }
      final existing = map[branchId]!;
      map[branchId] = BranchSummary(
        branchId: branchId,
        branchName: branchName,
        totalDue: existing.totalDue + p.amountExpected,
        totalCollected: existing.totalCollected +
            (p.isCollected ? (p.amountCollected ?? p.amountExpected) : 0),
        countDue: existing.countDue + 1,
        countCollected: existing.countCollected + (p.isCollected ? 1 : 0),
        countPending: existing.countPending + (p.isCollected ? 0 : 1),
      );
    }
    return map.values.toList()
      ..sort((a, b) => b.totalDue.compareTo(a.totalDue));
  }
}

// Auto-refresh timer provider
final autoRefreshTimerProvider = Provider<Timer?>((ref) {
  final filter = ref.watch(paymentFilterProvider);
  if (!filter.autoRefresh || !filter.isToday) return null;

  final timer = Timer.periodic(const Duration(minutes: 5), (_) {
    ref.invalidate(todayPaymentsProvider);
  });

  ref.onDispose(() => timer.cancel());
  return timer;
});
