import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/branch_model.dart';

class BranchRepository {
  final SupabaseClient _client;
  final String _orgId;

  BranchRepository(this._client, this._orgId);

  /// Get all branches for the organization
  Future<List<BranchModel>> getBranches() async {
    final response = await _client
        .from('branches')
        .select()
        .eq('org_id', _orgId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => BranchModel.fromJson(json))
        .toList();
  }

  /// Get active branches only
  Future<List<BranchModel>> getActiveBranches() async {
    final response = await _client
        .from('branches')
        .select()
        .eq('org_id', _orgId)
        .eq('status', 'active')
        .order('name');

    return (response as List)
        .map((json) => BranchModel.fromJson(json))
        .toList();
  }

  /// Get a single branch by ID
  Future<BranchModel?> getBranch(String id) async {
    final response = await _client
        .from('branches')
        .select()
        .eq('id', id)
        .eq('org_id', _orgId)
        .maybeSingle();

    if (response == null) return null;
    return BranchModel.fromJson(response);
  }

  /// Get branch by code
  Future<BranchModel?> getBranchByCode(String code) async {
    final response = await _client
        .from('branches')
        .select()
        .eq('org_id', _orgId)
        .eq('code', code)
        .maybeSingle();

    if (response == null) return null;
    return BranchModel.fromJson(response);
  }

  /// Create a new branch
  Future<BranchModel> createBranch({
    required String name,
    required String code,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? phone,
    String? email,
    String? managerId,
    double? locationLat,
    double? locationLng,
  }) async {
    // Check if code already exists
    final existing = await getBranchByCode(code);
    if (existing != null) {
      throw Exception('Branch code already exists: $code');
    }

    final response = await _client
        .from('branches')
        .insert({
          'org_id': _orgId,
          'name': name,
          'code': code.toUpperCase(),
          'address': address,
          'city': city,
          'state': state,
          'pincode': pincode,
          'phone': phone,
          'email': email,
          'manager_id': managerId,
          'location_lat': locationLat,
          'location_lng': locationLng,
        })
        .select()
        .single();

    return BranchModel.fromJson(response);
  }

  /// Update a branch
  Future<BranchModel> updateBranch(String id, Map<String, dynamic> data) async {
    // Remove fields that shouldn't be updated directly
    data.remove('id');
    data.remove('org_id');
    data.remove('created_at');

    final response = await _client
        .from('branches')
        .update(data)
        .eq('id', id)
        .eq('org_id', _orgId)
        .select()
        .single();

    return BranchModel.fromJson(response);
  }

  /// Delete a branch
  Future<void> deleteBranch(String id) async {
    // First, unassign all staff from this branch
    await _client
        .from('staff_profiles')
        .update({'branch_id': null}).eq('branch_id', id);

    // Then delete the branch
    await _client.from('branches').delete().eq('id', id).eq('org_id', _orgId);
  }

  /// Get branch statistics
  Future<BranchStats> getBranchStats(String branchId) async {
    final response = await _client.rpc('get_branch_stats',
        params: {'p_branch_id': branchId}).maybeSingle();

    if (response == null) return const BranchStats();
    return BranchStats.fromJson(response);
  }

  /// Get branch count
  Future<int> getBranchCount() async {
    final response =
        await _client.from('branches').select('id').eq('org_id', _orgId);

    return response.length;
  }

  /// Assign manager to branch
  Future<void> assignManager(String branchId, String? managerId) async {
    await _client
        .from('branches')
        .update({'manager_id': managerId})
        .eq('id', branchId)
        .eq('org_id', _orgId);
  }

  /// Get potential managers (staff with manager role)
  Future<List<Map<String, dynamic>>> getPotentialManagers() async {
    final response = await _client
        .from('staff_profiles')
        .select('id, full_name, email')
        .eq('org_id', _orgId)
        .inFilter('role', ['branch_manager', 'manager', 'supervisor']).order(
            'full_name');

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get staff for a branch
  Future<List<Map<String, dynamic>>> getBranchStaff(String branchId) async {
    final response = await _client
        .from('staff_profiles')
        .select('id, full_name, email, role, phone')
        .eq('branch_id', branchId)
        .order('full_name');

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get members for a branch
  Future<List<Map<String, dynamic>>> getBranchMembers(String branchId) async {
    final response = await _client
        .from('members')
        .select('id, full_name, phone, status')
        .eq('branch_id', branchId)
        .order('full_name');

    return List<Map<String, dynamic>>.from(response);
  }
}
