import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../models/today_payment_model.dart';
import '../../../../core/constants/enums.dart';

// Filter state
class PaymentFilterState {
  final String searchQuery;
  final String? branchId;
  final String? agentId;
  final DateTime selectedDate;
  final PaymentSortBy sortBy;
  final bool autoRefresh;
  final PaymentType? paymentTypeFilter;
  final Set<PaymentStatus> statusFilters;
  final double? minAmount;
  final double? maxAmount;
  final Set<String> paymentModeFilters;
  final Set<OverdueBucket> overdueDayFilters;

  const PaymentFilterState({
    this.searchQuery = '',
    this.branchId,
    this.agentId,
    required this.selectedDate,
    this.sortBy = PaymentSortBy.statusPriority,
    this.autoRefresh = true,
    this.paymentTypeFilter,
    this.statusFilters = const {},
    this.minAmount,
    this.maxAmount,
    this.paymentModeFilters = const {},
    this.overdueDayFilters = const {},
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
    PaymentType? paymentTypeFilter,
    bool clearPaymentType = false,
    Set<PaymentStatus>? statusFilters,
    double? minAmount,
    bool clearMinAmount = false,
    double? maxAmount,
    bool clearMaxAmount = false,
    Set<String>? paymentModeFilters,
    Set<OverdueBucket>? overdueDayFilters,
  }) {
    return PaymentFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      branchId: clearBranch ? null : (branchId ?? this.branchId),
      agentId: clearAgent ? null : (agentId ?? this.agentId),
      selectedDate: selectedDate ?? this.selectedDate,
      sortBy: sortBy ?? this.sortBy,
      autoRefresh: autoRefresh ?? this.autoRefresh,
      paymentTypeFilter: clearPaymentType
          ? null
          : (paymentTypeFilter ?? this.paymentTypeFilter),
      statusFilters: statusFilters ?? this.statusFilters,
      minAmount: clearMinAmount ? null : (minAmount ?? this.minAmount),
      maxAmount: clearMaxAmount ? null : (maxAmount ?? this.maxAmount),
      paymentModeFilters: paymentModeFilters ?? this.paymentModeFilters,
      overdueDayFilters: overdueDayFilters ?? this.overdueDayFilters,
    );
  }

  bool get hasActiveFilters =>
      branchId != null ||
      agentId != null ||
      paymentTypeFilter != null ||
      statusFilters.isNotEmpty ||
      minAmount != null ||
      maxAmount != null ||
      paymentModeFilters.isNotEmpty ||
      overdueDayFilters.isNotEmpty;

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
    // Show exact date with full month name
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${selectedDate.day} ${months[selectedDate.month - 1]} ${selectedDate.year}';
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

  void setPaymentType(PaymentType? type) {
    state = state.copyWith(
      paymentTypeFilter: type,
      clearPaymentType: type == null,
    );
  }

  void toggleStatusFilter(PaymentStatus status) {
    final updated = Set<PaymentStatus>.from(state.statusFilters);
    updated.contains(status) ? updated.remove(status) : updated.add(status);
    state = state.copyWith(statusFilters: updated);
  }

  void setAmountRange(
      {double? min,
      double? max,
      bool clearMin = false,
      bool clearMax = false}) {
    state = state.copyWith(
      minAmount: min,
      maxAmount: max,
      clearMinAmount: clearMin,
      clearMaxAmount: clearMax,
    );
  }

  void togglePaymentMode(String mode) {
    final updated = Set<String>.from(state.paymentModeFilters);
    updated.contains(mode) ? updated.remove(mode) : updated.add(mode);
    state = state.copyWith(paymentModeFilters: updated);
  }

  void toggleOverdueBucket(OverdueBucket bucket) {
    final updated = Set<OverdueBucket>.from(state.overdueDayFilters);
    updated.contains(bucket) ? updated.remove(bucket) : updated.add(bucket);
    state = state.copyWith(overdueDayFilters: updated);
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
final todayPaymentsProvider = FutureProvider<TodayPaymentData>((ref) async {
  final user = ref.watch(currentUserProvider);
  debugPrint('todayPaymentsProvider: user = $user');
  debugPrint('todayPaymentsProvider: user.orgId = ${user?.orgId}');
  if (user == null) {
    debugPrint('todayPaymentsProvider: user is null, returning empty payments');
    return const TodayPaymentData(payments: []);
  }

  final client = Supabase.instance.client;
  final orgId = user.orgId;
  final isSuperAdmin = user.role == UserRole.superAdmin;
  final filters = ref.watch(paymentFilterProvider);
  final d = filters.selectedDate;
  final dateStr =
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  debugPrint('todayPaymentsProvider: orgId = $orgId, dateStr = $dateStr');

  final List<TodayPayment> payments = [];

  // Helper to extract maps from nested lists/maps returned by Supabase joins
  Map<String, dynamic>? getNestedMap(dynamic value) {
    if (value == null) return null;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return null;
  }

  // Resolve a member's profile photo URL from a joined members map, in the
  // same priority order: profile_photo_url → shop_photo_url → profile.avatar_url
  String? resolveMemberPhoto(Map<String, dynamic>? member) {
    if (member == null) return null;
    final direct =
        (member['profile_photo_url'] ?? member['shop_photo_url'])?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    final profile = member['profile'];
    if (profile is Map) {
      final avatar = profile['avatar_url']?.toString();
      if (avatar != null && avatar.isNotEmpty) return avatar;
    } else {
      final avatar = member['avatar_url']?.toString();
      if (avatar != null && avatar.isNotEmpty) return avatar;
    }
    return null;
  }

  try {
    // 1. Build queries to run in parallel

    // Query A: EMI base for selected date (joined with loans and members)
    // Only fetch unpaid EMIs - paid EMIs are handled separately via collections
    const emiSelect =
        'id, emi_number, due_date, emi_amount, amount_paid, is_paid, status, penalty_amount, paid_on, payment_mode, loan_id, '
        'loans!emi_schedule_loan_id_fkey(id, loan_number, branch_id, customer_id, agent_id, members!fk_loans_customer(id, full_name, phone, profile_photo_url, profile:profile_id(avatar_url)))';

    final emiBase = client
        .from('emi_schedule')
        .select(emiSelect)
        .eq('due_date', dateStr)
        .eq('is_paid', false);
    final emiQuery = (isSuperAdmin ? emiBase : emiBase.eq('org_id', orgId!))
        .order('due_date', ascending: true);

    // Query B: Overdue EMIs (joined with loans and members)
    final overdueBase = client
        .from('emi_schedule')
        .select(emiSelect)
        .lt('due_date', dateStr)
        .eq('is_paid', false);
    final overdueQuery =
        (isSuperAdmin ? overdueBase : overdueBase.eq('org_id', orgId!))
            .order('due_date', ascending: true);

    // Query C: Collections for selected date
    final collectionsBase = client
        .from('collections')
        .select(
            'id, amount_expected, amount_collected, collection_type, payment_mode, collection_date, collection_time, member_name, member_phone, loan_number, loan_id, selected_schedule_id, member_id, staff_id, remarks')
        .eq('collection_date', dateStr);
    final collectionsQuery =
        (isSuperAdmin ? collectionsBase : collectionsBase.eq('org_id', orgId!))
            .order('collection_time', ascending: false);

    // Query D: Savings plans (joined with members)
    var plansQuery = client
        .from('savings_plans')
        .select(
            'id, plan_name, monthly_deposit, collection_type, collection_day_of_week, collection_day_of_month, next_due_date, start_date, member_id, installments_paid, total_installments, '
            'members(id, full_name, phone, branch_id, agent_id, profile_photo_url, profile:profile_id(avatar_url))')
        .eq('status', 'active');
    if (!isSuperAdmin) plansQuery = plansQuery.eq('org_id', orgId!);

    // Query E: Savings collections for selected date
    // Use collected_at (UTC timestamp) to detect any collection made today,
    // regardless of collection_date which may differ for overdue installments.
    final dayStartUtc = DateTime(d.year, d.month, d.day).toUtc();
    final dayEndUtc = DateTime(d.year, d.month, d.day + 1).toUtc();
    var savingsColQuery = client
        .from('savings_collections')
        .select(
            'id, savings_plan_id, amount_collected, payment_mode, collected_at, created_at')
        .gte('collected_at', dayStartUtc.toIso8601String())
        .lt('collected_at', dayEndUtc.toIso8601String());
    if (!isSuperAdmin) savingsColQuery = savingsColQuery.eq('org_id', orgId!);

    // 2. Await all Supabase requests concurrently
    final results = await Future.wait([
      emiQuery,
      overdueQuery,
      collectionsQuery,
      plansQuery,
      savingsColQuery,
    ]);

    final List<dynamic> emiDues = results[0] as List<dynamic>;
    final List<dynamic> overdueEmis = results[1] as List<dynamic>;
    final List<dynamic> collections = results[2] as List<dynamic>;
    final List<dynamic> allActivePlans = results[3] as List<dynamic>;
    final List<dynamic> collectionsToday = results[4] as List<dynamic>;

    // 3. Process EMIs (today + overdue)
    // A collection's collection_date is the date the payment was recorded, not
    // necessarily the due date of the EMI it settles. Only the explicit schedule
    // link is safe here; matching loan_id + collection_date can incorrectly mark
    // today's EMI as collected when the user paid older installments.
    final collectedScheduleIds = <String>{};
    for (final c in collections) {
      final scheduleId = c['selected_schedule_id'] as String?;
      if (scheduleId != null) {
        collectedScheduleIds.add(scheduleId);
      }
    }

    final allEmiDues = [...emiDues, ...overdueEmis];

    for (final emi in allEmiDues) {
      // If this EMI was already collected today (via selected_schedule_id in
      // today's collections), skip adding it to the payments list here.
      // The collection-processing step below will add it as a collected entry.
      // This prevents duplicate overdue+collected entries when the DB trigger
      // hasn't yet set is_paid=true on the schedule.
      final emiId = emi['id']?.toString();
      if (emiId != null && collectedScheduleIds.contains(emiId)) continue;

      final loan = getNestedMap(emi['loans!emi_schedule_loan_id_fkey']) ??
          getNestedMap(emi['loans']);
      if (loan == null) continue;

      final member = getNestedMap(loan['members!fk_loans_customer']) ??
          getNestedMap(loan['members']);

      // Apply branch filter
      if (filters.branchId != null && loan['branch_id'] != filters.branchId) {
        continue;
      }

      // Apply agent filter
      if (filters.agentId != null && loan['agent_id'] != filters.agentId) {
        continue;
      }

      final isPaid = emi['is_paid'] == true ||
          collectedScheduleIds.contains(emi['id']?.toString());
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
            ? ((emi['amount_paid'] as num?)?.toDouble() ?? 0) > 0
                ? (emi['amount_paid'] as num?)?.toDouble()
                : (emi['emi_amount'] as num?)?.toDouble()
            : null,
        dueDate: dueDate,
        loanNumber: loan['loan_number'],
        loanId: loan['id'],
        emiNumber: emi['emi_number']?.toString(),
        paymentMode: emi['payment_mode'],
        collectedAt: emi['paid_on'] != null
            ? DateTime.tryParse(emi['paid_on'])?.toLocal()
            : null,
        memberPhotoUrl: resolveMemberPhoto(member),
      ));
    }

    // Map to track collection IDs by loan_number for EMI revert support
    final Map<String, String> collectionIdByLoanNumber = {};

    // 4. Process EMI/Savings collections from "collections" table
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

      final collectionAmountCollected =
          (col['amount_collected'] as num?)?.toDouble() ?? 0;
      final selectedScheduleId = col['selected_schedule_id'] as String?;

      // Check if there's an existing unpaid EMI entry for the same loan/schedule
      // If so, update it to be collected instead of adding a duplicate
      // Use selected_schedule_id first (exact match), then fallback to loanId match
      int existingEmiIdx = -1;
      if (selectedScheduleId != null) {
        existingEmiIdx = payments.indexWhere((p) =>
            p.id == selectedScheduleId &&
            !p.isCollected &&
            p.type == PaymentType.emi);
      }
      if (existingEmiIdx == -1) {
        existingEmiIdx = payments.indexWhere((p) =>
            p.loanId == col['loan_id'] &&
            !p.isCollected &&
            p.type == PaymentType.emi);
      }

      if (existingEmiIdx != -1) {
        // Update the existing EMI entry to mark it as collected
        final existingEmi = payments[existingEmiIdx];
        payments[existingEmiIdx] = TodayPayment(
          id: existingEmi.id,
          type: existingEmi.type,
          status: PaymentStatus.collected,
          memberName: existingEmi.memberName,
          memberPhone: existingEmi.memberPhone,
          memberId: existingEmi.memberId,
          branchId: existingEmi.branchId,
          branchName: existingEmi.branchName,
          agentId: existingEmi.agentId,
          agentName: existingEmi.agentName,
          amountExpected: existingEmi.amountExpected,
          amountCollected: collectionAmountCollected > 0
              ? collectionAmountCollected
              : existingEmi.amountExpected,
          penaltyAmount: existingEmi.penaltyAmount,
          dueDate: existingEmi.dueDate,
          loanNumber: existingEmi.loanNumber,
          loanId: existingEmi.loanId,
          emiNumber: existingEmi.emiNumber,
          planName: existingEmi.planName,
          paymentMode: col['payment_mode'] as String?,
          collectedAt: col['collection_time'] != null
              ? DateTime.tryParse(
                      '${col['collection_date']}T${col['collection_time']}')
                  ?.toLocal()
              : DateTime.now(),
          remarks: col['remarks'] as String?,
          collectionId: col['id'] as String?,
          memberPhotoUrl: existingEmi.memberPhotoUrl,
        );
      } else {
        // No existing EMI entry found, add as new collected payment
        // Check if this exact schedule was already added as collected
        final existingCollectedIdx = selectedScheduleId != null
            ? payments
                .indexWhere((p) => p.id == selectedScheduleId && p.isCollected)
            : -1;
        final existingLoanCollectedIdx = existingCollectedIdx == -1
            ? payments.indexWhere(
                (p) => p.loanNumber == col['loan_number'] && p.isCollected)
            : existingCollectedIdx;

        if (existingLoanCollectedIdx == -1) {
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
            amountExpected: (col['amount_expected'] as num?)?.toDouble() ?? 0,
            amountCollected: collectionAmountCollected,
            dueDate: DateTime.parse(col['collection_date']),
            loanNumber: col['loan_number'],
            loanId: col['loan_id'],
            paymentMode: col['payment_mode'] as String?,
            collectedAt: col['collection_time'] != null
                ? DateTime.tryParse(
                        '${col['collection_date']}T${col['collection_time']}')
                    ?.toLocal()
                : null,
            remarks: col['remarks'] as String?,
            collectionId: col['id'] as String?,
            memberPhotoUrl: null,
          ));
        }
      }
    }

    // Deduplicate EMI entries: keep only one per loanId+emiNumber.
    // Previously only removed duplicate *collected* entries, which left
    // stale overdue entries in place when both overdue and collected
    // versions existed for the same EMI. Now collects all candidates
    // per key and keeps the collected entry if one exists, otherwise
    // the first non-collected entry.
    {
      final emiByLoanEmiKey = <String, List<TodayPayment>>{};
      for (final p in payments) {
        if (p.type == PaymentType.emi && p.loanId != null) {
          final key = '${p.loanId}_${p.emiNumber}';
          emiByLoanEmiKey.putIfAbsent(key, () => []).add(p);
        }
      }
      for (final entry in emiByLoanEmiKey.entries) {
        if (entry.value.length <= 1) continue;
        final collected = entry.value.where((p) => p.isCollected).toList();
        final keep = collected.isNotEmpty ? collected.first : entry.value.first;
        final removeIds = entry.value
            .where((p) => p.id != keep.id)
            .map((p) => p.id)
            .toSet();
        payments.removeWhere((p) => removeIds.contains(p.id));
      }
    }

    // 5. Process savings plans
    final selectedDate = filters.selectedDate;
    final dayOfWeek = selectedDate.weekday - 1; // 0=Mon, 6=Sun
    final dayOfMonth = selectedDate.day;

    // Aggregate multiple collections per savings plan (e.g. 3 installments
    // collected on the same day). Previously only the last collection survived.
    final Map<String, List<dynamic>> savingsCollectionsByPlan = {};
    for (final col in collectionsToday) {
      final planId = col['savings_plan_id'] as String?;
      if (planId != null) {
        savingsCollectionsByPlan.putIfAbsent(planId, () => []).add(col);
      }
    }
    final collectedPlanIds = savingsCollectionsByPlan.keys.toSet();

    // Filter plans that are due on the selected date OR were already collected today
    final savingsDues = allActivePlans.where((plan) {
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
          final nextDateOnly =
              DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);
          final selectedDateOnly =
              DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
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

    for (final plan in savingsDues) {
      final memberId = plan['member_id'];
      final member = getNestedMap(plan['members']);
      if (memberId == null || member == null) continue;

      // Apply branch filter
      if (filters.branchId != null && member['branch_id'] != filters.branchId) {
        continue;
      }

      // Apply agent filter
      if (filters.agentId != null && member['agent_id'] != filters.agentId) {
        continue;
      }

      final planCollections = savingsCollectionsByPlan[plan['id']];
      final isCollected = planCollections != null && planCollections.isNotEmpty;
      // Aggregate: sum amounts, use latest collection for metadata
      final totalCollected = isCollected
          ? planCollections.fold<double>(
              0.0,
              (sum, c) => sum + ((c['amount_collected'] as num?)?.toDouble() ?? 0),
            )
          : 0.0;
      final latestCollection = isCollected ? planCollections.last : null;

      // Determine if overdue (next_due_date is before today's date)
      final nextDueStr = plan['next_due_date'] as String?;
      final nextDueParsed =
          nextDueStr != null ? DateTime.tryParse(nextDueStr) : null;
      final nextDateOnly = nextDueParsed != null
          ? DateTime(nextDueParsed.year, nextDueParsed.month, nextDueParsed.day)
          : null;
      final selectedDateOnly =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final collectionType = plan['collection_type'] ?? 'daily';
      // A savings plan is overdue if it's not collected AND either:
      // (a) next_due_date is set and is before the selected date, or
      // (b) next_due_date is null (never updated / first time due) and collection_type is daily
      //     — daily plans with null next_due_date are implicitly overdue if not collected
      final isOverdue = !isCollected &&
          (nextDateOnly != null
              ? nextDateOnly.isBefore(selectedDateOnly)
              : collectionType == 'daily');
      final deposit = (plan['monthly_deposit'] as num?)?.toDouble() ?? 0;

      // Compute actual overdue installments from installments_paid vs expected.
      // This is more accurate than using next_due_date difference because
      // next_due_date only reflects the last advanced due date, not total missed.
      final paidCount = (plan['installments_paid'] as num?)?.toInt() ?? 0;
      final startDateStr = plan['start_date'] as String?;
      final startDate =
          startDateStr != null ? DateTime.tryParse(startDateStr) : null;

      int expectedUpToToday = 0;
      if (startDate != null) {
        final startOnly =
            DateTime(startDate.year, startDate.month, startDate.day);
        final diffDays = selectedDateOnly.difference(startOnly).inDays;
        switch (collectionType) {
          case 'weekly':
            expectedUpToToday = (diffDays ~/ 7) + 1;
            break;
          case 'monthly':
            expectedUpToToday = ((diffDays ~/ 30)) + 1;
            break;
          default: // daily
            expectedUpToToday = diffDays + 1;
        }
      }

      // Subtract 1 because today's installment is "due today", not overdue.
      // Overdue = installments expected BEFORE today that haven't been paid.
      final overdueCount = isOverdue
          ? (expectedUpToToday - paidCount - 1).clamp(0, expectedUpToToday)
          : 0;
      final overdueAmount = isOverdue ? deposit * overdueCount : deposit;

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
        amountExpected: overdueAmount,
        amountCollected: isCollected ? totalCollected : null,
        dueDate: isCollected
            ? DateTime.parse(dateStr)
            : (nextDueStr != null
                ? DateTime.parse(nextDueStr)
                : DateTime.parse(dateStr)),
        planName: plan['plan_name'],
        paymentMode: isCollected ? latestCollection['payment_mode'] : null,
        collectedAt: isCollected
            ? (latestCollection['collected_at'] != null
                ? DateTime.tryParse(latestCollection['collected_at'])
                    ?.toLocal()
                : (latestCollection['created_at'] != null
                    ? DateTime.tryParse(latestCollection['created_at'])
                    : null))
            : null,
        collectionId: isCollected ? latestCollection['id'] as String? : null,
        memberPhotoUrl: resolveMemberPhoto(member),
        installmentCount: isCollected ? planCollections.length : 1,
      ));

      // For daily collections that are overdue and not yet collected,
      // add a SEPARATE pending entry for today's collection.
      if (!isCollected &&
          isOverdue &&
          collectionType == 'daily' &&
          !selectedDateOnly.isAfter(DateTime.now())) {
        final todayPhotoUrl = resolveMemberPhoto(member);
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
          amountCollected: null,
          dueDate: DateTime.parse(dateStr),
          planName: '${plan['plan_name']} (Today)',
          paymentMode: null,
          collectedAt: null,
          collectionId: null,
          memberPhotoUrl: todayPhotoUrl,
        ));
      }
    }
  } catch (e, stack) {
    debugPrint('Error fetching payments: $e');
    debugPrint(stack.toString());
  }

  // Remove overdue entries for loans/savings that have a collected entry today.
  // This ensures that once a payment is processed for a loan, the entire loan
  // card disappears from the Overdue section (not just the single paid EMI).
  {
    final collectedLoanIds = <String>{};
    final collectedPlanIds = <String>{};
    for (final p in payments) {
      if (p.isCollected) {
        if (p.type == PaymentType.emi && p.loanId != null) {
          collectedLoanIds.add(p.loanId!);
        } else if (p.type == PaymentType.savings && p.planName != null) {
          // Match by planId: collected savings entry ID == plan ID
          collectedPlanIds.add(p.id);
        }
      }
    }
    payments.removeWhere((p) {
      if (p.isOverdue) {
        if (p.type == PaymentType.emi &&
            p.loanId != null &&
            collectedLoanIds.contains(p.loanId)) {
          return true; // remove overdue EMI for a loan that was paid today
        }
        if (p.type == PaymentType.savings &&
            collectedPlanIds.contains(p.id)) {
          return true; // remove overdue savings for a plan that was paid today
        }
      }
      return false;
    });
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

  // Apply advanced filters
  filtered = _applyAdvancedFilters(filtered, filters);

  // Apply sorting
  _sortPayments(filtered, filters.sortBy);

  // Use `filtered` for both payments and allPayments so the summary counts
  // (pending/overdue/collected) reflect the final grouped-card list, not
  // the raw EMI-level list.
  return TodayPaymentData(payments: filtered, allPayments: filtered);
});

List<TodayPayment> _applyAdvancedFilters(
  List<TodayPayment> payments,
  PaymentFilterState filters,
) {
  var result = payments;

  if (filters.paymentTypeFilter != null) {
    result = result.where((p) => p.type == filters.paymentTypeFilter).toList();
  }

  if (filters.statusFilters.isNotEmpty) {
    result =
        result.where((p) => filters.statusFilters.contains(p.status)).toList();
  }

  if (filters.minAmount != null) {
    result =
        result.where((p) => p.amountExpected >= filters.minAmount!).toList();
  }

  if (filters.maxAmount != null) {
    result =
        result.where((p) => p.amountExpected <= filters.maxAmount!).toList();
  }

  if (filters.paymentModeFilters.isNotEmpty) {
    result = result
        .where((p) =>
            p.paymentMode != null &&
            filters.paymentModeFilters.contains(p.paymentMode))
        .toList();
  }

  if (filters.overdueDayFilters.isNotEmpty) {
    result = result.where((p) {
      if (!p.isOverdue) return true;
      return filters.overdueDayFilters
          .any((bucket) => bucket.matches(p.daysOverdue));
    }).toList();
  }

  return result;
}

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
        final statusCompare =
            (statusOrder[a.status] ?? 3).compareTo(statusOrder[b.status] ?? 3);
        if (statusCompare != 0) return statusCompare;
        return a.dueDate.compareTo(b.dueDate);
      });
  }
}

class TodayPaymentData {
  final List<TodayPayment> payments;
  final List<TodayPayment> allPayments;

  const TodayPaymentData(
      {required this.payments, List<TodayPayment>? allPayments})
      : allPayments = allPayments ?? payments;

  TodayPaymentSummary get summary =>
      TodayPaymentSummary.fromPayments(allPayments);

  List<TodayPayment> get pendingPayments =>
      allPayments.where((p) => p.isPending).toList();

  List<TodayPayment> get collectedPayments =>
      allPayments.where((p) => p.isCollected).toList();

  List<TodayPayment> get overduePayments =>
      allPayments.where((p) => p.isOverdue).toList();

  /// Count of unique overdue groups (by loan/member), matching the number
  /// of cards actually displayed in the Overdue tab, not the raw EMI count.
  int get groupedOverdueCount {
    final seen = <String>{};
    for (final p in allPayments) {
      if (p.isOverdue) {
        final key = '${p.memberId ?? p.id}_${p.type.name}';
        seen.add(key);
      }
    }
    return seen.length;
  }

  List<GroupedOverduePayment> get groupedOverduePayments =>
      GroupedOverduePayment.group(overduePayments);

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

  final timer = Timer.periodic(const Duration(seconds: 30), (_) {
    ref.invalidate(todayPaymentsProvider);
  });

  ref.onDispose(() => timer.cancel());
  return timer;
});
