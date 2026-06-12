import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/glass_card.dart';
import 'customer_payment_trend_chart.dart' show MonthlyPaymentData;

/// Premium area chart showing savings growth over time.
/// Features: green gradient area, smooth curves, touch tooltip, animated mount.
class CustomerSavingsGrowthChart extends StatefulWidget {
  final List<MonthlyPaymentData> data;
  const CustomerSavingsGrowthChart({super.key, required this.data});

  @override
  State<CustomerSavingsGrowthChart> createState() =>
      _CustomerSavingsGrowthChartState();
}

class _CustomerSavingsGrowthChartState
    extends State<CustomerSavingsGrowthChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _drawAnimation;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    );
    _drawAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (widget.data.isEmpty) {
      return _buildEmptyState(isDark);
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        borderRadius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success
                        .withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.borderRadiusMd),
                  ),
                  child: Icon(
                    Icons.savings_rounded,
                    color: AppColors.success,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Savings Growth',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Chart
            AnimatedBuilder(
              animation: _drawAnimation,
              builder: (context, _) => SizedBox(
                height: 200,
                child: _buildChart(isDark),
              ),
            ),

            // Tooltip display
            if (_touchedIndex != null &&
                _touchedIndex! >= 0 &&
                _touchedIndex! < widget.data.length)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.success
                          .withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.success
                            .withValues(alpha: isDark ? 0.3 : 0.15),
                      ),
                    ),
                    child: Text(
                      '${widget.data[_touchedIndex!].label}  ·  ₹${_formatAmount(widget.data[_touchedIndex!].amount)}',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.successDark
                            : AppColors.success,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(bool isDark) {
    final spots = widget.data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.amount);
    }).toList();

    final maxY = widget.data
        .map((d) => d.amount)
        .reduce((a, b) => a > b ? a : b);
    final safeMaxY = maxY == 0 ? 100.0 : maxY * 1.2;

    return LineChart(
      duration: const Duration(milliseconds: 0),
      LineChartData(
        minY: 0,
        maxY: safeMaxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: safeMaxY / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.04),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == safeMaxY) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    _formatAxisAmount(value),
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= widget.data.length) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    widget.data[idx].label,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '₹${_formatAmount(spot.y)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                );
              }).toList();
            },
            tooltipRoundedRadius: 10,
            getTooltipColor: (touchedSpot) =>
                AppColors.success.withValues(alpha: 0.9),
          ),
          handleBuiltInTouches: true,
          touchCallback: (event, response) {
            if (event is FlLongPressEnd || event is FlPanEndEvent) {
              setState(() => _touchedIndex = null);
              return;
            }
            if (response?.lineBarSpots != null &&
                response!.lineBarSpots!.isNotEmpty) {
              setState(() {
                _touchedIndex = response.lineBarSpots!.first.spotIndex;
              });
            }
          },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: AppColors.success,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                final isTouched = index == _touchedIndex;
                return FlDotCirclePainter(
                  radius: isTouched ? 5 : 3,
                  color: isDark ? AppColors.backgroundDark : Colors.white,
                  strokeWidth: isTouched ? 3 : 2,
                  strokeColor: AppColors.success,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.success.withValues(
                      alpha: isDark ? 0.25 * _drawAnimation.value
                          : 0.18 * _drawAnimation.value),
                  AppColors.mint.withValues(
                      alpha: isDark ? 0.05 * _drawAnimation.value
                          : 0.02 * _drawAnimation.value),
                ],
              ),
            ),
            shadow: Shadow(
              color: AppColors.success.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderRadius: 18,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success
                      .withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.borderRadiusMd),
                ),
                child: Icon(
                  Icons.savings_rounded,
                  color: AppColors.success,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Savings Growth',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Icon(
            Icons.show_chart_rounded,
            size: 40,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No savings data yet',
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '',
      decimalDigits: 0,
    ).format(amount);
  }

  String _formatAxisAmount(double amount) {
    return NumberFormat.decimalPattern('en_IN').format(amount);
  }
}
