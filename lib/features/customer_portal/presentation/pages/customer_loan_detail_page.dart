import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/constants/layout.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/progress_gauge.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../../loans/data/models/emi_schedule_model.dart';
import '../../../loans/data/models/loan_model.dart';
import '../../../loans/data/services/loan_statement_pdf_service.dart';
import '../../data/models/customer_loan_model.dart';
import '../../data/models/customer_emi_model.dart';
import '../../data/providers/customer_loans_providers.dart';
import '../widgets/customer_loan_breakdown_chart.dart';
import '../widgets/customer_emi_tile.dart';
import '../widgets/customer_empty_state.dart';

class CustomerLoanDetailPage extends ConsumerStatefulWidget {
  final String loanId;

  const CustomerLoanDetailPage({super.key, required this.loanId});

  @override
  ConsumerState<CustomerLoanDetailPage> createState() =>
      _CustomerLoanDetailPageState();
}

class _CustomerLoanDetailPageState extends ConsumerState<CustomerLoanDetailPage>
    with TickerProviderStateMixin {
  late final AnimationController _staggerController;
  Uint8List? _generatedPdfBytes;
  String? _statementFilename;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _staggerController.forward();
    });
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loanAsync = ref.watch(customerLoanDetailProvider(widget.loanId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      extendBody: true,
      body: loanAsync.when(
        loading: () => _buildLoadingState(context, isDark),
        error: (e, _) => _buildErrorState(context, isDark, e),
        data: (loan) {
          if (loan == null) return _buildNotFound(context, isDark);
          return _buildBody(context, loan);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, CustomerLoanModel loan) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final paidAmount = (loan.amount - loan.outstandingBalance).clamp(
      0.0,
      loan.amount,
    );
    final mq = MediaQuery.of(context);
    final statusBarHeight = mq.padding.top;

    // Estimated interest for breakdown chart.
    final estimatedTotal = loan.emiAmount * loan.tenureMonths;
    final estimatedInterest =
        (estimatedTotal - loan.amount).clamp(0.0, double.infinity);

    final emiScheduleAsync =
        ref.watch(customerEmiScheduleProvider(widget.loanId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(customerLoanDetailProvider(widget.loanId));
        ref.invalidate(customerEmiScheduleProvider(widget.loanId));
      },
      color: AppColors.primary,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeroHeader(context, loan, isDark, statusBarHeight),
          ),

          // Progress + metrics
          SliverToBoxAdapter(
            child: _buildAnimatedSection(
              index: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.lg, AppSpacing.md, 0),
                child: _buildProgressSection(context, loan, isDark, paidAmount),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildAnimatedSection(
              index: 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                child: _buildKeyMetrics(context, loan, isDark),
              ),
            ),
          ),

          // Breakdown chart
          SliverToBoxAdapter(
            child: _buildAnimatedSection(
              index: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                child: CustomerLoanBreakdownChart(
                  paid: paidAmount,
                  outstanding: loan.outstandingBalance,
                  interest: estimatedInterest,
                ),
              ),
            ),
          ),

          // Schedule preview
          SliverToBoxAdapter(
            child: _buildAnimatedSection(
              index: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                child: _buildSchedulePreview(
                  context,
                  isDark,
                  emiScheduleAsync,
                ),
              ),
            ),
          ),

          // Payment history snapshot
          SliverToBoxAdapter(
            child: _buildAnimatedSection(
              index: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                child: _buildPaymentHistory(
                  context,
                  isDark,
                  emiScheduleAsync,
                ),
              ),
            ),
          ),

          // Details card
          SliverToBoxAdapter(
            child: _buildAnimatedSection(
              index: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                child: _buildDetailsCard(context, loan, isDark),
              ),
            ),
          ),

          // Secondary CTA: full schedule
          SliverToBoxAdapter(
            child: _buildAnimatedSection(
              index: 7,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
                child: _buildScheduleButton(context, isDark),
              ),
            ),
          ),

          // Statement download
          SliverToBoxAdapter(
            child: _buildAnimatedSection(
              index: 8,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
                child: _buildStatementButton(context, isDark, loan),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(
      BuildContext context, CustomerLoanModel loan, bool isDark, double topPad) {
    final theme = Theme.of(context);

    final gradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF1A1F3A), Color(0xFF151A30)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : AppColors.primaryGradient;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        topPad + AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CircleIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => context.pop(),
                isDark: isDark,
              ),
              const Spacer(),
              StatusBadge(
                label: loan.status[0].toUpperCase() + loan.status.substring(1),
                type: _statusType(loan.status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            loan.loanNumber ?? 'Loan Details',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Animated principal
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: loan.amount),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return Text(
                '₹${_formatAmount(value)}',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 38,
                  letterSpacing: -1,
                  height: 1.1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          if (loan.purpose != null)
            Text(
              loan.purpose!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(BuildContext context, CustomerLoanModel loan,
      bool isDark, double paidAmount) {
    final theme = Theme.of(context);
    final gaugeColor = loan.isOverdue ? AppColors.error : AppColors.success;

    return GlassCard(
      elevated: true,
      borderRadius: 20,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          ProgressGauge(
            value: (loan.paidPercentage / 100).clamp(0.0, 1.0),
            size: 104,
            strokeWidth: 10,
            progressColor: gaugeColor,
            backgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: loan.paidPercentage),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return Text(
                      '${value.toStringAsFixed(0)}%',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: gaugeColor,
                        fontSize: 22,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    );
                  },
                ),
                Text(
                  'paid',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Repayment Progress',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _ProgressStat(
                  label: 'Paid',
                  value: '₹${_formatAmount(paidAmount)}',
                  color: AppColors.success,
                  isDark: isDark,
                ),
                const SizedBox(height: AppSpacing.sm),
                _ProgressStat(
                  label: 'Remaining',
                  value: '₹${_formatAmount(loan.outstandingBalance)}',
                  color: loan.isOverdue ? AppColors.error : AppColors.warning,
                  isDark: isDark,
                ),
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressBar(
                    value: (loan.paidPercentage / 100).clamp(0.0, 1.0),
                    height: 6,
                    progressColor: gaugeColor,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyMetrics(
      BuildContext context, CustomerLoanModel loan, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.account_balance_wallet_rounded,
            label: 'EMI',
            value: '₹${_formatAmount(loan.emiAmount)}',
            color: AppColors.indigo,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _MetricCard(
            icon: Icons.percent_rounded,
            label: 'Interest',
            value: '${loan.interestRate.toStringAsFixed(1)}%',
            color: AppColors.orange,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _MetricCard(
            icon: Icons.schedule_rounded,
            label: 'Tenure',
            value: '${loan.tenureMonths}mo',
            color: AppColors.teal,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildSchedulePreview(
    BuildContext context,
    bool isDark,
    AsyncValue<List<CustomerEmiModel>> emisAsync,
  ) {
    final theme = Theme.of(context);

    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary
                      .withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.borderRadiusMd),
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Upcoming EMIs',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context
                    .push('/customer/loans/${widget.loanId}/schedule'),
                child: Row(
                  children: [
                    Text(
                      'View all',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          emisAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                children: [
                  ShimmerCard(height: 62, borderRadius: 12),
                  SizedBox(height: 8),
                  ShimmerCard(height: 62, borderRadius: 12),
                ],
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                'Couldn\'t load schedule.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.error.withValues(alpha: 0.8),
                ),
              ),
            ),
            data: (emis) {
              final upcoming = emis.where((e) => !e.isPaid).take(4).toList();
              if (upcoming.isEmpty) {
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(
                    child: Text(
                      'All EMIs paid — well done!',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: upcoming
                    .map((e) => CustomerEmiTile(emi: e))
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistory(
    BuildContext context,
    bool isDark,
    AsyncValue<List<CustomerEmiModel>> emisAsync,
  ) {
    final theme = Theme.of(context);

    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success
                      .withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.borderRadiusMd),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  size: 18,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Recent Payments',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          emisAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                children: [
                  ShimmerCard(height: 62, borderRadius: 12),
                  SizedBox(height: 8),
                  ShimmerCard(height: 62, borderRadius: 12),
                ],
              ),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Couldn\'t load payments.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.error.withValues(alpha: 0.8),
                ),
              ),
            ),
            data: (emis) {
              final paid = emis.where((e) => e.isPaid).toList()
                ..sort((a, b) {
                  final ad = a.paidOn ?? DateTime(1970);
                  final bd = b.paidOn ?? DateTime(1970);
                  return bd.compareTo(ad);
                });
              if (paid.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No payments made yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight)
                          .withValues(alpha: 0.8),
                    ),
                  ),
                );
              }
              final recent = paid.take(3).toList();
              final totalPaid =
                  paid.fold<double>(0, (s, e) => s + e.amountPaid);

              return Column(
                children: [
                  ...recent.map((e) => CustomerEmiTile(emi: e)),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Text(
                        'Total paid',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: (isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight)
                              .withValues(alpha: 0.7),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '₹${_formatAmount(totalPaid)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.success,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(
      BuildContext context, CustomerLoanModel loan, bool isDark) {
    final theme = Theme.of(context);

    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Loan Details',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _DetailRow(
            label: 'Loan Amount',
            value: '₹${_formatAmount(loan.amount)}',
            isDark: isDark,
          ),
          _DetailRow(
            label: 'Outstanding',
            value: '₹${_formatAmount(loan.outstandingBalance)}',
            isDark: isDark,
            valueColor: loan.isOverdue ? AppColors.error : null,
          ),
          _DetailRow(
            label: 'Frequency',
            value:
                loan.frequency[0].toUpperCase() + loan.frequency.substring(1),
            isDark: isDark,
          ),
          if (loan.disbursementDate != null)
            _DetailRow(
              label: 'Disbursed On',
              value: _formatDate(loan.disbursementDate!),
              isDark: isDark,
            ),
          if (loan.firstEmiDate != null)
            _DetailRow(
              label: 'Next Due',
              value: _formatDate(loan.firstEmiDate!),
              isDark: isDark,
            ),
          if (loan.purpose != null)
            _DetailRow(
              label: 'Purpose',
              value: loan.purpose!,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleButton(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () =>
            context.push('/customer/loans/${widget.loanId}/schedule'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'View Full EMI Schedule',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Statement button ─────────────────────────────────────────────

  Widget _buildStatementButton(BuildContext context, bool isDark, CustomerLoanModel loan) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _showStatementSheet(context, isDark, loan),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.description_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Download Statement',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Statement bottom sheet ──────────────────────────────────────

  void _showStatementSheet(BuildContext context, bool isDark, CustomerLoanModel loan) {
    String selectedFormat = 'pdf';
    String selectedRange = '30';
    String step = 'input';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: EdgeInsets.fromLTRB(
                  24,
                  16,
                  24,
                  MediaQuery.of(ctx).viewInsets.bottom +
                      MediaQuery.of(ctx).viewPadding.bottom +
                      kBottomNavBarHeight +
                      16,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E2030).withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (step == 'input') ...[
                        Text(
                          'Download Statement',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'FILE FORMAT',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildFormatCard(
                                label: 'PDF Report',
                                icon: Icons.picture_as_pdf_rounded,
                                color: AppColors.error,
                                isSelected: selectedFormat == 'pdf',
                                isDark: isDark,
                                onTap: () =>
                                    setSheetState(() => selectedFormat = 'pdf'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildFormatCard(
                                label: 'Excel Sheet',
                                icon: Icons.table_view_rounded,
                                color: AppColors.success,
                                isSelected: selectedFormat == 'excel',
                                isDark: isDark,
                                onTap: () => setSheetState(
                                    () => selectedFormat = 'excel'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildFormatCard(
                                label: 'CSV File',
                                icon: Icons.grid_on_rounded,
                                color: AppColors.info,
                                isSelected: selectedFormat == 'csv',
                                isDark: isDark,
                                onTap: () =>
                                    setSheetState(() => selectedFormat = 'csv'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'DATE RANGE',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildRangeCard(
                                label: '30 Days',
                                isSelected: selectedRange == '30',
                                isDark: isDark,
                                onTap: () =>
                                    setSheetState(() => selectedRange = '30'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildRangeCard(
                                label: '90 Days',
                                isSelected: selectedRange == '90',
                                isDark: isDark,
                                onTap: () =>
                                    setSheetState(() => selectedRange = '90'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildRangeCard(
                                label: 'All Time',
                                isSelected: selectedRange == 'all',
                                isDark: isDark,
                                onTap: () =>
                                    setSheetState(() => selectedRange = 'all'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  HapticFeedback.lightImpact();
                                  setSheetState(() => step = 'loading');
                                  try {
                                    final supabase =
                                        Supabase.instance.client;
                                    final orgId = ref.read(
                                        currentOrgIdOrThrowProvider);

                                    // Fetch org info
                                    final orgData = await supabase
                                        .from('organizations')
                                        .select(
                                            'name, address, city, state, pincode, phone, email, gst_number')
                                        .eq('id', orgId)
                                        .maybeSingle();

                                    final org = LoanStatementOrgInfo(
                                      name: orgData?['name'] ??
                                          'MicroFlow Pro',
                                      address: orgData?['address'],
                                      city: orgData?['city'],
                                      state: orgData?['state'],
                                      pincode: orgData?['pincode'],
                                      phone: orgData?['phone'],
                                      email: orgData?['email'],
                                      gstNumber: orgData?['gst_number'],
                                    );

                                    // Map CustomerLoanModel → LoanModel
                                    final adminLoan = LoanModel(
                                      id: loan.id,
                                      customerId: '',
                                      loanNumber: loan.loanNumber ??
                                          loan.id
                                              .substring(0, 8)
                                              .toUpperCase(),
                                      amount: loan.amount,
                                      interestRate: loan.interestRate,
                                      tenureMonths: loan.tenureMonths,
                                      emiAmount: loan.emiAmount,
                                      totalInterest:
                                          (loan.emiAmount *
                                                  loan.tenureMonths) -
                                              loan.amount,
                                      totalRepayable: loan.emiAmount *
                                          loan.tenureMonths,
                                      outstandingBalance:
                                          loan.outstandingBalance,
                                      interestType: InterestType.flat,
                                      disbursementDate:
                                          loan.disbursementDate,
                                      firstEmiDate: loan.firstEmiDate,
                                      status: _mapLoanStatus(loan.status),
                                      purpose: loan.purpose,
                                      createdAt: DateTime.now(),
                                      updatedAt: DateTime.now(),
                                      customerName: loan.memberName,
                                    );

                                    // Map EMI schedule
                                    final emiAsync = ref.read(
                                        customerEmiScheduleProvider(
                                            widget.loanId));
                                    final emiList =
                                        emiAsync.valueOrNull ?? [];

                                    final adminSchedule = emiList
                                        .map((e) => EMIScheduleModel(
                                              id: e.id,
                                              loanId: widget.loanId,
                                              emiNumber: e.emiNumber,
                                              dueDate: e.dueDate ??
                                                  DateTime.now(),
                                              emiAmount: e.emiAmount,
                                              principal: e.principal,
                                              interest: e.interest,
                                              balanceAfter:
                                                  e.balanceAfter,
                                              status: _mapEmiStatus(
                                                  e.status, e.isPaid),
                                              paidOn: e.paidOn,
                                              penaltyAmount:
                                                  e.penaltyAmount ?? 0,
                                              penaltyPaid: false,
                                              createdAt: DateTime.now(),
                                            ))
                                        .toList();

                                    // Map paid EMIs → payments
                                    final paidEmis = emiList
                                        .where((e) => e.isPaid)
                                        .toList();
                                    final payments = paidEmis
                                        .map((e) =>
                                            LoanStatementPayment(
                                              date: e.paidOn ??
                                                  e.dueDate ??
                                                  DateTime.now(),
                                              amount: e.amountPaid > 0
                                                  ? e.amountPaid
                                                  : e.emiAmount,
                                              mode: '',
                                            ))
                                        .toList();

                                    // Generate PDF with admin template
                                    final pdfBytes =
                                        await LoanStatementPdfService
                                            .buildCustomerStatement(
                                      loan: adminLoan,
                                      schedule: adminSchedule,
                                      payments: payments,
                                      org: org,
                                    );

                                    _generatedPdfBytes = pdfBytes;
                                    _statementFilename =
                                        'loan_statement_${loan.loanNumber ?? loan.id}.pdf';

                                    if (ctx.mounted) {
                                      setSheetState(
                                          () => step = 'success');
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      setSheetState(
                                          () => step = 'input');
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Failed to generate statement: $e')),
                                      );
                                    }
                                  }
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: const Padding(
                                  padding:
                                      EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: Text(
                                      'Generate Statement',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ] else if (step == 'loading') ...[
                        const SizedBox(height: 40),
                        CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Exporting statement report...',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 40),
                      ] else if (step == 'success') ...[
                        const SizedBox(height: 32),
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.success.withValues(alpha: 0.15),
                            border: Border.all(
                              color:
                                  AppColors.success.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.file_download_done_rounded,
                            color: AppColors.success,
                            size: 38,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Statement Downloaded!',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The statement file has been saved to your downloads folder.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                                isDark ? Colors.white70 : Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Open + Share buttons
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () async {
                                      HapticFeedback.lightImpact();
                                      if (_generatedPdfBytes != null) {
                                        await Printing.layoutPdf(
                                            onLayout: (format) async =>
                                                _generatedPdfBytes!);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(14),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                          vertical: 14),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.open_in_new_rounded,
                                              color: Colors.white, size: 18),
                                          SizedBox(width: 6),
                                          Text(
                                            'Open',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white
                                          .withValues(alpha: 0.08)
                                      : Colors.black
                                          .withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white
                                            .withValues(alpha: 0.1)
                                        : Colors.black
                                            .withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () async {
                                      HapticFeedback.lightImpact();
                                      if (_generatedPdfBytes != null &&
                                          _statementFilename != null) {
                                        await Printing.sharePdf(
                                            bytes: _generatedPdfBytes!,
                                            filename: _statementFilename!);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(14),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                          vertical: 14),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.share_rounded,
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black54,
                                              size: 18),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Share',
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black87,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Close text button
                        TextButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(ctx).pop();
                          },
                          child: Text(
                            'Close',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white54
                                  : Colors.black45,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFormatCard({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.2 : 0.12)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected
                    ? color
                    : (isDark ? Colors.white54 : Colors.black45),
                size: 22),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeCard({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.12)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedSection({required int index, required Widget child}) {
    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, c) {
        final delay = (index * 0.07).clamp(0.0, 0.9);
        final progress = ((_staggerController.value - delay) / (1 - delay))
            .clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(progress);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - eased)),
            child: c,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildHeaderLoading(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final statusBarHeight = mq.padding.top;
    final gradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF1A1F3A), Color(0xFF151A30)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : AppColors.primaryGradient;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        statusBarHeight + AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CircleIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => context.pop(),
                isDark: isDark,
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Loan Details',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const ShimmerCard(height: 38, width: 180, borderRadius: 8),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, bool isDark) {
    return Column(
      children: [
        _buildHeaderLoading(context, isDark),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.lg,
            ),
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              ShimmerCard(height: 140, borderRadius: 20), // Progress section
              SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(child: ShimmerCard(height: 90, borderRadius: 18)),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(child: ShimmerCard(height: 90, borderRadius: 18)),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(child: ShimmerCard(height: 90, borderRadius: 18)),
                ],
              ), // Key metrics
              SizedBox(height: AppSpacing.md),
              ShimmerCard(height: 180, borderRadius: 20), // Chart
              SizedBox(height: AppSpacing.md),
              ShimmerCard(height: 160, borderRadius: 20), // EMIs
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, bool isDark, Object error) {
    return Column(
      children: [
        _buildHeaderLoading(context, isDark),
        Expanded(
          child: CustomerEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Failed to load loan details',
            subtitle: error.toString(),
            ctaLabel: 'Retry',
            onCtaTap: () => ref.invalidate(customerLoanDetailProvider(widget.loanId)),
          ),
        ),
      ],
    );
  }

  Widget _buildNotFound(BuildContext context, bool isDark) {
    return Column(
      children: [
        _buildHeaderLoading(context, isDark),
        Expanded(
          child: CustomerEmptyState(
            icon: Icons.search_off_rounded,
            title: 'Loan Not Found',
            subtitle: 'We could not find this loan in your account details.',
          ),
        ),
      ],
    );
  }

  LoanStatus _mapLoanStatus(String status) {
    switch (status) {
      case 'active':
        return LoanStatus.active;
      case 'completed':
        return LoanStatus.closed;
      case 'closed':
        return LoanStatus.closed;
      case 'defaulted':
        return LoanStatus.defaultStatus;
      case 'pending':
        return LoanStatus.pending;
      case 'approved':
        return LoanStatus.approved;
      case 'rejected':
        return LoanStatus.rejected;
      default:
        return LoanStatus.active;
    }
  }

  EMIStatus _mapEmiStatus(String status, bool isPaid) {
    if (isPaid) return EMIStatus.paid;
    switch (status) {
      case 'paid':
        return EMIStatus.paid;
      case 'overdue':
        return EMIStatus.overdue;
      case 'upcoming':
        return EMIStatus.pending;
      case 'pending':
        return EMIStatus.pendingPayment;
      default:
        return EMIStatus.pending;
    }
  }

  StatusType _statusType(String status) {
    switch (status) {
      case 'active':
        return StatusType.active;
      case 'completed':
      case 'closed':
        return StatusType.completed;
      case 'defaulted':
        return StatusType.defaultStatus;
      default:
        return StatusType.pending;
    }
  }

  String _formatAmount(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(2)} Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(2)} L';
    } else if (amount >= 1000) {
      return _formatWithCommas(amount.round());
    }
    return amount.toStringAsFixed(0);
  }

  String _formatWithCommas(int number) {
    final str = number.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (count != 0 && count % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
      count++;
    }
    return buffer.toString().split('').reversed.join();
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// ── Private helper widgets ──────────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.2),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _ProgressStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _ProgressStat({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: -0.3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color
                  ?.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color
                  ?.withValues(alpha: 0.55),
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
