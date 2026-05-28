import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/member_model.dart';

class MembersRepository {
  final SupabaseClient _client;
  final String _orgId;

  MembersRepository(this._client, this._orgId);

  Future<List<MemberModel>> getMembers({int limit = 50, String? query}) async {
    try {
      var request = _client.from('members').select('id, full_name, phone, member_id, kyc_status, status, created_at, branch_id').eq('org_id', _orgId);

      if (query != null && query.isNotEmpty) {
        request = request.or(
            'full_name.ilike.%$query%,phone.ilike.%$query%,member_id.ilike.%$query%');
      }

      final response =
          await request.order('created_at', ascending: false).limit(limit);

      return (response as List)
          .map((json) => MemberModel.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<MemberSummary> getMemberSummary() async {
    try {
      final response = await _client
          .from('members')
          .select('id, kyc_status')
          .eq('org_id', _orgId);
      final members = response as List;

      return MemberSummary(
        totalMembers: members.length,
        activeMembers:
            members.where((m) => m['kyc_status'] == 'verified').length,
        pendingKYC: members.where((m) => m['kyc_status'] == 'pending').length,
      );
    } catch (e) {
      return MemberSummary(totalMembers: 0, activeMembers: 0, pendingKYC: 0);
    }
  }

  Future<MemberModel> createMember(MemberModel member) async {
    final json = member.toJson();
    json['org_id'] = _orgId;
    final response =
        await _client.from('members').insert(json).select().single();
    return MemberModel.fromJson(response);
  }
}
