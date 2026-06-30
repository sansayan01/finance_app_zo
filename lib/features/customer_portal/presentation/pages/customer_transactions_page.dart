import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../data/providers/customer_home_providers.dart';
import '../../data/models/customer_transaction_model.dart';
import '../widgets/customer_transaction_tile.dart';
import '../widgets/customer_empty_state.dart';

/// Super-premium customer transactions page.
///
/// Features:
///  - Gradient header with title + search-toggle
///  - Animated KPI strip (in / out / net)
///  - Filter chips (All / EMI / Deposit / Withdrawal / Credit / Debit)
///  - Date-grouped list (Today / Yesterday / Month YYYY) using
///    [CustomerTransactionTile]
///  - Shimmer loading, refresh indicator, empty state
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
  String _query = '';
  bool _searchOpen = false;

  late AnimationController _staggerController;
  late AnimationController _chipController;
  late AnimationController _kpiController;
  final TextEditingController _searchCtrl = TextEditingController();

  static const List<_FilterChipData> _filters = [
    _FilterChipData('all', 'All', Icons.dashboard_rounded),
    _FilterChipData('emi', 'EMI', Icons.payment_rounded),
    _FilterChipData('deposit', 'Deposits', Icons.savings_rounded),
    _FilterChipData('withdrawal', 'Withdrawals', Icons.account_balance_rounded),
    _FilterChipData('credit', 'Credits', Icons.arrow_downward_rounded),
    _FilterChipData('debit', 'Debits', Icons.arrow_upward_rounded),
    _FilterChipData('pending', 'Pending', Icons.hourglass_top_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    _chipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _kpiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _chipController.dispose();
    _kpiController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Animation<double> _staggered(int index, {double duration = 0.5}) {
    final start = (index * 0.07).clamp(0.0, 1.0);
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
    _staggerController.reset();
    _staggerController.forward();
    _kpiController.reset();
    _kpiController.forward();
  }

  void _toggleSearch() {
    HapticFeedback.lightImpact();
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _query = '';
        _searchCtrl.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final transactionsAsync = ref.watch(customerAllTransactionsProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: transactionsAsync.when(
        loading: () => _buildLoading(context, isDark),
        error: (e, _) => _buildError(context, isDark, e),
        data: (transactions) {
          final filtered = _applyFilters(transactions);

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
                SliverToBoxAdapter(
                  child: _buildHeader(context, isDark, transactions.length),
                ),
                SliverToBoxAdapter(
                  child: _buildKpiStrip(context, isDark, filtered),
                ),
                SliverToBoxAdapter(
                  child: _buildFilterChips(context, isDark),
                ),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xl),
                      child: CustomerEmptyState(
                        icon: Icons.receipt_long_rounded,
                        title: 'No Transactions',
                        subtitle: _filter == 'all' && _query.isEmpty
                            ? 'Your transactions will appear here once you have activity.'
                            : 'No transactions match your current filters.',
                      ),
                    ),
                  )
                else
                  ..._buildGroupedSlivers(context, isDark, filtered),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 96,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, bool isDark, int totalCount) {
    final theme = Theme.of(context);
    final topPadding = AppSpacing.md;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.primaryDark.withValues(alpha: 0.32),
                  AppColors.accentDark.withValues(alpha: 0.18),
                  AppColors.backgroundDark,
                ]
              : [
                  AppColors.primary,
                  AppColors.accent,
                  AppColors.primaryLight,
                ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.lg, topPadding, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  _GlassIconButton(
                    icon: _searchOpen
                        ? Icons.close_rounded
                        : Icons.search_rounded,
                    isDark: isDark,
                    onTap: _toggleSearch,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _CountBadge(count: totalCount),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Track all your financial activity',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w500,
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 240),
                crossFadeState: _searchOpen
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox(height: AppSpacing.xs),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: _buildInlineSearch(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildInlineSearch(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: TextField(
        controller: _searchCtrl,
        autofocus: true,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        cursorColor: Colors.white,
        onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Search by description, reference, member...',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 13,
          ),
          prefixIcon: const Icon(Icons.search_rounded,
              color: Colors.white, size: 18),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white70, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          isDense: true,
        ),
      ),
    );
  }

  // ── KPI Strip ──────────────────────────────────────────────────────
  Widget _buildKpiStrip(BuildContext context, bool isDark,
      List<CustomerTransactionModel> filtered) {
    final totalIn = filtered
        .where((t) => t.isCredit)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final totalOut = filtered
        .where((t) => t.isDebit)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final net = totalIn - totalOut;
    final theme = Theme.of(context);

    return FadeTransition(
      opacity: _staggered(0),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(_staggered(0)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: _KpiTile(
                  label: 'In',
                  amount: totalIn,
                  icon: Icons.arrow_downward_rounded,
                  color: AppColors.success,
                  isDark: isDark,
                  theme: theme,
                  controller: _kpiController,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _KpiTile(
                  label: 'Out',
                  amount: totalOut,
                  icon: Icons.arrow_upward_rounded,
                  color: AppColors.warning,
                  isDark: isDark,
                  theme: theme,
                  controller: _kpiController,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _KpiTile(
                  label: 'Net',
                  amount: net,
                  icon: net >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: net >= 0 ? AppColors.primary : AppColors.error,
                  isDark: isDark,
                  theme: theme,
                  controller: _kpiController,
                  signed: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Filter Chips ───────────────────────────────────────────────────
  Widget _buildFilterChips(BuildContext context, bool isDark) {
    return FadeTransition(
      opacity: _staggered(1),
      child: SizedBox(
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
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

  // ── Grouped Slivers ────────────────────────────────────────────────
  List<Widget> _buildGroupedSlivers(BuildContext context, bool isDark,
      List<CustomerTransactionModel> filtered) {
    final groups = _groupByDate(filtered);
    final widgets = <Widget>[];
    int globalIdx = 2;
    for (final entry in groups.entries) {
      widgets.add(
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: _staggered(globalIdx),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
              child: _GroupHeader(label: entry.key, isDark: isDark),
            ),
          ),
        ),
      );
      globalIdx++;

      final items = entry.value;
      widgets.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final animation = _staggered(globalIdx + i);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.1),
                      end: Offset.zero,
                    ).animate(animation),
                    child: _TransactionCard(
                      transaction: items[i],
                      isDark: isDark,
                    ),
                  ),
                );
              },
              childCount: items.length,
            ),
          ),
        ),
      );
      globalIdx += items.length;
    }
    return widgets;
  }

  Map<String, List<CustomerTransactionModel>> _groupByDate(
      List<CustomerTransactionModel> txns) {
    final groups = <String, List<CustomerTransactionModel>>{};
    // Sort newest first.
    final sorted = [...txns]
      ..sort((a, b) => (b.transactionDate ?? DateTime(1970))
          .compareTo(a.transactionDate ?? DateTime(1970)));
    for (final t in sorted) {
      final d = t.transactionDate;
      String key;
      if (d == null) {
        key = 'Earlier';
      } else {
        key = AppFormatters.formatDate(d);
      }
      groups.putIfAbsent(key, () => []).add(t);
    }
    return groups;
  }

  // ── Loading / Error ────────────────────────────────────────────────
  Widget _buildLoading(BuildContext context, bool isDark) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 8,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, i) => ShimmerCard(
            height: i == 0 ? 120 : 64,
            borderRadius: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, bool isDark, Object e) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
          const SizedBox(height: AppSpacing.md),
          Text('Something went wrong',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text('$e',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  // ── Filtering ──────────────────────────────────────────────────────
  List<CustomerTransactionModel> _applyFilters(
      List<CustomerTransactionModel> transactions) {
    Iterable<CustomerTransactionModel> result = transactions;
    result = switch (_filter) {
      'emi' => result.where((t) => t.type == 'emiPayment'),
      'deposit' => result.where(
          (t) => t.type == 'savingsDeposit' || t.type == 'deposit'),
      'withdrawal' => result.where(
          (t) => t.type == 'savingsWithdrawal' || t.type == 'withdrawal'),
      'credit' => result.where(
          (t) => t.type == 'collection' || t.type == 'loanDisbursement'),
      'debit' => result.where((t) =>
          t.type == 'emiPayment' ||
          t.type == 'savingsWithdrawal' ||
          t.type == 'withdrawal' ||
          t.type == 'penalty' ||
          t.type == 'upiPending' ||
          t.type == 'upiRejected'),
      'pending' => result.where((t) =>
          t.type == 'upiPending' || t.type == 'upiRejected'),
      _ => result,
    };
    if (_query.isNotEmpty) {
      result = result.where((t) {
        final q = _query;
        return (t.description?.toLowerCase().contains(q) ?? false) ||
            (t.memberName?.toLowerCase().contains(q) ?? false) ||
            (t.referenceNumber?.toLowerCase().contains(q) ?? false) ||
            t.type.toLowerCase().contains(q);
      });
    }
    return result.toList();
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
          color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.3),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
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
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
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
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.accent],
                )
              : null,
          color: isSelected
              ? null
              : isDark
                  ? AppColors.cardDark
                  : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : isDark
                    ? AppColors.separatorDark
                    : AppColors.separatorLight,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              data.icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
            ),
            const SizedBox(width: 6),
            Text(
              data.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  final bool isDark;
  final ThemeData theme;
  final AnimationController controller;
  final bool signed;

  const _KpiTile({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.theme,
    required this.controller,
    this.signed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.separatorDark : AppColors.separatorLight,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 13, color: color),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: amount),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return Text(
                _formatIndian(value, signed: signed),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: signed && amount < 0
                      ? AppColors.error
                      : isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                  letterSpacing: -0.3,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
        ],
      ),
    );
  }

  /// Indian-style compact currency using full comma-formatted numbers.
  String _formatIndian(double v, {bool signed = false}) {
    final negative = v < 0;
    final sign = negative ? '-' : (signed && v > 0 ? '+' : '');
    final formatted = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(v.abs());
    return '$sign$formatted';
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;
  final bool isDark;

  const _GroupHeader({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tertiary = isDark
        ? AppColors.textTertiaryDark
        : AppColors.textTertiaryLight;
    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: tertiary,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            color: (isDark
                    ? AppColors.separatorDark
                    : AppColors.separatorLight)
                .withValues(alpha: 0.6),
          ),
        ),
      ],
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.separatorDark : AppColors.separatorLight,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.textPrimaryLight.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CustomerTransactionTile(transaction: transaction),
      ),
    );
  }
}
