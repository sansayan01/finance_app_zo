import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/branch_stats_model.dart';
import '../../../auth/data/models/user_model.dart';

/// Branch Manager Repository
/// Handles all data operations for branch managers
class BranchManagerRepository {
  final SupabaseClient _client;

  BranchManagerRepository(this._client);

  /// Get branch statistics
  Future<BranchStats> getBranchStats(String branchId) async {
    final response = await _client.rpc('get_branch_stats', params: {'p_branch_id': branchId});
    return BranchStats.fromJson(response);
  }

  /// Get branch staff
  Future<List<ProfileModel>> getBranchStaff(String branchId) async {
    final response = await _client
        .from('staff_profiles')
        .select('''
          *,
          branch:branches!staff_profiles_branch_id_fkey(name, id)
        ''')
        .eq('branch_id', branchId)
        .order('full_name');

    final List<dynamic> list = response as List<dynamic>;
    return list.map((item) => ProfileModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Get branch collections
  Future<List<Map<String, dynamic>>> getBranchCollections(String branchId, {DateTime? date}) async {
    date ??= DateTime.now();
    
    final response = await _client
        .from('collections')
        .select('''
          *,
          collector:staff_profiles!collections_staff_id_fkey(full_name, id),
          loan:loans(
            id,
            loan_amount,
            member:members(name, id)
          )
        ''')
        .eq('branch_id', branchId)
        .gte('collected_at', date.toIso8601String())
        .lt('collected_at', date.add(const Duration(days: 1)).toIso8601String())
        .order('collected_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get pending approvals
  Future<List<Map<String, dynamic>>> getPendingApprovals(String branchId) async {
    final response = await _client
        .from('pending_approvals')
        .select('''
          *,
          requested_by_user:profiles!pending_approvals_requested_by_fkey(full_name as name, role),
          member:members(name, id, phone)
        ''')
        .eq('branch_id', branchId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get branch overdue loans
  Future<List<Map<String, dynamic>>> getBranchOverdueLoans(String branchId) async {
    final response = await _client
        .from('loans')
        .select('''
          *,
          member:members(name, id, phone, address),
          emi_schedule:emi_schedules(
            id,
            due_date,
            amount,
            status
          )
        ''')
        .eq('branch_id', branchId)
        .eq('status', 'active')
        .lt('next_emi_due', DateTime.now().toIso8601String());

    return List<Map<String, dynamic>>.from(response);
  }

  /// Approve pending request
  Future<void> approveRequest(String requestId, String managerId, {String? notes}) async {
    await _client.from('pending_approvals').update({
      'status': 'approved',
      'approved_by': managerId,
      'approved_at': DateTime.now().toIso8601String(),
      'notes': notes,
    }).eq('id', requestId);
  }

  /// Reject pending request
  Future<void> rejectRequest(String requestId, String managerId, String reason) async {
    await _client.from('pending_approvals').update({
      'status': 'rejected',
      'rejected_by': managerId,
      'rejected_at': DateTime.now().toIso8601String(),
      'rejection_reason': reason,
    }).eq('id', requestId);
  }

  /// Get staff performance
  Future<List<Map<String, dynamic>>> getStaffPerformance(String branchId, {DateTime? startDate, DateTime? endDate}) async {
    final response = await _client.rpc('get_branch_staff_performance', params: {
      'p_branch_id': branchId,
      'p_start_date': startDate?.toIso8601String() ?? DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
      'p_end_date': endDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
    });

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get branch daily summary
  Future<Map<String, dynamic>> getBranchDailySummary(String branchId, DateTime date) async {
    final response = await _client.rpc('get_branch_daily_summary', params: {
      'p_branch_id': branchId,
      'p_date': date.toIso8601String(),
    });

    return response;
  }

  /// Assign collection agent to area
  Future<void> assignAgentToArea(String agentId, String areaId, String branchId) async {
    await _client.from('agent_areas').upsert({
      'agent_id': agentId,
      'area_id': areaId,
      'branch_id': branchId,
      'assigned_at': DateTime.now().toIso8601String(),
    });
  }

  /// Get branch targets
  Future<Map<String, dynamic>> getBranchTargets(String branchId, {int? month, int? year}) async {
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

    return response ?? {
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
  Future<void> updateBranchTargets(String branchId, int month, int year, Map<String, double> targets) async {
    await _client.from('branch_targets').upsert({
      'branch_id': branchId,
      'month': month,
      'year': year,
      ...targets,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
