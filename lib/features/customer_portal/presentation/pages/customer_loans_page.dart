import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/providers/customer_loans_providers.dart';
import '../../data/models/customer_loan_model.dart';
import '../widgets/customer_loan_card.dart';
import '../widgets/customer_empty_state.dart';

class CustomerLoansPage extends ConsumerStatefulWidget {
  const CustomerLoansPage({super.key});

  @override
  ConsumerState<CustomerLoansPage> createState() => _CustomerLoansPageState();
}

class _CustomerLoansPageState extends ConsumerState<CustomerLoansPage>
    with TickerProviderStateMixin {
  String _filter = 'all';
  late final AnimationController _staggerController;
  late final AnimationController _headerController;
  late final Animation<double> _headerFadeAnimation;
  late final Animation<Offset> _headerSlideAnimation;

  static const _filterOptions = [
    ('all', 'All Loans', Icons.layers_rounded),
    ('active', 'Active', Icons.play_circle_fill_rounded),
    ('completed', 'Completed', Icons.check_circle_rounded),
    ('overdue', 'Overdue', Icons.warning_amber_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerFadeAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    );
    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    ));
    _headerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _headerController.dispose();
    super.dispose();
  }

  void _restartStagger() {
    _staggerController.reset();
    _staggerController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loansAsync = ref.watch(customerLoansProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: loansAsync.when(
        loading: () => _buildLoadingState(theme, isDark),
        error: (e, _) => _buildErrorState(theme, isDark, e),
        data: (loans) {
          final summary = CustomerLoanSummary.fromLoans(loans);
          final filtered = _filterLoans(loans);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_staggerController.isAnimating &&
                _staggerController.value == 0) {
              _staggerController.forward();
            }
          });
          return _buildContent(theme, isDark, summary, filtered);
        },
      ),
    );
  }

  Widget _buildContent(
    ThemeData theme,
    bool isDark,
    CustomerLoanSummary summary,
    List<CustomerLoanModel> filtered,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(customerLoansProvider);
        _restartStagger();
      },
      color: AppColors.primary,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          _buildSliverHeader(theme, isDark),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _headerFadeAnimation,
              child: SlideTransition(
                position: _headerSlideAnimation,
                child: _buildSummaryHero(theme, isDark, summary),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _headerFadeAnimation,
              child: _buildFilterChips(theme, isDark),
            ),
          ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: CustomerEmptyState(
                icon: _filterIcon,
                title: 'No Loans Found',
                subtitle: _filterEmptyMessage,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final entryAnimation = _buildStaggeredAnimation(index, filtered.length);
                    return FadeTransition(
                      opacity: entryAnimation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.08),
                          end: Offset.zero,
                        ).animate(entryAnimation),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: CustomerLoanCard(
                            loan: filtered[index],
                            onTap: () => context.push(
                              '/customer/loans/${filtered[index].id}',
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSliverHeader(ThemeData theme, bool isDark) {
    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: 140,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.primary,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white.withValues(alpha: 0.9),
          size: 20,
        ),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 52, bottom: 16),
        title: Text(
          'My Loans',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      AppColors.surfaceDark,
                      AppColors.surfaceDark.withValues(alpha: 0.95),
                    ]
                  : [
                      AppColors.primary,
                      AppColors.accent,
                    ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -40,
                right: -30,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Positioned(
                top: 20,
                right: 60,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
              ),
              Positioned(
                bottom: -20,
                left: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.03),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHero(
    ThemeData theme,
    bool isDark,
    CustomerLoanSummary summary,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      child: GlassCard(
        elevated: true,
        borderRadius: 20,
        padding: const EdgeInsets.all(AppSpacing.lg),
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        child: Column(
          children: [
            Row(
              children: [
                _buildSummaryStat(
                  theme,
                  isDark,
                  'Total Loans',
                  summary.activeLoans.toString(),
                  Icons.account_balance_wallet_rounded,
                  AppColors.primary,
                ),
                Container(
                  width: 1,
                  height: 44,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                ),
                _buildSummaryStat(
                  theme,
                  isDark,
                  'Outstanding',
                  _formatCompactCurrency(summary.totalOutstanding),
                  Icons.trending_up_rounded,
                  AppColors.warning,
                ),
                Container(
                  width: 1,
                  height: 44,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                ),
                _buildSummaryStat(
                  theme,
                  isDark,
                  'Disbursed',
                  _formatCompactCurrency(summary.totalDisbursed),
                  Icons.payments_rounded,
                  AppColors.success,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStat(
    ThemeData theme,
    bool isDark,
    String label,
    String value,
    IconData icon,
    Color accent,
  ) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)
                  .withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme, bool isDark) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        itemCount: _filterOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final (key, label, icon) = _filterOptions[index];
          final isSelected = _filter == key;
          final selectedColor = _colorForFilter(key, isDark);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected
                        ? selectedColor
                        : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                  ),
                  const SizedBox(width: 6),
                  Text(label),
                ],
              ),
              labelStyle: theme.textTheme.bodySmall?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? selectedColor
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
              selectedColor: selectedColor.withValues(alpha: isDark ? 0.15 : 0.08),
              backgroundColor: isDark ? AppColors.fillDark : AppColors.fillLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isSelected
                      ? selectedColor.withValues(alpha: 0.3)
                      : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04)),
                  width: isSelected ? 1.5 : 0.5,
                ),
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              onSelected: (_) {
                setState(() => _filter = key);
                _restartStagger();
              },
            ),
          );
        },
      ),
    );
  }

  Color _colorForFilter(String key, bool isDark) {
    switch (key) {
      case 'active':
        return isDark ? AppColors.successDark : AppColors.success;
      case 'completed':
        return isDark ? AppColors.primaryDark : AppColors.primary;
      case 'overdue':
        return isDark ? AppColors.errorDark : AppColors.error;
      default:
        return isDark ? AppColors.accentDark : AppColors.accent;
    }
  }

  Animation<double> _buildStaggeredAnimation(int index, int total) {
    final intervalStart = (index * 0.08).clamp(0.0, 0.7);
    final intervalEnd = (intervalStart + 0.35).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _staggerController,
      curve: Interval(intervalStart, intervalEnd, curve: Curves.easeOutCubic),
    );
  }

  IconData get _filterIcon {
    return switch (_filter) {
      'active' => Icons.play_circle_fill_rounded,
      'completed' => Icons.check_circle_rounded,
      'overdue' => Icons.warning_amber_rounded,
      _ => Icons.account_balance_rounded,
    };
  }

  String get _filterEmptyMessage {
    return switch (_filter) {
      'active' => 'You have no active loans at the moment.',
      'completed' => 'No completed loans to show yet.',
      'overdue' => 'Great news! No overdue loans.',
      _ => 'You don\'t have any loans yet.',
    };
  }

  List<CustomerLoanModel> _filterLoans(List<CustomerLoanModel> loans) {
    return switch (_filter) {
      'active' => loans.where((l) => l.status == 'active').toList(),
      'completed' =>
        loans.where((l) => l.status == 'completed' || l.status == 'closed').toList(),
      'overdue' => loans.where((l) => l.isOverdue).toList(),
      _ => loans,
    };
  }

  Widget _buildLoadingState(ThemeData theme, bool isDark) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        _buildSliverHeader(theme, isDark),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
            child: GlassCard(
              borderRadius: 20,
              padding: const EdgeInsets.all(AppSpacing.lg),
              backgroundColor: isDark ? AppColors.cardDark : Colors.white,
              child: Row(
                children: List.generate(3, (_) => Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        width: 48,
                        height: 14,
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 56,
                        height: 10,
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                )),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: List.generate(4, (_) => Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Container(
                  width: 80,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              )),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.md),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, __) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                    ),
                  ),
                ),
              ),
              childCount: 3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(ThemeData theme, bool isDark, Object error) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        _buildSliverHeader(theme, isDark),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.cloud_off_rounded,
                      size: 48,
                      color: isDark ? AppColors.errorDark : AppColors.error,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Something went wrong',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Unable to load your loans. Pull down to retry.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)
                          .withValues(alpha: 0.7),
                    ),
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

  String _formatCompactCurrency(double amount) {
    if (amount >= 10000000) {
      return '\u20b9${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount >= 100000) {
      return '\u20b9${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '\u20b9${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '\u20b9${amount.toStringAsFixed(0)}';
  }
}
