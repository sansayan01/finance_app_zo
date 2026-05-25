import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../loans/data/models/loan_model.dart';
import '../../../savings/data/models/savings_model.dart';
import 'branch_manager_providers.dart';

// =====================================================
// BRANCH-SCOPED LOANS
// =====================================================

final branchLoansProvider =
    FutureProvider.family<List<LoanModel>, String>((ref, branchId) async {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  try {
    final response = await client
        .from('loans')
        .select('*, customer:customer_id(full_name, phone)')
        .eq('org_id', orgId)
        .eq('branch_id', branchId)
        .order('created_at', ascending: false);
    final list = response as List<dynamic>;
    // Map 'customer' alias to 'profiles' key expected by LoanModel
    return list.map((item) {
      final map = Map<String, dynamic>.from(item as Map<String, dynamic>);
      if (map.containsKey('customer') && !map.containsKey('profiles')) {
        map['profiles'] = map['customer'];
      }
      return LoanModel.fromJson(map);
    }).toList();
  } catch (e) {
    return [];
  }
});

final branchLoanSummaryProvider =
    FutureProvider.family<LoanSummary, String>((ref, branchId) async {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  try {
    final response = await client
        .from('loans')
        .select('amount, outstanding_amount, status')
        .eq('org_id', orgId)
        .eq('branch_id', branchId);
    final list = response as List<dynamic>;
    final totalLoans = list.length;
    final activeLoans =
        list.where((l) => l['status'] == 'active').toList();
    final defaultLoans =
        list.where((l) => l['status'] == 'defaulted').toList();
    final totalDisbursed = list.fold<double>(
        0, (sum, l) => sum + ((l['amount'] as num?)?.toDouble() ?? 0));
    final totalOutstanding = activeLoans.fold<double>(
        0,
        (sum, l) =>
            sum + ((l['outstanding_amount'] as num?)?.toDouble() ?? 0));
    final overdueAmount = defaultLoans.fold<double>(
        0,
        (sum, l) =>
            sum + ((l['outstanding_amount'] as num?)?.toDouble() ?? 0));
    final parPercentage =
        totalOutstanding > 0 ? (overdueAmount / totalOutstanding * 100) : 0.0;
    return LoanSummary(
      totalLoans: totalLoans,
      activeLoans: activeLoans.length,
      defaultLoans: defaultLoans.length,
      totalOutstanding: totalOutstanding,
      totalDisbursed: totalDisbursed,
      totalCollected: 0,
      overdueAmount: overdueAmount,
      parPercentage: parPercentage,
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
        parPercentage: 0);
  }
});

// =====================================================
// BRANCH-SCOPED SAVINGS
// savings_plans is the actual table (member accounts)
// It has member_id but no branch_id — filter via member join
// =====================================================

final branchSavingsProvider =
    FutureProvider.family<List<SavingsModel>, String>((ref, branchId) async {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  try {
    final response = await client.from('savings_plans').select(
        '*, members:member_id(full_name, branch_id)').eq('org_id', orgId);
    final list = response as List<dynamic>;
    // Filter by branch_id through the joined member
    final branchSavings = list.where((item) {
      final member = item['members'] as Map<String, dynamic>?;
      return member?['branch_id'] == branchId;
    }).toList();
    return branchSavings.map((item) {
      final member = item['members'] as Map<String, dynamic>?;
      item['member_name'] = member?['full_name'] ?? '';
      return SavingsModel.fromJson(item as Map<String, dynamic>);
    }).toList();
  } catch (e) {
    return [];
  }
});

final branchSavingsSummaryProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
        (ref, branchId) async {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  try {
    final response = await client.from('savings_plans').select(
        'current_amount, status, members:member_id(branch_id)').eq('org_id', orgId);
    final list = (response as List<dynamic>).where((item) {
      final member = item['members'] as Map<String, dynamic>?;
      return member?['branch_id'] == branchId;
    }).toList();
    final totalBalance = list.fold<double>(
        0, (sum, s) => sum + ((s['current_amount'] as num?)?.toDouble() ?? 0));
    final activeCount =
        list.where((s) => s['status'] == 'active').length;
    final maturedCount =
        list.where((s) => s['status'] == 'matured').length;
    return {
      'total_balance': totalBalance,
      'total_plans': list.length,
      'active_count': activeCount,
      'matured_count': maturedCount,
    };
  } catch (e) {
    return {
      'total_balance': 0.0,
      'total_plans': 0,
      'active_count': 0,
      'matured_count': 0,
    };
  }
});

// =====================================================
// BRANCH-SCOPED MEMBERS
// =====================================================

final branchMembersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, branchId) async {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  try {
    final response = await client
        .from('members')
        .select('*')
        .eq('org_id', orgId)
        .eq('branch_id', branchId)
        .order('full_name');
    return List<Map<String, dynamic>>.from(response as List<dynamic>);
  } catch (e) {
    return [];
  }
});

final branchMemberCountProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
        (ref, branchId) async {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  try {
    final response = await client
        .from('members')
        .select('id, status, created_at')
        .eq('org_id', orgId)
        .eq('branch_id', branchId);
    final list = response as List<dynamic>;
    final total = list.length;
    final active =
        list.where((m) => m['status'] == 'active').length;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String();
    final newThisMonth = list.where((m) {
      final createdAt = m['created_at'] as String?;
      return createdAt != null && createdAt.compareTo(monthStart) >= 0;
    }).length;
    return {
      'total': total,
      'active': active,
      'new_this_month': newThisMonth,
      'inactive': total - active,
    };
  } catch (e) {
    return {'total': 0, 'active': 0, 'new_this_month': 0, 'inactive': 0};
  }
});

// =====================================================
// BRANCH-SCOPED COLLECTIONS
// collections has staff_id (→ profiles), loan_id (→ loans)
// Filter branch by joining loans and checking branch_id
// =====================================================

final branchTodayCollectionsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, branchId) async {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  try {
    final today = DateTime.now().toIso8601String().split('T').first;
    final response = await client
        .from('collections')
        .select('''
          *,
          collector:staff_id!fk_collections_staff(full_name, id),
          loan:loan_id(id, amount, branch_id, loan_number, customer_id)
        ''')
        .eq('org_id', orgId)
        .eq('collection_date', today)
        .order('created_at', ascending: false);
    final allCollections = List<Map<String, dynamic>>.from(
        response as List<dynamic>);
    // Filter to branch
    return allCollections.where((c) {
      final loan = c['loan'] as Map<String, dynamic>?;
      return loan?['branch_id'] == branchId;
    }).toList();
  } catch (e) {
    return [];
  }
});

final branchCollectionStatsProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
        (ref, branchId) async {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  try {
    final now = DateTime.now();
    final today = now.toIso8601String().split('T').first;
    final weekStart =
        now.subtract(Duration(days: now.weekday - 1)).toIso8601String().split('T').first;
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String().split('T').first;

    // Fetch all collections this month, joined with loans for branch filtering
    final response = await client
        .from('collections')
        .select('''
          amount_collected, collection_date,
          loan:loan_id(branch_id)
        ''')
        .eq('org_id', orgId)
        .gte('collection_date', monthStart);
    final all = (response as List<dynamic>).where((c) {
      final loan = c['loan'] as Map<String, dynamic>?;
      return loan?['branch_id'] == branchId;
    }).toList();

    double todayTotal = 0;
    int todayCount = 0;
    double weekTotal = 0;
    int weekCount = 0;
    double monthTotal = 0;

    for (final c in all) {
      final amount = (c['amount_collected'] as num?)?.toDouble() ?? 0;
      final date = c['collection_date'] as String;
      monthTotal += amount;
      if (date.compareTo(weekStart) >= 0) {
        weekTotal += amount;
        weekCount++;
      }
      if (date == today) {
        todayTotal += amount;
        todayCount++;
      }
    }

    return {
      'today_total': todayTotal,
      'today_count': todayCount,
      'week_total': weekTotal,
      'week_count': weekCount,
      'month_total': monthTotal,
      'month_count': all.length,
    };
  } catch (e) {
    return {
      'today_total': 0.0,
      'today_count': 0,
      'week_total': 0.0,
      'week_count': 0,
      'month_total': 0.0,
      'month_count': 0,
    };
  }
});

// =====================================================
// BRANCH ANALYTICS
// =====================================================

final branchAnalyticsProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
        (ref, branchId) async {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  try {
    final now = DateTime.now();
    final thirtyDaysAgo =
        now.subtract(const Duration(days: 30)).toIso8601String().split('T').first;

    // Collection trend (last 30 days)
    final collectionsResp = await client
        .from('collections')
        .select('''
          amount_collected, collection_date,
          loan:loan_id(branch_id)
        ''')
        .eq('org_id', orgId)
        .gte('collection_date', thirtyDaysAgo);
    final branchCollections = (collectionsResp as List<dynamic>).where((c) {
      final loan = c['loan'] as Map<String, dynamic>?;
      return loan?['branch_id'] == branchId;
    }).toList();

    // Group by date
    final collectionByDate = <String, double>{};
    for (final c in branchCollections) {
      final date = (c['collection_date'] as String);
      final amount = (c['amount_collected'] as num?)?.toDouble() ?? 0;
      collectionByDate[date] = (collectionByDate[date] ?? 0) + amount;
    }

    // Loan disbursement trend
    final loansResp = await client
        .from('loans')
        .select('amount, disbursement_date, status')
        .eq('org_id', orgId)
        .eq('branch_id', branchId)
        .gte('disbursement_date', thirtyDaysAgo);
    final loanData = loansResp as List<dynamic>;

    // Member growth
    final membersResp = await client
        .from('members')
        .select('created_at')
        .eq('org_id', orgId)
        .eq('branch_id', branchId)
        .gte('created_at', thirtyDaysAgo);
    final memberData = membersResp as List<dynamic>;

    return {
      'collection_trend': collectionByDate,
      'loans_disbursed_30d': loanData.length,
      'total_disbursed_30d': loanData.fold<double>(
          0, (sum, l) => sum + ((l['amount'] as num?)?.toDouble() ?? 0)),
      'new_members_30d': memberData.length,
    };
  } catch (e) {
    return {
      'collection_trend': <String, double>{},
      'loans_disbursed_30d': 0,
      'total_disbursed_30d': 0.0,
      'new_members_30d': 0,
    };
  }
});

// =====================================================
// AGGREGATE DASHBOARD
// =====================================================

final branchDashboardAggregateProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
        (ref, branchId) async {
  try {
    final results = await Future.wait([
      ref.watch(branchLoanSummaryProvider(branchId).future),
      ref.watch(branchSavingsSummaryProvider(branchId).future),
      ref.watch(branchMemberCountProvider(branchId).future),
      ref.watch(branchCollectionStatsProvider(branchId).future),
    ]);
    return {
      'loans': results[0],
      'savings': results[1],
      'members': results[2],
      'collections': results[3],
    };
  } catch (e) {
    return {};
  }
});

// =====================================================
// BRANCH-SCOPED MEMBER DETAIL
// =====================================================

/// Detailed member info including loans, savings, and recent transactions
final branchMemberDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, memberId) async {
  final repository = ref.watch(branchManagerRepositoryProvider);
  return repository.getMemberDetail(memberId);
});

/// Branch info (name, address, settings, etc.)
final branchInfoProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, branchId) async {
  final repository = ref.watch(branchManagerRepositoryProvider);
  return repository.getBranchInfo(branchId);
});

// =====================================================
// BRANCH WEEKLY COLLECTION TREND (last 7 days)
// Used by the Reports page collection chart
// =====================================================

/// Returns a list of 7 doubles representing collection totals for each day
/// of the current week (Monday to Sunday).
final branchWeeklyCollectionTrendProvider =
    FutureProvider.family<List<double>, String>((ref, branchId) async {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  try {
    final now = DateTime.now();
    // Find the Monday of the current week
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final mondayStr = DateTime(monday.year, monday.month, monday.day)
        .toIso8601String()
        .split('T')
        .first;
    final sundayStr =
        DateTime(monday.year, monday.month, monday.day + 6)
            .toIso8601String()
            .split('T')
            .first;

    // Fetch collections for this week joined with loans for branch filtering
    final response = await client
        .from('collections')
        .select('''
          amount_collected, collection_date,
          loan:loan_id(branch_id)
        ''')
        .eq('org_id', orgId)
        .gte('collection_date', mondayStr)
        .lte('collection_date', sundayStr);

    final branchCollections = (response as List<dynamic>).where((c) {
      final loan = c['loan'] as Map<String, dynamic>?;
      return loan?['branch_id'] == branchId;
    }).toList();

    // Initialize 7 days (Mon=0 to Sun=6)
    final weekData = List<double>.filled(7, 0);

    for (final c in branchCollections) {
      final dateStr = c['collection_date'] as String?;
      if (dateStr == null) continue;
      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;
      final dayIndex = date.weekday - 1; // Monday=0, Sunday=6
      if (dayIndex >= 0 && dayIndex < 7) {
        weekData[dayIndex] +=
            (c['amount_collected'] as num?)?.toDouble() ?? 0;
      }
    }

    return weekData;
  } catch (e) {
    return List<double>.filled(7, 0);
  }
});
