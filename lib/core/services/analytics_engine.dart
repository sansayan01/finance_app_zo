import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import 'package:microflow_pro/core/providers/org_provider.dart';
import 'package:microflow_pro/core/services/analytics_service.dart';
import 'package:microflow_pro/features/analytics/data/models/analytics_engine_models.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// AnalyticsEngine
///
/// Tenant-scoped advanced analytics computed directly from Supabase via
/// aggregate/select queries. Mirrors the project's service pattern
/// (plain class, async methods, try/catch + debugPrint, no-op safe).
///
/// It also emits PostHog funnel/behavior events so the marketing side can
/// build signup→org_create→first_collection→active funnels.
/// ─────────────────────────────────────────────────────────────────────────
class AnalyticsEngine {
  final SupabaseClient _client;
  final String _orgId;

  AnalyticsEngine(this._client, this._orgId);

  /// Factory used by the Riverpod provider.
  factory AnalyticsEngine.fromRef(Ref ref) {
    final client = ref.watch(supabaseClientProvider);
    final orgId = ref.watch(currentOrgIdOrThrowProvider);
    return AnalyticsEngine(client, orgId);
  }

  // ── Collection-agent leaderboard ────────────────────────────────────────
  Future<List<AgentLeaderboardEntry>> agentLeaderboard({int months = 1}) async {
    try {
      final since = DateTime.now().subtract(Duration(days: 30 * months));
      final rows = await _client
          .from('collections')
          .select('staff_id, amount_collected, collection_date')
          .eq('org_id', _orgId)
          .gte('collection_date', since.toIso8601String().split('T').first);

      final byAgent = <String, AgentLeaderboardEntry>{};
      for (final r in rows) {
        final staffId = (r['staff_id'] as String?) ?? 'unknown';
        final entry = byAgent.putIfAbsent(
          staffId,
          () => AgentLeaderboardEntry(staffId: staffId, name: staffId),
        );
        byAgent[staffId] = AgentLeaderboardEntry(
          staffId: entry.staffId,
          name: entry.name,
          collectionsCount: entry.collectionsCount + 1,
          amountCollected: entry.amountCollected + _toDouble(r['amount_collected']),
        );
      }

      // Resolve agent names from staff_profiles / profiles.
      await _resolveAgentNames(byAgent);

      final list = byAgent.values.toList()
        ..sort((a, b) => b.amountCollected.compareTo(a.amountCollected));
      return list;
    } catch (e) {
      debugPrint('⚠️ AnalyticsEngine.agentLeaderboard failed: $e');
      return [];
    }
  }

  Future<void> _resolveAgentNames(
      Map<String, AgentLeaderboardEntry> byAgent) async {
    if (byAgent.isEmpty) return;
    try {
      final ids = byAgent.keys.where((k) => k != 'unknown').toList();
      if (ids.isEmpty) return;
      final profiles = await _client
          .from('profiles')
          .select('user_id, full_name')
          .eq('org_id', _orgId)
          .filter('user_id', 'in', '(${ids.join(',')})');
      for (final p in profiles) {
        final id = p['user_id'] as String;
        final name = (p['full_name'] as String?) ?? id;
        final entry = byAgent[id];
        if (entry != null) {
          byAgent[id] = AgentLeaderboardEntry(
            staffId: entry.staffId,
            name: name,
            branchId: entry.branchId,
            collectionsCount: entry.collectionsCount,
            amountCollected: entry.amountCollected,
            efficiency: entry.efficiency,
            activeStreak: entry.activeStreak,
          );
        }
      }
    } catch (_) {
      // Names stay as ids — non-fatal.
    }
  }

  // ── PAR bucket analysis (days past due) ─────────────────────────────────
  Future<List<ParBucket>> parBuckets() async {
    try {
      final rows = await _client
          .from('loans')
          .select('outstanding_balance, status, updated_at')
          .eq('org_id', _orgId)
          .neq('status', 'closed');
      final buckets = <String, ParBucket>{
        'PAR 1-30': const ParBucket(label: 'PAR 1-30'),
        'PAR 31-60': const ParBucket(label: 'PAR 31-60'),
        'PAR 60+': const ParBucket(label: 'PAR 60+'),
      };
      for (final r in rows) {
        final bal = _toDouble(r['outstanding_balance']);
        if (bal <= 0) continue;
        final bucket = _parLabel(r);
        if (bucket == null) continue;
        final prev = buckets[bucket]!;
        buckets[bucket] = ParBucket(
          label: prev.label,
          loanCount: prev.loanCount + 1,
          outstanding: prev.outstanding + bal,
        );
      }
      return buckets.values.toList();
    } catch (e) {
      debugPrint('⚠️ AnalyticsEngine.parBuckets failed: $e');
      return [];
    }
  }

  String? _parLabel(Map<String, dynamic> loan) {
    // Without a reliable due_date here we bucket by status hints; loans table
    // carries status. We treat anything non-active/non-pending as risk.
    final status = (loan['status'] as String? ?? '').toLowerCase();
    if (status == 'overdue' || status == 'defaulted') return 'PAR 60+';
    if (status == 'delayed') return 'PAR 31-60';
    if (status == 'active') return 'PAR 1-30';
    return null;
  }

  // ── Branch comparison ───────────────────────────────────────────────────
  Future<List<BranchComparison>> branchComparison() async {
    try {
      final branches = await _client
          .from('branches')
          .select('id, name')
          .eq('org_id', _orgId);
      final out = <BranchComparison>[];
      for (final b in branches) {
        final branchId = b['id'] as String;
        final name = (b['name'] as String?) ?? branchId;
        final cols = await _client
            .from('collections')
            .select('amount_collected')
            .eq('org_id', _orgId)
            .eq('branch_id', branchId);
        final members = await _client
            .from('members')
            .select('id')
            .eq('org_id', _orgId)
            .eq('branch_id', branchId)
            .eq('status', 'active')
            .count();
        final loans = await _client
            .from('loans')
            .select('id')
            .eq('org_id', _orgId)
            .eq('branch_id', branchId)
            .eq('status', 'active')
            .count();
        final collected = (cols as List)
            .fold<double>(0, (s, c) => s + _toDouble(c['amount_collected']));
        out.add(BranchComparison(
          branchId: branchId,
          name: name,
          collections: collected,
          activeMembers: members.count,
          activeLoans: loans.count,
        ));
      }
      out.sort((a, b) => b.collections.compareTo(a.collections));
      return out;
    } catch (e) {
      debugPrint('⚠️ AnalyticsEngine.branchComparison failed: $e');
      return [];
    }
  }

  // ── Monthly collection trend (last 6 months) ────────────────────────────
  Future<List<MonthlyTrendPoint>> monthlyTrend({int months = 6}) async {
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month - (months - 1), 1);
      final rows = await _client
          .from('collections')
          .select('amount_collected, amount_expected, collection_date')
          .eq('org_id', _orgId)
          .gte('collection_date', start.toIso8601String().split('T').first);

      final Map<DateTime, MonthlyTrendPoint> map = {};
      for (int i = 0; i < months; i++) {
        final m = DateTime(now.year, now.month - i, 1);
        map[m] = MonthlyTrendPoint(month: m);
      }
      for (final r in rows) {
        final dateStr = (r['collection_date'] as String?)?.split('T').first;
        if (dateStr == null) continue;
        final d = DateTime.tryParse(dateStr);
        if (d == null) continue;
        final key = DateTime(d.year, d.month, 1);
        final prev = map[key];
        if (prev == null) continue;
        map[key] = MonthlyTrendPoint(
          month: prev.month,
          collected: prev.collected + _toDouble(r['amount_collected']),
          expected: prev.expected + _toDouble(r['amount_expected']),
          collectionsCount: prev.collectionsCount + 1,
        );
      }
      final list = map.values.toList()
        ..sort((a, b) => a.month.compareTo(b.month));
      return list;
    } catch (e) {
      debugPrint('⚠️ AnalyticsEngine.monthlyTrend failed: $e');
      return [];
    }
  }

  // ── Member cohort retention (last 6 cohorts) ────────────────────────────
  Future<List<CohortRetention>> cohortRetention({int cohorts = 6}) async {
    try {
      final now = DateTime.now();
      final out = <CohortRetention>[];
      for (int i = cohorts - 1; i >= 0; i--) {
        final cohortStart = DateTime(now.year, now.month - i, 1);
        final cohortEnd =
            DateTime(now.year, now.month - i + 1, 1).subtract(const Duration(days: 1));
        final cohort = await _client
            .from('members')
            .select('id')
            .eq('org_id', _orgId)
            .gte('created_at', cohortStart.toIso8601String())
            .lte('created_at', cohortEnd.toIso8601String())
            .count();
        final size = cohort.count;
        if (size == 0) continue;

        // Active members from this cohort, measured at month offsets 0..i
        final retention = <double>[];
        for (int m = 0; m <= i; m++) {
          final asOf = DateTime(now.year, now.month - i + m + 1, 1)
              .subtract(const Duration(days: 1));
          final active = await _client
              .from('members')
              .select('id')
              .eq('org_id', _orgId)
              .gte('created_at', cohortStart.toIso8601String())
              .lte('created_at', cohortEnd.toIso8601String())
              .eq('status', 'active')
              .lte('created_at', asOf.toIso8601String())
              .count();
          retention.add(active.count / size * 100);
        }
        out.add(CohortRetention(
          cohortMonth: cohortStart,
          cohortSize: size,
          retentionByMonth: retention,
        ));
      }
      return out;
    } catch (e) {
      debugPrint('⚠️ AnalyticsEngine.cohortRetention failed: $e');
      return [];
    }
  }

  // ── Signup → activation funnel ──────────────────────────────────────────
  Future<List<FunnelMilestone>> activationFunnel() async {
    try {
      final signups = await _client
          .from('profiles')
          .select('id')
          .eq('org_id', _orgId)
          .count();
      final orgs = await _client
          .from('organizations')
          .select('id')
          .eq('id', _orgId)
          .count();
      final firstCol = await _client
          .from('collections')
          .select('id')
          .eq('org_id', _orgId)
          .count();

      final signupCount = signups.count;
      final orgCount = orgs.count;
      final collectionCount = firstCol.count;

      final funnel = <FunnelMilestone>[
        _milestone('signup', 'Signed up', signupCount, null),
        _milestone('org_created', 'Org created', orgCount, signupCount),
        _milestone('first_collection', 'First collection', collectionCount, orgCount),
      ];
      return funnel;
    } catch (e) {
      debugPrint('⚠️ AnalyticsEngine.activationFunnel failed: $e');
      return [];
    }
  }

  FunnelMilestone _milestone(
      String key, String label, int count, int? prev) {
    final conv = (prev != null && prev > 0) ? (count / prev * 100) : 100.0;
    return FunnelMilestone(
        key: key, label: label, count: count, conversionFromPrevious: conv);
  }

  // ── Combined load ───────────────────────────────────────────────────────
  Future<AnalyticsEngineResult> loadAll() async {
    final results = await Future.wait([
      agentLeaderboard(),
      parBuckets(),
      branchComparison(),
      monthlyTrend(),
      cohortRetention(),
      activationFunnel(),
    ]);
    return AnalyticsEngineResult(
      leaderboard: results[0] as List<AgentLeaderboardEntry>,
      parBuckets: results[1] as List<ParBucket>,
      branches: results[2] as List<BranchComparison>,
      monthlyTrend: results[3] as List<MonthlyTrendPoint>,
      cohorts: results[4] as List<CohortRetention>,
      funnel: results[5] as List<FunnelMilestone>,
      computedAt: DateTime.now(),
    );
  }

  // ── PostHog funnel event helpers (marketing side) ───────────────────────
  void trackFunnelMilestone(String milestone, Map<String, Object> props) {
    analytics.track('funnel_$milestone', {'org_id': _orgId, ...props});
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
