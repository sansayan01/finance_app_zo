// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/providers/branch_manager_providers.dart';
import '../../data/providers/branch_scoped_providers.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/shimmer_card.dart';

class BranchReportsPage extends ConsumerWidget {
  const BranchReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchId = ref.watch(currentUserBranchIdProvider);

    return DefaultTabController(
      length: 4,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Branch Reports'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            bottom: TabBar(
              indicatorColor: Theme.of(context).colorScheme.primary,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              tabs: const [
                Tab(text: 'Collections'),
                Tab(text: 'Loans'),
                Tab(text: 'Members'),
                Tab(text: 'Staff'),
              ],
            ),
          ),
          body: branchId == null
              ? const Center(child: Text('No branch assigned'))
              : TabBarView(
                  children: [
                    _CollectionsReport(branchId: branchId),
                    _LoansReport(branchId: branchId),
                    _MembersReport(branchId: branchId),
                    _StaffReport(branchId: branchId),
                  ],
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// COLLECTIONS TAB
// ---------------------------------------------------------------------------

class _CollectionsReport extends ConsumerWidget {
  final String branchId;
  const _CollectionsReport({required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final statsAsync = ref.watch(branchCollectionStatsProvider(branchId));
    final weeklyTrendAsync =
        ref.watch(branchWeeklyCollectionTrendProvider(branchId));

    return statsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(
            3,
            (i) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: ShimmerCard(height: 72),
            ),
          ),
        ),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (stats) {
        final todayTotal = (stats['today_total'] as num?)?.toDouble() ?? 0;
        final todayCount = (stats['today_count'] as int?) ?? 0;
        final weekTotal = (stats['week_total'] as num?)?.toDouble() ?? 0;
        final weekCount = (stats['week_count'] as int?) ?? 0;
        final monthTotal = (stats['month_total'] as num?)?.toDouble() ?? 0;
        final monthCount = (stats['month_count'] as int?) ?? 0;

        // Build chart spots from real weekly data
        final weeklyData = weeklyTrendAsync.valueOrNull ?? List.filled(7, 0.0);
        final spots = <FlSpot>[];
        for (int i = 0; i < weeklyData.length; i++) {
          spots.add(FlSpot(i.toDouble(), weeklyData[i]));
        }
        final maxY =
            spots.fold<double>(0, (max, s) => s.y > max ? s.y : max);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Collection Trend (This Week)',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 180,
                  child: weeklyTrendAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    error: (_, __) => const Center(
                        child: Text('Unable to load trend')),
                    data: (_) => spots.every((s) => s.y == 0)
                        ? Center(
                            child: Text(
                              'No collections this week',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.5),
                                  ),
                            ),
                          )
                        : LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval:
                                    maxY > 0 ? (maxY / 4).ceilToDouble() : 1,
                                getDrawingHorizontalLine: (_) => FlLine(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withOpacity(0.1),
                                  strokeWidth: 1,
                                ),
                              ),
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 28,
                                    getTitlesWidget: (value, _) {
                                      final days = [
                                        'Mon',
                                        'Tue',
                                        'Wed',
                                        'Thu',
                                        'Fri',
                                        'Sat',
                                        'Sun'
                                      ];
                                      final idx = value.toInt();
                                      if (idx >= 0 && idx < days.length) {
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8),
                                          child: Text(
                                            days[idx],
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(fontSize: 10),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  isCurved: true,
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                  barWidth: 3,
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter: (spot, _, __, ___) =>
                                        FlDotCirclePainter(
                                      radius: 4,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      strokeWidth: 2,
                                      strokeColor: Theme.of(context)
                                          .colorScheme
                                          .surface,
                                    ),
                                  ),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.15),
                                        Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.0),
                                      ],
                                    ),
                                  ),
                                  spots: spots,
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 24),
              // Summary cards with real data
              _CollectionSummaryCard(
                title: 'Today',
                amount: currencyFormat.format(todayTotal),
                count: todayCount,
                icon: Icons.today,
                color: Theme.of(context).colorScheme.primary,
              ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.05),
              const SizedBox(height: 10),
              _CollectionSummaryCard(
                title: 'This Week',
                amount: currencyFormat.format(weekTotal),
                count: weekCount,
                icon: Icons.date_range,
                color: Theme.of(context).colorScheme.tertiary,
              ).animate().fadeIn(duration: 300.ms, delay: 150.ms).slideY(begin: 0.05),
              const SizedBox(height: 10),
              _CollectionSummaryCard(
                title: 'This Month',
                amount: currencyFormat.format(monthTotal),
                count: monthCount,
                icon: Icons.calendar_month,
                color: Theme.of(context).colorScheme.secondary,
              ).animate().fadeIn(duration: 300.ms, delay: 200.ms).slideY(begin: 0.05),
            ],
          ),
        );
      },
    );
  }
}

class _CollectionSummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final int count;
  final IconData icon;
  final Color color;

  const _CollectionSummaryCard({
    required this.title,
    required this.amount,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                ),
                const SizedBox(height: 2),
                Text(
                  amount,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count txns',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LOANS TAB
// ---------------------------------------------------------------------------

class _LoansReport extends ConsumerWidget {
  final String branchId;
  const _LoansReport({required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final loanAsync = ref.watch(branchLoanSummaryProvider(branchId));

    return loanAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(
            4,
            (i) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: ShimmerCard(height: 80),
            ),
          ),
        ),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (summary) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _LoanStatCard(
              title: 'Active Loans',
              value: '${summary.activeLoans}',
              subtitle: 'of ${summary.totalLoans} total',
              icon: Icons.account_balance,
              color: Colors.blue,
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05),
            const SizedBox(height: 10),
            _LoanStatCard(
              title: 'Total Disbursed',
              value: currencyFormat.format(summary.totalDisbursed),
              subtitle: '${summary.totalLoans} loans',
              icon: Icons.payments,
              color: Colors.green,
            ).animate().fadeIn(duration: 300.ms, delay: 50.ms).slideY(begin: 0.05),
            const SizedBox(height: 10),
            _LoanStatCard(
              title: 'Outstanding Balance',
              value: currencyFormat.format(summary.totalOutstanding),
              subtitle: 'PAR ${summary.parPercentage.toStringAsFixed(1)}%',
              icon: Icons.account_balance_wallet,
              color: Colors.orange,
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.05),
            const SizedBox(height: 10),
            _LoanStatCard(
              title: 'Defaulted Loans',
              value: '${summary.defaultLoans}',
              subtitle: currencyFormat.format(summary.overdueAmount),
              icon: Icons.warning_amber,
              color: Colors.red,
            ).animate().fadeIn(duration: 300.ms, delay: 150.ms).slideY(begin: 0.05),
          ],
        ),
      ),
    );
  }
}

class _LoanStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _LoanStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                ),
              ],
            ),
          ),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MEMBERS TAB
// ---------------------------------------------------------------------------

class _MembersReport extends ConsumerWidget {
  final String branchId;
  const _MembersReport({required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberAsync = ref.watch(branchMemberCountProvider(branchId));

    return memberAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(
            3,
            (i) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: ShimmerCard(height: 80),
            ),
          ),
        ),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (memberData) {
        final total = (memberData['total'] as int?) ?? 0;
        final active = (memberData['active'] as int?) ?? 0;
        final newThisMonth = (memberData['new_this_month'] as int?) ?? 0;
        final inactive = (memberData['inactive'] as int?) ?? 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _MemberStatCard(
                title: 'Total Members',
                value: '$total',
                subtitle: '$active active',
                icon: Icons.group,
                color: Colors.blue,
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05),
              const SizedBox(height: 10),
              _MemberStatCard(
                title: 'Active Members',
                value: '$active',
                subtitle:
                    total > 0 ? '${(active / total * 100).toStringAsFixed(0)}% of total' : '0%',
                icon: Icons.person,
                color: Colors.green,
              ).animate().fadeIn(duration: 300.ms, delay: 50.ms).slideY(begin: 0.05),
              const SizedBox(height: 10),
              _MemberStatCard(
                title: 'New This Month',
                value: '$newThisMonth',
                subtitle: '$inactive inactive',
                icon: Icons.person_add,
                color: Colors.purple,
              ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.05),
            ],
          ),
        );
      },
    );
  }
}

class _MemberStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MemberStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                ),
              ],
            ),
          ),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// STAFF TAB (kept real — existing provider)
// ---------------------------------------------------------------------------

class _StaffReport extends ConsumerWidget {
  final String branchId;
  const _StaffReport({required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performanceAsync = ref.watch(
      staffPerformanceProvider((branchId, null, null)),
    );

    return performanceAsync.when(
      data: (performance) {
        if (performance.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline,
                    size: 48,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.3)),
                const SizedBox(height: 12),
                Text(
                  'No staff data yet',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5),
                      ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: performance.length,
          itemBuilder: (context, index) {
            final staff = performance[index];
            final name = staff['name'] as String? ?? 'Unknown';
            final efficiency = staff['efficiency'] ?? 0;
            final collected = staff['collected'] ?? 0;

            return GlassCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Efficiency: $efficiency%',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.6),
                              ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹$collected',
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      Text(
                        'Collected',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.5),
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(
                    duration: 300.ms,
                    delay: Duration(milliseconds: index * 50))
                .slideX(begin: 0.05);
          },
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(
            4,
            (i) => const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: ShimmerCard(height: 72),
            ),
          ),
        ),
      ),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }
}
