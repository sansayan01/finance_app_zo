import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import 'customer_payment_trend_chart.dart';
import 'customer_savings_growth_chart.dart';
import 'customer_loan_breakdown_chart.dart';

/// Composes all customer dashboard charts into a staggered-animated section.
/// Displays: section title, payment trend, savings growth, loan breakdown.
class CustomerDashboardCharts extends StatefulWidget {
  final List<MonthlyPaymentData> paymentTrend;
  final List<MonthlyPaymentData> savingsGrowth;
  final double loanPaid;
  final double loanOutstanding;
  final double loanInterest;

  const CustomerDashboardCharts({
    super.key,
    required this.paymentTrend,
    required this.savingsGrowth,
    required this.loanPaid,
    required this.loanOutstanding,
    required this.loanInterest,
  });

  @override
  State<CustomerDashboardCharts> createState() =>
      _CustomerDashboardChartsState();
}

class _CustomerDashboardChartsState extends State<CustomerDashboardCharts>
    with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Animation<double> _staggered(int index, {double duration = 0.5}) {
    final start = (index * 0.15).clamp(0.0, 1.0);
    final end = (start + duration).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _staggerController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          _StaggeredFadeSlide(
            animation: _staggered(0),
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xs,
                top: AppSpacing.md,
                bottom: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.indigo, AppColors.accent],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Insights',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Payment trend chart
          _StaggeredFadeSlide(
            animation: _staggered(1),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: CustomerPaymentTrendChart(data: widget.paymentTrend),
            ),
          ),

          // Savings growth chart
          _StaggeredFadeSlide(
            animation: _staggered(2),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: CustomerSavingsGrowthChart(data: widget.savingsGrowth),
            ),
          ),

          // Loan breakdown chart
          _StaggeredFadeSlide(
            animation: _staggered(3),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: CustomerLoanBreakdownChart(
                paid: widget.loanPaid,
                outstanding: widget.loanOutstanding,
                interest: widget.loanInterest,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable staggered fade + slide animation wrapper.
class _StaggeredFadeSlide extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _StaggeredFadeSlide({
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - animation.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
