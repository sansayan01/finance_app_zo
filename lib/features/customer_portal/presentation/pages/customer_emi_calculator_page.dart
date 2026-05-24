// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/services/customer_emi_calculator_service.dart';

class CustomerEmiCalculatorPage extends ConsumerStatefulWidget {
  const CustomerEmiCalculatorPage({super.key});

  @override
  ConsumerState<CustomerEmiCalculatorPage> createState() =>
      _CustomerEmiCalculatorPageState();
}

class _CustomerEmiCalculatorPageState
    extends ConsumerState<CustomerEmiCalculatorPage>
    with TickerProviderStateMixin {
  // ── Input state ──
  double _loanAmount = 100000;
  double _interestRate = 12.0;
  double _tenure = 24;

  // ── Animated values ──
  double _animatedEmi = 0;
  double _animatedTotalInterest = 0;
  double _animatedTotalPayment = 0;

  // ── Schedule state ──
  bool _showFullSchedule = false;
  List<Map<String, dynamic>> _schedule = [];

  // ── Animations ──
  late AnimationController _staggerController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideHeader;
  late Animation<Offset> _slideInputs;
  late Animation<Offset> _slideResults;
  late Animation<Offset> _slideSchedule;

  @override
  void initState() {
    super.initState();

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeIn = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    );

    _slideHeader = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOutCubic),
    ));

    _slideInputs = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.15, 0.5, curve: Curves.easeOutCubic),
    ));

    _slideResults = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.35, 0.7, curve: Curves.easeOutCubic),
    ));

    _slideSchedule = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
    ));

    _staggerController.forward();
    _recalculate();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  void _recalculate() {
    final emi = CustomerEmiCalculatorService.calculateEMI(
      _loanAmount,
      _interestRate,
      _tenure.toInt(),
    );
    final totalPayment = CustomerEmiCalculatorService.calculateTotalPayment(
      emi,
      _tenure.toInt(),
    );
    final totalInterest = CustomerEmiCalculatorService.calculateTotalInterest(
      totalPayment,
      _loanAmount,
    );

    setState(() {
      _animatedEmi = emi;
      _animatedTotalInterest = totalInterest;
      _animatedTotalPayment = totalPayment;
      _schedule = CustomerEmiCalculatorService.generateSchedule(
        _loanAmount,
        _interestRate,
        _tenure.toInt(),
      );
      _showFullSchedule = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: FadeTransition(
        opacity: _fadeIn,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Gradient Header ──
            SliverToBoxAdapter(
              child: SlideTransition(
                position: _slideHeader,
                child: _buildHeader(isDark),
              ),
            ),

            // ── Input Section ──
            SliverToBoxAdapter(
              child: SlideTransition(
                position: _slideInputs,
                child: _buildInputSection(isDark),
              ),
            ),

            // ── Results Section ──
            SliverToBoxAdapter(
              child: SlideTransition(
                position: _slideResults,
                child: _buildResultsSection(isDark),
              ),
            ),

            // ── Repayment Schedule ──
            SliverToBoxAdapter(
              child: SlideTransition(
                position: _slideSchedule,
                child: _buildScheduleSection(isDark),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 40),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Header
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        MediaQuery.of(context).padding.top + 12,
        AppSpacing.md,
        28,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.indigo,
            AppColors.accent,
            AppColors.accentLight.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.indigo.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildGlassIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              Text(
                'EMI Calculator',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Plan your loan repayment',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Input Section
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildInputSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        backgroundColor: isDark ? AppColors.cardDark : AppColors.surfaceLight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel('Loan Parameters', isDark),
            const SizedBox(height: 20),
            _buildLoanAmountSlider(isDark),
            const SizedBox(height: 24),
            _buildInterestRateSlider(isDark),
            const SizedBox(height: 24),
            _buildTenureSlider(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, bool isDark) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.indigo, AppColors.accent],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildLoanAmountSlider(bool isDark) {
    return _buildSliderRow(
      isDark: isDark,
      label: 'Loan Amount',
      valueDisplay: _formatCurrency(_loanAmount),
      value: _loanAmount,
      min: 10000,
      max: 5000000,
      divisions: 499,
      onChanged: (v) {
        setState(() => _loanAmount = v);
        _recalculate();
      },
    );
  }

  Widget _buildInterestRateSlider(bool isDark) {
    return _buildSliderRow(
      isDark: isDark,
      label: 'Interest Rate',
      valueDisplay: '${_interestRate.toStringAsFixed(1)}% p.a.',
      value: _interestRate,
      min: 1,
      max: 36,
      divisions: 350,
      onChanged: (v) {
        setState(() => _interestRate = v);
        _recalculate();
      },
    );
  }

  Widget _buildTenureSlider(bool isDark) {
    return _buildSliderRow(
      isDark: isDark,
      label: 'Tenure',
      valueDisplay: '${_tenure.toInt()} months',
      value: _tenure,
      min: 1,
      max: 60,
      divisions: 59,
      onChanged: (v) {
        setState(() => _tenure = v);
        _recalculate();
      },
    );
  }

  Widget _buildSliderRow({
    required bool isDark,
    required String label,
    required String valueDisplay,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.indigo.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.indigo.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: Text(
                valueDisplay,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.indigo,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 6,
            activeTrackColor: Colors.transparent,
            inactiveTrackColor:
                isDark ? AppColors.fillDark : AppColors.fillLight,
            thumbColor: AppColors.indigo,
            thumbShape: _GradientThumbShape(),
            overlayColor: AppColors.indigo.withValues(alpha: 0.15),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Results Section
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildResultsSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: [
          // ── EMI Hero Card ──
          GlassCard(
            padding: const EdgeInsets.all(24),
            backgroundColor:
                isDark ? AppColors.cardDark : AppColors.surfaceLight,
            elevated: true,
            child: Column(
              children: [
                Text(
                  'Monthly EMI',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: _animatedEmi),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return Text(
                      _formatCurrency(value),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        foreground: Paint()
                          ..shader = LinearGradient(
                            colors: [AppColors.indigo, AppColors.accentLight],
                          ).createShader(
                            const Rect.fromLTWH(0, 0, 220, 40),
                          ),
                        letterSpacing: -1,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  'per month',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Interest & Total Payment Row ──
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  isDark: isDark,
                  label: 'Total Interest',
                  value: _animatedTotalInterest,
                  icon: Icons.trending_up_rounded,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  isDark: isDark,
                  label: 'Total Payment',
                  value: _animatedTotalPayment,
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Donut Chart ──
          GlassCard(
            padding: const EdgeInsets.all(20),
            backgroundColor:
                isDark ? AppColors.cardDark : AppColors.surfaceLight,
            child: _buildBreakdownChart(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required bool isDark,
    required String label,
    required double value,
    required IconData icon,
    required Color color,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: isDark ? AppColors.cardDark : AppColors.surfaceLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, val, _) {
              return Text(
                _formatCurrency(val),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                  letterSpacing: -0.3,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownChart(bool isDark) {
    final principal = _loanAmount;
    final interest = _animatedTotalInterest;
    final total = principal + interest;
    final principalPct = total > 0 ? (principal / total * 100) : 0;
    final interestPct = total > 0 ? (interest / total * 100) : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Payment Breakdown', isDark),
        const SizedBox(height: 20),
        SizedBox(
          height: 180,
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, animValue, _) {
                    return PieChart(
                      PieChartData(
                        centerSpaceRadius: 40,
                        sectionsSpace: 3,
                        startDegreeOffset: -90,
                        sections: [
                          PieChartSectionData(
                            value: principal * animValue,
                            color: AppColors.indigo,
                            radius: 32,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: interest * animValue,
                            color: AppColors.accentLight,
                            radius: 32,
                            showTitle: false,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem(
                      color: AppColors.indigo,
                      label: 'Principal',
                      percentage: '${principalPct.toStringAsFixed(1)}%',
                      amount: _formatCurrency(principal),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildLegendItem(
                      color: AppColors.accentLight,
                      label: 'Interest',
                      percentage: '${interestPct.toStringAsFixed(1)}%',
                      amount: _formatCurrency(interest),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required String percentage,
    required String amount,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ),
              Text(
                '$percentage  $amount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Repayment Schedule
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildScheduleSection(bool isDark) {
    if (_schedule.isEmpty) return const SizedBox.shrink();

    final visibleRows = _showFullSchedule ? _schedule : _schedule.take(5).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        backgroundColor: isDark ? AppColors.cardDark : AppColors.surfaceLight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel('Repayment Schedule', isDark),
            const SizedBox(height: 16),

            // ── Table header ──
            _buildScheduleHeader(isDark),
            const SizedBox(height: 8),

            // ── Rows ──
            ...List.generate(visibleRows.length, (index) {
              final row = visibleRows[index];
              final isEven = index % 2 == 0;
              return _buildScheduleRow(
                isDark: isDark,
                period: row['emiNumber'] as int,
                emi: row['emiAmount'] as double,
                principal: row['principal'] as double,
                interest: row['interest'] as double,
                balance: row['balanceAfter'] as double,
                isEven: isEven,
                isLast: index == visibleRows.length - 1,
              );
            }),

            // ── Expand / Collapse toggle ──
            if (_schedule.length > 5)
              GestureDetector(
                onTap: () => setState(() => _showFullSchedule = !_showFullSchedule),
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.indigo.withValues(alpha: isDark ? 0.1 : 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.indigo.withValues(alpha: 0.15),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _showFullSchedule
                            ? 'Show Less'
                            : 'View Full Schedule (${_schedule.length} months)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.indigo,
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: _showFullSchedule ? 0.5 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.indigo,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleHeader(bool isDark) {
    final style = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
      letterSpacing: 0.5,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('PERIOD', style: style)),
          Expanded(flex: 3, child: Text('EMI', style: style, textAlign: TextAlign.right)),
          Expanded(flex: 3, child: Text('PRINCIPAL', style: style, textAlign: TextAlign.right)),
          Expanded(flex: 3, child: Text('INTEREST', style: style, textAlign: TextAlign.right)),
          Expanded(flex: 3, child: Text('BALANCE', style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildScheduleRow({
    required bool isDark,
    required int period,
    required double emi,
    required double principal,
    required double interest,
    required double balance,
    required bool isEven,
    required bool isLast,
    }) {
    final textStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
    );
    final mutedStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: isEven
            ? (isDark ? AppColors.fillDark.withValues(alpha: 0.3) : AppColors.fillLight)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(isLast ? 0 : 4),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.indigo.withValues(alpha: 0.15),
                    AppColors.accent.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$period',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.indigo,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(_formatCompact(emi), style: textStyle, textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 3,
            child: Text(_formatCompact(principal), style: mutedStyle, textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 3,
            child: Text(_formatCompact(interest), style: mutedStyle, textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 3,
            child: Text(_formatCompact(balance), style: textStyle, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Formatting
  // ═══════════════════════════════════════════════════════════════════════════

  String _formatCurrency(double value) {
    if (value >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(2)} Cr';
    } else if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(2)} L';
    }
    return '₹${_addCommas(value.toStringAsFixed(0))}';
  }

  String _formatCompact(double value) {
    if (value >= 10000000) {
      return '${(value / 10000000).toStringAsFixed(1)}Cr';
    } else if (value >= 100000) {
      return '${(value / 100000).toStringAsFixed(1)}L';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }

  String _addCommas(String numberStr) {
    final parts = numberStr.split('.');
    final intPart = parts[0];
    final result = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      result.write(intPart[i]);
      count++;
      if (count == 3 && i > 0) {
        result.write(',');
        count = 0;
      }
    }
    return result.toString().split('').reversed.join();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Custom gradient thumb for sliders
// ═══════════════════════════════════════════════════════════════════════════════

class _GradientThumbShape extends SliderComponentShape {
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size(22, 22);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    // Outer glow
    final glowPaint = Paint()
      ..color = AppColors.indigo.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center, 14, glowPaint);

    // White background
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, 10, bgPaint);

    // Gradient fill
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        colors: [AppColors.indigo, AppColors.accentLight],
      ).createShader(Rect.fromCircle(center: center, radius: 8));
    canvas.drawCircle(center, 8, gradientPaint);

    // Inner dot
    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, 3, dotPaint);
  }
}
