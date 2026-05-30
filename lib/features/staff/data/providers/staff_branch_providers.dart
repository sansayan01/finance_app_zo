import 'package:flutter/foundation.dart';
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
  final profile = await ref.watch(staffProfileProvider.future);
  final staffProfileId = profile?.id;
  try {
    final thirtyDaysAgo = DateTime.now()
        .subtract(const Duration(days: 30))
        .toIso8601String()
        .split('T')
        .first;

    // Step 1: Get loan IDs for this branch
    final loans = await client
        .from('loans')
        .select('id')
        .eq('branch_id', branchId);
    final loanIds =
        (loans as List).map((l) => l['id'] as String).toList();

    // Step 2: Get savings plan IDs for this branch (via members)
    final memberResp = await client
        .from('members')
        .select('id')
        .eq('org_id', orgId)
        .eq('branch_id', branchId);
    final memberIds =
        (memberResp as List).map((m) => m['id'] as String).toList();

    // Fetch loan collections and savings collections in parallel
    final loanCollectionsFuture = () async {
      if (loanIds.isEmpty) return <dynamic>[];
      var q = client
          .from('collections')
          .select('*')
          .eq('org_id', orgId)
          .inFilter('loan_id', loanIds)
          .gte('collection_date', thirtyDaysAgo);
      if (staffProfileId != null) {
        q = q.eq('staff_id', staffProfileId);
      }
      return await q.order('created_at', ascending: false);
    }();

    final savingsCollectionsFuture = () async {
      if (memberIds.isEmpty) return <dynamic>[];
      // Get savings plan IDs for these members
      final plans = await client
          .from('savings_plans')
          .select('id')
          .eq('org_id', orgId)
          .inFilter('member_id', memberIds);
      final planIds =
          (plans as List).map((p) => p['id'] as String).toList();
      if (planIds.isEmpty) return <dynamic>[];
      var sq = client
          .from('savings_collections')
          .select('*')
          .eq('org_id', orgId)
          .inFilter('savings_plan_id', planIds)
          .gte('collection_date', thirtyDaysAgo);
      if (staffProfileId != null) {
        sq = sq.eq('staff_id', staffProfileId);
      }
      return await sq.order('created_at', ascending: false);
    }();

    final results = await Future.wait([
      loanCollectionsFuture,
      savingsCollectionsFuture,
    ]);

    final loanCollections = results[0] as List<Map<String, dynamic>>;
    final savingsCollections = results[1] as List<Map<String, dynamic>>;

    // Merge and sort by created_at descending
    final allCollections = [
      ...List<Map<String, dynamic>>.from(loanCollections),
      ...List<Map<String, dynamic>>.from(savingsCollections),
    ];
    allCollections.sort((a, b) {
      final aDate = a['created_at'] ?? a['collection_date'] ?? '';
      final bDate = b['created_at'] ?? b['collection_date'] ?? '';
      return bDate.toString().compareTo(aDate.toString());
    });

    return allCollections;
  } catch (e) {
    debugPrint('Error loading collections: $e');
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
