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
            'id, full_name, phone, email, kyc_status, area, village, address, '
            'aadhar_number, pan_number, date_of_birth, gender, occupation, '
            'monthly_income, profile_id, created_at',
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
      await _client
          .from('members')
          .update(data)
          .eq('id', memberId)
          .eq('org_id', _orgId);
      return true;
    } catch (e) {
      return false;
    }
  }
}
