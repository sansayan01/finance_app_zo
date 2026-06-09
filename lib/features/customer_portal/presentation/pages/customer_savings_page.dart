import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/progress_gauge.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../data/providers/customer_savings_providers.dart';
import '../widgets/customer_savings_card.dart';
import '../widgets/customer_savings_achievements_row.dart';
import '../widgets/customer_empty_state.dart';

class CustomerSavingsPage extends ConsumerStatefulWidget {
  const CustomerSavingsPage({super.key});

  @override
  ConsumerState<CustomerSavingsPage> createState() =>
      _CustomerSavingsPageState();
}

class _CustomerSavingsPageState extends ConsumerState<CustomerSavingsPage>
    with TickerProviderStateMixin {
  late final AnimationController _headerController;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;

  late final AnimationController _staggerController;

  double _previousBalance = 0;
  double _targetBalance = 0;
  bool _hasAnimated = false;

  String _filter = 'all'; // all | active | completed

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
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

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _headerController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  void _scheduleAnimations(double total) {
    if (_hasAnimated && _targetBalance == total) return;
    _hasAnimated = true;
    _previousBalance = _targetBalance;
    _targetBalance = total;
    _staggerController.reset();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _staggerController.forward();
    });
  }

  /// Indian-style currency formatting (e.g. 12,34,567).
  String _formatCurrency(double value) {
    if (value.abs() >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(2)} Cr';
    }
    if (value.abs() >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(2)} L';
    }
    final n = value.round();
    final s = n.toString();
    if (s.length <= 3) return '₹$s';
    final last3 = s.substring(s.length - 3);
    final rest = s.substring(0, s.length - 3);
    final buf = StringBuffer();
    for (int i = 0; i < rest.length; i++) {
      buf.write(rest[i]);
      final remaining = rest.length - i - 1;
      if (remaining > 0 && remaining % 2 == 0) buf.write(',');
    }
    return '₹${buf.toString()},$last3';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final savingsAsync = ref.watch(customerSavingsProvider);

    final headerGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF1A1F3A), Color(0xFF151A30)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : AppColors.primaryGradient;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      extendBody: true,
      body: AuroraBackground(
        child: savingsAsync.when(
          loading: () => _buildLoadingState(isDark, headerGradient),
          error: (e, _) => _buildErrorState(e, isDark, headerGradient),
          data: (savings) {
            final totalBalance =
                savings.fold<double>(0, (sum, s) => sum + s.currentAmount);
            final totalTarget =
                savings.fold<double>(0, (sum, s) => sum + s.targetAmount);
            final double overallProgress = totalTarget > 0
                ? (totalBalance / totalTarget * 100).clamp(0.0, 100.0)
                : 0.0;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scheduleAnimations(totalBalance);
            });

            if (savings.isEmpty) {
              return Column(
                children: [
                  _buildGradientHeader(
                    context, isDark, headerGradient, 0, 0, 0, 0,
                  ),
                  Expanded(
                    child: CustomerEmptyState(
                      icon: Icons.savings_rounded,
                      title: 'Start your savings journey',
                      subtitle:
                          'Build wealth, one deposit at a time. Open a vault and watch your goals come to life.',
                      ctaLabel: 'Refresh',
                      onCtaTap: () =>
                          ref.invalidate(customerSavingsProvider),
                    ),
                  ),
                ],
              );
            }

            // Derive available filters
            final hasActive = savings.any((s) => s.status == 'active');
            final hasCompleted = savings.any((s) => s.status == 'completed');
            final filtered = savings.where((s) {
              if (_filter == 'all') return true;
              return s.status == _filter;
            }).toList();

            return RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(customerSavingsProvider),
              color: theme.colorScheme.primary,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildGradientHeader(
                      context,
                      isDark,
                      headerGradient,
                      totalBalance,
                      totalTarget,
                      overallProgress,
                      savings.length,
                    ),
                  ),

                  // Achievements
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.sm,
                      ),
                      child: CustomerSavingsAchievementsRow(
                        currentAmount: totalBalance,
                        targetAmount: totalTarget,
                        depositCount: savings.length,
                      ),
                    ),
                  ),

                  // Filter chips (only when both states exist)
                  if (hasActive && hasCompleted)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.sm,
                          AppSpacing.md,
                          0,
                        ),
                        child: _buildFilterChips(theme, isDark),
                      ),
                    ),

                  // Section title
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Your Vaults',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${filtered.length} ${filtered.length == 1 ? 'vault' : 'vaults'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: (isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight)
                                  .withValues(alpha: 0.5),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Stagger fade+slide vault cards
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final delay = (index * 0.07).clamp(0.0, 0.9);
                        return AnimatedBuilder(
                          animation: _staggerController,
                          builder: (context, child) {
                            final progress =
                                ((_staggerController.value - delay) / (1 - delay))
                                    .clamp(0.0, 1.0);
                            final eased =
                                Curves.easeOutCubic.transform(progress);
                            return Opacity(
                              opacity: eased,
                              child: Transform.translate(
                                offset: Offset(0, 28 * (1 - eased)),
                                child: child,
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm / 2,
                            ),
                            child: CustomerSavingsCard(
                              savings: filtered[index],
                              onTap: () => context.push(
                                '/customer/savings/${filtered[index].id}',
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 110),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme, bool isDark) {
    final chips = [
      ('all', 'All'),
      ('active', 'Active'),
      ('completed', 'Completed'),
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (key, label) = chips[i];
          final selected = _filter == key;
          final activeColor = theme.colorScheme.primary;

          return GestureDetector(
            onTap: () => setState(() => _filter = key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                gradient: selected
                    ? LinearGradient(
                        colors: [
                          activeColor,
                          activeColor.withValues(alpha: 0.85),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: selected
                    ? null
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06)),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState(bool isDark, LinearGradient gradient) {
    return Column(
      children: [
        _buildGradientHeader(context, isDark, gradient, 0, 0, 0, 0),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: 4,
            itemBuilder: (_, __) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: ShimmerCard(height: 140, borderRadius: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(Object e, bool isDark, LinearGradient gradient) {
    return Column(
      children: [
        _buildGradientHeader(context, isDark, gradient, 0, 0, 0, 0),
        Expanded(
          child: CustomerEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Couldn\'t load savings',
            subtitle: e.toString(),
            ctaLabel: 'Retry',
            onCtaTap: () => ref.invalidate(customerSavingsProvider),
          ),
        ),
      ],
    );
  }

  Widget _buildGradientHeader(
    BuildContext context,
    bool isDark,
    LinearGradient gradient,
    double totalBalance,
    double totalTarget,
    double overallProgress,
    int accountCount,
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
            mq.padding.top + AppSpacing.lg,
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
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'My Savings',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Savings Balance',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: _previousBalance,
                            end: totalBalance,
                          ),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) {
                            return Text(
                              _formatCurrency(value),
                              style:
                                  theme.textTheme.headlineLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$accountCount vault${accountCount != 1 ? 's' : ''}  •  ${overallProgress.toStringAsFixed(1)}% overall',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ProgressGauge(
                    value: (overallProgress / 100).clamp(0.0, 1.0),
                    size: 84,
                    strokeWidth: 7,
                    progressColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    center: Text(
                      '${overallProgress.toStringAsFixed(0)}%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.track_changes_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Target ${_formatCurrency(totalTarget)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.savings_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Saved ${_formatCurrency(totalBalance)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
