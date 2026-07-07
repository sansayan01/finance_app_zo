import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/supabase_provider.dart';
import '../repositories/activity_log_repository.dart';

/// Base activity log repository — org-scoping is handled at call time
/// via [orgScopedActivityLogRepositoryProvider] to avoid circular
/// dependency (authRepositoryProvider → activityLogRepositoryProvider
/// → currentOrgIdProvider → currentUserProvider → authProvider → authRepositoryProvider).
final Provider<ActivityLogRepository> activityLogRepositoryProvider =
    Provider<ActivityLogRepository>((ref) {
  return ActivityLogRepository(ref.watch(supabaseClientProvider));
});

/// Org-scoped activity log repository for read paths (fetchLogs, etc.).
/// Pass this provider to code that needs tenant-scoped log reads.
final Provider<ActivityLogRepository> orgScopedActivityLogRepositoryProvider =
    Provider<ActivityLogRepository>((ref) {
  // Intentionally does NOT depend on currentOrgIdProvider to avoid the
  // circular dependency above. Callers must provide orgId explicitly,
  // or the repo resolves it from the auth profile at runtime.
  return ActivityLogRepository(ref.watch(supabaseClientProvider));
});
