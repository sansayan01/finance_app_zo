import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../utils/json_normalize.dart';

/// Sentinel UUID used by the platform only for *opt-in* development flows.
/// IMPORTANT: never feed this into a Supabase query as an `org_id` filter on
/// real tenant data — it intentionally has no rows attached.
const String kDevFallbackOrgId = '00000000-0000-0000-0000-000000000001';

final Provider<String?> currentOrgIdProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.orgId;
});

/// Returns the current org id or throws if the user has no org assigned.
/// Use this in **any** code path that hits tenant-scoped tables — never
/// return a fallback UUID here, that caused cross-tenant data leaks.
final currentOrgIdOrThrowProvider = Provider<String>((ref) {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null || orgId.isEmpty) {
    throw StateError(
      'No organization is assigned to the current user. '
      'Assign an org_id to the user profile before calling tenant-scoped queries.',
    );
  }
  return orgId;
});

/// Safe variant — returns null if no org is assigned (works for superAdmin).
final currentOrgIdOrNullProvider = Provider<String?>((ref) {
  return ref.watch(currentOrgIdProvider);
});

final currentOrgProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return null;
  final client = ref.watch(supabaseClientProvider);
  final response =
      await client.from('organizations').select().eq('id', orgId).maybeSingle();
  return response != null ? normalizeMap(response) : null;
});
