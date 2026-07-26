import 'package:equatable/equatable.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Advanced Analytics Engine — typed models
/// Complements the existing `analytics_page` demo with deeper, tenant-scoped
/// aggregation: agent performance, PAR buckets, branch comparison, cohort
/// retention, monthly trends and signup→activation funnels.
/// ─────────────────────────────────────────────────────────────────────────

/// Collection-agent performance leaderboard entry.
class AgentLeaderboardEntry extends Equatable {
  final String staffId;
  final String name;
  final String? branchId;
  final int collectionsCount;
  final double amountCollected;
  final double amountExpected;
  final double efficiency; // 0-100
  final int activeStreak;

  const AgentLeaderboardEntry({
    required this.staffId,
    required this.name,
    this.branchId,
    this.collectionsCount = 0,
    this.amountCollected = 0,
    this.amountExpected = 0,
    this.efficiency = 0,
    this.activeStreak = 0,
  });

  @override
  List<Object?> get props => [
        staffId,
        name,
        branchId,
        collectionsCount,
        amountCollected,
        amountExpected,
        efficiency,
        activeStreak,
      ];
}

/// A single PAR (Portfolio At Risk) bucket by days-past-due.
class ParBucket extends Equatable {
  final String label; // e.g. "PAR 1-30", "PAR 31-60", "PAR 60+"
  final int loanCount;
  final double outstanding;

  const ParBucket({
    required this.label,
    this.loanCount = 0,
    this.outstanding = 0,
  });

  @override
  List<Object?> get props => [label, loanCount, outstanding];
}

/// Side-by-side branch performance for comparison.
class BranchComparison extends Equatable {
  final String branchId;
  final String name;
  final double collections;
  final int activeMembers;
  final int activeLoans;
  final double collectionEfficiency;

  const BranchComparison({
    required this.branchId,
    required this.name,
    this.collections = 0,
    this.activeMembers = 0,
    this.activeLoans = 0,
    this.collectionEfficiency = 0,
  });

  @override
  List<Object?> get props => [
        branchId,
        name,
        collections,
        activeMembers,
        activeLoans,
        collectionEfficiency,
      ];
}

/// Monthly aggregate of collected vs expected amount.
class MonthlyTrendPoint extends Equatable {
  final DateTime month;
  final double collected;
  final double expected;
  final int collectionsCount;

  const MonthlyTrendPoint({
    required this.month,
    this.collected = 0,
    this.expected = 0,
    this.collectionsCount = 0,
  });

  @override
  List<Object?> get props => [month, collected, expected, collectionsCount];
}

/// Member cohort retention: members onboarded in [cohortMonth] and still
/// active N months later.
class CohortRetention extends Equatable {
  final DateTime cohortMonth;
  final int cohortSize;
  final List<double> retentionByMonth; // index 0 = month 0 (100%), then decay

  const CohortRetention({
    required this.cohortMonth,
    this.cohortSize = 0,
    this.retentionByMonth = const [],
  });

  @override
  List<Object?> get props => [cohortMonth, cohortSize, retentionByMonth];
}

/// A funnel milestone for signup → activation analysis.
class FunnelMilestone extends Equatable {
  final String key; // 'signup' | 'org_created' | 'first_collection' | 'active_30d'
  final String label;
  final int count;
  final double conversionFromPrevious; // 0-100

  const FunnelMilestone({
    required this.key,
    required this.label,
    this.count = 0,
    this.conversionFromPrevious = 0,
  });

  @override
  List<Object?> get props => [key, label, count, conversionFromPrevious];
}

/// Aggregate container returned by [AnalyticsEngine.loadAll].
class AnalyticsEngineResult extends Equatable {
  final List<AgentLeaderboardEntry> leaderboard;
  final List<ParBucket> parBuckets;
  final List<BranchComparison> branches;
  final List<MonthlyTrendPoint> monthlyTrend;
  final List<CohortRetention> cohorts;
  final List<FunnelMilestone> funnel;
  final DateTime computedAt;

  const AnalyticsEngineResult({
    this.leaderboard = const [],
    this.parBuckets = const [],
    this.branches = const [],
    this.monthlyTrend = const [],
    this.cohorts = const [],
    this.funnel = const [],
    required this.computedAt,
  });

  @override
  List<Object?> get props => [
        leaderboard,
        parBuckets,
        branches,
        monthlyTrend,
        cohorts,
        funnel,
        computedAt,
      ];
}
