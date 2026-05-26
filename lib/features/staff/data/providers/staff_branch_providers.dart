import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import 'staff_providers.dart';

// =====================================================
// STAFF BRANCH ID — bridges staff profile to branch-scoped providers
// =====================================================

/// Returns the branch_id of the current logged-in staff agent.
/// Throws if the staff has no branch assigned.
final staffBranchIdProvider = FutureProvider<String?>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  return profile?.branchId;
});

/// Same but as a synchronous provider that returns null until loaded.
final currentStaffBranchIdProvider = Provider<String?>((ref) {
  final branchAsync = ref.watch(staffBranchIdProvider);
  return branchAsync.valueOrNull;
});

// =====================================================
// STAFF COLLECTION HISTORY — branch-scoped, optionally filtered by staff_id
// =====================================================

final staffCollectionHistoryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, branchId) async {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  try {
    final thirtyDaysAgo = DateTime.now()
        .subtract(const Duration(days: 30))
        .toIso8601String()
        .split('T')
        .first;

    final response = await client
        .from('collections')
        .select('''
          *,
          collector:staff_id!fk_collections_staff(full_name, id),
          loan:loan_id(id, amount, branch_id, loan_number, customer_id)
        ''')
        .eq('org_id', orgId)
        .gte('collection_date', thirtyDaysAgo)
        .order('created_at', ascending: false);

    final allCollections =
        List<Map<String, dynamic>>.from(response as List<dynamic>);
    // Filter to branch
    return allCollections.where((c) {
      final loan = c['loan'] as Map<String, dynamic>?;
      return loan?['branch_id'] == branchId;
    }).toList();
  } catch (e) {
    return [];
  }
});

// =====================================================
// STAFF TIMELINE — combined collections + transactions for the branch
// =====================================================

final staffTimelineProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, branchId) async {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  try {
    final thirtyDaysAgo = DateTime.now()
        .subtract(const Duration(days: 30))
        .toIso8601String()
        .split('T')
        .first;

    // Get staff IDs for this branch
    final staffResp = await client
        .from('profiles')
        .select('id')
        .eq('org_id', orgId)
        .eq('branch_id', branchId)
        .inFilter('role', ['manager', 'collectionAgent']);
    final staffIds =
        (staffResp as List<dynamic>).map((s) => s['id'] as String).toList();

    // Get member IDs for this branch
    final memberResp = await client
        .from('members')
        .select('id')
        .eq('org_id', orgId)
        .eq('branch_id', branchId);
    final memberIds =
        (memberResp as List<dynamic>).map((m) => m['id'] as String).toList();

    final allIds = [...staffIds, ...memberIds];
    if (allIds.isEmpty) return [];

    // Fetch recent transactions
    final response = await client
        .from('transactions')
        .select('*')
        .eq('org_id', orgId)
        .or(
            'staff_id.in.(${staffIds.join(",")}),member_id.in.(${memberIds.join(",")})')
        .gte('created_at', thirtyDaysAgo)
        .order('created_at', ascending: false)
        .limit(100);

    return List<Map<String, dynamic>>.from(response as List<dynamic>);
  } catch (e) {
    return [];
  }
});
