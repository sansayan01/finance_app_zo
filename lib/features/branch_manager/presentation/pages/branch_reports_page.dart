// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/providers/branch_manager_providers.dart';
import '../../data/providers/branch_scoped_providers.dart';

class BranchReportsPage extends ConsumerStatefulWidget {
  const BranchReportsPage({super.key});

  @override
  ConsumerState<BranchReportsPage> createState() => _BranchReportsPageState();
}

class _BranchReportsPageState extends ConsumerState<BranchReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authProvider).user;
    final branchId = user?.branchId;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF2F2F7),
      body: AuroraBackground(
        child: Column(
          children: [
            // ─── App Bar ───
            SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Branch Reports',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: Colors.white,
                        unselectedLabelColor:
                            isDark ? Colors.white54 : Colors.black54,
                        labelStyle: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                        unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 13),
                        tabs: const [
                          Tab(text: 'Collections'),
                          Tab(text: 'Loans'),
                          Tab(text: 'Members'),
                          Tab(text: 'Staff'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Tab Content ───
            if (branchId == null)
              const Expanded(
                child: Center(child: Text('No branch assigned')),
              )
            else
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _CollectionsTab(branchId: branchId),
                    _LoansTab(branchId: branchId),
                    _MembersTab(branchId: branchId),
                    _StaffTab(branchId: branchId),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// COLLECTIONS TAB
// ============================================================================

class _CollectionsTab extends ConsumerWidget {
  final String branchId;
  const _CollectionsTab({required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currencyFormat =
        NumberFormat.currency(symbol: '\u20B9', decimalDigits: 0);
    final statsAsync = ref.watch(branchCollectionStatsProvider(branchId));
    final weeklyAsync =
        ref.watch(branchWeeklyCollectionTrendProvider(branchId));

    return statsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: List.generate(
              3,
              (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: ShimmerCard(height: 100),
                  )),
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

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(branchCollectionStatsProvider(branchId));
            ref.invalidate(branchWeeklyCollectionTrendProvider(branchId));
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            children: [
              // ─── Hero Card ───
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, Color(0xFF6366F1)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.trending_up_rounded,
                            color: Colors.white70, size: 20),
                        const SizedBox(width: 10),
                        Text('This Week',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(currencyFormat.format(weekTotal),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1)),
                    const SizedBox(height: 4),
                    Text('$weekCount transactions',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13)),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),

              const SizedBox(height: 20),

              // ─── Weekly Trend Chart ───
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Collection Trend',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 160,
                      child: weeklyAsync.when(
                        loading: () => const Center(
                            child:
                                CircularProgressIndicator(strokeWidth: 2)),
                        error: (_, __) => const Center(
                            child: Text('Unable to load trend')),
                        data: (weeklyData) {
                          final spots = <FlSpot>[];
                          for (int i = 0; i < weeklyData.length; i++) {
                            spots.add(
                                FlSpot(i.toDouble(), weeklyData[i]));
                          }
                          final maxY = spots.fold<double>(
                              0, (m, s) => s.y > m ? s.y : m);

                          if (spots.every((s) => s.y == 0)) {
                            return Center(
                              child: Text('No collections this week',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(
                                          color: isDark
                                              ? Colors.white38
                                              : Colors.black38)),
                            );
                          }

                          return LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: maxY > 0
                                    ? (maxY / 4).ceilToDouble()
                                    : 1,
                                getDrawingHorizontalLine: (_) => FlLine(
                                  color: isDark
                                      ? Colors.white
                                          .withValues(alpha: 0.05)
                                      : Colors.black
                                          .withValues(alpha: 0.05),
                                  strokeWidth: 1,
                                ),
                              ),
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(),
                                topTitles: const AxisTitles(),
                                rightTitles: const AxisTitles(),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 28,
                                    getTitlesWidget: (value, _) {
                                      const days = [
                                        'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
                                      ];
                                      final idx = value.toInt();
                                      if (idx >= 0 && idx < days.length) {
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8),
                                          child: Text(days[idx],
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: isDark
                                                      ? Colors.white38
                                                      : Colors.black38)),
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
                                  spots: spots,
                                  isCurved: true,
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.primary,
                                      AppColors.accent
                                    ],
                                  ),
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter: (spot, _, __, ___) =>
                                        FlDotCirclePainter(
                                      radius: 4,
                                      color: AppColors.primary,
                                      strokeWidth: 2,
                                      strokeColor: isDark
                                          ? const Color(0xFF1C1C2E)
                                          : Colors.white,
                                    ),
                                  ),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        AppColors.primary
                                            .withValues(alpha: 0.2),
                                        AppColors.primary
                                            .withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              lineTouchData: LineTouchData(
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipItems: (spots) =>
                                      spots.map((spot) {
                                    return LineTooltipItem(
                                      currencyFormat.format(spot.y),
                                      const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05, end: 0),

              const SizedBox(height: 16),

              // ─── Summary Cards ───
              _summaryCard(theme, isDark, 'Today', currencyFormat.format(todayTotal),
                  '$todayCount txns', Icons.today_rounded, AppColors.primary),
              const SizedBox(height: 10),
              _summaryCard(theme, isDark, 'This Week', currencyFormat.format(weekTotal),
                  '$weekCount txns', Icons.date_range_rounded, AppColors.accent),
              const SizedBox(height: 10),
              _summaryCard(theme, isDark, 'This Month', currencyFormat.format(monthTotal),
                  '$monthCount txns', Icons.calendar_month_rounded, AppColors.success),

              const SizedBox(height: 16),

              // ─── Insight Box ───
              if (weekTotal > 0)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded,
                          color: AppColors.success, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Average daily collection: ${currencyFormat.format(weekTotal / 7)}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryCard(ThemeData theme, bool isDark, String title,
      String amount, String count, IconData icon, Color color) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white54 : Colors.black54)),
                const SizedBox(height: 2),
                Text(amount,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(count,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05, end: 0);
  }
}

// ============================================================================
// LOANS TAB
// ============================================================================

class _LoansTab extends ConsumerWidget {
  final String branchId;
  const _LoansTab({required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currencyFormat =
        NumberFormat.currency(symbol: '\u20B9', decimalDigits: 0);
    final loanAsync = ref.watch(branchLoanSummaryProvider(branchId));

    return loanAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: List.generate(
              4,
              (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: ShimmerCard(height: 100),
                  )),
        ),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (summary) {
        final active = summary.activeLoans.toDouble();
        final closed = (summary.totalLoans - summary.activeLoans - summary.defaultLoans)
            .toDouble()
            .clamp(0.0, double.infinity);
        final defaulted = summary.defaultLoans.toDouble();

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(branchLoanSummaryProvider(branchId)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            children: [
              // ─── PAR Gauge ───
              GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text('Portfolio at Risk',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              startDegreeOffset: -90,
                              centerSpaceRadius: 55,
                              sectionsSpace: 0,
                              sections: [
                                PieChartSectionData(
                                  value: summary.parPercentage.clamp(0, 100),
                                  color: summary.parPercentage > 15
                                      ? AppColors.error
                                      : summary.parPercentage > 5
                                          ? AppColors.warning
                                          : AppColors.success,
                                  radius: 14,
                                  showTitle: false,
                                ),
                                PieChartSectionData(
                                  value: (100 - summary.parPercentage.clamp(0, 100)).toDouble(),
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.black.withValues(alpha: 0.04),
                                  radius: 14,
                                  showTitle: false,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${summary.parPercentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: summary.parPercentage > 15
                                      ? AppColors.error
                                      : summary.parPercentage > 5
                                          ? AppColors.warning
                                          : AppColors.success,
                                ),
                              ),
                              Text(
                                summary.parPercentage > 15
                                    ? 'Critical'
                                    : summary.parPercentage > 5
                                        ? 'Watch'
                                        : 'Healthy',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: summary.parPercentage > 15
                                      ? AppColors.error
                                      : summary.parPercentage > 5
                                          ? AppColors.warning
                                          : AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),

              const SizedBox(height: 16),

              // ─── Loan Status Donut ───
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Loan Status Distribution',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: PieChart(
                            PieChartData(
                              centerSpaceRadius: 25,
                              sectionsSpace: 2,
                              sections: [
                                PieChartSectionData(
                                  value: active > 0 ? active : 1,
                                  color: AppColors.primary,
                                  radius: 16,
                                  showTitle: false,
                                ),
                                PieChartSectionData(
                                  value: closed,
                                  color: AppColors.success,
                                  radius: 16,
                                  showTitle: false,
                                ),
                                PieChartSectionData(
                                  value: defaulted,
                                  color: AppColors.error,
                                  radius: 16,
                                  showTitle: false,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _donutLegend('Active', summary.activeLoans,
                                  AppColors.primary),
                              const SizedBox(height: 10),
                              _donutLegend(
                                  'Closed', closed.toInt(), AppColors.success),
                              const SizedBox(height: 10),
                              _donutLegend('Defaulted', summary.defaultLoans,
                                  AppColors.error),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05, end: 0),

              const SizedBox(height: 16),

              // ─── Key Metrics ───
              _metricCard(theme, isDark, 'Total Disbursed',
                  currencyFormat.format(summary.totalDisbursed), '${summary.totalLoans} loans', Icons.payments_rounded, AppColors.success),
              const SizedBox(height: 10),
              _metricCard(theme, isDark, 'Outstanding',
                  currencyFormat.format(summary.totalOutstanding), '${summary.activeLoans} active', Icons.account_balance_wallet_rounded, AppColors.warning),
              const SizedBox(height: 10),
              _metricCard(theme, isDark, 'Overdue Amount',
                  currencyFormat.format(summary.overdueAmount), '${summary.defaultLoans} defaulted', Icons.warning_amber_rounded, AppColors.error),

              const SizedBox(height: 16),

              // ─── Insight ───
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: summary.parPercentage > 5
                      ? AppColors.error.withValues(alpha: 0.08)
                      : AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: summary.parPercentage > 5
                          ? AppColors.error.withValues(alpha: 0.15)
                          : AppColors.success.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Icon(
                      summary.parPercentage > 5
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline,
                      color: summary.parPercentage > 5
                          ? AppColors.error
                          : AppColors.success,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        summary.parPercentage > 5
                            ? 'PAR rate is ${summary.parPercentage.toStringAsFixed(1)}% — needs attention. Focus on recovering overdue loans.'
                            : 'PAR rate is healthy at ${summary.parPercentage.toStringAsFixed(1)}%. Keep up the good collection discipline.',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: summary.parPercentage > 5
                                ? AppColors.error
                                : AppColors.success),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms),
            ],
          ),
        );
      },
    );
  }

  Widget _donutLegend(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text('$count',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _metricCard(ThemeData theme, bool isDark, String title,
      String value, String subtitle, IconData icon, Color color) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white54 : Colors.black54)),
                const SizedBox(height: 2),
                Text(value,
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          ),
          Text(subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white38 : Colors.black38)),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05, end: 0);
  }
}

// ============================================================================
// MEMBERS TAB
// ============================================================================

class _MembersTab extends ConsumerWidget {
  final String branchId;
  const _MembersTab({required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final memberAsync = ref.watch(branchMemberCountProvider(branchId));

    return memberAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: List.generate(
              3,
              (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: ShimmerCard(height: 100),
                  )),
        ),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (memberData) {
        final total = (memberData['total'] as int?) ?? 0;
        final active = (memberData['active'] as int?) ?? 0;
        final newThisMonth = (memberData['new_this_month'] as int?) ?? 0;
        final inactive = (memberData['inactive'] as int?) ?? 0;
        final activePercent = total > 0 ? (active / total * 100).round() : 0;

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(branchMemberCountProvider(branchId)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            children: [
              // ─── Member Growth Bar Chart ───
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Member Overview',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 180,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: (total > 0 ? total : 10).toDouble() * 1.2,
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                return BarTooltipItem(
                                  '${rod.toY.toInt()}',
                                  const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            rightTitles: const AxisTitles(),
                            topTitles: const AxisTitles(),
                            leftTitles: const AxisTitles(),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, _) {
                                  const labels = ['Total', 'Active', 'New', 'Inactive'];
                                  final idx = value.toInt();
                                  if (idx >= 0 && idx < labels.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(labels[idx],
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: isDark
                                                  ? Colors.white38
                                                  : Colors.black38)),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: total > 0
                                ? (total / 4).ceilToDouble()
                                : 1,
                            getDrawingHorizontalLine: (_) => FlLine(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.05),
                              strokeWidth: 1,
                            ),
                          ),
                          barGroups: [
                            BarChartGroupData(x: 0, barRods: [
                              BarChartRodData(
                                toY: total.toDouble(),
                                width: 28,
                                borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(8)),
                                gradient: const LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [AppColors.primary, AppColors.accent]),
                              ),
                            ]),
                            BarChartGroupData(x: 1, barRods: [
                              BarChartRodData(
                                toY: active.toDouble(),
                                width: 28,
                                borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(8)),
                                gradient: const LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [AppColors.success, Color(0xFF34D399)]),
                              ),
                            ]),
                            BarChartGroupData(x: 2, barRods: [
                              BarChartRodData(
                                toY: newThisMonth.toDouble(),
                                width: 28,
                                borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(8)),
                                gradient: const LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [AppColors.accent, Color(0xFF818CF8)]),
                              ),
                            ]),
                            BarChartGroupData(x: 3, barRods: [
                              BarChartRodData(
                                toY: inactive.toDouble(),
                                width: 28,
                                borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(8)),
                                gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      AppColors.error.withValues(alpha: 0.6),
                                      AppColors.error
                                    ]),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),

              const SizedBox(height: 16),

              // ─── Active Ratio ───
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Active Ratio',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        Text('$activePercent%',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: activePercent > 70
                                    ? AppColors.success
                                    : activePercent > 40
                                        ? AppColors.warning
                                        : AppColors.error)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: activePercent / 100,
                        minHeight: 12,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          activePercent > 70
                              ? AppColors.success
                              : activePercent > 40
                                  ? AppColors.warning
                                  : AppColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('$active of $total members are active',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white54 : Colors.black54)),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05, end: 0),

              const SizedBox(height: 16),

              // ─── Insight ───
              if (newThisMonth > 0)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_add_rounded,
                          color: AppColors.accent, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '$newThisMonth new member${newThisMonth > 1 ? 's' : ''} joined this month',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// STAFF TAB
// ============================================================================

class _StaffTab extends ConsumerWidget {
  final String branchId;
  const _StaffTab({required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currencyFormat =
        NumberFormat.currency(symbol: '\u20B9', decimalDigits: 0);
    final performanceAsync = ref.watch(
        staffPerformanceProvider((branchId, null, null)));

    return performanceAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: List.generate(
              4,
              (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: ShimmerCard(height: 80),
                  )),
        ),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (performance) {
        if (performance.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline,
                    size: 48,
                    color: isDark ? Colors.white24 : Colors.black26),
                const SizedBox(height: 12),
                Text('No staff data yet',
                    style: theme.textTheme.bodyLarge?.copyWith(
                        color: isDark ? Colors.white54 : Colors.black54)),
              ],
            ),
          );
        }

        final sorted = List<Map<String, dynamic>>.from(performance)
          ..sort((a, b) => ((b['collected'] as num?) ?? 0)
              .compareTo((a['collected'] as num?) ?? 0));
        final maxCollected =
            ((sorted.first['collected'] as num?) ?? 1).toDouble();

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(
              staffPerformanceProvider((branchId, null, null))),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final staff = sorted[index];
              final name = (staff['name'] as String?) ?? 'Unknown';
              final collected =
                  ((staff['collected'] as num?) ?? 0).toDouble();
              final efficiency = ((staff['efficiency'] as num?) ?? 0).toDouble();
              final ratio =
                  maxCollected > 0 ? collected / maxCollected : 0.0;
              final rankColor = index == 0
                  ? const Color(0xFFFFD700)
                  : index == 1
                      ? const Color(0xFFC0C0C0)
                      : index == 2
                          ? const Color(0xFFCD7F32)
                          : AppColors.primary;

              return GlassCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: rankColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: index < 3
                                ? Icon(
                                    index == 0
                                        ? Icons.emoji_events_rounded
                                        : Icons.military_tech_rounded,
                                    color: rankColor,
                                    size: 16,
                                  )
                                : Text('${index + 1}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: rankColor)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              const SizedBox(height: 2),
                              Text('Efficiency: ${efficiency.round()}%',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black38)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(currencyFormat.format(collected),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                            const Text('Collected',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(rankColor),
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(
                      duration: 300.ms,
                      delay: Duration(milliseconds: index * 60))
                  .slideX(begin: 0.05);
            },
          ),
        );
      },
    );
  }
}
