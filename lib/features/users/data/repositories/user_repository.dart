import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/data/models/user_model.dart';

/// Sort criteria available on the User Hub.
enum UserSortBy { createdDesc, createdAsc, nameAsc, nameDesc, lastSeenDesc }

extension UserSortByX on UserSortBy {
  String get label => switch (this) {
        UserSortBy.createdDesc => 'Newest first',
        UserSortBy.createdAsc => 'Oldest first',
        UserSortBy.nameAsc => 'Name (A → Z)',
        UserSortBy.nameDesc => 'Name (Z → A)',
        UserSortBy.lastSeenDesc => 'Recently active',
      };
}

class UserRepository {
  final SupabaseClient _client;
  final String _orgId;

  UserRepository(this._client, this._orgId);

  String get orgId => _orgId;

  // ---------------------------------------------------------------------------
  // PROFILES (Team / Suspended)
  // ---------------------------------------------------------------------------

  /// Server-side paginated query against the `profiles` table.
  ///
  /// [roles] — limit to specific staff roles. Empty = all profiles.
  /// [includeStatuses] — ANY-match against the `status` column.
  /// [excludeStatuses] — exclude rows whose `status` matches.
  /// [search] — case-insensitive match on full_name / email / phone / staff_code.
  Future<List<ProfileModel>> getProfilesPaginated({
    Set<UserRole> roles = const {},
    Set<AccountStatus> includeStatuses = const {},
    Set<AccountStatus> excludeStatuses = const {},
    String? branchId,
    String? search,
    UserSortBy sortBy = UserSortBy.createdDesc,
    int offset = 0,
    int limit = 25,
  }) async {
    try {
      var query = _client
          .from('profiles')
          .select('*, branch:branches(id, name)')
          .eq('org_id', _orgId);

      if (roles.isNotEmpty) {
        query = query.inFilter('role', roles.map((r) => r.name).toList());
      }
      if (includeStatuses.isNotEmpty) {
        query = query.inFilter(
            'status', includeStatuses.map((s) => s.wireValue).toList());
      }
      for (final s in excludeStatuses) {
        query = query.not('status', 'eq', s.wireValue);
      }
      if (branchId != null && branchId.isNotEmpty) {
        query = query.eq('branch_id', branchId);
      }
      if (search != null && search.trim().isNotEmpty) {
        final s = search.trim().replaceAll('%', r'\%');
        query = query.or(
          'full_name.ilike.%$s%,email.ilike.%$s%,phone.ilike.%$s%,staff_code.ilike.%$s%',
        );
      }

      final response = await _applyOrder(query, sortBy)
          .range(offset, offset + limit - 1) as List;

      return response
          .whereType<Map>()
          .map((j) => ProfileModel.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    } catch (e) {
      debugPrint('getProfilesPaginated error: $e');
      rethrow;
    }
  }

  /// Server-side paginated query against the `members` table (customers).
  Future<List<ProfileModel>> getMembersPaginated({
    String? branchId,
    String? search,
    UserSortBy sortBy = UserSortBy.createdDesc,
    int offset = 0,
    int limit = 25,
  }) async {
    try {
      var query = _client
          .from('members')
          .select('*, branch:branches(id, name)')
          .eq('org_id', _orgId);

      if (branchId != null && branchId.isNotEmpty) {
        query = query.eq('branch_id', branchId);
      }
      if (search != null && search.trim().isNotEmpty) {
        final s = search.trim().replaceAll('%', r'\%');
        query = query.or(
          'full_name.ilike.%$s%,email.ilike.%$s%,phone.ilike.%$s%,member_id.ilike.%$s%',
        );
      }

      final response = await _applyOrder(query, sortBy)
          .range(offset, offset + limit - 1) as List;

      return response
          .whereType<Map>()
          .map((j) =>
              ProfileModel.fromMembersJson(Map<String, dynamic>.from(j)))
          .toList();
    } catch (e) {
      debugPrint('getMembersPaginated error: $e');
      rethrow;
    }
  }

  /// Apply order clause based on [sortBy].
  dynamic _applyOrder(dynamic query, UserSortBy sortBy) {
    switch (sortBy) {
      case UserSortBy.createdDesc:
        return query.order('created_at', ascending: false);
      case UserSortBy.createdAsc:
        return query.order('created_at', ascending: true);
      case UserSortBy.nameAsc:
        return query.order('full_name', ascending: true);
      case UserSortBy.nameDesc:
        return query.order('full_name', ascending: false);
      case UserSortBy.lastSeenDesc:
        // last_seen_at column may not exist in all environments — fall back to created_at.
        return query.order('created_at', ascending: false);
    }
  }

  // ---------------------------------------------------------------------------
  // STATS
  // ---------------------------------------------------------------------------

  Future<Map<String, int>> getUserStats() async {
    final stats = <String, int>{
      'total': 0,
      'admins': 0,
      'managers': 0,
      'staff': 0,
      'members': 0,
      'suspended': 0,
    };

    try {
      final response = await _client
          .from('profiles')
          .select('role,status')
          .eq('org_id', _orgId);
      for (final r in (response as List? ?? [])) {
        if (r is! Map) continue;
        final role = (r['role'] ?? '').toString().toLowerCase();
        final status = (r['status'] ?? 'active').toString().toLowerCase();
        if (status == 'suspended' || status == 'inactive') {
          stats['suspended'] = (stats['suspended'] ?? 0) + 1;
          continue;
        }
        if (role.contains('admin') && !role.contains('super')) {
          stats['admins'] = stats['admins']! + 1;
        } else if (role.contains('manager')) {
          stats['managers'] = stats['managers']! + 1;
        } else if (role.contains('agent') ||
            role == 'staff' ||
            role == 'collector') {
          stats['staff'] = stats['staff']! + 1;
        } else if (role.contains('customer')) {
          stats['members'] = stats['members']! + 1;
        }
      }
    } catch (e) {
      debugPrint('getUserStats profiles error: $e');
    }

    try {
      final r = await _client.from('members').select('id').eq('org_id', _orgId);
      stats['members'] = (stats['members'] ?? 0) + ((r as List?)?.length ?? 0);
    } catch (e) {
      debugPrint('getUserStats members error: $e');
    }

    stats['total'] = (stats['admins']! +
            stats['managers']! +
            stats['staff']! +
            stats['members']! +
            stats['suspended']!)
        .toInt();
    return stats;
  }

  // ---------------------------------------------------------------------------
  // ADMIN ACTIONS
  // ---------------------------------------------------------------------------

  /// Update a single profile. `org_id` is forced to the current org.
  Future<void> updateProfile(String id, Map<String, dynamic> data) async {
    data.remove('id');
    data.remove('org_id');
    data['updated_at'] = DateTime.now().toIso8601String();
    await _client
        .from('profiles')
        .update(data)
        .eq('id', id)
        .eq('org_id', _orgId);
  }

  Future<void> updateUserRole(String id, UserRole role) =>
      updateProfile(id, {'role': role.name});

  Future<void> updateUserStatus(String id, AccountStatus status) =>
      updateProfile(id, {'status': status.wireValue});

  /// Send a password reset email through Supabase Auth.
  Future<void> sendPasswordReset(String email) async {
    if (email.trim().isEmpty) {
      throw Exception('Email is required to send a password reset.');
    }
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  /// Force-logout a user. Tries the `force-logout` edge function first;
  /// falls back to flipping the profile's status to `inactive`, which
  /// will be picked up by the next session refresh.
  Future<void> forceLogout(String profileId, {String? userId}) async {
    if (userId != null) {
      try {
        await _client.functions
            .invoke('force-logout', body: {'user_id': userId});
        return;
      } catch (e) {
        debugPrint('force-logout edge function failed: $e — using fallback');
      }
    }
    await updateUserStatus(profileId, AccountStatus.inactive);
  }

  // ---------------------------------------------------------------------------
  // BULK OPS
  // ---------------------------------------------------------------------------

  /// Bulk-insert customers into the `members` table. Returns number of rows
  /// successfully inserted.
  Future<int> bulkInsertMembers(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return 0;
    int success = 0;
    // Insert in chunks of 100 so a single bad row doesn't sink the whole batch.
    const chunkSize = 50;
    for (var i = 0; i < rows.length; i += chunkSize) {
      final chunk = rows.skip(i).take(chunkSize).map((r) {
        final clean = Map<String, dynamic>.from(r);
        clean['org_id'] = _orgId;
        clean['kyc_status'] = clean['kyc_status'] ?? 'pending';
        if (clean['member_id'] == null ||
            clean['member_id'].toString().trim().isEmpty) {
          clean['member_id'] =
              'CUST-${DateTime.now().millisecondsSinceEpoch}-$i';
        }
        return clean;
      }).toList();
      try {
        final res = await _client.from('members').insert(chunk).select('id');
        success += (res as List?)?.length ?? 0;
      } catch (e) {
        debugPrint('bulkInsertMembers chunk error: $e');
      }
    }
    return success;
  }

  // ---------------------------------------------------------------------------
  // ACTIVITY / PERFORMANCE
  // ---------------------------------------------------------------------------

  /// Returns the latest activity timestamp for each user_id provided.
  Future<Map<String, DateTime>> getLastActivityBatch(
      List<String> userIds) async {
    final out = <String, DateTime>{};
    if (userIds.isEmpty) return out;
    try {
      final res = await _client
          .from('activity_logs')
          .select('user_id,timestamp')
          .eq('org_id', _orgId)
          .inFilter('user_id', userIds)
          .order('timestamp', ascending: false)
          .limit(500);
      for (final row in (res as List? ?? [])) {
        if (row is! Map) continue;
        final uid = row['user_id']?.toString();
        final ts = row['timestamp']?.toString();
        if (uid == null || ts == null) continue;
        final dt = DateTime.tryParse(ts);
        if (dt == null) continue;
        // Keep only the newest per user.
        if (!out.containsKey(uid) || out[uid]!.isBefore(dt)) {
          out[uid] = dt;
        }
      }
    } catch (e) {
      debugPrint('getLastActivityBatch error: $e');
    }
    return out;
  }

  /// Today's collection totals per staff_id (for performance metric).
  Future<Map<String, double>> getStaffPerformanceToday(
      List<String> staffIds) async {
    final out = <String, double>{};
    if (staffIds.isEmpty) return out;
    try {
      final start = DateTime.now().toUtc();
      final dayStart =
          DateTime.utc(start.year, start.month, start.day).toIso8601String();
      final res = await _client
          .from('collections')
          .select('staff_id,amount_collected')
          .eq('org_id', _orgId)
          .inFilter('staff_id', staffIds)
          .gte('collection_time', dayStart);
      for (final row in (res as List? ?? [])) {
        if (row is! Map) continue;
        final sid = row['staff_id']?.toString();
        if (sid == null) continue;
        final amt = (row['amount_collected'] as num?)?.toDouble() ?? 0.0;
        out[sid] = (out[sid] ?? 0) + amt;
      }
    } catch (e) {
      debugPrint('getStaffPerformanceToday error: $e');
    }
    return out;
  }

  /// All activity_logs for one user, newest first.
  Future<List<Map<String, dynamic>>> getActivityLogsForUser(
    String userId, {
    int limit = 100,
  }) async {
    try {
      final res = await _client
          .from('activity_logs')
          .select()
          .eq('org_id', _orgId)
          .eq('user_id', userId)
          .order('timestamp', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(res as List? ?? []);
    } catch (e) {
      debugPrint('getActivityLogsForUser error: $e');
      return const [];
    }
  }

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  Future<void> createUser({
    required String fullName,
    required String email,
    required String phone,
    required UserRole role,
    required String aadhar,
    required String pan,
    String? employeeId,
    String? assignedZone,
    String? branchId,
    required String password,
  }) async {
    debugPrint(
        'createUser called: name=$fullName, role=${role.name}, org_id=$_orgId');

    if (role == UserRole.customer) {
      try {
        final memberId =
            'CUST-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
        await _client.from('members').insert({
          'org_id': _orgId,
          'full_name': fullName,
          'phone': phone,
          'email': email.isNotEmpty ? email : null,
          'branch_id': branchId,
          'kyc_status': 'pending',
          'member_id': memberId,
        });
        return;
      } catch (e) {
        debugPrint('Failed to create customer in members table: $e');
        rethrow;
      }
    }

    try {
      await _client.functions.invoke('create-user', body: {
        'email': email,
        'password': password,
        'full_name': fullName,
        'phone': phone,
        'role': role.name,
        'aadhar': aadhar,
        'pan': pan,
        'employee_id': employeeId,
        'assigned_zone': assignedZone,
        'branch_id': branchId,
        'org_id': _orgId,
      });
    } catch (_) {
      await _client.from('profiles').insert({
        'user_id': _client.auth.currentUser?.id,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'role': role.name,
        'aadhar': aadhar,
        'pan': pan,
        'employee_id': employeeId,
        'assigned_zone': assignedZone,
        'branch_id': branchId,
        'org_id': _orgId,
        'status': 'active',
      });
    }
  }

  /// Legacy alias retained so that `updateUser(id, {...})` callers don't break.
  Future<void> updateUser(String id, Map<String, dynamic> data) =>
      updateProfile(id, data);

  Future<void> deleteUser(String id) async {
    final profile = await _client
        .from('profiles')
        .select('user_id')
        .eq('id', id)
        .maybeSingle();

    final userId = profile?['user_id'] as String?;

    await _client.from('profiles').delete().eq('id', id);

    if (userId != null) {
      try {
        await _client.functions
            .invoke('delete-user', body: {'user_id': userId});
      } catch (_) {
        // Ignore — profile already deleted.
      }
    }
  }

  Future<void> deleteUsers(List<String> ids) async {
    for (final id in ids) {
      await deleteUser(id);
    }
  }

  /// Legacy "fetch everything" helper kept for backwards-compat with the few
  /// callers that still expect a single flat list. Prefer the paginated
  /// methods above for new code.
  Future<List<ProfileModel>> getUsers() async {
    final users = <ProfileModel>[];
    try {
      final profiles = await getProfilesPaginated(limit: 1000);
      users.addAll(profiles);
    } catch (e) {
      debugPrint('getUsers profiles error: $e');
    }
    try {
      final members = await getMembersPaginated(limit: 1000);
      users.addAll(members);
    } catch (e) {
      debugPrint('getUsers members error: $e');
    }
    return users;
  }
}
