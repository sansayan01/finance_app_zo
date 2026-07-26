import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/analytics_engine.dart';
import '../../features/analytics/data/models/analytics_engine_models.dart';

/// Provider exposing the tenant-scoped [AnalyticsEngine].
final analyticsEngineProvider = Provider<AnalyticsEngine>((ref) {
  return AnalyticsEngine.fromRef(ref);
});

/// Loads the full advanced-analytics result set for the current org.
final analyticsEngineResultProvider =
    FutureProvider.autoDispose<AnalyticsEngineResult>((ref) async {
  final engine = ref.watch(analyticsEngineProvider);
  return engine.loadAll();
});

/// Individual slices (so the page can show partial data as each resolves).
final agentLeaderboardProvider =
    FutureProvider.autoDispose<List<AgentLeaderboardEntry>>((ref) async {
  return ref.watch(analyticsEngineProvider).agentLeaderboard();
});

final parBucketsProvider =
    FutureProvider.autoDispose<List<ParBucket>>((ref) async {
  return ref.watch(analyticsEngineProvider).parBuckets();
});

final branchComparisonProvider =
    FutureProvider.autoDispose<List<BranchComparison>>((ref) async {
  return ref.watch(analyticsEngineProvider).branchComparison();
});

final monthlyTrendProvider =
    FutureProvider.autoDispose<List<MonthlyTrendPoint>>((ref) async {
  return ref.watch(analyticsEngineProvider).monthlyTrend();
});

final cohortRetentionProvider =
    FutureProvider.autoDispose<List<CohortRetention>>((ref) async {
  return ref.watch(analyticsEngineProvider).cohortRetention();
});

final activationFunnelProvider =
    FutureProvider.autoDispose<List<FunnelMilestone>>((ref) async {
  return ref.watch(analyticsEngineProvider).activationFunnel();
});
