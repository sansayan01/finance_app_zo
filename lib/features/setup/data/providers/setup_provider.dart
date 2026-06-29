import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Whether the organization setup is complete.
///
/// The authoritative answer lives in `organizations.is_setup_complete`
/// (set by the `complete_org_setup` RPC when the wizard finishes). We
/// also fall back to the RPC `check_setup_complete()` so the route guard
/// in app_router and this provider can never disagree.
final setupCompleteProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);

  // Super admin doesn't need setup.
  if (user == null || user.role?.name == 'superAdmin') return true;

  // Only executiveAdmin is required to run the wizard.
  if (user.role?.name != 'executiveAdmin') return true;

  final orgId = user.orgId;
  if (orgId == null) return true;

  try {
    final client = Supabase.instance.client;

    // Authoritative check: server-side RPC returns the persisted flag.
    final rpcRows = await client.rpc('check_setup_complete');
    final flag = rpcRows;
    if (flag is List && flag.isNotEmpty) {
      final value = flag.first;
      if (value is Map && value['is_complete'] == true) return true;
      if (value == true) return true;
    }

    // Fallback: read the persisted flag directly so the route guard and
    // this provider can never disagree, even if the RPC changes shape.
    final org = await client
        .from('organizations')
        .select('is_setup_complete, address')
        .eq('id', orgId)
        .maybeSingle();

    if (org == null) return true;

    final isComplete = org['is_setup_complete'] == true;
    if (isComplete) return true;

    // Last-resort heuristic for orgs that haven't been marked complete yet
    // but already satisfy the historical conditions (so existing data
    // doesn't get bounced back into the wizard).
    final hasAddress = org['address'] is String &&
        (org['address'] as String).trim().isNotEmpty;
    if (!hasAddress) return false;

    final branches = await client
        .from('branches')
        .select('id')
        .eq('org_id', orgId)
        .limit(1);

    return (branches as List).isNotEmpty;
  } catch (_) {
    // On error, never block the user.
    return true;
  }
});
