import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/data/models/user_model.dart';

class UserRepository {
  final SupabaseClient _client;
  final String _orgId;

  UserRepository(this._client, this._orgId);

  Future<List<ProfileModel>> getUsers() async {
    final users = <ProfileModel>[];
    final seenIds = <String>{};

    debugPrint('getUsers called with _orgId: $_orgId');

    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('org_id', _orgId)
          .order('created_at', ascending: false);
      final list = response as List? ?? <dynamic>[];
      debugPrint('Profiles fetched: ${list.length}');
      for (final j in list) {
        if (j is! Map) continue;
        try {
          final p = ProfileModel.fromJson(Map<String, dynamic>.from(j));
          seenIds.add(p.id);
          users.add(p);
        } catch (e) {
          debugPrint('Error parsing profile: $e');
        }
      }
    } catch (e) {
      debugPrint('Error fetching profiles: $e');
    }

    debugPrint('Fetching members now, seenIds count: ${seenIds.length}');

    try {
      List<dynamic> memberResponse;

      try {
        debugPrint('Attempting members query with org_id: $_orgId');
        memberResponse = await _client
            .from('members')
            .select()
            .eq('org_id', _orgId)
            .order('created_at', ascending: false);
        debugPrint(
            'Members fetched with org_id filter: ${memberResponse.length}');
        if (memberResponse.isNotEmpty) {
          debugPrint('First member data: ${memberResponse.first}');
        }
      } catch (e) {
        debugPrint('First member query failed (with org_id): $e');
        debugPrint('Trying without org_id filter...');
        try {
          memberResponse = await _client
              .from('members')
              .select()
              .order('created_at', ascending: false);
          debugPrint(
              'Members fetched without filter: ${memberResponse.length}');
          // Filter manually by org_id
          memberResponse = memberResponse.where((m) {
            if (m is! Map) return false;
            final mOrgId = m['org_id']?.toString();
            return mOrgId == _orgId;
          }).toList();
          debugPrint(
              'Members after manual org_id filter: ${memberResponse.length}');
        } catch (e2) {
          debugPrint('Second member query failed: $e2');
          debugPrint('Trying plain select...');
          memberResponse = await _client.from('members').select();
          debugPrint(
              'Members fetched with plain select: ${memberResponse.length}');
          // Filter manually by org_id
          memberResponse = memberResponse.where((m) {
            if (m is! Map) return false;
            final mOrgId = m['org_id']?.toString();
            return mOrgId == _orgId;
          }).toList();
          debugPrint(
              'Members after manual org_id filter: ${memberResponse.length}');
        }
      }

      int addedCount = 0;
      int skippedCount = 0;

      for (final m in memberResponse) {
        if (m is! Map) {
          debugPrint('Skipping non-Map member entry: $m');
          continue;
        }
        final map = Map<String, dynamic>.from(m);
        final mid = map['id']?.toString() ?? '';

        if (mid.isEmpty) {
          debugPrint('Skipping member with empty id');
          continue;
        }

        final memberOrgId = map['org_id']?.toString();
        if (memberOrgId != null &&
            memberOrgId.isNotEmpty &&
            memberOrgId != _orgId) {
          debugPrint(
              'Skipping member $mid with different org_id: $memberOrgId (expected: $_orgId)');
          continue;
        }

        if (seenIds.contains(mid)) {
          debugPrint(
              'Skipping member $mid - already in seenIds (from profiles)');
          skippedCount++;
          continue;
        }

        final fullName =
            (map['full_name'] ?? map['name'] ?? 'Unknown').toString();
        debugPrint(
            'Adding member: id=$mid, name=$fullName, phone=${map['phone']}, email=${map['email']}, org_id=${map['org_id']}');
        seenIds.add(mid);
        addedCount++;
        users.add(ProfileModel(
          id: mid,
          userId: map['user_id']?.toString(),
          fullName: fullName,
          phone: map['phone']?.toString(),
          email: map['email']?.toString(),
          role: UserRole.customer,
          orgId: memberOrgId ?? _orgId,
          branchId: map['branch_id']?.toString(),
          address: map['address']?.toString(),
          city: map['city']?.toString(),
          state: map['state']?.toString(),
          pincode: map['pincode']?.toString(),
          aadhar: map['aadhar']?.toString(),
          pan: map['pan']?.toString(),
          createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
        ));
      }

      debugPrint(
          'Member processing complete: added=$addedCount, skipped(duplicate)=$skippedCount');
    } catch (e, st) {
      debugPrint('Error fetching members: $e');
      debugPrint('Stack trace: $st');
    }

    debugPrint('Total users returned: ${users.length}');
    return users;
  }

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

    // For customers, create directly in members table (not profiles)
    if (role == UserRole.customer) {
      debugPrint('Creating customer in members table');
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
        debugPrint('Customer created successfully in members table');
        return;
      } catch (e) {
        debugPrint('Failed to create customer in members table: $e');
        rethrow;
      }
    }

    // For staff roles, use existing flow (profiles table)
    debugPrint('Creating staff user in profiles table');
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
      debugPrint('Staff user created via edge function');
    } catch (_) {
      debugPrint('Edge function failed, falling back to direct profile insert');
      // Fallback: insert profile directly without creating an auth user.
      // Using auth.signUp() here would sign OUT the admin and sign IN the
      // new user when email auto-confirm is enabled, breaking the admin session.
      // The admin/manager can create login credentials for the user later.
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
      });
      debugPrint('Staff profile created directly');
    }
  }

  Future<void> updateUser(String id, Map<String, dynamic> data) async {
    data['org_id'] = _orgId;
    await _client
        .from('profiles')
        .update(data)
        .eq('id', id)
        .eq('org_id', _orgId);
  }

  Future<Map<String, int>> getUserStats() async {
    final roles = <String>[];
    try {
      final response =
          await _client.from('profiles').select('role').eq('org_id', _orgId);
      final list = response as List? ?? [];
      for (final r in list) {
        if (r is! Map) continue;
        roles.add(r['role']?.toString() ?? 'customer');
      }
    } catch (e) {
      debugPrint('Error getting profile roles: $e');
    }

    int memberCount = 0;
    try {
      dynamic r;
      try {
        r = await _client.from('members').select('id').eq('org_id', _orgId);
      } catch (e) {
        debugPrint('Member count query with org_id failed: $e');
        try {
          r = await _client.from('members').select('id');
        } catch (e2) {
          debugPrint('Member count query without filter failed: $e2');
          r = [];
        }
      }
      final list = r as List? ?? [];
      memberCount = list.length;
      debugPrint('Member count: $memberCount');
    } catch (e) {
      debugPrint('Error getting member count: $e');
    }

    return {
      'total': roles.length + memberCount,
      'admins': roles.where((r) {
        final n = r.toLowerCase();
        return n.contains('admin') || n == 'owner';
      }).length,
      'managers':
          roles.where((r) => r.toLowerCase().contains('manager')).length,
      'staff': roles.where((r) {
        final n = r.toLowerCase();
        return n.contains('agent') || n == 'staff' || n == 'collector';
      }).length,
      'members': memberCount +
          roles.where((r) {
            final n = r.toLowerCase();
            return n.contains('customer') ||
                n.contains('member') ||
                n == 'user';
          }).length,
    };
  }

  Future<void> deleteUser(String id) async {
    // Get user_id from profile first
    final profile = await _client
        .from('profiles')
        .select('user_id')
        .eq('id', id)
        .maybeSingle();

    final userId = profile?['user_id'] as String?;

    // Delete profile first
    await _client.from('profiles').delete().eq('id', id);

    // If there's an auth user, delete it via edge function
    if (userId != null) {
      try {
        await _client.functions
            .invoke('delete-user', body: {'user_id': userId});
      } catch (e) {
        // Ignore if function fails - profile is already deleted
      }
    }
  }

  Future<void> deleteUsers(List<String> ids) async {
    for (final id in ids) {
      await deleteUser(id);
    }
  }
}
