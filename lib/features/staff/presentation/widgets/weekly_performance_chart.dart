import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/providers/staff_providers.dart';
import 'premium_helpers.dart';

class WeeklyPerformanceChart extends ConsumerWidget {
  const WeeklyPerformanceChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final trendAsync = ref.watch(weeklyTrendProvider);

    return trendAsync.when(
      data: (trend) {
        if (trend.isEmpty) return const SizedBox.shrink();

        final amounts =
            trend.map((e) => (e['amount'] as num?)?.toDouble() ?? 0).toList();
        final maxVal = amounts.reduce((a, b) => a > b ? a : b);
        final total = amounts.fold(0.0, (a, b) => a + b);
        final yesterdayAmount =
            amounts.length >= 2 ? amounts[amounts.length - 2] : 0.0;
        final todayAmount = amounts.last;
        final pctChange = yesterdayAmount > 0
            ? ((todayAmount - yesterdayAmount) / yesterdayAmount * 100)
            : 0.0;

        return GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumHelpers.sectionHeader(
                theme,
                'Performance Pulse',
                trailing: pctChange != 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (pctChange >= 0
                                  ? Colors.greenAccent
                                  : Colors.redAccent)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${pctChange >= 0 ? '+' : ''}${pctChange.toStringAsFixed(1)}% Today',
                          style: TextStyle(
                            color: pctChange >= 0
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 60,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(trend.length, (index) {
                    final amount = trend[index]['amount'] as num? ?? 0;
                    final barHeight =
                        maxVal > 0 ? (amount.toDouble() / maxVal) * 50 : 0.0;
                    final dayLabel = trend[index]['dayLabel'] as String? ?? '';

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: barHeight.clamp(4.0, 50.0),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: index == trend.length - 1
                                      ? [AppColors.primary, AppColors.accent]
                                      : [
                                          AppColors.primary
                                              .withValues(alpha: 0.3),
                                          AppColors.primary
                                              .withValues(alpha: 0.15),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: index == trend.length - 1
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.4),
                                          blurRadius: 6,
                                          offset: const Offset(0, -2),
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dayLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 9,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Week Total: ₹${total.toStringAsFixed(0)}',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 11),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
