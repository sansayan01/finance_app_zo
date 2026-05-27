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
          .select('*, branch:branches!branch_id(id, name)')
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
  /// Server-side paginated query for customers.
  /// Fetches from BOTH the `members` table and `profiles` table (role=customer)
  /// to ensure all customers are shown regardless of where they were created.
  Future<List<ProfileModel>> getMembersPaginated({
    String? branchId,
    String? search,
    UserSortBy sortBy = UserSortBy.createdDesc,
    int offset = 0,
    int limit = 25,
  }) async {
    try {
      final List<ProfileModel> results = [];

      // 1. Fetch from profiles table (customers with role = 'customer')
      var profileQuery = _client
          .from('profiles')
          .select('*, branch:branches!branch_id(id, name)')
          .eq('org_id', _orgId)
          .eq('role', 'customer');

      if (branchId != null && branchId.isNotEmpty) {
        profileQuery = profileQuery.eq('branch_id', branchId);
      }
      if (search != null && search.trim().isNotEmpty) {
        final s = search.trim().replaceAll('%', r'\%');
        profileQuery = profileQuery.or(
          'full_name.ilike.%$s%,email.ilike.%$s%,phone.ilike.%$s%',
        );
      }

      final profileResponse = await _applyOrder(profileQuery, sortBy)
          .range(offset, offset + limit - 1) as List;

      // Collect profile_ids to exclude from members query
      final profileIds = <String>{};
      for (final j in profileResponse.whereType<Map>()) {
        final profile = ProfileModel.fromJson(Map<String, dynamic>.from(j));
        results.add(profile);
        profileIds.add(profile.id);
      }

      // 2. Fetch from members table (members without a linked profile already fetched)
      if (results.length < limit) {
        final membersLimit = limit - results.length;
        var membersQuery = _client
            .from('members')
            .select('*, branch:branches(id, name)')
            .eq('org_id', _orgId);

        if (branchId != null && branchId.isNotEmpty) {
          membersQuery = membersQuery.eq('branch_id', branchId);
        }
        if (search != null && search.trim().isNotEmpty) {
          final s = search.trim().replaceAll('%', r'\%');
          membersQuery = membersQuery.or(
            'full_name.ilike.%$s%,email.ilike.%$s%,phone.ilike.%$s%,member_id.ilike.%$s%',
          );
        }
        // Exclude members that already have a profile we fetched
        if (profileIds.isNotEmpty) {
          // Use .or() to include members with null profile_id OR profile_id not in the set
          // because NOT IN doesn't match NULL values in PostgreSQL
          final quotedIds = profileIds.map((id) => '"$id"').join(',');
          membersQuery = membersQuery.or(
            'profile_id.is.null,profile_id.not.in.($quotedIds)',
          );
        }

        final membersResponse = await _applyOrder(membersQuery, sortBy)
            .range(0, membersLimit - 1) as List;

        for (final j in membersResponse.whereType<Map>()) {
          results.add(
              ProfileModel.fromMembersJson(Map<String, dynamic>.from(j)));
        }
      }

      return results;
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
      final r = await _client
          .from('members')
          .select('id')
          .eq('org_id', _orgId)
          .isFilter('profile_id', null);
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

  /// Update a single profile. RLS enforces org isolation; we don't filter
  /// by org_id here because that would silently no-op for profiles with a
  /// NULL org_id (orphan self-registered users), making the update appear
  /// to succeed while changing nothing.
  Future<void> updateProfile(String id, Map<String, dynamic> data) async {
    data.remove('id');
    data.remove('org_id');
    data['updated_at'] = DateTime.now().toIso8601String();
    final rows = await _client
        .from('profiles')
        .update(data)
        .eq('id', id)
        .select('id');
    if (rows.isEmpty) {
      throw Exception(
        'No profile was updated. The profile may belong to a different '
        'organization, have a missing org_id, or you may lack permission.',
      );
    }

    // Sync branch_id to members table if it was changed
    if (data.containsKey('branch_id')) {
      try {
        await _client
            .from('members')
            .update({'branch_id': data['branch_id']})
            .eq('profile_id', id);
      } catch (_) {
        // Member record may not exist — that's fine
      }
    }
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

  /// Forcefully set a new password for a user via the admin Edge Function.
  /// Only executive admins and managers can use this.
  /// The Edge Function validates org isolation and role hierarchy.
  /// Pass either the profile UUID (if user has no auth account yet) –
  /// the Edge Function will create and link the auth account automatically.
  Future<void> adminSetUserPassword({
    required String targetUserId,
    required String newPassword,
  }) async {
    if (targetUserId.isEmpty) {
      throw Exception('Target user ID is required.');
    }
    if (newPassword.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    // Quick pre-check: try to read the profile to confirm it exists.
    // If the target is a member (no profile yet), create a profile first
    // so the Edge Function can link an auth account to it.
    String effectiveTargetId = targetUserId;
    try {
      var profileQuery = _client
          .from('profiles')
          .select('id, full_name, user_id, org_id');
      if (targetUserId.isNotEmpty) {
        profileQuery = profileQuery.or(
          'id.eq.$targetUserId,user_id.eq.$targetUserId',
        );
      }
      final profile = await profileQuery.maybeSingle();
      if (profile == null) {
        // Profile not found — check if this is a member without a profile
        final member = await _client
            .from('members')
            .select('id, full_name, phone, email, org_id')
            .eq('id', targetUserId)
            .maybeSingle();
        if (member == null) {
          throw Exception('Target user profile not found.');
        }
        // Verify org isolation
        if ((member['org_id'] as String?) != _orgId) {
          throw Exception('Forbidden: target user belongs to a different organization.');
        }
        // Create a profile for this member so the Edge Function can work with it
        final newProfile = await _client.from('profiles').insert({
          'full_name': member['full_name'],
          'phone': member['phone'],
          'email': member['email'],
          'org_id': member['org_id'],
          'role': 'customer',
          'status': 'active',
        }).select('id').single();
        // Link the member to the new profile
        await _client
            .from('members')
            .update({'profile_id': newProfile['id']})
            .eq('id', targetUserId);
        effectiveTargetId = newProfile['id'] as String;
      } else {
        final uid = profile['user_id'] as String?;
        if (uid == null && (profile['org_id'] as String?) != _orgId) {
          throw Exception('Forbidden: target user belongs to a different organization.');
        }
      }
    } catch (_) {
      // Re-throw only pre-check errors; let the edge function do the heavy lift
      rethrow;
    }

    final response = await _client.functions.invoke(
      'set-user-password',
      body: {
        'target_user_id': effectiveTargetId,
        'new_password': newPassword,
      },
    );

    if (response.status != 200) {
      final data = response.data;
      final message = data is Map ? (data['message']?.toString() ?? 'Failed to set password') : 'Failed to set password';
      throw Exception(message);
    }
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

    // All users must have email and password to create auth account
    if (email.isEmpty || password.isEmpty) {
      throw Exception('Email and password are required to create a user.');
    }

    // Check if email already exists in profiles
    final existingProfile = await _client
        .from('profiles')
        .select('id')
        .eq('email', email.toLowerCase().trim())
        .maybeSingle();

    if (existingProfile != null) {
      throw Exception('This email is already registered. Please use a different email.');
    }

    // Check if email already exists in members
    final existingMember = await _client
        .from('members')
        .select('id')
        .eq('email', email.toLowerCase().trim())
        .maybeSingle();

    if (existingMember != null) {
      throw Exception('This email is already registered. Please use a different email.');
    }

    // Step 1: Create auth user via edge function
    final response = await _client.functions.invoke(
      'create-user',
      body: {
        'email': email,
        'password': password,
        'full_name': fullName,
        'phone': phone,
        'role': role.name,
        'aadhar': aadhar,
        'pan': pan,
        'employee_id': employeeId,
        'assigned_zone': assignedZone,
      },
    );

    if (response.status != 200) {
      throw Exception(response.data?['error'] ?? 'Failed to create user account.');
    }

    final authUserId = response.data['user_id'] as String?;

    if (authUserId == null) {
      throw Exception('Failed to get user ID from auth response.');
    }

    // Step 2: Create profile with the auth user ID
    final profileResult = await _client.from('profiles').upsert({
      'user_id': authUserId,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'role': role.name,
      'aadhar': aadhar.isEmpty ? null : aadhar,
      'pan': pan.isEmpty ? null : pan,
      'employee_id': employeeId,
      'assigned_zone': assignedZone,
      'branch_id': branchId,
      'org_id': _orgId,
      'status': 'active',
    }, onConflict: 'user_id').select('id').single();

    final profileId = profileResult['id'] as String;

    // Step 3: For customers, also create a members record
    if (role == UserRole.customer) {
      try {
        final memberId =
            'CUST-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
        await _client.from('members').insert({
          'org_id': _orgId,
          'full_name': fullName,
          'phone': phone,
          'email': email,
          'branch_id': branchId,
          'kyc_status': 'pending',
          'member_id': memberId,
          'profile_id': profileId,
        });
      } catch (e) {
        debugPrint('Failed to create customer in members table: $e');
        // Don't throw - auth user and profile are already created
      }
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
      // Only add members that don't already have a linked profile
      // (those are already included from the profiles query above)
      final profileIds = users.map((u) => u.id).toSet();
      for (final m in members) {
        if (!profileIds.contains(m.id)) {
          users.add(m);
        }
      }
    } catch (e) {
      debugPrint('getUsers members error: $e');
    }
    return users;
  }

  // ---------------------------------------------------------------------------
  // ADMIN: AUDIT LOG WRITE / READ
  // ---------------------------------------------------------------------------

  /// Append a row to `audit_logs` describing an admin action.
  /// Best-effort: failures are swallowed so a logging hiccup never blocks
  /// the actual admin operation.
  Future<void> logAdminAction({
    required String action,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? details,
  }) async {
    try {
      await _client.from('audit_logs').insert({
        'org_id': _orgId,
        'user_id': _client.auth.currentUser?.id,
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'details': details ?? <String, dynamic>{},
      });
    } catch (e) {
      debugPrint('logAdminAction error: $e');
    }
  }

  /// Fetch admin-relevant audit_logs entries that target the given user.
  /// Looks up by both:
  ///   - rows where the user IS the actor (audit_logs.user_id == authUserId)
  ///   - rows where the user IS the entity (entity_type='profile' AND
  ///     entity_id == profileId)
  Future<List<Map<String, dynamic>>> getAuditLogsForUser({
    required String profileId,
    String? authUserId,
    int limit = 100,
  }) async {
    try {
      final orParts = <String>['entity_id.eq.$profileId'];
      if (authUserId != null && authUserId.isNotEmpty) {
        orParts.add('user_id.eq.$authUserId');
      }
      final res = await _client
          .from('audit_logs')
          .select()
          .eq('org_id', _orgId)
          .or(orParts.join(','))
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(res as List? ?? const []);
    } catch (e) {
      debugPrint('getAuditLogsForUser error: $e');
      return const [];
    }
  }

  // ---------------------------------------------------------------------------
  // ADMIN: ADMIN NOTES (admin-only annotations on a user profile)
  // ---------------------------------------------------------------------------

  /// All notes attached to [profileId], newest first.
  Future<List<Map<String, dynamic>>> getAdminNotes(String profileId) async {
    try {
      final res = await _client
          .from('admin_notes')
          .select(
              '*, author:profiles!admin_notes_author_profile_id_fkey(id, full_name, role)')
          .eq('user_profile_id', profileId)
          .order('pinned', ascending: false)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res as List? ?? const []);
    } catch (e) {
      debugPrint('getAdminNotes error: $e');
      // Fall back to a plain select if the join above isn't available
      try {
        final res = await _client
            .from('admin_notes')
            .select()
            .eq('user_profile_id', profileId)
            .order('created_at', ascending: false);
        return List<Map<String, dynamic>>.from(res as List? ?? const []);
      } catch (e2) {
        debugPrint('getAdminNotes fallback error: $e2');
        return const [];
      }
    }
  }

  /// Insert a new admin note. Returns the created row.
  Future<Map<String, dynamic>?> addAdminNote({
    required String profileId,
    required String body,
    bool pinned = false,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw Exception('Note body cannot be empty');
    }
    // Find the author's profile id from the current auth user.
    String? authorProfileId;
    final authUserId = _client.auth.currentUser?.id;
    if (authUserId != null) {
      try {
        final p = await _client
            .from('profiles')
            .select('id')
            .eq('user_id', authUserId)
            .eq('org_id', _orgId)
            .maybeSingle();
        authorProfileId = p?['id'] as String?;
      } catch (e) {
        debugPrint('addAdminNote author lookup error: $e');
      }
    }
    final row = await _client
        .from('admin_notes')
        .insert({
          'org_id': _orgId,
          'user_profile_id': profileId,
          'author_profile_id': authorProfileId,
          'body': trimmed,
          'pinned': pinned,
        })
        .select()
        .maybeSingle();
    await logAdminAction(
      action: 'admin_note.created',
      entityType: 'profile',
      entityId: profileId,
      details: {'note_id': row?['id'], 'pinned': pinned},
    );
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  /// Toggle the pinned flag on an existing note.
  Future<void> setAdminNotePinned(String noteId, bool pinned) async {
    await _client
        .from('admin_notes')
        .update({'pinned': pinned}).eq('id', noteId);
  }

  /// Delete an admin note. Author or super-admin only (enforced by RLS).
  Future<void> deleteAdminNote(String noteId, {String? profileId}) async {
    await _client.from('admin_notes').delete().eq('id', noteId);
    await logAdminAction(
      action: 'admin_note.deleted',
      entityType: 'profile',
      entityId: profileId,
      details: {'note_id': noteId},
    );
  }

  // ---------------------------------------------------------------------------
  // ADMIN: COMPLIANCE — DATA EXPORT REQUESTS
  // ---------------------------------------------------------------------------

  /// Queue a data-export request for one user. Writes a row into the
  /// existing `data_exports` table (which already has RLS for org isolation).
  /// A backend worker / Edge Function (admin-export-user-data) is expected
  /// to pick up rows with status='pending' and produce the file.
  Future<Map<String, dynamic>?> requestUserDataExport({
    required String profileId,
    String format = 'json',
  }) async {
    String? createdById;
    final authUserId = _client.auth.currentUser?.id;
    if (authUserId != null) {
      try {
        final p = await _client
            .from('profiles')
            .select('id')
            .eq('user_id', authUserId)
            .eq('org_id', _orgId)
            .maybeSingle();
        createdById = p?['id'] as String?;
      } catch (_) {}
    }

    final row = await _client
        .from('data_exports')
        .insert({
          'org_id': _orgId,
          // 'full_backup' is the only generic value supported by the
          // data_exports.type CHECK constraint that fits "everything for
          // one user". The user is identified via filters.
          'type': 'full_backup',
          'format': format,
          'status': 'pending',
          'filters': {
            'scope': 'single_user',
            'profile_id': profileId,
          },
          'created_by': createdById,
        })
        .select()
        .maybeSingle();

    await logAdminAction(
      action: 'data_export.requested',
      entityType: 'profile',
      entityId: profileId,
      details: {'export_id': row?['id'], 'format': format},
    );

    return row == null ? null : Map<String, dynamic>.from(row);
  }

  /// List recent export requests scoped to a single user.
  Future<List<Map<String, dynamic>>> listUserDataExports(
      String profileId) async {
    try {
      final res = await _client
          .from('data_exports')
          .select()
          .eq('org_id', _orgId)
          // PostgREST JSON contains operator
          .contains('filters', {'profile_id': profileId})
          .order('created_at', ascending: false)
          .limit(20);
      return List<Map<String, dynamic>>.from(res as List? ?? const []);
    } catch (e) {
      debugPrint('listUserDataExports error: $e');
      return const [];
    }
  }

  // ---------------------------------------------------------------------------
  // ADMIN: DELETE WITH REASON (audit-logged)
  // ---------------------------------------------------------------------------

  /// Audit-logged version of [deleteUser]. The reason is required and is
  /// stored in audit_logs.details.reason for compliance.
  Future<void> deleteUserWithReason({
    required String profileId,
    required String reason,
  }) async {
    final r = reason.trim();
    if (r.isEmpty) {
      throw Exception('A reason is required to permanently delete a user.');
    }
    // Snapshot a few useful fields before the row disappears.
    Map<String, dynamic>? snapshot;
    try {
      snapshot = await _client
          .from('profiles')
          .select('id, full_name, email, phone, role, branch_id')
          .eq('id', profileId)
          .maybeSingle();
    } catch (_) {}

    await logAdminAction(
      action: 'profile.deleted',
      entityType: 'profile',
      entityId: profileId,
      details: {
        'reason': r,
        if (snapshot != null) 'snapshot': snapshot,
      },
    );
    await deleteUser(profileId);
  }

  // ---------------------------------------------------------------------------
  // ADMIN: ROLE CHANGE (audit-logged wrapper)
  // ---------------------------------------------------------------------------

  Future<void> changeUserRole({
    required String profileId,
    required UserRole oldRole,
    required UserRole newRole,
    String? reason,
  }) async {
    if (oldRole == newRole) return;
    await updateUserRole(profileId, newRole);
    await logAdminAction(
      action: 'profile.role_changed',
      entityType: 'profile',
      entityId: profileId,
      details: {
        'from': oldRole.name,
        'to': newRole.name,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  // ---------------------------------------------------------------------------
  // ADMIN: STATUS CHANGE (audit-logged wrapper)
  // ---------------------------------------------------------------------------

  Future<void> changeUserStatus({
    required String profileId,
    required AccountStatus oldStatus,
    required AccountStatus newStatus,
    String? reason,
  }) async {
    if (oldStatus == newStatus) return;
    await updateUserStatus(profileId, newStatus);
    await logAdminAction(
      action: 'profile.status_changed',
      entityType: 'profile',
      entityId: profileId,
      details: {
        'from': oldStatus.wireValue,
        'to': newStatus.wireValue,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }
}
