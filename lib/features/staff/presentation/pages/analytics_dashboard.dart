import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/staff_providers.dart';
import '../../data/providers/collection_providers.dart';

class AnalyticsDashboard extends ConsumerStatefulWidget {
  const AnalyticsDashboard({super.key});

  @override
  ConsumerState<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends ConsumerState<AnalyticsDashboard> {
  String _selectedPeriod = 'week';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white70 : Colors.black87),
        ),
        title: const Text('Analytics', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async { ref.invalidate(todaySummaryProvider); ref.invalidate(staffStreakProvider); ref.invalidate(todayTargetProvider); ref.invalidate(weeklyTrendProvider); await Future.delayed(const Duration(milliseconds: 500)); },
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPeriodSelector(theme, isDark),
              const SizedBox(height: 20),
              _buildSummaryCards(theme, isDark),
              const SizedBox(height: 20),
              _buildCollectionsChart(theme, isDark),
              const SizedBox(height: 20),
              _buildPerformanceMetrics(theme, isDark),
              const SizedBox(height: 20),
              _buildTopCustomers(theme, isDark),
            ].animate(interval: 60.ms).fadeIn().slideY(begin: 0.04, end: 0),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: ['day', 'week', 'month', 'year'].map((period) {
          final isSelected = _selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = period),
              child: AnimatedContainer(
                duration: 200.ms,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  period[0].toUpperCase() + period.substring(1),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryCards(ThemeData theme, bool isDark) {
    final statsAsync = ref.watch(todayCollectionStatsProvider);

    return statsAsync.when(
      data: (stats) {
        final total = (stats['total_collected'] as num?)?.toDouble() ?? 0;
        final count = stats['collection_count'] as int? ?? 0;
        final avg = count > 0 ? total / count : 0.0;

        return Row(
          children: [
            Expanded(child: _buildSummaryCard(theme, 'Collected', '₹${_fmt(total)}', '+12%', AppColors.success, Icons.trending_up_rounded, isDark)),
            const SizedBox(width: 10),
            Expanded(child: _buildSummaryCard(theme, 'Count', '$count', '+8%', AppColors.info, Icons.receipt_long_rounded, isDark)),
            const SizedBox(width: 10),
            Expanded(child: _buildSummaryCard(theme, 'Average', '₹${_fmt(avg)}', '+5%', AppColors.accent, Icons.payments_rounded, isDark)),
          ],
        );
      },
      loading: () => _buildSummarySkeleton(theme, isDark),
      error: (_, __) => _buildSummarySkeleton(theme, isDark),
    );
  }

  Widget _buildSummarySkeleton(ThemeData theme, bool isDark) {
    return Row(
      children: List.generate(3, (_) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181C24) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 20, height: 20, decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 10),
              Container(width: 40, height: 18, decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 4),
              Container(width: 60, height: 12, decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4))),
            ],
          ),
        ),
      )),
    );
  }

  Widget _buildSummaryCard(ThemeData theme, String title, String value, String change, Color color, IconData icon, bool isDark) {
    final isPositive = change.startsWith('+');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color, height: 1.1)),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(isPositive ? Icons.arrow_upward : Icons.arrow_downward, color: isPositive ? AppColors.success : AppColors.error, size: 12),
              const SizedBox(width: 2),
              Text(change, style: TextStyle(color: isPositive ? AppColors.success : AppColors.error, fontSize: 10, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionsChart(ThemeData theme, bool isDark) {
    final trendAsync = ref.watch(weeklyTrendProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C24) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.trending_up_rounded, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Text('Collection Trend', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                child: Text(_selectedPeriod == 'week' ? 'This Week' : _selectedPeriod, style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          trendAsync.when(
            data: (trend) {
              if (trend.isEmpty) {
                return _buildChartPlaceholder(theme, 'No trend data');
              }
              final amounts = trend.map((e) => (e['amount'] as num?)?.toDouble() ?? 0).toList();
              final maxVal = amounts.reduce((a, b) => a > b ? a : b);
              return Column(
                children: [
                  SizedBox(
                    height: 140,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(trend.length, (i) {
                        final amt = amounts[i];
                        final barH = maxVal > 0 ? (amt / maxVal) * 110 : 0.0;
                        final dayLabel = trend[i]['dayLabel'] as String? ?? '';
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (amt > 0)
                                  Text('₹${_fmt(amt)}', style: TextStyle(fontSize: 7, color: theme.colorScheme.onSurface.withValues(alpha: 0.3))),
                                const SizedBox(height: 2),
                                Container(
                                  height: barH.clamp(4.0, 110.0),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter, end: Alignment.topCenter,
                                      colors: i == trend.length - 1
                                          ? [AppColors.primary, AppColors.accent]
                                          : [AppColors.primary.withValues(alpha: 0.3), AppColors.primary.withValues(alpha: 0.1)],
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(dayLabel, style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface.withValues(alpha: 0.35))),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Total: ₹${_fmt(amounts.fold(0.0, (a, b) => a + b))}', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
                ],
              );
            },
            loading: () => _buildChartPlaceholder(theme, 'Loading...'),
            error: (_, __) => _buildChartPlaceholder(theme, 'No data'),
          ),
        ],
      ),
    );
  }

  Widget _buildChartPlaceholder(ThemeData theme, String message) {
    return Container(
      height: 140,
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(16)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded, size: 36, color: theme.colorScheme.onSurface.withValues(alpha: 0.15)),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.3))),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceMetrics(ThemeData theme, bool isDark) {
    final streakAsync = ref.watch(staffStreakProvider);
    final targetAsync = ref.watch(todayTargetProvider);

    final streakDays = streakAsync.valueOrNull?.currentStreak ?? 0;
    final targetProgress = targetAsync.valueOrNull?.progress ?? 0.0;

    final metrics = [
      {'label': 'Target Achievement', 'value': '${(targetProgress * 100).toStringAsFixed(0)}%', 'progress': targetProgress.clamp(0.0, 1.0)},
      {'label': 'Collection Streak', 'value': '$streakDays days', 'progress': (streakDays / 30).clamp(0.0, 1.0)},
      {'label': 'On-time Rate', 'value': '92%', 'progress': 0.92},
      {'label': 'Visit Success', 'value': '78%', 'progress': 0.78},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C24) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.speed_rounded, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text('Performance', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          ...metrics.map((m) => _buildMetricRow(theme, m['label'] as String, m['value'] as String, m['progress'] as double, isDark)),
        ],
      ),
    );
  }

  Widget _buildMetricRow(ThemeData theme, String label, String value, double progress, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.06) : theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(progress >= 0.8 ? AppColors.success : AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCustomers(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C24) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.people_rounded, size: 18, color: Colors.amber.shade600),
                  ),
                  const SizedBox(width: 10),
                  Text('Top Customers', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
              TextButton(onPressed: () {}, child: const Text('View All', style: TextStyle(fontSize: 12))),
            ],
          ),
          const SizedBox(height: 12),
          ...[
            {'name': 'Ramesh Kumar', 'amount': '₹12,500', 'collections': 8, 'color': Colors.amber},
            {'name': 'Priya Sharma', 'amount': '₹10,200', 'collections': 6, 'color': Colors.grey},
            {'name': 'Amit Patel', 'amount': '₹8,900', 'collections': 5, 'color': Colors.brown},
          ].asMap().entries.map((entry) {
            final i = entry.key; final c = entry.value;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(color: (c['color'] as Color).withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: Center(child: Text('${i + 1}', style: TextStyle(color: c['color'] as Color, fontWeight: FontWeight.w800, fontSize: 11))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${c['collections']} collections', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
                    ]),
                  ),
                  Text(c['amount'] as String, style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _fmt(double n) {
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }
}
