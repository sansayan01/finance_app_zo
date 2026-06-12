import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/glass_card.dart';

/// Premium donut chart showing loan breakdown (paid, outstanding, interest).
/// Features: animated rotation, center total, legend, touch highlight.
class CustomerLoanBreakdownChart extends StatefulWidget {
  final double paid;
  final double outstanding;
  final double interest;
  const CustomerLoanBreakdownChart({
    super.key,
    required this.paid,
    required this.outstanding,
    required this.interest,
  });

  @override
  State<CustomerLoanBreakdownChart> createState() =>
      _CustomerLoanBreakdownChartState();
}

class _CustomerLoanBreakdownChartState
    extends State<CustomerLoanBreakdownChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotateAnimation;
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
    _rotateAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.1, 1.0, curve: Curves.easeOutCubic),
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
    final total = widget.paid + widget.outstanding + widget.interest;

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
                    color: AppColors.accent
                        .withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.borderRadiusMd),
                  ),
                  child: Icon(
                    Icons.pie_chart_rounded,
                    color: AppColors.accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Loan Breakdown',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Donut chart with center text
            AnimatedBuilder(
              animation: _rotateAnimation,
              builder: (context, _) => SizedBox(
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        startDegreeOffset:
                            -90 + (360 * _rotateAnimation.value),
                        centerSpaceRadius: 56,
                        sectionsSpace: 3,
                        sections: _buildSections(isDark, total),
                        pieTouchData: PieTouchData(
                          enabled: true,
                          touchCallback: (event, response) {
                            if (event is FlLongPressEnd ||
                                event is FlPanEndEvent) {
                              setState(() => _touchedIndex = null);
                              return;
                            }
                            if (response?.touchedSection != null) {
                              setState(() {
                                _touchedIndex = response!
                                    .touchedSection!.touchedSectionIndex;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    // Center content
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${_formatAmount(total)}',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Legend
            _buildLegendRow(
              isDark: isDark,
              color: AppColors.success,
              label: 'Paid',
              amount: widget.paid,
              total: total,
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildLegendRow(
              isDark: isDark,
              color: AppColors.orange,
              label: 'Outstanding',
              amount: widget.outstanding,
              total: total,
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildLegendRow(
              isDark: isDark,
              color: AppColors.indigo,
              label: 'Interest',
              amount: widget.interest,
              total: total,
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildSections(bool isDark, double total) {
    if (total == 0) {
      return [
        PieChartSectionData(
          value: 1,
          color: isDark ? AppColors.fillDark : AppColors.fillLight,
          radius: _touchedIndex == 0 ? 52 : 44,
          showTitle: false,
        ),
      ];
    }

    final sections = <_SectionDef>[
      _SectionDef(
        value: widget.paid,
        color: AppColors.success,
        darkColor: AppColors.successDark,
      ),
      _SectionDef(
        value: widget.outstanding,
        color: AppColors.orange,
        darkColor: const Color(0xFFFDBA74),
      ),
      _SectionDef(
        value: widget.interest,
        color: AppColors.indigo,
        darkColor: AppColors.accentDark,
      ),
    ];

    return sections.asMap().entries.map((entry) {
      final idx = entry.key;
      final def = entry.value;
      final isTouched = idx == _touchedIndex;
      final pct = ((def.value / total) * 100).toStringAsFixed(0);

      return PieChartSectionData(
        value: def.value == 0 ? 0.001 : def.value,
        color: isDark ? def.darkColor : def.color,
        radius: isTouched ? 52 : 44,
        title: isTouched ? '$pct%' : '',
        titleStyle: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
            ),
          ],
        ),
        titlePositionPercentageOffset: 0.6,
      );
    }).toList();
  }

  Widget _buildLegendRow({
    required bool isDark,
    required Color color,
    required String label,
    required double amount,
    required double total,
  }) {
    final pct = total > 0 ? ((amount / total) * 100).toStringAsFixed(0) : '0';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
        ),
      ),
      child: Row(
        children: [
          // Color dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 6,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Label
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Percentage
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$pct%',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Amount
          Text(
            '₹${_formatAmount(amount)}',
            style: TextStyle(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
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
}

/// Internal model for pie chart section definition.
class _SectionDef {
  final double value;
  final Color color;
  final Color darkColor;
  const _SectionDef({
    required this.value,
    required this.color,
    required this.darkColor,
  });
}
