import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../models/org_invitation_model.dart';
import '../repositories/invitation_repository.dart';

// Repository provider
final invitationRepositoryProvider = Provider<InvitationRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return InvitationRepository(client);
});

// All org invitations
final orgInvitationsProvider = FutureProvider<List<OrgInvitationModel>>((ref) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return [];

  final repository = ref.watch(invitationRepositoryProvider);
  return repository.getOrgInvitations(orgId);
});

// Pending invitations
final pendingInvitationsProvider = FutureProvider<List<OrgInvitationModel>>((ref) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return [];

  final repository = ref.watch(invitationRepositoryProvider);
  return repository.getOrgInvitations(orgId, status: 'pending');
});

// Invitation stats
final invitationStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return {'pending': 0, 'accepted': 0, 'expired': 0, 'revoked': 0};

  final repository = ref.watch(invitationRepositoryProvider);
  return repository.getInvitationStats(orgId);
});

// Invitation by token (for accept page)
final invitationByTokenProvider = FutureProvider.family<OrgInvitationModel?, String>((ref, token) async {
  final repository = ref.watch(invitationRepositoryProvider);
  return repository.getInvitationByToken(token);
});

// Invitation actions notifier
class InvitationNotifier extends StateNotifier<AsyncValue<void>> {
  final InvitationRepository _repository;
  final Ref _ref;

  InvitationNotifier(this._repository, this._ref) : super(const AsyncValue.data(null));

  /// Create invitation
  Future<OrgInvitationModel?> createInvitation({
    required String email,
    required String role,
    String? branchId,
    String? message,
  }) async {
    state = const AsyncValue.loading();
    try {
      final orgId = _ref.read(currentOrgIdProvider);
      if (orgId == null) throw Exception('No organization selected');

      final invitation = await _repository.createInvitation(
        orgId: orgId,
        email: email,
        role: role,
        branchId: branchId,
        message: message,
      );

      _ref.invalidate(orgInvitationsProvider);
      _ref.invalidate(pendingInvitationsProvider);
      _ref.invalidate(invitationStatsProvider);
      state = const AsyncValue.data(null);
      return invitation;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Revoke invitation
  Future<bool> revokeInvitation(String invitationId) async {
    state = const AsyncValue.loading();
    try {
      final success = await _repository.revokeInvitation(invitationId);
      if (success) {
        _ref.invalidate(orgInvitationsProvider);
        _ref.invalidate(pendingInvitationsProvider);
        _ref.invalidate(invitationStatsProvider);
      }
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Resend invitation
  Future<bool> resendInvitation(String invitationId) async {
    state = const AsyncValue.loading();
    try {
      final success = await _repository.resendInvitation(invitationId);
      if (success) {
        _ref.invalidate(orgInvitationsProvider);
        _ref.invalidate(pendingInvitationsProvider);
      }
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Accept invitation (called from accept page)
  Future<Map<String, dynamic>?> acceptInvitation({
    required String token,
    String? fullName,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repository.acceptInvitation(
        token: token,
        fullName: fullName,
      );
      state = const AsyncValue.data(null);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Bulk create invitations
  Future<int> bulkCreateInvitations(List<InvitationRequest> requests) async {
    state = const AsyncValue.loading();
    try {
      final orgId = _ref.read(currentOrgIdProvider);
      if (orgId == null) throw Exception('No organization selected');

      int successCount = 0;
      for (final request in requests) {
        try {
          await _repository.createInvitation(
            orgId: orgId,
            email: request.email,
            role: request.role,
            branchId: request.branchId,
            message: request.message,
          );
          successCount++;
        } catch (_) {
          // Continue with next invitation
        }
      }

      _ref.invalidate(orgInvitationsProvider);
      _ref.invalidate(pendingInvitationsProvider);
      _ref.invalidate(invitationStatsProvider);
      state = const AsyncValue.data(null);
      return successCount;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return 0;
    }
  }
}

final invitationNotifierProvider = StateNotifierProvider<InvitationNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(invitationRepositoryProvider);
  return InvitationNotifier(repository, ref);
});

/// Helper class for bulk invitations
class InvitationRequest {
  final String email;
  final String role;
  final String? branchId;
  final String? message;

  const InvitationRequest({
    required this.email,
    required this.role,
    this.branchId,
    this.message,
  });
}
