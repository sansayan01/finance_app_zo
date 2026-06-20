import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/progress_gauge.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../../../core/widgets/sparkline_chart.dart';
import '../../data/models/customer_emi_model.dart';
import '../../data/providers/customer_loans_providers.dart';
import '../widgets/customer_empty_state.dart';
import '../../../../payments/presentation/widgets/upi_payment_sheet.dart';

class CustomerEmiSchedulePage extends ConsumerStatefulWidget {
  final String loanId;

  const CustomerEmiSchedulePage({super.key, required this.loanId});

  @override
  ConsumerState<CustomerEmiSchedulePage> createState() =>
      _CustomerEmiSchedulePageState();
}

class _CustomerEmiSchedulePageState
    extends ConsumerState<CustomerEmiSchedulePage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _staggerController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  // ─── Indian currency formatting ───
  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(value);
  }

  String _formatPlainAmount(double value) {
    final n = value.round();
    final s = n.toString();
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    final rest = s.substring(0, s.length - 3);
    final buf = StringBuffer();
    for (int i = 0; i < rest.length; i++) {
      buf.write(rest[i]);
      final remaining = rest.length - i - 1;
      if (remaining > 0 && remaining % 2 == 0) buf.write(',');
    }
    return '${buf.toString()},$last3';
  }

  static const _months = [
    '',
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
    'Dec',
  ];

  String _formatPaidRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'today';
    if (d == today.subtract(const Duration(days: 1))) return 'yesterday';
    return 'on ${_months[date.month]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final emiAsync = ref.watch(customerEmiScheduleProvider(widget.loanId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final headerGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF1A1F3A), Color(0xFF151A30)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [AppColors.primary, AppColors.accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      extendBody: true,
      body: emiAsync.when(
        loading: () => _buildLoadingState(isDark, headerGradient),
        error: (e, _) => _buildErrorState(e, isDark, headerGradient),
        data: (emis) {
          if (emis.isEmpty) {
            return _buildEmptyState(isDark, headerGradient);
          }

          final sorted = [...emis]
            ..sort((a, b) {
              final ad = a.dueDate;
              final bd = b.dueDate;
              if (ad == null && bd == null) return a.emiNumber - b.emiNumber;
              if (ad == null) return 1;
              if (bd == null) return -1;
              return ad.compareTo(bd);
            });

          final paidCount = sorted.where((e) => e.isPaid).length;
          final totalPaid = sorted
              .where((e) => e.isPaid)
              .fold(0.0, (s, e) => s + e.amountPaid);
          final totalPending = sorted
              .where((e) => !e.isPaid)
              .fold(0.0, (s, e) => s + e.emiAmount);
          final totalPenalty =
              sorted.fold(0.0, (s, e) => s + (e.penaltyAmount ?? 0));
          final loanTotal = sorted.fold(0.0, (s, e) => s + e.emiAmount);
          final progress =
              sorted.isEmpty ? 0.0 : (paidCount / sorted.length).clamp(0.0, 1.0);

          // Cumulative paid sparkline data
          final List<double> cumulativePaid = [];
          double running = 0;
          for (final e in sorted) {
            if (e.isPaid) running += e.amountPaid;
            cumulativePaid.add(running);
          }
          // Ensure sparkline has at least 2 distinct points
          if (cumulativePaid.length < 2) {
            cumulativePaid.add(running == 0 ? 1 : running);
          }
          if (cumulativePaid.toSet().length == 1) {
            cumulativePaid[cumulativePaid.length - 1] =
                cumulativePaid.last + 0.0001;
          }

          // Group by month
          final groups = <String, List<CustomerEmiModel>>{};
          for (final e in sorted) {
            final key = e.dueDate != null
                ? '${_months[e.dueDate!.month]} ${e.dueDate!.year}'
                : 'Unscheduled';
            groups.putIfAbsent(key, () => []).add(e);
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_staggerController.status == AnimationStatus.dismissed) {
              _staggerController.forward();
            }
          });

          // Flat index for staggering across groups
          int flatIndex = 0;
          final slivers = <Widget>[];
          slivers.add(
            SliverToBoxAdapter(
              child: _buildGradientHeader(
                context: context,
                isDark: isDark,
                gradient: headerGradient,
                loanTotal: loanTotal,
                emiCount: sorted.length,
                totalPending: totalPending,
              ),
            ),
          );
          slivers.add(
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildSummaryCard(
                  isDark: isDark,
                  theme: theme,
                  paidCount: paidCount,
                  totalEmis: sorted.length,
                  totalPaid: totalPaid,
                  totalPending: totalPending,
                  totalPenalty: totalPenalty,
                  progress: progress,
                  sparkline: cumulativePaid,
                ),
              ),
            ),
          );

          groups.forEach((monthKey, items) {
            slivers.add(
              SliverPersistentHeader(
                pinned: true,
                delegate: _MonthHeaderDelegate(
                  label: monthKey,
                  count: items.length,
                  isDark: isDark,
                ),
              ),
            );
            for (final emi in items) {
              final currentIndex = flatIndex++;
              slivers.add(
                SliverToBoxAdapter(
                  child: _StaggeredEntry(
                    index: currentIndex,
                    controller: _staggerController,
                    child: _PremiumEmiRow(
                      emi: emi,
                      isDark: isDark,
                      theme: theme,
                      formatCurrency: _formatCurrency,
                      formatPlain: _formatPlainAmount,
                      formatPaidRelative: _formatPaidRelative,
                      months: _months,
                      isFirst: currentIndex == 0,
                      isLast: currentIndex == sorted.length - 1,
                    ),
                  ),
                ),
              );
            }
          });

          slivers.add(const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.xxl),
          ));

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              _staggerController.reset();
              ref.invalidate(customerEmiScheduleProvider(widget.loanId));
              await Future.delayed(const Duration(milliseconds: 300));
              if (mounted) _staggerController.forward();
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: slivers,
            ),
          );
        },
      ),
    );
  }

  // ─── Gradient Header ───
  Widget _buildGradientHeader({
    required BuildContext context,
    required bool isDark,
    required Gradient gradient,
    required double loanTotal,
    required int emiCount,
    double totalPending = 0,
  }) {
    final topPad = MediaQuery.of(context).padding.top + 8;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        topPad,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppColors.primary)
                .withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _circleIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => context.pop(),
                ),
                const Spacer(),
                _headerChip(
                  icon: Icons.receipt_long_rounded,
                  label: 'Loan #${_shortId(widget.loanId)}',
                ),
                if (totalPending > 0) ...[
                  const SizedBox(width: 8),
                  _upiPayButton(totalPending),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Repayment',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.7),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'EMI Schedule',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.8,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_formatCurrency(loanTotal)} • $emiCount installments',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.75),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _shortId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 4)}…${id.substring(id.length - 4)}';
  }

  Widget _circleIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Widget _headerChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _upiPayButton(double amount) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => UpiPaymentSheet.show(
          context,
          amount: amount,
          loanId: widget.loanId,
          emiScheduleId: null,
          loanNumber: _shortId(widget.loanId),
          emiNumber: null,
        ),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.payments_rounded, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Text(
                'Pay via UPI',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Summary Card ───
  Widget _buildSummaryCard({
    required bool isDark,
    required ThemeData theme,
    required int paidCount,
    required int totalEmis,
    required double totalPaid,
    required double totalPending,
    required double totalPenalty,
    required double progress,
    required List<double> sparkline,
  }) {
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor =
        isDark ? AppColors.separatorDark : AppColors.separatorLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final textTertiary =
        isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    final pct = (progress * 100).clamp(0.0, 100.0);

    return Transform.translate(
      offset: const Offset(0, -20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ProgressGauge(
                    value: progress,
                    size: 84,
                    strokeWidth: 8,
                    progressColor: progress >= 1.0
                        ? AppColors.success
                        : AppColors.primary,
                    backgroundColor:
                        isDark ? AppColors.fillDark : AppColors.fillLight,
                    center: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: pct),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${v.toInt()}%',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                              letterSpacing: -0.5,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          Text(
                            'done',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '$paidCount',
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                  letterSpacing: -1.2,
                                  fontFeatures: [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              TextSpan(
                                text: ' / $totalEmis',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w500,
                                  color: textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Installments completed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _paidVsPendingPill(
                          isDark: isDark,
                          paid: totalPaid,
                          pending: totalPending,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Divider(color: borderColor, height: 1),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _miniStat(
                      label: 'Total Paid',
                      icon: Icons.check_circle_rounded,
                      color: AppColors.success,
                      isDark: isDark,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: totalPaid),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => Text(
                          _formatCurrency(v),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            letterSpacing: -0.4,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _miniStat(
                      label: 'Pending',
                      icon: Icons.pending_actions_rounded,
                      color: AppColors.warning,
                      isDark: isDark,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: totalPending),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => Text(
                          _formatCurrency(v),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            letterSpacing: -0.4,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (totalPenalty > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.error,
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Penalties accrued',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatCurrency(totalPenalty),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.error,
                          letterSpacing: -0.4,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (totalPaid > 0) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Icon(
                      Icons.show_chart_rounded,
                      size: 14,
                      color: textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Cumulative paid',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textTertiary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SparklineChart(
                  data: sparkline,
                  color: AppColors.success,
                  height: 38,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _paidVsPendingPill({
    required bool isDark,
    required double paid,
    required double pending,
  }) {
    final total = paid + pending;
    final paidRatio = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: isDark ? AppColors.fillDark : AppColors.fillLight,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        children: [
          Expanded(
            flex: (paidRatio * 1000).round().clamp(0, 1000),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.success, AppColors.primary],
                ),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Expanded(
            flex: ((1 - paidRatio) * 1000).round().clamp(0, 1000),
            child: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _miniStat({
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Widget child,
  }) {
    final textTertiary =
        isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 4,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textTertiary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  // ─── Loading / Error / Empty ───
  Widget _buildLoadingState(bool isDark, Gradient gradient) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _buildGradientHeader(
            context: context,
            isDark: isDark,
            gradient: gradient,
            loanTotal: 0,
            emiCount: 0,
          ),
        ),
        SliverToBoxAdapter(
          child: Transform.translate(
            offset: const Offset(0, -20),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: ShimmerCard(height: 220, borderRadius: 22),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, __) => const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                4,
                AppSpacing.md,
                4,
              ),
              child: ShimmerCard(height: 76, borderRadius: 16),
            ),
            childCount: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(Object error, bool isDark, Gradient gradient) {
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textTertiary =
        isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    return Column(
      children: [
        _buildGradientHeader(
          context: context,
          isDark: isDark,
          gradient: gradient,
          loanTotal: 0,
          emiCount: 0,
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 56,
                    color: AppColors.error.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Something went wrong',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '$error',
                    style: TextStyle(fontSize: 13, color: textTertiary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark, Gradient gradient) {
    return Column(
      children: [
        _buildGradientHeader(
          context: context,
          isDark: isDark,
          gradient: gradient,
          loanTotal: 0,
          emiCount: 0,
        ),
        const Expanded(
          child: CustomerEmptyState(
            icon: Icons.calendar_month_rounded,
            title: 'No EMIs',
            subtitle: 'No EMI schedule found for this loan.',
          ),
        ),
      ],
    );
  }
}

// ─── Sticky Month Header ───
class _MonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String label;
  final int count;
  final bool isDark;

  _MonthHeaderDelegate({
    required this.label,
    required this.count,
    required this.isDark,
  });

  @override
  double get minExtent => 44;
  @override
  double get maxExtent => 44;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final bg = isDark
        ? AppColors.backgroundDark.withValues(alpha: 0.92)
        : AppColors.backgroundLight.withValues(alpha: 0.92);
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textTertiary =
        isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primary, AppColors.accent],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            count == 1 ? 'EMI' : 'EMIs',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _MonthHeaderDelegate old) =>
      old.label != label || old.count != count || old.isDark != isDark;
}

// ─── Staggered entry wrapper ───
class _StaggeredEntry extends StatefulWidget {
  final int index;
  final AnimationController controller;
  final Widget child;

  const _StaggeredEntry({
    required this.index,
    required this.controller,
    required this.child,
  });

  @override
  State<_StaggeredEntry> createState() => _StaggeredEntryState();
}

class _StaggeredEntryState extends State<_StaggeredEntry> {
  late final CurvedAnimation _animation;

  @override
  void initState() {
    super.initState();
    final start = (widget.index * 0.07).clamp(0.0, 0.85);
    final end = (start + 0.3).clamp(0.0, 1.0);
    _animation = CurvedAnimation(
      parent: widget.controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(_animation),
        child: widget.child,
      ),
    );
  }
}

// ─── Premium EMI row ───
class _PremiumEmiRow extends StatelessWidget {
  final CustomerEmiModel emi;
  final bool isDark;
  final ThemeData theme;
  final String Function(double) formatCurrency;
  final String Function(double) formatPlain;
  final String Function(DateTime) formatPaidRelative;
  final List<String> months;
  final bool isFirst;
  final bool isLast;

  const _PremiumEmiRow({
    required this.emi,
    required this.isDark,
    required this.theme,
    required this.formatCurrency,
    required this.formatPlain,
    required this.formatPaidRelative,
    required this.months,
    this.isFirst = false,
    this.isLast = false,
  });

  Color get _statusColor {
    if (emi.isPaid) return AppColors.success;
    if (emi.isOverdue) return AppColors.error;
    return AppColors.primary;
  }

  String get _statusLabel {
    if (emi.isPaid) return 'Paid';
    if (emi.isOverdue) return 'Overdue';
    return 'Upcoming';
  }

  IconData get _statusIcon {
    if (emi.isPaid) return Icons.check_rounded;
    if (emi.isOverdue) return Icons.error_outline_rounded;
    return Icons.schedule_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor =
        isDark ? AppColors.separatorDark : AppColors.separatorLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final textTertiary =
        isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    final dueLabel = emi.dueDate != null
        ? '${months[emi.dueDate!.month]} ${emi.dueDate!.day}, ${emi.dueDate!.year}'
        : 'Unscheduled';

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 0),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left timeline graphic column
            SizedBox(
              width: 32,
              child: CustomPaint(
                painter: _TimelinePainter(
                  color: _statusColor,
                  isFirst: isFirst,
                  isLast: isLast,
                  isPaid: emi.isPaid,
                  isDark: isDark,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Right detail card
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm + 4,
                      AppSpacing.md,
                      AppSpacing.sm + 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // EMI number badge
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _statusColor.withValues(
                                  alpha: isDark ? 0.18 : 0.10,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _statusColor.withValues(
                                    alpha: isDark ? 0.3 : 0.18,
                                  ),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: emi.isPaid
                                  ? Icon(
                                      _statusIcon,
                                      size: 18,
                                      color: _statusColor,
                                    )
                                  : Text(
                                      '${emi.emiNumber}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: _statusColor,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                            ),
                            const SizedBox(width: AppSpacing.sm + 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'EMI #${emi.emiNumber}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 3,
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: textTertiary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          dueLabel,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: textSecondary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (emi.isPaid && emi.paidOn != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        'Paid ${formatPaidRelative(emi.paidOn!)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.success.withValues(
                                            alpha: isDark ? 0.85 : 0.75,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Row(
                                        children: [
                                          _principalInterestChip(
                                            label: 'P',
                                            value: emi.principal,
                                            color: AppColors.primary,
                                            isDark: isDark,
                                          ),
                                          const SizedBox(width: 6),
                                          _principalInterestChip(
                                            label: 'I',
                                            value: emi.interest,
                                            color: AppColors.accent,
                                            isDark: isDark,
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${formatPlain(emi.emiAmount)}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                    letterSpacing: -0.4,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor.withValues(
                                      alpha: isDark ? 0.18 : 0.10,
                                    ),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _statusIcon,
                                        size: 10,
                                        color: _statusColor,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        _statusLabel,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: _statusColor,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (emi.isPaid &&
                            (emi.principal > 0 || emi.interest > 0)) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _principalInterestChip(
                                label: 'Principal',
                                value: emi.principal,
                                color: AppColors.primary,
                                isDark: isDark,
                                expanded: true,
                              ),
                              const SizedBox(width: 6),
                              _principalInterestChip(
                                label: 'Interest',
                                value: emi.interest,
                                color: AppColors.accent,
                                isDark: isDark,
                                expanded: true,
                              ),
                            ],
                          ),
                        ],
                        if ((emi.penaltyAmount ?? 0) > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 12,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Penalty ₹${formatPlain(emi.penaltyAmount!)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.error,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
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

  Widget _principalInterestChip({
    required String label,
    required double value,
    required Color color,
    required bool isDark,
    bool expanded = false,
  }) {
    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? 10 : 6,
        vertical: expanded ? 6 : 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: expanded ? 10 : 9,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '₹${NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 0).format(value)}',
            style: TextStyle(
              fontSize: expanded ? 11 : 10,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
    return expanded ? Expanded(child: content) : content;
  }
}

class _TimelinePainter extends CustomPainter {
  final Color color;
  final bool isFirst;
  final bool isLast;
  final bool isPaid;
  final bool isDark;

  _TimelinePainter({
    required this.color,
    required this.isFirst,
    required this.isLast,
    required this.isPaid,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paintLine = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final paintProgressLine = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Draw background vertical line segment
    final startY = isFirst ? center.dy : 0.0;
    final endY = isLast ? center.dy : size.height;
    canvas.drawLine(Offset(center.dx, startY), Offset(center.dx, endY), paintLine);

    // If paid, draw progress colored line
    if (isPaid) {
      canvas.drawLine(Offset(center.dx, startY), Offset(center.dx, endY), paintProgressLine);
    }

    // Outer glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 11, glowPaint);

    // Dynamic dot
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 6, dotPaint);

    // Inner pin
    final innerPin = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 2.0, innerPin);
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.isFirst != isFirst ||
      oldDelegate.isLast != isLast ||
      oldDelegate.isPaid != isPaid ||
      oldDelegate.isDark != isDark;
}
