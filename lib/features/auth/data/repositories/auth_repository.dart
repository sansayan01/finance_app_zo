import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../settings/data/repositories/activity_log_repository.dart';
import '../../../settings/data/models/activity_log_model.dart';
import '../models/user_model.dart';

class AuthRepository {
  final SupabaseClient _client;
  final ActivityLogRepository? _logRepo;

  AuthRepository(this._client, [this._logRepo]);

  SupabaseClient get client => _client;

  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Authentication failed');
    }

    // Use getCurrentUser to handle profile fetching and auto-creation
    final userModel = await getCurrentUser();
    if (userModel == null) {
      throw Exception('Failed to load user profile');
    }

    // Audit the login action (Fail-safe)
    try {
      await _logRepo?.log(
        action: 'Admin Login',
        details:
            'Admin user ${userModel.email} successfully authenticated and accessed the dashboard.',
        type: ActivityType.authAction,
        userId: userModel.id,
        userName: userModel.fullName,
      );
    } catch (e) {
      // Never block login because of logging failure
    }

    return userModel;
  }

  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String? orgName,
  }) async {
    final metadata = <String, dynamic>{
      'full_name': fullName,
      'phone': phone,
      if (orgName != null && orgName.isNotEmpty) 'org_name': orgName,
    };

    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: metadata,
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Sign up failed');
    }

    // If email confirmation is disabled and we have a session, create org + profile now
    if (response.session != null) {
      return _createOrgAndProfile(user, fullName, email, phone, orgName);
    }

    // Email confirmation required - return user without org/profile
    // They'll be created on first login via getCurrentUser()
    final parsedDate = DateTime.tryParse(user.createdAt);
    return UserModel(
      id: user.id,
      email: user.email ?? '',
      fullName: fullName,
      phone: phone,
      role: UserRole.executiveAdmin,
      createdAt: parsedDate ?? DateTime.now(),
    );
  }

  Future<UserModel> _createOrgAndProfile(
    User user,
    String fullName,
    String email,
    String? phone,
    String? orgName,
  ) async {
    String orgId = '00000000-0000-0000-0000-000000000001';
    if (orgName != null && orgName.isNotEmpty) {
      final slug = orgName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
      final trialEnd =
          DateTime.now().add(const Duration(days: 14)).toIso8601String();
      final orgResponse = await _client
          .from('organizations')
          .insert({
            'name': orgName,
            'slug': slug,
            'status': 'trial',
            'trial_ends_at': trialEnd,
            'max_branches': 2,
            'max_staff': 5,
            'max_members': 100,
          })
          .select('id')
          .single();
      orgId = orgResponse['id'].toString();

      await _client.from('profiles').insert({
        'user_id': user.id,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'role': 'executiveAdmin',
        'org_id': orgId,
      });
    }

    final parsedDate = DateTime.tryParse(user.createdAt);
    return UserModel(
      id: user.id,
      email: user.email ?? '',
      fullName: fullName,
      phone: phone,
      role: UserRole.executiveAdmin,
      orgId: orgId,
      createdAt: parsedDate ?? DateTime.now(),
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<UserModel?> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final parsedDate = DateTime.tryParse(user.createdAt);

    UserRole role = _parseRole(null, user.email, user.userMetadata);
    Map<String, dynamic>? profile;
    try {
      profile = await _client
          .from('profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (profile == null && user.email != null) {
        profile = await _client
            .from('profiles')
            .select()
            .eq('email', user.email!)
            .maybeSingle();

        if (profile != null) {
          await _client
              .from('profiles')
              .update({'user_id': user.id}).eq('id', profile['id']);
        }
      }

      // Auto-create org + profile for users who signed up with email verification
      if (profile == null) {
        final orgName = user.userMetadata?['org_name'] as String?;
        if (orgName != null && orgName.isNotEmpty) {
          final created = await _createOrgAndProfile(
            user,
            user.userMetadata?['full_name'] as String? ?? '',
            user.email ?? '',
            user.userMetadata?['phone'] as String?,
            orgName,
          );
          return created;
        }
      }

      if (profile != null) {
        role = _parseRole(
            profile['role'] as String?, user.email, user.userMetadata);
      } else {
        role = _parseRole(null, user.email, user.userMetadata);
      }
    } catch (e) {
      // Fallback already handled by initial role assignment
    }

    return UserModel(
      id: user.id,
      email: user.email ?? '',
      fullName: user.userMetadata?['full_name'] as String? ??
          (profile != null ? profile['full_name'] as String? : null) ??
          '',
      phone:
          user.phone ?? (profile != null ? profile['phone'] as String? : null),
      role: role,
      orgId: profile?['org_id'] as String?,
      branchId: profile?['branch_id'] as String?,
      memberId: profile?['member_id'] as String?,
      createdAt: parsedDate ?? DateTime.now(),
    );
  }

  UserRole _parseRole(
      String? roleStr, String? email, Map<String, dynamic>? metadata) {
    // 1. Explicit super admin override
    if (email != null && email.toLowerCase() == 'msayan9733@gmail.com') {
      return UserRole.superAdmin;
    }

    // 2. Check metadata role (set during signup)
    final metadataRole = metadata?['role'] as String?;
    final effectiveRole = roleStr ?? metadataRole;

    if (effectiveRole == null) {
      // 3. Fallback for new signups with org name (they are always executiveAdmins)
      if (metadata?['org_name'] != null) {
        return UserRole.executiveAdmin;
      }
      return UserRole.customer;
    }

    final normalized = effectiveRole.toLowerCase();

    if (normalized == 'superadmin' || normalized == 'super_admin') {
      return UserRole.superAdmin;
    }
    if (normalized == 'executiveadmin' || normalized == 'admin') {
      return UserRole.executiveAdmin;
    }
    if (normalized == 'manager') {
      return UserRole.manager;
    }
    if (normalized == 'collectionagent' ||
        normalized == 'staff' ||
        normalized == 'fieldstaff') {
      return UserRole.collectionAgent;
    }
    if (normalized == 'customer' || normalized == 'retailmember') {
      return UserRole.customer;
    }

    return UserRole.values.firstWhere(
      (e) => e.name.toLowerCase() == normalized,
      orElse: () => UserRole.customer,
    );
  }

  Future<void> updateProfile({
    required String fullName,
    String? phone,
    String? email,
    String? address,
    String? pan,
    String? aadhar,
    String? employeeId,
    String? assignedZone,
  }) async {
    final attributes = UserAttributes(
      email: email,
      data: {
        'full_name': fullName,
        'phone': phone,
      },
    );
    await _client.auth.updateUser(attributes);

    try {
      final updates = <String, dynamic>{
        'full_name': fullName,
        'phone': phone,
      };
      if (address != null) updates['address'] = address;
      if (pan != null) updates['pan'] = pan;
      if (aadhar != null) updates['aadhar'] = aadhar;
      if (employeeId != null) updates['employee_id'] = employeeId;
      if (assignedZone != null) updates['assigned_zone'] = assignedZone;

      await _client
          .from('profiles')
          .update(updates)
          .eq('user_id', _client.auth.currentUser!.id);

      await _logRepo?.log(
        action: 'Profile Updated',
        details: 'User updated their personal information',
        type: ActivityType.userAction,
      );
    } catch (e) {
      // Ignore if table doesn't exist
    }
  }

  Future<void> verifyPassword(String currentPassword) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) throw Exception('User not logged in');

    await _client.auth.signInWithPassword(
      email: email,
      password: currentPassword,
    );
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );

    await _logRepo?.log(
      action: 'Password Changed',
      details: 'User successfully updated their account password',
      type: ActivityType.securityAlert,
    );
  }

  Stream<User?> authStateChanges() {
    return _client.auth.onAuthStateChange.map((event) => event.session?.user);
  }
}
