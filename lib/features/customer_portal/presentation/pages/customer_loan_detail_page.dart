import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/progress_gauge.dart';
import '../../data/models/customer_loan_model.dart';
import '../../data/providers/customer_loans_providers.dart';

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
  late final AnimationController _amountController;
  late final Animation<double> _amountAnimation;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _amountController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _amountAnimation = CurvedAnimation(
      parent: _amountController,
      curve: Curves.easeOutCubic,
    );

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _staggerController.forward();
        _amountController.forward();
      }
    });
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loanAsync = ref.watch(customerLoanDetailProvider(widget.loanId));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: loanAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildErrorState(context, e),
        data: (loan) {
          if (loan == null) return _buildNotFound(context);
          return _buildBody(context, loan);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, CustomerLoanModel loan) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final paidAmount = loan.amount - loan.outstandingBalance;
    final mq = MediaQuery.of(context);
    final statusBarHeight = mq.padding.top;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(customerLoanDetailProvider(widget.loanId));
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // Hero header
          SliverToBoxAdapter(
            child: _buildHeroHeader(context, loan, isDark, statusBarHeight),
          ),

          // Progress gauge section
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

          // Key metrics row
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

          // Details card
          SliverToBoxAdapter(
            child: _buildAnimatedSection(
              index: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                child: _buildDetailsCard(context, loan, isDark),
              ),
            ),
          ),

          // EMI Schedule button
          SliverToBoxAdapter(
            child: _buildAnimatedSection(
              index: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.xl),
                child: _buildScheduleButton(context, isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(
      BuildContext context, CustomerLoanModel loan, bool isDark, double topPad) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, topPad + AppSpacing.md,
          AppSpacing.lg, AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.primary.withValues(alpha: 0.35),
                  AppColors.accent.withValues(alpha: 0.2),
                  const Color(0xFF0F1115),
                ]
              : [
                  AppColors.primary,
                  AppColors.accent,
                  AppColors.indigo.withValues(alpha: 0.85),
                ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button + status
          Row(
            children: [
              _CircleIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
                isDark: isDark,
              ),
              const Spacer(),
              StatusBadge(
                label: loan.status[0].toUpperCase() +
                    loan.status.substring(1),
                type: _statusType(loan.status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Loan number
          Text(
            loan.loanNumber ?? 'Loan Details',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
              letterSpacing: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Animated loan amount
          AnimatedBuilder(
            animation: _amountAnimation,
            builder: (context, _) {
              final displayAmount = loan.amount * _amountAnimation.value;
              return Text(
                '\u20b9${_formatAmount(displayAmount)}',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 38,
                  letterSpacing: -1,
                  height: 1.1,
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),

          // Subtitle
          if (loan.purpose != null)
            Text(
              loan.purpose!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
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
          // Circular gauge
          ProgressGauge(
            value: loan.paidPercentage / 100,
            size: 100,
            strokeWidth: 10,
            progressColor: gaugeColor,
            backgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${loan.paidPercentage.toStringAsFixed(0)}%',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: gaugeColor,
                    fontSize: 22,
                  ),
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

          // Progress details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Repayment Progress',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _ProgressStat(
                  label: 'Paid',
                  value: '\u20b9${_formatAmount(paidAmount)}',
                  color: AppColors.success,
                  isDark: isDark,
                ),
                const SizedBox(height: AppSpacing.sm),
                _ProgressStat(
                  label: 'Remaining',
                  value: '\u20b9${_formatAmount(loan.outstandingBalance)}',
                  color: loan.isOverdue ? AppColors.error : AppColors.warning,
                  isDark: isDark,
                ),
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressBar(
                    value: loan.paidPercentage / 100,
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
            label: 'EMI Amount',
            value: '\u20b9${_formatAmount(loan.emiAmount)}',
            color: AppColors.indigo,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _MetricCard(
            icon: Icons.percent_rounded,
            label: 'Interest Rate',
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
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _DetailRow(
            label: 'Loan Amount',
            value: '\u20b9${_formatAmount(loan.amount)}',
            isDark: isDark,
          ),
          _DetailRow(
            label: 'Outstanding',
            value: '\u20b9${_formatAmount(loan.outstandingBalance)}',
            isDark: isDark,
            valueColor: loan.isOverdue ? AppColors.error : null,
          ),
          _DetailRow(
            label: 'Frequency',
            value: loan.frequency[0].toUpperCase() +
                loan.frequency.substring(1),
            isDark: isDark,
          ),
          if (loan.disbursementDate != null)
            _DetailRow(
              label: 'Disbursed On',
              value: _formatDate(loan.disbursementDate!),
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  AppColors.primary.withValues(alpha: 0.85),
                  AppColors.accent.withValues(alpha: 0.85),
                ]
              : AppColors.premiumGradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () =>
              context.push('/customer/loans/${widget.loanId}/schedule'),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'View EMI Schedule',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedSection({required int index, required Widget child}) {
    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, child) {
        final progress = _staggerController.value;
        final itemProgress =
            ((progress * 4) - index).clamp(0.0, 1.0).toDouble();
        if (itemProgress <= 0) return const SizedBox.shrink();

        return Opacity(
          opacity: itemProgress,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - itemProgress)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.error.withValues(alpha: 0.6)),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$error',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color
                    ?.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              size: 48,
              color: theme.textTheme.bodyMedium?.color
                  ?.withValues(alpha: 0.3)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Loan not found',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
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
      return '${(amount / 10000000).toStringAsFixed(2)}Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(2)}L';
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
            fontWeight: FontWeight.w700,
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
              fontSize: 10,
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
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
