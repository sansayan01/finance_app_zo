import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'new_user_provider.dart';

// =============================================================================
// ADMIN: AUDIT LOGS FOR ONE USER
// =============================================================================

class UserAuditQuery {
  final String profileId;
  final String? authUserId;
  const UserAuditQuery({required this.profileId, this.authUserId});

  @override
  bool operator ==(Object other) =>
      other is UserAuditQuery &&
      other.profileId == profileId &&
      other.authUserId == authUserId;

  @override
  int get hashCode => Object.hash(profileId, authUserId);
}

/// audit_logs entries that target the user (either as actor or as entity).
final userAuditLogsProvider = FutureProvider.family<List<Map<String, dynamic>>,
    UserAuditQuery>((ref, q) async {
  final repo = ref.watch(userRepositoryProvider);
  return repo.getAuditLogsForUser(
    profileId: q.profileId,
    authUserId: q.authUserId,
    limit: 100,
  );
});

// =============================================================================
// ADMIN: ADMIN NOTES FOR ONE USER
// =============================================================================

/// All admin notes attached to a profile, newest first (pinned first).
final adminNotesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, profileId) async {
  final repo = ref.watch(userRepositoryProvider);
  return repo.getAdminNotes(profileId);
});

// =============================================================================
// ADMIN: DATA EXPORTS FOR ONE USER
// =============================================================================

/// Recent data-export requests scoped to a single user.
final userDataExportsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, profileId) async {
  final repo = ref.watch(userRepositoryProvider);
  return repo.listUserDataExports(profileId);
});
