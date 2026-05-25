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
import '../../data/providers/branch_scoped_providers.dart';

/// Branch-scoped analytics page for Branch Manager Portal.
/// Shows performance trends, collection trends, and branch KPIs.
class BranchAnalyticsPage extends ConsumerStatefulWidget {
  const BranchAnalyticsPage({super.key});

  @override
  ConsumerState<BranchAnalyticsPage> createState() =>
      _BranchAnalyticsPageState();
}

class _BranchAnalyticsPageState extends ConsumerState<BranchAnalyticsPage> {
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
        body: const Center(
            child: Text('No branch assigned to your profile.')),
      );
    }

    final analyticsAsync = ref.watch(branchAnalyticsProvider(branchId));
    final loanSummaryAsync = ref.watch(branchLoanSummaryProvider(branchId));
    final savingsSummaryAsync =
        ref.watch(branchSavingsSummaryProvider(branchId));
    final memberCountAsync = ref.watch(branchMemberCountProvider(branchId));

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF2F2F7),
      body: AuroraBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(branchAnalyticsProvider(branchId));
            ref.invalidate(branchLoanSummaryProvider(branchId));
            ref.invalidate(branchSavingsSummaryProvider(branchId));
            ref.invalidate(branchMemberCountProvider(branchId));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // App Bar
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

              // KPI Summary
              SliverToBoxAdapter(
                child: _buildKPISummary(
                  theme, isDark, loanSummaryAsync, savingsSummaryAsync,
                  memberCountAsync, currencyFormat,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // Collection Trend Chart
              SliverToBoxAdapter(
                child: analyticsAsync.when(
                  data: (data) => _buildCollectionTrendCard(
                    theme, isDark, data, currencyFormat,
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: ShimmerCard(height: 220),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // 30-Day Stats
              SliverToBoxAdapter(
                child: analyticsAsync.when(
                  data: (data) =>
                      _build30DayStats(theme, isDark, data, currencyFormat),
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

  // KPI Summary
  Widget _buildKPISummary(
    ThemeData theme,
    bool isDark,
    AsyncValue loanAsync,
    AsyncValue savingsAsync,
    AsyncValue memberAsync,
    NumberFormat currencyFormat,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: loanAsync.when(
              data: (summary) => _buildKPICard(
                theme, isDark,
                icon: Icons.account_balance_rounded,
                label: 'Active Loans',
                value: '${summary.activeLoans}',
                sub: '${summary.parPercentage.toStringAsFixed(1)}% PAR',
                color: AppColors.primary,
                isCurrency: false,
              ),
              loading: () => const ShimmerCard(height: 110),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: savingsAsync.when(
              data: (summary) => _buildKPICard(
                theme, isDark,
                icon: Icons.account_balance_wallet_rounded,
                label: 'Savings Balance',
                value: currencyFormat
                    .format(summary['total_balance'] as double? ?? 0),
                sub: '${summary['active_count'] ?? 0} active',
                color: AppColors.success,
                isCurrency: true,
              ),
              loading: () => const ShimmerCard(height: 110),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: memberAsync.when(
              data: (counts) => _buildKPICard(
                theme, isDark,
                icon: Icons.people_rounded,
                label: 'Members',
                value: '${counts['total'] ?? 0}',
                sub: '${counts['active'] ?? 0} active',
                color: AppColors.info,
                isCurrency: false,
              ),
              loading: () => const ShimmerCard(height: 110),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildKPICard(
    ThemeData theme,
    bool isDark, {
    required IconData icon,
    required String label,
    required String value,
    required String sub,
    required Color color,
    required bool isCurrency,
  }) {
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
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              fontSize: isCurrency ? 13 : 18,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            sub,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Collection Trend Card
  Widget _buildCollectionTrendCard(
    ThemeData theme,
    bool isDark,
    Map<String, dynamic> data,
    NumberFormat currencyFormat,
  ) {
    final collectionTrend =
        data['collection_trend'] as Map<String, double>? ?? {};

    if (collectionTrend.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedDates = collectionTrend.keys.toList()..sort();
    final spots = <FlSpot>[];
    for (int i = 0; i < sortedDates.length; i++) {
      spots.add(FlSpot(i.toDouble(), collectionTrend[sortedDates[i]] ?? 0));
    }

    final maxY = spots.fold<double>(
        0, (max, spot) => spot.y > max ? spot.y : max);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Collection Trend (30 days)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 160,
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
                        interval: (sortedDates.length / 5).ceilToDouble(),
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= sortedDates.length) {
                            return const SizedBox.shrink();
                          }
                          final date = DateTime.tryParse(sortedDates[idx]);
                          if (date == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('d').format(date),
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? Colors.white38
                                    : Colors.black38,
                              ),
                            ),
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
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.accent,
                        ],
                      ),
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
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
                          TextStyle(
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
      ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0),
    );
  }

  // 30-Day Stats
  Widget _build30DayStats(
    ThemeData theme,
    bool isDark,
    Map<String, dynamic> data,
    NumberFormat currencyFormat,
  ) {
    final loansDisbursed = data['loans_disbursed_30d'] as int? ?? 0;
    final totalDisbursed = (data['total_disbursed_30d'] as num?)?.toDouble() ?? 0;
    final newMembers = data['new_members_30d'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last 30 Days',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _build30DayTile(
                  theme, isDark,
                  icon: Icons.account_balance_rounded,
                  label: 'Loans Disbursed',
                  value: '$loansDisbursed',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _build30DayTile(
                  theme, isDark,
                  icon: Icons.payments_rounded,
                  label: 'Amount Disbursed',
                  value: currencyFormat.format(totalDisbursed),
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _build30DayTile(
                  theme, isDark,
                  icon: Icons.person_add_rounded,
                  label: 'New Members',
                  value: '$newMembers',
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ],
      )
          .animate()
          .fadeIn(duration: 400.ms, delay: 200.ms)
          .slideY(begin: 0.1, end: 0),
    );
  }

  Widget _build30DayTile(
    ThemeData theme,
    bool isDark, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
