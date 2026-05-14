import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../providers/supabase_provider.dart';

final Provider<String?> currentOrgIdProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.orgId;
});

final currentOrgIdOrThrowProvider = Provider<String>((ref) {
  final orgId = ref.watch(currentOrgIdProvider);
  return orgId ?? '00000000-0000-0000-0000-000000000001';
});

final currentOrgProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return null;
  final client = ref.watch(supabaseClientProvider);
  final response = await client.from('organizations').select().eq('id', orgId).maybeSingle();
  return response;
});

/// Checks if mandatory setup steps are complete:
/// org has at least one branch OR at least one staff profile (manager/agent).
/// Used by router redirect to keep showing wizard until done.
final setupCompleteProvider = FutureProvider<bool>((ref) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return false;
  final client = ref.watch(supabaseClientProvider);
  try {
    final branches = await client.from('branches').select('id').eq('org_id', orgId).limit(1);
    if (branches.isNotEmpty) return true;
    final staff = await client.from('profiles').select('id').eq('org_id', orgId).inFilter('role', ['manager', 'collectionAgent']).limit(1);
    return staff.isNotEmpty;
  } catch (_) {
    return false;
  }
});
