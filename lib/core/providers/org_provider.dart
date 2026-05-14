import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// Whether at least one branch manager exists for the org.
/// Hides Quick Setup tile once a manager is created.
final hasBranchManagerProvider = FutureProvider<bool>((ref) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return false;
  final client = ref.watch(supabaseClientProvider);
  try {
    final result = await client.from('profiles').select('id').eq('org_id', orgId).eq('role', 'manager').limit(1);
    return (result as List).isNotEmpty;
  } catch (_) {
    return false;
  }
});

/// Checks if setup is complete. Uses SharedPreferences flag + DB fallback.
final setupCompleteProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('wizard_completed') == true) return true;

  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return false;
  final client = ref.watch(supabaseClientProvider);
  try {
    final result = await client.rpc('check_setup_complete');
    if (result is List && result.isNotEmpty) {
      final row = result[0];
      if (row is Map) return row['is_complete'] == true;
      return row == true;
    }
    if (result is Map) return result['is_complete'] == true;
    return result == true;
  } catch (_) {
    return false;
  }
});
