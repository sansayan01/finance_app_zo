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
  if (user == null || user.orgId == null) {
    return const TodayPaymentData(payments: []);
  }

  final client = Supabase.instance.client;
  final orgId = user.orgId!;
  final filters = ref.watch(paymentFilterProvider);
  final dateStr = filters.selectedDate.toIso8601String().split('T').first;

  final List<TodayPayment> payments = [];

  try {
    // 1. Fetch EMI dues for the selected date (due on that day + overdue)
    final emiDues = await client
        .from('emi_schedule')
        .select('''
          id,
          emi_number,
          due_date,
          emi_amount,
          is_paid,
          status,
          penalty_amount,
          paid_on,
          payment_mode,
          loans!fk_emi_loan(
            id,
            loan_number,
            org_id,
            branch_id,
            customer_id,
            agent_id,
            members!fk_loans_customer(id, full_name, phone),
            branches(id, name),
            profiles!fk_loans_agent(id, full_name)
          )
        ''')
        .eq('org_id', orgId)
        .eq('due_date', dateStr)
        .order('due_date', ascending: true);

    // Also fetch overdue EMIs (due before selected date, still unpaid)
    List<dynamic> overdueEmis = [];
    try {
      overdueEmis = await client
          .from('emi_schedule')
          .select('''
            id,
            emi_number,
            due_date,
            emi_amount,
            is_paid,
            status,
            penalty_amount,
            paid_on,
            payment_mode,
            loans!fk_emi_loan(
              id,
              loan_number,
              org_id,
              branch_id,
              customer_id,
              agent_id,
              members!fk_loans_customer(id, full_name, phone),
              branches(id, name),
              profiles!fk_loans_agent(id, full_name)
            )
          ''')
          .eq('org_id', orgId)
          .lt('due_date', dateStr)
          .eq('is_paid', false)
          .order('due_date', ascending: true);
    } catch (e) {
      debugPrint('Error fetching overdue EMIs: $e');
    }

    // Combine both lists
    final allEmiDues = [...emiDues, ...overdueEmis];

    for (final emi in allEmiDues) {
      final loan = emi['loans'];
      if (loan == null) continue;

      final member = loan['members'];
      final branch = loan['branches'];
      final agent = loan['profiles'];

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
        branchName: branch?['name'],
        agentId: agent?['id'],
        agentName: agent?['full_name'],
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
  } catch (e) {
    debugPrint('Error fetching EMI dues: $e');
  }

  try {
    // 2. Fetch collections for the selected date
    final collections = await client
        .from('collections')
        .select('''
          id,
          amount_expected,
          amount_collected,
          collection_type,
          payment_mode,
          collection_date,
          collection_time,
          member_name,
          member_phone,
          loan_number,
          loan_id,
          member_id,
          staff_id,
          remarks,
          loans!fk_collections_loan(id, loan_number, branch_id, members!fk_loans_customer(id, full_name, phone)),
          profiles!fk_collections_staff(id, full_name),
          branches(name)
        ''')
        .eq('org_id', orgId)
        .eq('collection_date', dateStr)
        .order('collection_time', ascending: false);

    for (final col in collections) {
      // Apply branch filter
      if (filters.branchId != null &&
          col['loans']?['branch_id'] != filters.branchId) {
        continue;
      }

      // Apply agent filter
      if (filters.agentId != null && col['staff_id'] != filters.agentId) {
        continue;
      }

      final existingIdx = payments.indexWhere(
          (p) => p.loanNumber == col['loan_number'] && p.isCollected);

      if (existingIdx == -1) {
        final member = col['loans']?['members'];
        final agent = col['profiles'];

        payments.add(TodayPayment(
          id: col['id'],
          type: col['collection_type'] == 'savings'
              ? PaymentType.savings
              : PaymentType.emi,
          status: PaymentStatus.collected,
          memberName:
              col['member_name'] ?? member?['full_name'] ?? 'Unknown',
          memberPhone: col['member_phone'] ?? member?['phone'],
          memberId: col['member_id'] ?? member?['id'],
          branchId: col['loans']?['branch_id'],
          branchName: col['branches']?['name'],
          agentId: col['staff_id'],
          agentName: agent?['full_name'],
          amountExpected:
              (col['amount_expected'] as num?)?.toDouble() ?? 0,
          amountCollected:
              (col['amount_collected'] as num?)?.toDouble() ?? 0,
          dueDate: DateTime.parse(col['collection_date']),
          loanNumber: col['loan_number'],
          loanId: col['loan_id'],
          paymentMode: col['payment_mode'],
          collectedAt: col['collection_time'] != null
              ? DateTime.tryParse(col['collection_time'])
              : null,
          remarks: col['remarks'],
        ));
      }
    }
  } catch (e) {
    debugPrint('Error fetching collections: $e');
  }

  // Apply search filter
  List<TodayPayment> filtered = payments;
  if (filters.searchQuery.isNotEmpty) {
    final query = filters.searchQuery.toLowerCase();
    filtered = payments.where((p) {
      return p.memberName.toLowerCase().contains(query) ||
          (p.memberPhone?.contains(query) ?? false) ||
          (p.loanNumber?.toLowerCase().contains(query) ?? false) ||
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
