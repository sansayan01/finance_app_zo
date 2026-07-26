import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/core/constants/app_colors.dart';
import 'package:microflow_pro/core/utils/formatters.dart';
import 'package:microflow_pro/core/widgets/glass_card.dart';
import 'package:microflow_pro/core/widgets/sparkline_chart.dart';
import 'package:microflow_pro/core/providers/analytics_engine_provider.dart';
import 'package:microflow_pro/features/analytics/data/models/analytics_engine_models.dart';

/// Advanced Analytics — deeper, tenant-scoped insights:
/// agent leaderboard, PAR buckets, branch comparison, monthly trend,
/// cohort retention and signup→activation funnel.
class AdvancedAnalyticsPage extends ConsumerWidget {
  const AdvancedAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final result = ref.watch(analyticsEngineResultProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Advanced Analytics'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load analytics: $e',
              style: TextStyle(color: theme.colorScheme.error)),
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionTitle('Collection Agent Leaderboard'),
            _LeaderboardCard(data.leaderboard),
            const SizedBox(height: 20),
            _SectionTitle('Portfolio At Risk (PAR)'),
            _ParCard(data.parBuckets),
            const SizedBox(height: 20),
            _SectionTitle('Branch Comparison'),
            _BranchCard(data.branches),
            const SizedBox(height: 20),
            _SectionTitle('Monthly Collection Trend'),
            _TrendCard(data.monthlyTrend),
            const SizedBox(height: 20),
            _SectionTitle('Member Cohort Retention'),
            _CohortCard(data.cohorts),
            const SizedBox(height: 20),
            _SectionTitle('Signup → Activation Funnel'),
            _FunnelCard(data.funnel),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  final List<AgentLeaderboardEntry> entries;
  const _LeaderboardCard(this.entries);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (entries.isEmpty) return const _EmptyCard();
    return GlassCard(
      child: Column(
        children: [
          for (int i = 0; i < entries.length; i++) ...[
            if (i > 0)
              Divider(color: theme.dividerColor.withValues(alpha: 0.1)),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text('${i + 1}',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold)),
              ),
              title: Text(entries[i].name),
              subtitle: Text('${entries[i].collectionsCount} collections'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(AppFormatters.formatCurrency(entries[i].amountCollected),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    '${entries[i].efficiency.toStringAsFixed(0)}% eff',
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ParCard extends StatelessWidget {
  final List<ParBucket> buckets;
  const _ParCard(this.buckets);
  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) return const _EmptyCard();
    final total = buckets.fold<double>(0, (s, b) => s + b.outstanding);
    return GlassCard(
      child: Column(
        children: [
          for (final b in buckets) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _parColor(b.label),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(b.label)),
                  Text('${b.loanCount} loans'),
                  const SizedBox(width: 12),
                  Text(
                    AppFormatters.formatCurrency(b.outstanding),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            if (total > 0)
              LinearProgressIndicator(
                value: b.outstanding / total,
                backgroundColor:
                    Theme.of(context).dividerColor.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(_parColor(b.label)),
              ),
          ],
        ],
      ),
    );
  }

  Color _parColor(String label) {
    if (label.contains('60')) return AppColors.error;
    if (label.contains('31')) return AppColors.warning;
    return AppColors.orange;
  }
}

class _BranchCard extends StatelessWidget {
  final List<BranchComparison> branches;
  const _BranchCard(this.branches);
  @override
  Widget build(BuildContext context) {
    if (branches.isEmpty) return const _EmptyCard();
    return GlassCard(
      child: Column(
        children: [
          for (final b in branches)
            ListTile(
              title: Text(b.name),
              subtitle: Text(
                  '${b.activeMembers} members · ${b.activeLoans} active loans'),
              trailing: Text(AppFormatters.formatCurrency(b.collections),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final List<MonthlyTrendPoint> trend;
  const _TrendCard(this.trend);
  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) return const _EmptyCard();
    final collected = trend.map((t) => t.collected).toList();
    final total = collected.fold<double>(0, (s, v) => s + v);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total collected (6 mo): ${AppFormatters.formatCurrency(total)}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SparklineChart(
            data: collected,
            color: AppColors.primary,
            height: 48,
          ),
        ],
      ),
    );
  }
}

class _CohortCard extends StatelessWidget {
  final List<CohortRetention> cohorts;
  const _CohortCard(this.cohorts);
  @override
  Widget build(BuildContext context) {
    if (cohorts.isEmpty) return const _EmptyCard();
    final theme = Theme.of(context);
    return GlassCard(
      child: Column(
        children: [
          for (final c in cohorts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: Text(
                      '${c.cohortMonth.month}/${c.cohortMonth.year % 100}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: c.retentionByMonth.map((r) {
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.mint
                                  .withValues(alpha: (r / 100).clamp(0.1, 1)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(r.toStringAsFixed(0),
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.white)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('n=${c.cohortSize}',
                      style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FunnelCard extends StatelessWidget {
  final List<FunnelMilestone> funnel;
  const _FunnelCard(this.funnel);
  @override
  Widget build(BuildContext context) {
    if (funnel.isEmpty) return const _EmptyCard();
    return GlassCard(
      child: Column(
        children: [
          for (final f in funnel)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(f.label,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${f.count}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: (f.conversionFromPrevious / 100).clamp(0, 1),
                    backgroundColor:
                        Theme.of(context).dividerColor.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(AppColors.accent),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${f.conversionFromPrevious.toStringAsFixed(0)}% from previous',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text('No data yet',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5))),
        ),
      ),
    );
  }
}
