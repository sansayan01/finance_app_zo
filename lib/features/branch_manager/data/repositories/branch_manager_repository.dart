import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/branch_stats_model.dart';
import '../../../auth/data/models/user_model.dart';

/// Branch Manager Repository
/// Handles all data operations for branch managers
class BranchManagerRepository {
  final SupabaseClient _client;

  BranchManagerRepository(this._client);

  /// Get branch statistics — computed from direct queries (no RPC needed)
  Future<BranchStats> getBranchStats(String branchId) async {
    final branch = await _client
        .from('branches')
        .select('name, address, status')
        .eq('id', branchId)
        .maybeSingle();

    final staffCount = await _client
        .from('profiles')
        .select('id')
        .eq('branch_id', branchId)
        .inFilter('role', ['collectionAgent', 'manager']);
    final staff = staffCount as List<dynamic>;

    final membersCount = await _client
        .from('members')
        .select('id')
        .eq('branch_id', branchId)
        .eq('status', 'active');
    final members = membersCount as List<dynamic>;

    final loansResp = await _client
        .from('loans')
        .select('amount, outstanding_amount, status')
        .eq('branch_id', branchId);
    final loans = loansResp as List<dynamic>;

    final activeLoans = loans.where((l) => l['status'] == 'active').toList();
    final overdueLoans = loans.where((l) => l['status'] == 'defaulted').toList();
    final totalDisbursed = loans.fold<double>(
        0, (sum, l) => sum + ((l['amount'] as num?)?.toDouble() ?? 0));
    final outstanding = activeLoans.fold<double>(
        0, (sum, l) => sum + ((l['outstanding_amount'] as num?)?.toDouble() ?? 0));

    // savings_plans has no branch_id — join through members
    final allSavingsResp = await _client
        .from('savings_plans')
        .select('current_amount, member_id');
    // Get all member IDs for this branch to filter savings
    final allBranchMembers = await _client
        .from('members')
        .select('id')
        .eq('branch_id', branchId);
    final allBranchMemberIds = (allBranchMembers as List<dynamic>)
        .map((m) => m['id'] as String)
        .toSet();
    final totalSavings = (allSavingsResp as List<dynamic>)
        .where((s) => allBranchMemberIds.contains(s['member_id']))
        .fold<double>(
            0, (sum, s) => sum + ((s['current_amount'] as num?)?.toDouble() ?? 0));

    // Get staff IDs to filter collections
    final staffIds = staff.map((s) => s['id'] as String).toList();
    double totalCollections = 0;
    if (staffIds.isNotEmpty) {
      final collResp = await _client
          .from('collections')
          .select('amount_collected')
          .inFilter('staff_id', staffIds);
      totalCollections = (collResp as List<dynamic>).fold<double>(
          0, (sum, c) => sum + ((c['amount_collected'] as num?)?.toDouble() ?? 0));
    }

    return BranchStats(
      branchId: branchId,
      branchName: branch?['name']?.toString() ?? '',
      branchAddress: branch?['address']?.toString() ?? '',
      isActive: branch?['status'] == 'active',
      totalStaff: staff.length,
      totalMembers: members.length,
      totalLoans: loans.length,
      activeLoansCount: activeLoans.length,
      overdueLoans: overdueLoans.length,
      totalCollections: totalCollections,
      totalDisbursements: totalDisbursed,
      totalSavings: totalSavings,
      outstandingAmount: outstanding,
    );
  }

  /// Get branch staff
  Future<List<ProfileModel>> getBranchStaff(String branchId) async {
    final response = await _client.from('profiles').select('''
          *,
          branch:branches!fk_profiles_branch(name, id)
        ''').eq('branch_id', branchId).inFilter('role', ['collectionAgent', 'manager']).order('full_name');

    final List<dynamic> list = response as List<dynamic>;
    return list
        .map((item) => ProfileModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Get branch collections
  Future<List<Map<String, dynamic>>> getBranchCollections(String branchId,
      {DateTime? date}) async {
    date ??= DateTime.now();
    final dateStr = date.toIso8601String().split('T').first;

    final response = await _client
        .from('collections')
        .select('''
          *,
          collector:staff_id!fk_collections_staff(full_name, id),
          loan:loan_id(
            id,
            amount,
            branch_id,
            customer_id
          )
        ''')
        .eq('collection_date', dateStr)
        .order('created_at', ascending: false)
        .limit(200);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get branch overdue loans
  Future<List<Map<String, dynamic>>> getBranchOverdueLoans(
      String branchId) async {
    final response = await _client.from('loans').select('''
          *,
          member:customer_id(full_name, id, phone, address),
          emi_schedule(
            id,
            due_date,
            emi_amount,
            status
          )
        ''').eq('branch_id', branchId).eq('status', 'active')
        .limit(200);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get staff performance — computed from direct queries (no RPC needed)
  Future<List<Map<String, dynamic>>> getStaffPerformance(String branchId,
      {DateTime? startDate, DateTime? endDate}) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now();
    final startStr = start.toIso8601String().split('T').first;
    final endStr = end.toIso8601String().split('T').first;

    // 1. Get all staff for this branch
    final staffResponse = await _client
        .from('profiles')
        .select('id, full_name, employee_id, role')
        .eq('branch_id', branchId)
        .inFilter('role', ['collectionAgent', 'manager']);

    final staffList = List<Map<String, dynamic>>.from(staffResponse);
    if (staffList.isEmpty) return [];

    final staffIds = staffList.map((s) => s['id'] as String).toList();

    // 2. Get collections for those staff in date range
    final collectionsResponse = await _client
        .from('collections')
        .select('staff_id, amount_collected, amount_expected')
        .inFilter('staff_id', staffIds)
        .gte('collection_date', startStr)
        .lte('collection_date', endStr);

    final collections = List<Map<String, dynamic>>.from(collectionsResponse);

    // 3. Aggregate per staff
    final Map<String, Map<String, dynamic>> performanceMap = {};
    for (final staff in staffList) {
      final sid = staff['id'] as String;
      performanceMap[sid] = {
        'staff_id': sid,
        'name': staff['full_name'] ?? 'Unknown',
        'employee_id': staff['employee_id'],
        'designation': staff['role'],
        'collected': 0.0,
        'expected': 0.0,
        'transactions': 0,
        'efficiency': 0.0,
      };
    }

    for (final c in collections) {
      final sid = c['staff_id'] as String?;
      if (sid == null || !performanceMap.containsKey(sid)) continue;
      final entry = performanceMap[sid]!;
      entry['collected'] = (entry['collected'] as double) +
          ((c['amount_collected'] as num?)?.toDouble() ?? 0);
      entry['expected'] = (entry['expected'] as double) +
          ((c['amount_expected'] as num?)?.toDouble() ?? 0);
      entry['transactions'] = (entry['transactions'] as int) + 1;
    }

    // Calculate efficiency
    for (final entry in performanceMap.values) {
      final expected = entry['expected'] as double;
      final collected = entry['collected'] as double;
      entry['efficiency'] = expected > 0
          ? double.parse((collected / expected * 100).toStringAsFixed(1))
          : 0.0;
    }

    return performanceMap.values.toList();
  }

  /// Get branch daily summary — computed from direct queries (no RPC needed)
  Future<Map<String, dynamic>> getBranchDailySummary(
      String branchId, DateTime date) async {
    final dateStr = date.toIso8601String().split('T').first;

    // Get staff IDs for this branch to filter collections
    final staffResponse = await _client
        .from('profiles')
        .select('id')
        .eq('branch_id', branchId)
        .inFilter('role', ['collectionAgent', 'manager']);

    final staffIds = (staffResponse as List)
        .map((s) => s['id'] as String)
        .toList();

    if (staffIds.isEmpty) {
      return {
        'total_collected': 0.0,
        'total_expected': 0.0,
        'total_transactions': 0,
        'by_payment_mode': <String, double>{},
      };
    }

    // Get today's collections for branch staff
    final collectionsResponse = await _client
        .from('collections')
        .select('amount_collected, amount_expected, payment_mode')
        .inFilter('staff_id', staffIds)
        .eq('collection_date', dateStr);

    final collections = List<Map<String, dynamic>>.from(collectionsResponse);

    double totalCollected = 0;
    double totalExpected = 0;
    final Map<String, double> byPaymentMode = {};

    for (final c in collections) {
      final collected = (c['amount_collected'] as num?)?.toDouble() ?? 0;
      final expected = (c['amount_expected'] as num?)?.toDouble() ?? 0;
      final mode = c['payment_mode'] as String? ?? 'cash';

      totalCollected += collected;
      totalExpected += expected;
      byPaymentMode[mode] = (byPaymentMode[mode] ?? 0) + collected;
    }

    return {
      'total_collected': totalCollected,
      'total_expected': totalExpected,
      'total_transactions': collections.length,
      'by_payment_mode': byPaymentMode,
    };
  }

  /// Assign collection agent to area
  Future<void> assignAgentToArea(
      String agentId, String areaId, String branchId) async {
    try {
      await _client.from('agent_areas').upsert({
        'agent_id': agentId,
        'area_id': areaId,
        'branch_id': branchId,
        'assigned_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // agent_areas table may not exist
    }
  }

  /// Get branch targets
  Future<Map<String, dynamic>> getBranchTargets(String branchId,
      {int? month, int? year}) async {
    final now = DateTime.now();
    final targetMonth = month ?? now.month;
    final targetYear = year ?? now.year;

    final response = await _client
        .from('branch_targets')
        .select()
        .eq('branch_id', branchId)
        .eq('month', targetMonth)
        .eq('year', targetYear)
        .maybeSingle();

    return response ??
        {
          'branch_id': branchId,
          'month': targetMonth,
          'year': targetYear,
          'collection_target': 0,
          'new_members_target': 0,
          'loans_disbursed_target': 0,
          'savings_target': 0,
        };
  }

  /// Update branch targets
  Future<void> updateBranchTargets(
      String branchId, int month, int year, Map<String, double> targets) async {
    await _client.from('branch_targets').upsert({
      'branch_id': branchId,
      'month': month,
      'year': year,
      ...targets,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ─── Branch-scoped queries for premium pages ───

  /// Get all members for a branch with detail
  Future<List<Map<String, dynamic>>> getBranchMembersDetailed(
      String branchId) async {
    final response = await _client
        .from('members')
        .select('id, full_name, phone, status, created_at, kyc_status, address, email')
        .eq('branch_id', branchId)
        .order('full_name');

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get all loans for a branch
  Future<List<Map<String, dynamic>>> getBranchLoans(String branchId) async {
    final response = await _client.from('loans').select(
        '*, profiles:customer_id(full_name, phone)')
        .eq('branch_id', branchId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get all savings plans for a branch (joined through members)
  Future<List<Map<String, dynamic>>> getBranchSavings(String branchId) async {
    final response = await _client.from('savings_plans').select('''
          *,
          members:member_id!inner(full_name, id, phone, branch_id)
        ''').eq('members.branch_id', branchId).order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get member detail with loans, savings, and recent transactions
  Future<Map<String, dynamic>> getMemberDetail(String memberId) async {
    final member = await _client
        .from('members')
        .select('*')
        .eq('id', memberId)
        .maybeSingle();

    final loans = await _client
        .from('loans')
        .select('*, profiles:customer_id(full_name, phone)')
        .eq('customer_id', memberId)
        .order('created_at', ascending: false);

    final savings = await _client
        .from('savings_plans')
        .select('*, members:member_id(full_name)')
        .eq('member_id', memberId)
        .order('created_at', ascending: false);

    final transactions = await _client
        .from('transactions')
        .select('*')
        .eq('member_id', memberId)
        .order('created_at', ascending: false)
        .limit(20);

    return {
      'member': member,
      'loans': loans,
      'savings': savings,
      'transactions': transactions,
    };
  }

  /// Get branch info
  Future<Map<String, dynamic>?> getBranchInfo(String branchId) async {
    final response = await _client
        .from('branches')
        .select('*')
        .eq('id', branchId)
        .maybeSingle();
    return response;
  }
}
