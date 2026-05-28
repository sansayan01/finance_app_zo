// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class BranchAnalyticsPage extends ConsumerStatefulWidget {
  const BranchAnalyticsPage({super.key});

  @override
  ConsumerState<BranchAnalyticsPage> createState() =>
      _BranchAnalyticsPageState();
}

class _BranchAnalyticsPageState extends ConsumerState<BranchAnalyticsPage> {
  int _selectedPeriod = 1; // 0=7d, 1=30d, 2=90d, 3=1y

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authProvider).user;
    final branchId = user?.branchId;
    final currencyFormat =
        NumberFormat.currency(symbol: '\u20B9', decimalDigits: 0);

    if (branchId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Analytics')),
        body:
            const Center(child: Text('No branch assigned to your profile.')),
      );
    }

    final statsAsync = ref.watch(branchStatsProvider(branchId));
    final loanAsync = ref.watch(branchLoanSummaryProvider(branchId));
    final savingsAsync = ref.watch(branchSavingsSummaryProvider(branchId));
    final memberAsync = ref.watch(branchMemberCountProvider(branchId));
    final analyticsAsync = ref.watch(branchAnalyticsProvider(branchId));
    final weeklyAsync =
        ref.watch(branchWeeklyCollectionTrendProvider(branchId));
    final staffAsync = ref.watch(
        staffPerformanceProvider((branchId, null, null)));

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF2F2F7),
      body: AuroraBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(branchStatsProvider(branchId));
            ref.invalidate(branchLoanSummaryProvider(branchId));
            ref.invalidate(branchSavingsSummaryProvider(branchId));
            ref.invalidate(branchMemberCountProvider(branchId));
            ref.invalidate(branchAnalyticsProvider(branchId));
            ref.invalidate(branchWeeklyCollectionTrendProvider(branchId));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // ─── App Bar ───
              SliverAppBar(
                pinned: true,
                elevation: 0,
                backgroundColor: isDark
                    ? const Color(0xFF0A0A0C).withValues(alpha: 0.85)
                    : const Color(0xFFF2F2F7).withValues(alpha: 0.85),
                surfaceTintColor: Colors.transparent,
                title: Text(
                  'Branch Analytics',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                systemOverlayStyle: isDark
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark,
              ),

              // ─── Period Selector ───
              SliverToBoxAdapter(
                child: _buildPeriodSelector(theme, isDark),
              ),

              // ─── Health Score ───
              SliverToBoxAdapter(
                child: statsAsync.when(
                  data: (stats) => loanAsync.when(
                    data: (loan) => memberAsync.when(
                      data: (members) =>
                          _buildHealthScore(theme, isDark, stats, loan,
                              members, currencyFormat),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: ShimmerCard(height: 200),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ─── KPI Cards ───
              SliverToBoxAdapter(
                child: statsAsync.when(
                  data: (stats) =>
                      _buildKPICards(theme, isDark, stats, currencyFormat),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ─── Collection Trend ───
              SliverToBoxAdapter(
                child: analyticsAsync.when(
                  data: (data) => _buildCollectionTrend(
                      theme, isDark, data, currencyFormat),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: ShimmerCard(height: 240),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ─── Weekly Bar Chart ───
              SliverToBoxAdapter(
                child: weeklyAsync.when(
                  data: (data) =>
                      _buildWeeklyBars(theme, isDark, data, currencyFormat),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ─── Loan Portfolio Donut ───
              SliverToBoxAdapter(
                child: statsAsync.when(
                  data: (stats) => loanAsync.when(
                    data: (loan) => _buildLoanPortfolio(
                        theme, isDark, stats, loan, currencyFormat),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ─── Savings Overview ───
              SliverToBoxAdapter(
                child: savingsAsync.when(
                  data: (savings) =>
                      _buildSavingsOverview(theme, isDark, savings, currencyFormat),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ─── Staff Performance ───
              SliverToBoxAdapter(
                child: staffAsync.when(
                  data: (staff) =>
                      _buildStaffPerformance(theme, isDark, staff, currencyFormat),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ─── Member Insights ───
              SliverToBoxAdapter(
                child: memberAsync.when(
                  data: (members) =>
                      _buildMemberInsights(theme, isDark, members),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Period Selector ───────────────────────────────────────────────
  Widget _buildPeriodSelector(ThemeData theme, bool isDark) {
    const labels = ['7d', '30d', '90d', '1Y'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: List.generate(4, (i) {
            final selected = _selectedPeriod == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedPeriod = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? Colors.white
                          : (isDark ? Colors.white54 : Colors.black54),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  // ─── Health Score ──────────────────────────────────────────────────
  Widget _buildHealthScore(
    ThemeData theme,
    bool isDark,
    dynamic stats,
    dynamic loan,
    Map<String, dynamic> members,
    NumberFormat currencyFormat,
  ) {
    // Compute health score
    final collectionEfficiency = stats.totalDisbursements > 0
        ? (stats.totalCollections / stats.totalDisbursements).clamp(0.0, 1.0)
        : 0.0;
    final parHealth =
        (1 - (loan.parPercentage / 100)).clamp(0.0, 1.0);
    final memberTotal = (members['total'] as int?) ?? 0;
    final memberActive = (members['active'] as int?) ?? 0;
    final memberActivity =
        memberTotal > 0 ? (memberActive / memberTotal) : 0.0;
    final staffProductivity = stats.totalStaff > 0
        ? (stats.activeLoansCount / (stats.totalStaff * 10)).clamp(0.0, 1.0)
        : 0.0;

    final score = ((collectionEfficiency * 0.4) +
            (parHealth * 0.3) +
            (memberActivity * 0.15) +
            (staffProductivity * 0.15)) *
        100;

    final scoreColor = score >= 70
        ? AppColors.success
        : score >= 40
            ? AppColors.warning
            : AppColors.error;
    final scoreLabel =
        score >= 70 ? 'Healthy' : score >= 40 ? 'Needs Attention' : 'Critical';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Branch Health Score',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
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
                          value: score,
                          color: scoreColor,
                          radius: 14,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: (100 - score).toDouble(),
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
                        '${score.round()}',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: scoreColor,
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        scoreLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scoreColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _healthComponent('Collections',
                    '${(collectionEfficiency * 100).round()}%', AppColors.primary),
                _healthComponent(
                    'PAR Health', '${(parHealth * 100).round()}%', AppColors.success),
                _healthComponent(
                    'Members', '${(memberActivity * 100).round()}%', AppColors.info),
                _healthComponent('Staff',
                    '${(staffProductivity * 100).round()}%', AppColors.accentLight),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0),
    );
  }

  Widget _healthComponent(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  // ─── KPI Cards ─────────────────────────────────────────────────────
  Widget _buildKPICards(ThemeData theme, bool isDark, dynamic stats,
      NumberFormat currencyFormat) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _kpiTile(theme, isDark,
                icon: Icons.account_balance_rounded,
                label: 'Outstanding',
                value: currencyFormat.format(stats.outstandingAmount),
                sub: 'Active: ${stats.activeLoansCount}',
                color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _kpiTile(theme, isDark,
                icon: Icons.payments_rounded,
                label: 'Collected',
                value: currencyFormat.format(stats.totalCollections),
                sub: 'Disbursed: ${currencyFormat.format(stats.totalDisbursements)}',
                color: AppColors.success),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _kpiTile(theme, isDark,
                icon: Icons.savings_rounded,
                label: 'Savings',
                value: currencyFormat.format(stats.totalSavings),
                sub: '${stats.totalMembers} members',
                color: AppColors.info),
          ),
        ],
      ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05, end: 0),
    );
  }

  Widget _kpiTile(ThemeData theme, bool isDark,
      {required IconData icon,
      required String label,
      required String value,
      required String sub,
      required Color color}) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white54 : Colors.black45,
                fontSize: 10,
              )),
          Text(sub,
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  // ─── Collection Trend ──────────────────────────────────────────────
  Widget _buildCollectionTrend(ThemeData theme, bool isDark,
      Map<String, dynamic> data, NumberFormat currencyFormat) {
    final collectionTrend =
        data['collection_trend'] as Map<String, double>? ?? {};
    if (collectionTrend.isEmpty) return const SizedBox.shrink();

    final sortedDates = collectionTrend.keys.toList()..sort();
    final spots = <FlSpot>[];
    for (int i = 0; i < sortedDates.length; i++) {
      spots.add(FlSpot(i.toDouble(), collectionTrend[sortedDates[i]] ?? 0));
    }
    final maxY =
        spots.fold<double>(0, (max, spot) => spot.y > max ? spot.y : max);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Text('Collection Trend',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${sortedDates.length} days',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval:
                        maxY > 0 ? (maxY / 4).ceilToDouble() : 1,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.05),
                      strokeWidth: 1,
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
                        reservedSize: 28,
                        interval:
                            (sortedDates.length / 5).ceilToDouble(),
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= sortedDates.length) {
                            return const SizedBox.shrink();
                          }
                          final date =
                              DateTime.tryParse(sortedDates[idx]);
                          if (date == null) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(DateFormat('d').format(date),
                                style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38)),
                          );
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
                        colors: [AppColors.primary, AppColors.accent],
                      ),
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, _, __, ___) =>
                            FlDotCirclePainter(
                          radius: 3,
                          color: AppColors.primary,
                          strokeWidth: 2,
                          strokeColor: isDark
                              ? const Color(0xFF0A0A0C)
                              : const Color(0xFFF2F2F7),
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.2),
                            AppColors.primary.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((spot) {
                        return LineTooltipItem(
                          currencyFormat.format(spot.y),
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0),
    );
  }

  // ─── Weekly Bar Chart ──────────────────────────────────────────────
  Widget _buildWeeklyBars(ThemeData theme, bool isDark, List<double> data,
      NumberFormat currencyFormat) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxY = data.fold<double>(0, (m, v) => v > m ? v : m);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart_rounded,
                    color: AppColors.accent, size: 20),
                const SizedBox(width: 10),
                Text('This Week',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY > 0 ? maxY * 1.2 : 100,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          currencyFormat.format(rod.toY),
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
                          final idx = value.toInt();
                          if (idx >= 0 && idx < days.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
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
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval:
                        maxY > 0 ? (maxY / 4).ceilToDouble() : 1,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.05),
                      strokeWidth: 1,
                    ),
                  ),
                  barGroups: List.generate(7, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: data[i],
                          width: 20,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              AppColors.primary.withValues(alpha: 0.6),
                              AppColors.accent,
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05, end: 0),
    );
  }

  // ─── Loan Portfolio Donut ──────────────────────────────────────────
  Widget _buildLoanPortfolio(ThemeData theme, bool isDark, dynamic stats,
      dynamic loan, NumberFormat currencyFormat) {
    final active = stats.activeLoansCount.toDouble();
    final defaulted = stats.overdueLoans.toDouble();
    final closed = (stats.totalLoans - stats.activeLoansCount - stats.overdueLoans)
        .toDouble()
        .clamp(0.0, double.infinity);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Text('Loan Portfolio',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 30,
                      sectionsSpace: 2,
                      sections: [
                        PieChartSectionData(
                          value: active > 0 ? active : 1,
                          color: AppColors.primary,
                          radius: 16,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: closed > 0 ? closed : 0,
                          color: AppColors.success,
                          radius: 16,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: defaulted > 0 ? defaulted : 0,
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
                      _legendItem('Active', active.toInt(), AppColors.primary),
                      const SizedBox(height: 8),
                      _legendItem('Closed', closed.toInt(), AppColors.success),
                      const SizedBox(height: 8),
                      _legendItem(
                          'Defaulted', defaulted.toInt(), AppColors.error),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: loan.parPercentage > 5
                              ? AppColors.error.withValues(alpha: 0.08)
                              : AppColors.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              loan.parPercentage > 5
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline,
                              size: 16,
                              color: loan.parPercentage > 5
                                  ? AppColors.error
                                  : AppColors.success,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'PAR: ${loan.parPercentage.toStringAsFixed(1)}% — ${loan.parPercentage > 5 ? "needs attention" : "healthy"}',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: loan.parPercentage > 5
                                        ? AppColors.error
                                        : AppColors.success),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05, end: 0),
    );
  }

  Widget _legendItem(String label, int count, Color color) {
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
                fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  // ─── Savings Overview ──────────────────────────────────────────────
  Widget _buildSavingsOverview(ThemeData theme, bool isDark,
      Map<String, dynamic> savings, NumberFormat currencyFormat) {
    final totalBalance =
        (savings['total_balance'] as num?)?.toDouble() ?? 0;
    final activeCount = (savings['active_count'] as int?) ?? 0;
    final maturedCount = (savings['matured_count'] as int?) ?? 0;
    final total = activeCount + maturedCount;
    final activeRatio = total > 0 ? activeCount / total : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.savings_rounded,
                    color: AppColors.success, size: 20),
                const SizedBox(width: 10),
                Text('Savings Overview',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 20),
            Text(currencyFormat.format(totalBalance),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                )),
            const SizedBox(height: 4),
            Text('Total Savings Balance',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white54 : Colors.black54)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _savingsStatTile(
                      theme, isDark, 'Active', '$activeCount', AppColors.success),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _savingsStatTile(
                      theme, isDark, 'Matured', '$maturedCount', AppColors.info),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: activeRatio,
                minHeight: 10,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.success),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(activeRatio * 100).round()}% of accounts are active',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0),
    );
  }

  Widget _savingsStatTile(
      ThemeData theme, bool isDark, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white54 : Colors.black54)),
        ],
      ),
    );
  }

  // ─── Staff Performance ─────────────────────────────────────────────
  Widget _buildStaffPerformance(ThemeData theme, bool isDark,
      List<Map<String, dynamic>> staff, NumberFormat currencyFormat) {
    if (staff.isEmpty) return const SizedBox.shrink();

    final sorted = List<Map<String, dynamic>>.from(staff)
      ..sort((a, b) => ((b['collected'] as num?) ?? 0)
          .compareTo((a['collected'] as num?) ?? 0));
    final top5 = sorted.take(5).toList();
    final maxCollected =
        ((top5.first['collected'] as num?) ?? 1).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.leaderboard_rounded,
                    color: AppColors.accent, size: 20),
                const SizedBox(width: 10),
                Text('Staff Performance',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(top5.length, (i) {
              final s = top5[i];
              final name = (s['name'] as String?) ?? 'Unknown';
              final collected =
                  ((s['collected'] as num?) ?? 0).toDouble();
              final ratio =
                  maxCollected > 0 ? collected / maxCollected : 0.0;
              final rankColor = i == 0
                  ? const Color(0xFFFFD700)
                  : i == 1
                      ? const Color(0xFFC0C0C0)
                      : i == 2
                          ? const Color(0xFFCD7F32)
                          : AppColors.primary;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: rankColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text('${i + 1}',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: rankColor)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                        Text(currencyFormat.format(collected),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                        valueColor: AlwaysStoppedAnimation<Color>(rankColor),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.05, end: 0),
    );
  }

  // ─── Member Insights ───────────────────────────────────────────────
  Widget _buildMemberInsights(
      ThemeData theme, bool isDark, Map<String, dynamic> members) {
    final total = (members['total'] as int?) ?? 0;
    final active = (members['active'] as int?) ?? 0;
    final newThisMonth = (members['new_this_month'] as int?) ?? 0;
    final activePercent = total > 0 ? (active / total * 100).round() : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.person_add_rounded,
                      color: AppColors.accent, size: 28),
                  const SizedBox(height: 10),
                  Text('$newThisMonth',
                      style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.accent)),
                  const SizedBox(height: 4),
                  Text('New This Month',
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black54)),
                ],
              ),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05, end: 0),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            centerSpaceRadius: 14,
                            sectionsSpace: 0,
                            sections: [
                              PieChartSectionData(
                                value: activePercent.toDouble(),
                                color: AppColors.success,
                                radius: 7,
                                showTitle: false,
                              ),
                              PieChartSectionData(
                                value: (100 - activePercent).toDouble(),
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.04),
                                radius: 7,
                                showTitle: false,
                              ),
                            ],
                          ),
                        ),
                        Text('$activePercent%',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.success)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Active Rate',
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black54)),
                ],
              ),
            ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.05, end: 0),
          ),
        ],
      ),
    );
  }
}
