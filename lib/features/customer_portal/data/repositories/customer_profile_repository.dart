import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerProfileRepository {
  final SupabaseClient _client;
  final String _orgId;

  CustomerProfileRepository(this._client, _orgId) : _orgId = _orgId;

  Future<Map<String, dynamic>?> getMemberProfile(String memberId) async {
    try {
      final memberData = await _client
          .from('members')
          .select(
            'id, full_name, father_name, phone, email, kyc_status, area, village, address, '
            'aadhar_number, pan_number, date_of_birth, gender, occupation, monthly_income, '
            'profile_id, created_at',
          )
          .eq('id', memberId)
          .eq('org_id', _orgId)
          .maybeSingle();

      if (memberData == null) return null;

      // Fetch profile email if members.email is empty
      String? email = memberData['email'] as String?;
      if ((email == null || email.isEmpty) &&
          memberData['profile_id'] != null) {
        try {
          final profileData = await _client
              .from('profiles')
              .select('email')
              .eq('id', memberData['profile_id'] as String)
              .maybeSingle();
          email = profileData?['email'] as String?;
        } catch (_) {}
      }

      // Fetch loan count
      int totalLoans = 0;
      try {
        final loans = await _client
            .from('loans')
            .select('id')
            .eq('member_id', memberId)
            .eq('org_id', _orgId);
        totalLoans = (loans as List).length;
      } catch (_) {}

      // Fetch total savings
      double totalSavings = 0;
      try {
        final savings = await _client
            .from('savings_plans')
            .select('current_amount')
            .eq('member_id', memberId)
            .eq('org_id', _orgId);
        for (final s in savings as List) {
          totalSavings += (s['current_amount'] as num?)?.toDouble() ?? 0;
        }
      } catch (_) {}

      return {
        ...memberData,
        'email': email,
        'total_loans': totalLoans,
        'total_savings': totalSavings,
      };
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateMemberProfile(
    String memberId,
    Map<String, dynamic> data,
  ) async {
    try {
      // Only send fields that exist on the members table
      const allowedFields = {
        'full_name', 'father_name', 'phone', 'email', 'kyc_status',
        'area', 'village', 'address', 'aadhar_number', 'pan_number',
        'date_of_birth', 'gender', 'occupation', 'monthly_income',
      };
      final sanitized = <String, dynamic>{};
      for (final entry in data.entries) {
        if (allowedFields.contains(entry.key)) {
          sanitized[entry.key] = entry.value;
        }
      }
      if (sanitized.isEmpty) return true;

      await _client
          .from('members')
          .update(sanitized)
          .eq('id', memberId)
          .eq('org_id', _orgId);

      // Sync full_name / phone / email back to profiles table
      final profileSync = <String, dynamic>{};
      if (sanitized.containsKey('full_name')) profileSync['full_name'] = sanitized['full_name'];
      if (sanitized.containsKey('phone')) profileSync['phone'] = sanitized['phone'];
      if (sanitized.containsKey('email')) profileSync['email'] = sanitized['email'];
      if (profileSync.isNotEmpty) {
        try {
          // Get the profile_id from this member row
          final member = await _client
              .from('members')
              .select('profile_id')
              .eq('id', memberId)
              .maybeSingle();
          if (member != null && member['profile_id'] != null) {
            await _client
                .from('profiles')
                .update(profileSync)
                .eq('id', member['profile_id']);
          }
        } catch (_) {
          // Profile may not exist — that's fine
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}
