import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/org_invitation_model.dart';

class InvitationRepository {
  final SupabaseClient _client;

  InvitationRepository(this._client);

  /// Create a new invitation
  Future<OrgInvitationModel> createInvitation({
    required String orgId,
    required String email,
    required String role,
    String? branchId,
    String? message,
  }) async {
    final response = await _client.rpc(
      'create_invitation',
      params: {
        'p_org_id': orgId,
        'p_email': email,
        'p_role': role,
        'p_branch_id': branchId,
        'p_message': message,
      },
    );

    // Fetch the created invitation
    final invitation = await _client
        .from('org_invitations')
        .select()
        .eq('id', response as String)
        .single();

    return OrgInvitationModel.fromJson(invitation);
  }

  /// Get invitation by token
  Future<OrgInvitationModel?> getInvitationByToken(String token) async {
    final response = await _client
        .from('org_invitations')
        .select('''
          *,
          org:organizations(name),
          inviter:profiles!org_invitations_invited_by_fkey(full_name)
        ''')
        .eq('token', token)
        .maybeSingle();

    if (response == null) return null;
    return OrgInvitationModel.fromJson(response);
  }

  /// Get all invitations for an org
  Future<List<OrgInvitationModel>> getOrgInvitations(
    String orgId, {
    String? status,
    int limit = 50,
  }) async {
    var query = _client
        .from('org_invitations')
        .select()
        .eq('org_id', orgId)
        .order('created_at', ascending: false)
        .limit(limit);

    if (status != null) {
      query = query.eq('status', status);
    }

    final response = await query;
    return response
        .map<OrgInvitationModel>((json) => OrgInvitationModel.fromJson(json))
        .toList();
  }

  /// Get pending invitations count
  Future<int> getPendingCount(String orgId) async {
    final response = await _client
        .from('org_invitations')
        .select('id')
        .eq('org_id', orgId)
        .eq('status', 'pending');

    return response.length;
  }

  /// Accept invitation
  Future<Map<String, dynamic>> acceptInvitation({
    required String token,
    String? fullName,
  }) async {
    final response = await _client.rpc(
      'accept_invitation',
      params: {
        'p_token': token,
        'p_full_name': fullName,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  /// Revoke invitation
  Future<bool> revokeInvitation(String invitationId) async {
    final response = await _client.rpc(
      'revoke_invitation',
      params: {'p_invitation_id': invitationId},
    );

    return response as bool;
  }

  /// Resend invitation
  Future<bool> resendInvitation(String invitationId) async {
    final response = await _client.rpc(
      'resend_invitation',
      params: {'p_invitation_id': invitationId},
    );

    return response as bool;
  }

  /// Get invitation stats for org
  Future<Map<String, int>> getInvitationStats(String orgId) async {
    final response = await _client
        .from('org_invitations')
        .select('status')
        .eq('org_id', orgId);

    final stats = <String, int>{
      'pending': 0,
      'accepted': 0,
      'expired': 0,
      'revoked': 0,
    };

    for (final item in response) {
      final status = item['status'] as String? ?? 'pending';
      stats[status] = (stats[status] ?? 0) + 1;
    }

    return stats;
  }
}
