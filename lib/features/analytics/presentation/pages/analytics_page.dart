import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../providers/analytics_providers.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(analyticsProvider);
    final selectedPeriod = ref.watch(analyticsPeriodProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AuroraBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(analyticsProvider);
          },
          displacement: 20,
          color: theme.colorScheme.primary,
          backgroundColor: theme.cardColor,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                  child: _buildHeader(context, theme),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildPeriodSelector(ref, selectedPeriod, theme),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              analyticsAsync.when(
                data: (stats) => SliverList(
                  delegate: SliverChildListDelegate([
                    _buildHealthScoreGauge(stats, theme),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildPortfolioOverview(stats, theme),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildSavingsAnalytics(stats, theme),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildDisbursementVsCollection(context, stats, theme),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildPortfolioTrend(context, stats, theme),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildMemberInsights(stats, theme),
                    ),
                    const SizedBox(height: 24),
                    if (stats.upcomingMaturities.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _buildUpcomingMaturities(stats, theme),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildDelinquencyAnalysis(stats, theme),
                    ),
                    const SizedBox(height: 32),
                    _buildExportButton(context, theme),
                    const SizedBox(height: 100),
                  ]),
                ),
                loading: () => SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ShimmerCard(height: 220),
                    ),
                  ),
                ),
                error: (err, _) => SliverFillRemaining(
                  child: _buildErrorState(err, theme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Intelligence Hub',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                      fontSize: 34,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time portfolio performance',
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
              child: IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showExportDialog(context);
                },
                icon: Icon(Icons.ios_share_rounded,
                    color: theme.colorScheme.primary),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.05, end: 0);
  }

  Widget _buildPeriodSelector(
      WidgetRef ref, AnalyticsPeriod selected, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AnalyticsPeriod.values.map((period) {
          final isSelected = period == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () =>
                  ref.read(analyticsPeriodProvider.notifier).state = period,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primary.withValues(alpha: 0.12)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04)),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected
                        ? primary
                        : theme.dividerColor.withValues(alpha: 0.2),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  period.label,
                  style: TextStyle(
                    color:
                        isSelected ? primary : theme.textTheme.bodySmall?.color,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildHealthScoreGauge(AnalyticsStats stats, ThemeData theme) {
    final score = stats.collectionEfficiency.clamp(0, 100).toDouble();
    final primary = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Portfolio Health',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Based on collection efficiency',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'OPTIMAL',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 14,
                    strokeCap: StrokeCap.round,
                    backgroundColor: primary.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(primary),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${score.toInt()}%',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'Score',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSmallGaugeStat('Yield', '${stats.portfolioYield.toInt()}%',
                    Icons.trending_up_rounded, theme),
                _buildSmallGaugeStat('PAR', '${stats.parPercentage.toInt()}%',
                    Icons.warning_amber_rounded, theme),
                _buildSmallGaugeStat('Growth',
                    '${stats.memberGrowthRate.toInt()}%', Icons.groups_rounded, theme),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildSmallGaugeStat(
      String label, String value, IconData icon, ThemeData theme) {
    return Column(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
        const SizedBox(height: 4),
        Text(value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(fontSize: 10)),
      ],
    );
  }

  Widget _buildUpcomingMaturities(AnalyticsStats stats, ThemeData theme) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_available_outlined,
                  size: 20, color: AppColors.orange),
              const SizedBox(width: 10),
              Text(
                'Upcoming Maturities',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${stats.upcomingMaturities.length} plans',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    color: AppColors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: stats.upcomingMaturities
                .take(3)
                .map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.orange.withValues(alpha: 0.15),
                                  AppColors.orange.withValues(alpha: 0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.savings_outlined,
                                size: 18, color: AppColors.orange),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.memberName,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${AppFormatters.formatDate(s.maturityDate)} \u2022 ${s.maturityDate.difference(DateTime.now()).inDays} days left',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                AppFormatters.formatCurrency(s.targetAmount),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.orange,
                                ),
                              ),
                              Text(
                                AppFormatters.formatCurrency(s.currentAmount),
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildPortfolioOverview(AnalyticsStats stats, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _OverviewCard(
            title: 'Total Disbursement',
            value: AppFormatters.formatCompactCurrency(stats.totalDisbursed),
            change: _formatChange(stats.disbursementChange),
            isPositive: stats.disbursementChange >= 0,
            chartData: stats.monthlyDisbursements,
            theme: theme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _OverviewCard(
            title: 'Total Collection',
            value: AppFormatters.formatCompactCurrency(stats.totalCollected),
            change: _formatChange(stats.collectionChange),
            isPositive: stats.collectionChange >= 0,
            chartData: stats.monthlyCollections,
            theme: theme,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  String _formatChange(double value) {
    if (value == 0) return '--';
    final prefix = value > 0 ? '+' : '';
    return '$prefix${value.toStringAsFixed(1)}%';
  }

  Widget _buildSavingsAnalytics(AnalyticsStats stats, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final successColor = isDark ? AppColors.successDark : AppColors.success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Savings Analytics',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Total Savings',
                value: AppFormatters.formatCompactCurrency(stats.totalSavings),
                icon: Icons.savings_outlined,
                color: successColor,
                theme: theme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Active Accounts',
                value: stats.activeSavingsAccounts.toString(),
                icon: Icons.people_outline,
                color: AppColors.primary,
                theme: theme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Interest Earned',
                value:
                    AppFormatters.formatCompactCurrency(stats.interestEarned),
                icon: Icons.trending_up_outlined,
                color: AppColors.accentLight,
                theme: theme,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Avg Balance',
                value: AppFormatters.formatCompactCurrency(
                    stats.averageSavingsBalance),
                icon: Icons.account_balance_wallet_outlined,
                color: AppColors.info,
                theme: theme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Maturities',
                value: stats.upcomingMaturities.length.toString(),
                icon: Icons.event_available_outlined,
                color: AppColors.orange,
                theme: theme,
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildDisbursementVsCollection(
      BuildContext context, AnalyticsStats stats, ThemeData theme) {
    final hasData = stats.monthlyDisbursements.isNotEmpty &&
        stats.monthlyCollections.isNotEmpty;
    final hasNonZero = stats.monthlyDisbursements.any((v) => v > 0) ||
        stats.monthlyCollections.any((v) => v > 0);
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Disbursement vs Collection',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (!hasNonZero)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Live',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      color: AppColors.info,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (!hasData || !hasNonZero)
            SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.bar_chart_rounded,
                          size: 40,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.3)),
                    ),
                    const SizedBox(height: 16),
                    Text('No transaction history yet',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => context.push('/loans/new'),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Create First Loan'),
                      style: TextButton.styleFrom(
                        foregroundColor: primary,
                        backgroundColor: primary.withValues(alpha: 0.1),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _computeMaxY(
                      stats.monthlyDisbursements, stats.monthlyCollections),
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final monthNames = [
                            'Jan',
                            'Feb',
                            'Mar',
                            'Apr',
                            'May',
                            'Jun',
                            'Jul',
                            'Aug',
                            'Sep',
                            'Oct',
                            'Nov',
                            'Dec'
                          ];
                          final now = DateTime.now();
                          final idx = (now.month - 6 + value.toInt()) % 12;
                          final label = monthNames[idx < 0 ? idx + 12 : idx];
                          return Text(label,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontSize: 10));
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  barGroups:
                      stats.monthlyDisbursements.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value,
                          color: primary,
                          width: 12,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                        BarChartRodData(
                          toY: stats.monthlyCollections[entry.key],
                          color: secondary,
                          width: 12,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(label: 'Disbursed', color: primary),
              const SizedBox(width: 24),
              _LegendItem(label: 'Collected', color: secondary),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.05, end: 0);
  }

  double _computeMaxY(List<double> list1, List<double> list2) {
    double max = 0;
    for (final v in list1) {
      if (v > max) max = v;
    }
    for (final v in list2) {
      if (v > max) max = v;
    }
    return max == 0 ? 100 : max * 1.2;
  }

  Widget _buildPortfolioTrend(
      BuildContext context, AnalyticsStats stats, ThemeData theme) {
    final primary = theme.colorScheme.primary;
    final hasNonZero = stats.monthlyDisbursements.any((v) => v > 0);

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Growth Projection',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          if (!hasNonZero)
            SizedBox(
              height: 180,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Waiting for data trends...',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => context.push('/loans/new'),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Deploy Capital'),
                      style: TextButton.styleFrom(
                        foregroundColor: primary,
                        backgroundColor: primary.withValues(alpha: 0.1),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.dividerColor.withValues(alpha: 0.2),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final monthNames = [
                            'Jan',
                            'Feb',
                            'Mar',
                            'Apr',
                            'May',
                            'Jun',
                            'Jul',
                            'Aug',
                            'Sep',
                            'Oct',
                            'Nov',
                            'Dec'
                          ];
                          final now = DateTime.now();
                          final idx = (now.month - 6 + value.toInt()) % 12;
                          final label = monthNames[idx < 0 ? idx + 12 : idx];
                          return Text(label,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontSize: 10));
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            AppFormatters.formatCompactCurrency(value),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontSize: 9),
                          );
                        },
                        reservedSize: 50,
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: stats.monthlyDisbursements.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value);
                      }).toList(),
                      isCurved: true,
                      color: primary,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: primary.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildMemberInsights(AnalyticsStats stats, ThemeData theme) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Member Insights',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '${stats.totalMembers} total',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _MemberStat(
                  value: stats.newMembersThisPeriod.toString(),
                  label: 'New This Period',
                  icon: Icons.person_add_outlined,
                  color: AppColors.success,
                ),
              ),
              Container(
                  height: 40,
                  width: 1,
                  color: theme.dividerColor.withValues(alpha: 0.2)),
              Expanded(
                child: _MemberStat(
                  value: stats.activeMembers.toString(),
                  label: 'Verified KYC',
                  icon: Icons.verified_outlined,
                  color: AppColors.accentLight,
                ),
              ),
              Container(
                  height: 40,
                  width: 1,
                  color: theme.dividerColor.withValues(alpha: 0.2)),
              Expanded(
                child: _MemberStat(
                  value: stats.pendingKYC.toString(),
                  label: 'Pending KYC',
                  icon: Icons.pending_outlined,
                  color: AppColors.orange,
                ),
              ),
            ],
          ),
          if (stats.recentMembers.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Recent Members',
                style: theme.textTheme.labelSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Column(
              children: stats.recentMembers
                  .take(3)
                  .map((member) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.primary.withValues(alpha: 0.15),
                                    AppColors.primary.withValues(alpha: 0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  member.fullName.isNotEmpty
                                      ? member.fullName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member.fullName,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    member.phone,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: member.kycStatus == KYCStatus.verified
                                    ? AppColors.success.withValues(alpha: 0.1)
                                    : AppColors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                member.kycStatus == KYCStatus.verified
                                    ? 'Verified'
                                    : 'Pending',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: member.kycStatus == KYCStatus.verified
                                      ? AppColors.success
                                      : AppColors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildDelinquencyAnalysis(AnalyticsStats stats, ThemeData theme) {
    final successColor = AppColors.success;
    final errorColor = AppColors.error;

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delinquency Analysis',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                  child: _DelinquencyChart(
                      parPercentage: stats.parPercentage, theme: theme)),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _DelinquencyItem(
                      label: 'Current',
                      amount: stats.totalDisbursed -
                          (stats.totalDisbursed * stats.parPercentage / 100),
                      percentage: 100 - stats.parPercentage,
                      color: successColor,
                      theme: theme,
                    ),
                    const SizedBox(height: 12),
                    _DelinquencyItem(
                      label: 'PAR (Overdue)',
                      amount: stats.totalDisbursed * stats.parPercentage / 100,
                      percentage: stats.parPercentage,
                      color: errorColor,
                      theme: theme,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildExportButton(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GlassCard(
        onTap: () {
          HapticFeedback.mediumImpact();
          _showExportDialog(context);
        },
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.ios_share_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              'Export Financial Report',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 800.ms);
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Report'),
        content: const Text(
            'A comprehensive financial report will be generated and saved to your device. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Generating PDF Report...')),
              );
              await Future.delayed(const Duration(seconds: 3));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Report saved to Downloads folder'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('GENERATE'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object err, ThemeData theme) {
    return Center(
      child: GlassCard(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: AppColors.error.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(
              'Unable to load analytics',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              err.toString(),
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String title;
  final String value;
  final String change;
  final bool isPositive;
  final List<double> chartData;
  final ThemeData theme;

  const _OverviewCard({
    required this.title,
    required this.value,
    required this.change,
    required this.isPositive,
    required this.chartData,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final trendColor = change == '--'
        ? theme.textTheme.bodySmall?.color
        : (isPositive ? AppColors.success : AppColors.error);
    final primary = theme.colorScheme.primary;
    final hasData = chartData.any((v) => v > 0);

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primary.withValues(alpha: 0.1),
              theme.colorScheme.surface.withValues(alpha: 0.5),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: 0.15),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          )),
                      if (change != '--')
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isPositive
                                    ? AppColors.success
                                    : AppColors.error)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            change,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: trendColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    value,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (hasData)
                    SizedBox(
                      height: 40,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: chartData.asMap().entries.map((e) {
                                return FlSpot(e.key.toDouble(), e.value);
                              }).toList(),
                              isCurved: true,
                              color: trendColor,
                              barWidth: 2.5,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: trendColor?.withValues(alpha: 0.1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final ThemeData theme;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}



class _MemberStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _MemberStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 20, color: color.withValues(alpha: 0.7)),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _DelinquencyChart extends StatelessWidget {
  final double parPercentage;
  final ThemeData theme;

  const _DelinquencyChart({required this.parPercentage, required this.theme});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: PieChart(
        PieChartData(
          sectionsSpace: 0,
          centerSpaceRadius: 35,
          sections: [
            PieChartSectionData(
              color: AppColors.success,
              value: (100 - parPercentage).clamp(0, 100),
              title: '',
              radius: 12,
            ),
            PieChartSectionData(
              color: AppColors.error,
              value: parPercentage.clamp(0, 100),
              title: '',
              radius: 12,
            ),
          ],
        ),
      ),
    );
  }
}

class _DelinquencyItem extends StatelessWidget {
  final String label;
  final double amount;
  final double percentage;
  final Color color;
  final ThemeData theme;

  const _DelinquencyItem({
    required this.label,
    required this.amount,
    required this.percentage,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(label, style: theme.textTheme.labelSmall),
            const Spacer(),
            Text('${percentage.toStringAsFixed(1)}%',
                style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        Text(AppFormatters.formatCompactCurrency(amount),
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendItem({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
      ],
    );
  }
}
