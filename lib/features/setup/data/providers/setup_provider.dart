import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Whether the organization setup is complete.
/// Setup is complete when:
/// 1. The org has at least 1 branch
/// 2. The org has address filled in
final setupCompleteProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);

  // Super admin doesn't need setup
  if (user == null || user.role?.name == 'superAdmin') return true;

  // ExecutiveAdmin must complete setup
  if (user.role?.name != 'executiveAdmin') return true;

  final orgId = user.orgId;
  if (orgId == null) return true;

  try {
    final client = Supabase.instance.client;

    // Check if org has address filled
    final org = await client
        .from('organizations')
        .select('address')
        .eq('id', orgId)
        .maybeSingle();

    if (org == null || org['address'] == null || (org['address'] as String).isEmpty) {
      return false;
    }

    // Check if org has at least 1 branch
    final branches = await client
        .from('branches')
        .select('id')
        .eq('org_id', orgId)
        .limit(1);

    if ((branches as List).isEmpty) {
      return false;
    }

    return true;
  } catch (_) {
    return true; // On error, don't block the user
  }
});
