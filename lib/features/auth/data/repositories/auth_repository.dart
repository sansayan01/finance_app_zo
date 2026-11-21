import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../settings/data/repositories/activity_log_repository.dart';
import '../../../settings/data/models/activity_log_model.dart';
import '../../../../core/config/env_config.dart';
import '../models/user_model.dart';

class AuthRepository {
  final SupabaseClient _client;
  final ActivityLogRepository? _logRepo;

  AuthRepository(this._client, [this._logRepo]);

  SupabaseClient get client => _client;

  /// Check if an email exists in profiles table OR auth metadata.
  /// Uses two checks for reliability — the email may exist in auth.users
  /// without a matching profiles row, or vice versa.
  Future<bool> _checkEmailInProfiles(String email) async {
    final normalized = email.toLowerCase().trim();
    try {
      // Check 1: profiles table (our app's user records)
      final profile = await _client
          .from('profiles')
          .select('id')
          .eq('email', normalized)
          .maybeSingle();
      if (profile != null) return true;

      // Check 2: auth.users via RPC — any user with this email
      // The user may have an auth account but no profile yet
      final authCheck = await _client.rpc('check_email_exists', params: {
        'p_email': normalized,
      });
      if (authCheck == true) return true;

      return false;
    } catch (_) {
      // If queries fail, assume email exists (don't leak info)
      return true;
    }
  }

  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final AuthResponse response;
    try {
      response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      // Log the actual error for debugging
      debugPrint('🔑 [AUTH] signInWithPassword failed: ${e.toString()}');
      debugPrint('🔑 [AUTH] Supabase URL: ${EnvConfig.supabaseUrl}');

      // Network/connection errors — rethrow as-is so the provider can show the right message
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socket') ||
          errStr.contains('network') ||
          errStr.contains('connection') ||
          errStr.contains('timeout') ||
          errStr.contains('cors') ||
          errStr.contains('blocked') ||
          errStr.contains('failed to fetch') ||
          errStr.contains('xmlhttprequest')) {
        rethrow;
      }
      // Sign-in failed — now check if the email exists in profiles
      // to distinguish "email not found" from "wrong password"
      final emailExists = await _checkEmailInProfiles(email);
      if (emailExists) {
        throw AuthException(
          'Incorrect password. Please check your password and try again.',
          statusCode: 'invalid_password',
        );
      } else {
        throw AuthException(
          'No account found with this email. Please check your email address.',
          statusCode: 'email_not_found',
        );
      }
    }

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
    // Check if email already exists in profiles or members
    final existingProfile = await _client
        .from('profiles')
        .select('id')
        .eq('email', email.toLowerCase().trim())
        .maybeSingle();

    if (existingProfile != null) {
      throw Exception('This email is already registered. Please sign in instead.');
    }

    final existingMember = await _client
        .from('members')
        .select('id')
        .eq('email', email.toLowerCase().trim())
        .maybeSingle();

    if (existingMember != null) {
      throw Exception('This email is already registered. Please sign in instead.');
    }

    final metadata = <String, dynamic>{
      'full_name': fullName,
      'phone': phone,
      if (orgName != null && orgName.isNotEmpty) 'org_name': orgName,
    };

    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: metadata,
      emailRedirectTo: 'https://microflow-pro.vercel.app/confirm',
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Sign up failed. This email may already be registered.');
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
    if (orgName == null || orgName.isEmpty) {
      throw StateError('Cannot create org and profile without an org name');
    }
    final slug = orgName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    if (slug.isEmpty) {
      throw StateError(
        'Organization name "$orgName" produces an empty slug — pick a name with letters or digits',
      );
    }

    final trialEnd =
        DateTime.now().add(const Duration(days: 14)).toIso8601String();

    String? orgId;
    // 1) Try to insert a brand-new org row.
    try {
      final orgResponse = await _client
          .from('organizations')
          .insert({
            'name': orgName,
            'slug': slug,
            'status': 'trial',
            'trial_ends_at': trialEnd,
            'max_branches': 10,
            'max_staff': 5,
            'max_members': 100,
            'created_by': user.id,
          })
          .select('id')
          .single();
      orgId = orgResponse['id'].toString();
    } catch (_) {
      // 2) Org creation failed (e.g. slug conflict or RLS) — try to find existing org.
      try {
        final existing = await _client
            .from('organizations')
            .select('id')
            .eq('slug', slug)
            .maybeSingle();
        if (existing != null) {
          orgId = existing['id'].toString();
        }
      } catch (_) {
        // fall through — the "no orgId" throw below handles it
      }
    }

    if (orgId == null) {
      // Do NOT silently bind the user to a sentinel UUID — that caused
      // cross-tenant data leakage. Bubble up so the caller can show an
      // actionable error.
      throw StateError(
        'Failed to provision organization "$orgName". '
        'Please try again or contact support if the issue persists.',
      );
    }

    // Create profile — use upsert to handle race conditions
    try {
      await _client.from('profiles').upsert({
        'user_id': user.id,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'role': 'executiveAdmin',
        'org_id': orgId,
      }, onConflict: 'user_id');
    } catch (_) {
      // Profile creation failed — will be retried on next login
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

  Future<bool> refreshSession() async {
    try {
      final response = await _client.auth.refreshSession();
      return response.session != null;
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('invalid refresh token') ||
          errStr.contains('session not found') ||
          errStr.contains('expired') ||
          errStr.contains('401')) {
        await _client.auth.signOut();
      }
      return false;
    }
  }

  Future<UserModel?> getCurrentUser() async {
    // Proactively refresh the session so the JWT isn't expired
    // when PostgREST calls are made. If refresh fails the user
    // gets signed out and redirected to login.
    try {
      await _client.auth.refreshSession();
    } catch (_) {
      await _client.auth.signOut();
      return null;
    }

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

      // Auto-create org + profile for users who signed up with email verification.
      // The DB trigger (trg_auth_user_creates_profile) may have created a stub
      // profile with role='customer' and org_id=null before we get here, so we
      // also handle the case where the profile exists but has no linked org.
      final orgName = user.userMetadata?['org_name'] as String?;
      if (orgName != null && orgName.isNotEmpty) {
        final needsOrgSetup = profile == null || profile['org_id'] == null;
        if (needsOrgSetup) {
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
    } catch (e, st) {
      debugPrint('⚠️ [AUTH] Error in getCurrentUser: $e');
      debugPrint('⚠️ [AUTH] Stack trace: $st');
      // Fallback already handled by initial role assignment
    }

    return UserModel(
      id: user.id,
      email: user.email ?? '',
      fullName: user.userMetadata?['full_name'] as String? ??
          (profile != null ? profile['full_name'] as String? : null) ??
          '',
      fatherName: profile?['father_name'] as String?,
      phone:
          user.phone ?? (profile != null ? profile['phone'] as String? : null),
      role: role,
      avatarUrl: profile?['avatar_url'] as String?,
      orgId: profile?['org_id'] as String?,
      branchId: profile?['branch_id'] as String?,
      memberId: profile?['member_id'] as String?,
      createdAt: parsedDate ?? DateTime.now(),
    );
  }

  UserRole _parseRole(
      String? roleStr, String? email, Map<String, dynamic>? metadata) {
    // Super admin status is determined exclusively by the role stored in the
    // `profiles` table (or, for new signups, the role baked into auth
    // metadata). Email-based privilege escalation is intentionally removed:
    // super admins must be granted via the platform admin tools.
    // (Parameter `email` retained for signature stability — the previous
    // hard-coded override based on it was a security backdoor and has been
    // removed.)

    // 1. Check metadata role (set during signup)
    final metadataRole = metadata?['role'] as String?;
    final effectiveRole = roleStr ?? metadataRole;

    if (effectiveRole == null) {
      // 2. Fallback for new signups with org name (they are always executiveAdmins)
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

  /// Saves the signed-in user's own profile.
  ///
  /// The `profiles` row is written first and must be confirmed: before this,
  /// any failure (permission, stale record, network) was swallowed by a bare
  /// `catch` and the screen still said "Profile updated successfully", which
  /// is why users saw a change revert after reopening the page.
  ///
  /// Only the fields that were actually supplied are written, so saving the
  /// form cannot blank out a phone number or father name that was not retyped.
  /// On success returns an optional notice to show to the user (for example,
  /// "check your inbox to confirm the new email"); null means a plain success.
  Future<String?> updateProfile({
    required String fullName,
    String? fatherName,
    String? phone,
    String? email,
    String? address,
    String? pan,
    String? aadhar,
    String? employeeId,
    String? assignedZone,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('You are not signed in. Please sign in again.');
    }

    final trimmedName = fullName.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Name cannot be empty.');
    }

    // ---- 1. The profile row (the thing the app actually reads) -------------
    final updates = <String, dynamic>{
      'full_name': trimmedName,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (phone != null) updates['phone'] = phone.trim();
    if (fatherName != null) updates['father_name'] = fatherName.trim();
    if (address != null) updates['address'] = address.trim();
    if (pan != null) updates['pan'] = pan.trim();
    if (aadhar != null) updates['aadhar'] = aadhar.trim();
    if (employeeId != null) updates['employee_id'] = employeeId.trim();
    if (assignedZone != null) updates['assigned_zone'] = assignedZone.trim();

    final savedRows = await _client
        .from('profiles')
        .update(updates)
        .eq('user_id', currentUser.id)
        .select('id');

    if (savedRows.isEmpty) {
      throw Exception(
        'Your profile was not saved. No profile record is linked to this '
        'account, or you do not have permission to edit it. Please contact '
        'your administrator.',
      );
    }

    // ---- 2. Members mirror, so loan/savings lists show the same name --------
    try {
      final memberSync = <String, dynamic>{'full_name': trimmedName};
      if (phone != null) memberSync['phone'] = phone.trim();
      if (fatherName != null) memberSync['father_name'] = fatherName.trim();
      await _client
          .from('members')
          .update(memberSync)
          .eq('profile_id', savedRows.first['id']);
    } catch (_) {
      // Staff profiles have no members row — nothing to mirror.
    }

    // ---- 3. Auth account: name/phone metadata, and email if it changed ------
    // This is best effort. A failure here must not make the whole save look
    // failed, because the profile row above is already saved.
    try {
      final metadata = <String, dynamic>{'full_name': trimmedName};
      if (phone != null) metadata['phone'] = phone.trim();

      final newEmail = (email ?? '').trim();
      final emailChanged = newEmail.isNotEmpty &&
          newEmail.toLowerCase() != (currentUser.email ?? '').toLowerCase();

      await _client.auth.updateUser(
        UserAttributes(
          email: emailChanged ? newEmail : null,
          data: metadata,
        ),
      );

      if (emailChanged) {
        // Supabase only switches the login email after it is confirmed, so say
        // so instead of showing a plain success message.
        return 'Profile saved. To finish changing your email, open the '
            'confirmation link we sent to $newEmail. Until then you keep signing '
            'in with your old email.';
      }
    } catch (e) {
      debugPrint('Auth metadata update failed (profile row already saved): $e');
      return 'Profile saved. Your login details could not be updated: $e';
    }

    await _logRepo?.log(
      action: 'Profile Updated',
      details: 'User updated their personal information',
      type: ActivityType.userAction,
    );

    return null;
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
