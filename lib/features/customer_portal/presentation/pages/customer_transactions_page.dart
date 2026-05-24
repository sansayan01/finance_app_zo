import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/customer_home_providers.dart';
import '../../data/models/customer_transaction_model.dart';
import '../widgets/customer_transaction_tile.dart';
import '../widgets/customer_empty_state.dart';

class CustomerTransactionsPage extends ConsumerStatefulWidget {
  const CustomerTransactionsPage({super.key});

  @override
  ConsumerState<CustomerTransactionsPage> createState() =>
      _CustomerTransactionsPageState();
}

class _CustomerTransactionsPageState
    extends ConsumerState<CustomerTransactionsPage>
    with TickerProviderStateMixin {
  String _filter = 'all';
  late AnimationController _staggerController;
  late AnimationController _chipController;

  static const List<_FilterChipData> _filters = [
    _FilterChipData('all', 'All', Icons.dashboard_rounded),
    _FilterChipData('emi', 'EMI', Icons.payment_rounded),
    _FilterChipData('deposit', 'Deposits', Icons.savings_rounded),
    _FilterChipData('withdrawal', 'Withdrawals', Icons.account_balance_rounded),
    _FilterChipData('credit', 'Credits', Icons.arrow_downward_rounded),
    _FilterChipData('debit', 'Debits', Icons.arrow_upward_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _chipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _chipController.dispose();
    super.dispose();
  }

  Animation<double> _staggered(int index, {double duration = 0.5}) {
    final start = (index * 0.06).clamp(0.0, 1.0);
    final end = (start + duration).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _staggerController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  void _onFilterChanged(String value) {
    if (_filter == value) return;
    HapticFeedback.lightImpact();
    setState(() => _filter = value);
    // Restart stagger for list items
    _staggerController.reset();
    _staggerController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final transactionsAsync = ref.watch(customerAllTransactionsProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: transactionsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
          ),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              Text('Something went wrong',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.xs),
              Text('$e',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
        data: (transactions) {
          final filtered = _filterTransactions(transactions);

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor:
                isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            onRefresh: () async =>
                ref.invalidate(customerAllTransactionsProvider),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // -- Gradient Header --
                SliverToBoxAdapter(
                  child: _buildHeader(context, isDark, transactions.length),
                ),
                // -- Filter Chips --
                SliverToBoxAdapter(
                  child: _buildFilterChips(context, isDark),
                ),
                // -- Content --
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: CustomerEmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: 'No Transactions',
                      subtitle: _filter == 'all'
                          ? 'Your transactions will appear here once you have activity.'
                          : 'No transactions match this filter.',
                    ),
                  )
                else ...[
                  // -- Summary Row --
                  SliverToBoxAdapter(
                    child: _buildSummaryRow(
                        context, isDark, filtered, transactions),
                  ),
                  // -- Transaction List --
                  SliverPadding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                      bottom: AppSpacing.xxl,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final itemAnimation = _staggered(index + 2);
                          return FadeTransition(
                            opacity: itemAnimation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.15),
                                end: Offset.zero,
                              ).animate(itemAnimation),
                              child: _TransactionCard(
                                transaction: filtered[index],
                                isDark: isDark,
                              ),
                            ),
                          );
                        },
                        childCount: filtered.length,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, int totalCount) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final topPadding = mq.padding.top + AppSpacing.md;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.primaryDark.withValues(alpha: 0.25),
                  AppColors.accentDark.withValues(alpha: 0.15),
                  AppColors.backgroundDark,
                ]
              : [
                  AppColors.primary,
                  AppColors.accent,
                  AppColors.primaryLight,
                ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.lg, topPadding, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button + Title row
              Row(
                children: [
                  _GlassIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    isDark: isDark,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Transactions',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  // Transaction count badge
                  _CountBadge(count: totalCount),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Subtitle
              Text(
                'Track all your financial activity',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, bool isDark) {
    return AnimatedBuilder(
      animation: _chipController,
      builder: (context, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: _chipController,
            curve: Curves.easeOut,
          ),
          child: child,
        );
      },
      child: Container(
        height: 60,
        margin: const EdgeInsets.only(top: AppSpacing.md),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          itemCount: _filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, index) {
            final chip = _filters[index];
            final isSelected = _filter == chip.value;
            return _FilterChip(
              data: chip,
              isSelected: isSelected,
              isDark: isDark,
              onTap: () => _onFilterChanged(chip.value),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    bool isDark,
    List<CustomerTransactionModel> filtered,
    List<CustomerTransactionModel> all,
  ) {
    final totalCredit = filtered
        .where((t) => t.isCredit)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final totalDebit = filtered
        .where((t) => t.isDebit)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: _SummaryPill(
              label: 'Credits',
              amount: totalCredit,
              icon: Icons.arrow_downward_rounded,
              color: AppColors.success,
              isDark: isDark,
              theme: theme,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _SummaryPill(
              label: 'Debits',
              amount: totalDebit,
              icon: Icons.arrow_upward_rounded,
              color: AppColors.warning,
              isDark: isDark,
              theme: theme,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _SummaryPill(
              label: 'Count',
              amount: filtered.length.toDouble(),
              icon: Icons.receipt_long_rounded,
              color: AppColors.info,
              isDark: isDark,
              theme: theme,
              isCount: true,
            ),
          ),
        ],
      ),
    );
  }

  List<CustomerTransactionModel> _filterTransactions(
      List<CustomerTransactionModel> transactions) {
    return switch (_filter) {
      'emi' => transactions.where((t) => t.type == 'emiPayment').toList(),
      'deposit' => transactions
          .where((t) =>
              t.type == 'savingsDeposit' ||
              t.type == 'deposit' ||
              t.type == 'collection')
          .toList(),
      'withdrawal' => transactions
          .where((t) =>
              t.type == 'savingsWithdrawal' || t.type == 'withdrawal')
          .toList(),
      'credit' => transactions.where((t) => t.isCredit).toList(),
      'debit' => transactions.where((t) => t.isDebit).toList(),
      _ => transactions,
    };
  }
}

// ─── Private helper widgets ─────────────────────────────────────────────

class _FilterChipData {
  final String value;
  final String label;
  final IconData icon;

  const _FilterChipData(this.value, this.label, this.icon);
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.3),
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count txn',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final _FilterChipData data;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _FilterChip({
    required this.data,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppSpacing.animationNormal,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : isDark
                  ? AppColors.cardDark
                  : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : isDark
                    ? AppColors.separatorDark
                    : AppColors.separatorLight,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: AppSpacing.animationFast,
              child: Icon(
                data.icon,
                key: ValueKey(isSelected),
                size: 16,
                color: isSelected
                    ? Colors.white
                    : isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(width: 6),
            AnimatedDefaultTextStyle(
              duration: AppSpacing.animationNormal,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                letterSpacing: 0.2,
              ),
              child: Text(data.label),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  final bool isDark;
  final ThemeData theme;
  final bool isCount;

  const _SummaryPill({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.theme,
    this.isCount = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.separatorDark : AppColors.separatorLight,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isCount
                ? amount.toInt().toString()
                : '\u20b9${amount.toStringAsFixed(0)}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final CustomerTransactionModel transaction;
  final bool isDark;

  const _TransactionCard({
    required this.transaction,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.separatorDark : AppColors.separatorLight,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.textPrimaryLight.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: CustomerTransactionTile(transaction: transaction),
      ),
    );
  }
}
