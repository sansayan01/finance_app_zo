import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/utils/formatters.dart';
import '../../../home/data/providers/dashboard_providers.dart';
import '../../data/models/transaction_model.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  TransactionType? _filterType;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  // Pagination state
  final List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  bool _hasMore = true;
  bool _initialLoaded = false;
  static const _pageSize = 20;

  final List<Map<String, dynamic>> _filters = [
    {'label': 'All', 'type': null, 'icon': Icons.receipt_long_rounded},
    {'label': 'EMI', 'type': TransactionType.emiPayment, 'icon': Icons.payments_rounded},
    {'label': 'Savings', 'type': TransactionType.savingsDeposit, 'icon': Icons.savings_rounded},
    {'label': 'Disbursed', 'type': TransactionType.loanDisbursement, 'icon': Icons.account_balance_rounded},
    {'label': 'Withdrawal', 'type': TransactionType.savingsWithdrawal, 'icon': Icons.money_off_rounded},
    {'label': 'Penalty', 'type': TransactionType.penalty, 'icon': Icons.warning_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPage());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadPage();
    }
  }

  Future<void> _loadPage() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    final repo = ref.read(transactionsRepositoryProvider);
    final results = await repo.getTransactionsPaginated(
      offset: _transactions.length,
      limit: _pageSize,
      typeFilter: _filterType,
      searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
    );

    if (!mounted) return;
    setState(() {
      _transactions.addAll(results);
      _hasMore = results.length >= _pageSize;
      _isLoading = false;
      _initialLoaded = true;
    });
  }

  void _resetAndReload() {
    setState(() {
      _transactions.clear();
      _hasMore = true;
      _initialLoaded = false;
    });
    _loadPage();
  }

  Future<void> _onRefresh() async {
    ref.invalidate(todayStatsProvider);
    _resetAndReload();
  }

  @override
  Widget build(BuildContext context) {
    final todayStats = ref.watch(todayStatsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            displacement: 20,
            color: primary,
            backgroundColor: theme.cardColor,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.arrow_back_rounded,
                                color: primary, size: 20),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FINANCIAL TIMELINE',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  fontSize: 10,
                                  color: primary,
                                ),
                              ),
                              Text(
                                'Transaction History',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // Today's Stats
                SliverToBoxAdapter(
                  child: todayStats.when(
                    data: (stats) => _buildTodayStats(stats, theme, isDark),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // Search Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.fillDark : AppColors.fillLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.1)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onSubmitted: (v) {
                          _searchQuery = v;
                          _resetAndReload();
                        },
                        onChanged: (v) {
                          // Debounce: only search on submit or after clearing
                          if (v.isEmpty && _searchQuery.isNotEmpty) {
                            _searchQuery = '';
                            _resetAndReload();
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Search by member name...',
                          hintStyle: theme.textTheme.bodySmall,
                          prefixIcon: Icon(Icons.search_rounded,
                              color: primary.withValues(alpha: 0.6), size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchQuery = '';
                                    _resetAndReload();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Filter Chips
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _filters.length,
                      itemBuilder: (context, index) {
                        final filter = _filters[index];
                        final isSelected = _filterType == filter['type'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() =>
                                  _filterType = filter['type'] as TransactionType?);
                              _resetAndReload();
                            },
                            child: AnimatedContainer(
                              duration: 200.ms,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primary
                                    : (isDark
                                        ? AppColors.fillDark
                                        : AppColors.fillLight),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? primary
                                      : theme.dividerColor.withValues(alpha: 0.1),
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                            color: primary.withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2))
                                      ]
                                    : [],
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    filter['icon'] as IconData,
                                    size: 14,
                                    color: isSelected
                                        ? Colors.white
                                        : theme.textTheme.bodyMedium?.color,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    filter['label'] as String,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : theme.textTheme.bodyMedium?.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // Transaction List (paginated)
                if (!_initialLoaded)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_transactions.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(theme, primary),
                  )
                else ...[
                  _buildTransactionSliver(theme, isDark),
                  // Loading indicator at bottom
                  if (_isLoading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    ),
                  if (!_hasMore && _transactions.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                        child: Center(
                          child: Text(
                            '— All ${_transactions.length} transactions loaded —',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.4),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionSliver(ThemeData theme, bool isDark) {
    final grouped = _groupByDate(_transactions);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final entry = grouped.entries.elementAt(index);
            return _buildDateGroup(entry.key, entry.value, theme, isDark);
          },
          childCount: grouped.length,
        ),
      ),
    );
  }

  Widget _buildTodayStats(
      Map<String, dynamic> stats, ThemeData theme, bool isDark) {
    final collected = (stats['collected'] as num?)?.toDouble() ?? 0;
    final disbursed = (stats['disbursed'] as num?)?.toDouble() ?? 0;
    final count = (stats['collectionCount'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _StatMini(
              label: "TODAY'S INFLOW",
              value: AppFormatters.formatCompactCurrency(collected),
              icon: Icons.arrow_downward_rounded,
              color: AppColors.success,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatMini(
              label: 'DISBURSED',
              value: AppFormatters.formatCompactCurrency(disbursed),
              icon: Icons.arrow_upward_rounded,
              color: AppColors.error,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatMini(
              label: 'COLLECTIONS',
              value: count.toString(),
              icon: Icons.receipt_long_rounded,
              color: theme.colorScheme.primary,
              isDark: isDark,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Map<String, List<TransactionModel>> _groupByDate(
      List<TransactionModel> transactions) {
    final map = <String, List<TransactionModel>>{};
    for (final t in transactions) {
      final key = _dateLabel(t.createdAt);
      map.putIfAbsent(key, () => []).add(t);
    }
    return map;
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) return 'Today';
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return AppFormatters.formatDate(dt);
  }

  Widget _buildDateGroup(String dateLabel, List<TransactionModel> transactions,
      ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                dateLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Divider(
                    color: theme.dividerColor.withValues(alpha: 0.15)),
              ),
            ],
          ),
        ),
        ...transactions.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TransactionCard(transaction: t),
            )),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme, Color primary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_rounded,
                size: 56, color: primary.withValues(alpha: 0.3)),
          ),
          const SizedBox(height: 20),
          Text('No Transactions Found',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Adjust your filters or check back later.',
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

// ─── Transaction Card ───

class _TransactionCard extends StatelessWidget {
  final TransactionModel transaction;
  const _TransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final config = _getTypeConfig(transaction.type, isDark);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: config.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: config.color.withValues(alpha: 0.15)),
            ),
            child: Icon(config.icon, color: config.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.memberName.isNotEmpty
                      ? transaction.memberName
                      : 'Unknown Member',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(config.icon, size: 10, color: config.color),
                    const SizedBox(width: 4),
                    Text(
                      config.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: config.color,
                      ),
                    ),
                    if (transaction.paymentMode != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _paymentModeLabel(transaction.paymentMode!),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  AppFormatters.formatRelativeTime(transaction.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${config.isInflow ? '+' : '-'}${AppFormatters.formatCurrency(transaction.amount)}',
                style: TextStyle(
                  color: config.color,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: -0.3,
                ),
              ),
              if (transaction.description != null &&
                  transaction.description!.isNotEmpty) ...[
                const SizedBox(height: 2),
                SizedBox(
                  width: 80,
                  child: Text(
                    transaction.description!,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  _TypeConfig _getTypeConfig(TransactionType type, bool isDark) {
    switch (type) {
      case TransactionType.emiPayment:
        return _TypeConfig(Icons.payments_rounded, 'EMI Payment',
            isDark ? AppColors.successDark : AppColors.success, true);
      case TransactionType.savingsDeposit:
        return _TypeConfig(Icons.savings_rounded, 'Savings Deposit',
            isDark ? AppColors.successDark : AppColors.success, true);
      case TransactionType.loanDisbursement:
        return _TypeConfig(Icons.account_balance_rounded, 'Loan Disbursed',
            isDark ? AppColors.errorDark : AppColors.error, false);
      case TransactionType.savingsWithdrawal:
        return _TypeConfig(Icons.money_off_rounded, 'Withdrawal',
            isDark ? AppColors.warningDark : AppColors.warning, false);
      case TransactionType.penalty:
        return _TypeConfig(Icons.warning_amber_rounded, 'Penalty',
            isDark ? AppColors.errorDark : AppColors.error, true);
      case TransactionType.staffCashDeposit:
        return _TypeConfig(Icons.account_balance_wallet_rounded, 'Cash Deposit',
            isDark ? AppColors.successDark : AppColors.success, true);
      default:
        return _TypeConfig(Icons.swap_horiz_rounded, 'Transaction',
            isDark ? Colors.grey.shade400 : Colors.grey.shade600, true);
    }
  }

  String _paymentModeLabel(PaymentMode mode) {
    switch (mode) {
      case PaymentMode.cash:
        return 'CASH';
      case PaymentMode.upi:
        return 'UPI';
      case PaymentMode.bankTransfer:
        return 'BANK';
      case PaymentMode.cheque:
        return 'CHEQUE';
      case PaymentMode.card:
        return 'CARD';
    }
  }
}

class _TypeConfig {
  final IconData icon;
  final String label;
  final Color color;
  final bool isInflow;
  _TypeConfig(this.icon, this.label, this.color, this.isInflow);
}

// ─── Stats Mini Card ───

class _StatMini extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatMini({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
