import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/progress_gauge.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../data/models/customer_savings_model.dart';
import '../../data/providers/customer_savings_providers.dart';
import '../widgets/customer_transaction_tile.dart';
import '../widgets/customer_empty_state.dart';
import '../widgets/customer_savings_milestones.dart';

class CustomerSavingsDetailPage extends ConsumerStatefulWidget {
  final String savingsId;

  const CustomerSavingsDetailPage({super.key, required this.savingsId});

  @override
  ConsumerState<CustomerSavingsDetailPage> createState() =>
      _CustomerSavingsDetailPageState();
}

class _CustomerSavingsDetailPageState
    extends ConsumerState<CustomerSavingsDetailPage>
    with TickerProviderStateMixin {
  late final AnimationController _headerController;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;

  late final AnimationController _contentController;
  late final AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _headerFade = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    ));

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _contentController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _staggerController.forward();
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _contentController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final savingsAsync =
        ref.watch(customerSavingsDetailProvider(widget.savingsId));
    final transactionsAsync =
        ref.watch(customerSavingsTransactionsProvider(widget.savingsId));

    final headerGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : AppColors.primaryGradient;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: savingsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            color: theme.colorScheme.primary,
          ),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (savings) {
          if (savings == null) {
            return Column(
              children: [
                _buildGradientHeader(context, isDark, headerGradient, null),
                const Expanded(
                  child: Center(
                    child: Text('Savings account not found'),
                  ),
                ),
              ],
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(
                  customerSavingsDetailProvider(widget.savingsId));
              ref.invalidate(
                  customerSavingsTransactionsProvider(widget.savingsId));
            },
            color: theme.colorScheme.primary,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                // Gradient header
                SliverToBoxAdapter(
                  child: _buildGradientHeader(
                    context, isDark, headerGradient, savings,
                  ),
                ),

                // Goal progress gauge card
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _contentController,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.sm,
                      ),
                      child: GlassCard(
                        elevated: true,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Row(
                          children: [
                            ProgressGauge(
                              value:
                                  (savings.progressPercentage / 100)
                                      .clamp(0.0, 1.0),
                              size: 96,
                              strokeWidth: 8,
                              progressColor: _progressColor(
                                  savings.progressPercentage, isDark),
                              backgroundColor: isDark
                                  ? AppColors.surfaceDark
                                  : AppColors.fillLight,
                              center: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${savings.progressPercentage.toStringAsFixed(0)}%',
                                    style:
                                        theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: _progressColor(
                                          savings.progressPercentage,
                                          isDark),
                                    ),
                                  ),
                                  Text(
                                    'done',
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                      color: theme
                                          .textTheme.bodySmall?.color
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
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  _GoalLine(
                                    icon: Icons.flag_rounded,
                                    label: 'Target',
                                    value:
                                        '\u20b9${savings.targetAmount.toStringAsFixed(0)}',
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  _GoalLine(
                                    icon: Icons.savings_rounded,
                                    label: 'Saved',
                                    value:
                                        '\u20b9${savings.currentAmount.toStringAsFixed(0)}',
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  _GoalLine(
                                    icon: Icons.trending_up_rounded,
                                    label: 'Remaining',
                                    value:
                                        '\u20b9${(savings.targetAmount - savings.currentAmount).clamp(0, double.infinity).toStringAsFixed(0)}',
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Savings Milestones widget
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _contentController,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm / 2,
                      ),
                      child: CustomerSavingsMilestones(
                        currentAmount: savings.currentAmount,
                        targetAmount: savings.targetAmount,
                        planName: savings.displayName,
                      ),
                    ),
                  ),
                ),

                // Account details card
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _contentController,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm / 2,
                      ),
                      child: GlassCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.info
                                        .withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.info_outline_rounded,
                                    size: 16,
                                    color: AppColors.info,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'Account Details',
                                  style:
                                      theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _DetailRow(
                              label: 'Monthly Deposit',
                              value:
                                  '\u20b9${savings.monthlyDeposit.toStringAsFixed(0)}',
                            ),
                            _DetailRow(
                              label: 'Interest Rate',
                              value:
                                  '${savings.interestRate.toStringAsFixed(1)}%',
                            ),
                            if (savings.tenureMonths != null)
                              _DetailRow(
                                label: 'Tenure',
                                value: '${savings.tenureMonths} months',
                              ),
                            if (savings.maturityDate != null)
                              _DetailRow(
                                label: 'Maturity Date',
                                value: _formatDate(savings.maturityDate!),
                              ),
                            _DetailRow(
                              label: 'Status',
                              value: savings.status[0].toUpperCase() +
                                  savings.status.substring(1),
                              trailing: StatusBadge(
                                label: savings.status[0].toUpperCase() +
                                    savings.status.substring(1),
                                type: savings.status == 'active'
                                    ? StatusType.active
                                    : savings.status == 'completed'
                                        ? StatusType.completed
                                        : StatusType.standard,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Transactions section header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.accent
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            size: 16,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Transactions',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Transactions list
                transactionsAsync.when(
                  loading: () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text('Error: $e'),
                    ),
                  ),
                  data: (transactions) {
                    if (transactions.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: CustomerEmptyState(
                          icon: Icons.receipt_long_rounded,
                          title: 'No Transactions',
                          subtitle:
                              'No transactions found for this savings account.',
                        ),
                      );
                    }
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final delay = index * 0.06;
                          return AnimatedBuilder(
                            animation: _staggerController,
                            builder: (context, child) {
                              final progress =
                                  (_staggerController.value - delay)
                                      .clamp(0.0, 1.0);
                              final eased = Curves.easeOutCubic
                                  .transform(progress);
                              return Opacity(
                                opacity: eased,
                                child: Transform.translate(
                                  offset: Offset(0, 16 * (1 - eased)),
                                  child: child,
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                              ),
                              child: GlassCard(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                borderRadius: 16,
                                child: CustomerTransactionTile(
                                  transaction: transactions[index],
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: transactions.length,
                      ),
                    );
                  },
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGradientHeader(
    BuildContext context,
    bool isDark,
    LinearGradient gradient,
    CustomerSavingsModel? savings,
  ) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);

    return FadeTransition(
      opacity: _headerFade,
      child: SlideTransition(
        position: _headerSlide,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            mq.padding.top + AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button + title
              Row(
                children: [
                  _CircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      savings?.displayName ?? 'Savings Details',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (savings != null)
                    StatusBadge(
                      label: savings.status[0].toUpperCase() +
                          savings.status.substring(1),
                      type: savings.status == 'active'
                          ? StatusType.active
                          : savings.status == 'completed'
                              ? StatusType.completed
                              : StatusType.standard,
                      glow: true,
                    ),
                ],
              ),
              if (savings != null) ...[
                const SizedBox(height: AppSpacing.lg),
                // Balance display
                Text(
                  'Current Balance',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\u20b9${savings.currentAmount.toStringAsFixed(0)}',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'of \u20b9${savings.targetAmount.toStringAsFixed(0)} target',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _progressColor(double percentage, bool isDark) {
    if (percentage >= 100) return AppColors.success;
    if (percentage >= 60) return isDark ? AppColors.primaryDark : AppColors.primary;
    if (percentage >= 30) return AppColors.warning;
    return AppColors.error;
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

/// Line item in the goal progress section.
class _GoalLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _GoalLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color
                ?.withValues(alpha: 0.55),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Detail row with optional trailing widget (e.g., StatusBadge).
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;

  const _DetailRow({
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          trailing ??
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
        ],
      ),
    );
  }
}

/// Circular icon button used in the header.
class _CircleIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  State<_CircleIconButton> createState() => _CircleIconButtonState();
}

class _CircleIconButtonState extends State<_CircleIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _pressed
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          widget.icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
