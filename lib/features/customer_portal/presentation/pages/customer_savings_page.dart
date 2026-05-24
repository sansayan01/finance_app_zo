import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/progress_gauge.dart';
import '../../data/providers/customer_savings_providers.dart';
import '../widgets/customer_savings_card.dart';
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

  late final AnimationController _balanceController;
  late final Animation<double> _balanceAnimation;

  late final AnimationController _staggerController;

  double _displayedBalance = 0;
  double _targetBalance = 0;

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
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    ));

    _balanceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _balanceAnimation = CurvedAnimation(
      parent: _balanceController,
      curve: Curves.easeOutCubic,
    );

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _headerController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _balanceController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  void _startBalanceAnimation(double total) {
    if (_targetBalance == total) return;
    _targetBalance = total;
    _balanceController.reset();
    _balanceController.forward();
    _staggerController.reset();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _staggerController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final savingsAsync = ref.watch(customerSavingsProvider);

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
          final totalBalance =
              savings.fold<double>(0, (sum, s) => sum + s.currentAmount);
          final totalTarget =
              savings.fold<double>(0, (sum, s) => sum + s.targetAmount);
          final double overallProgress =
              totalTarget > 0 ? (totalBalance / totalTarget * 100).clamp(0.0, 100.0) : 0.0;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startBalanceAnimation(totalBalance);
          });

          if (savings.isEmpty) {
            return Column(
              children: [
                _buildGradientHeader(
                  context, isDark, headerGradient, 0, 0, 0, 0,
                ),
                const Expanded(
                  child: CustomerEmptyState(
                    icon: Icons.savings_rounded,
                    title: 'No Savings',
                    subtitle:
                        'You don\'t have any savings accounts yet.',
                  ),
                ),
              ],
            );
          }

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(customerSavingsProvider),
            color: theme.colorScheme.primary,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                // Gradient header with animated balance
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

                // Section title
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: Text(
                      'Your Accounts',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                ),

                // Staggered savings cards
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final delay = index * 0.08;
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
                              offset: Offset(0, 24 * (1 - eased)),
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
                            savings: savings[index],
                            onTap: () => context.push(
                              '/customer/savings/${savings[index].id}',
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: savings.length,
                  ),
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
                  Text(
                    'My Savings',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // Balance + Gauge row
              Row(
                children: [
                  // Left: animated balance text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Savings Balance',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedBuilder(
                          animation: _balanceAnimation,
                          builder: (context, _) {
                            _displayedBalance =
                                totalBalance * _balanceAnimation.value;
                            return Text(
                              '\u20b9${_displayedBalance.toStringAsFixed(0)}',
                              style: theme.textTheme.headlineLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$accountCount account${accountCount != 1 ? 's' : ''}  \u2022  ${overallProgress.toStringAsFixed(1)}% overall',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Right: circular gauge
                  ProgressGauge(
                    value: (overallProgress / 100).clamp(0.0, 1.0),
                    size: 80,
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

              // Target summary bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
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
                      'Target: \u20b9${totalTarget.toStringAsFixed(0)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
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
                      'Saved: \u20b9${totalBalance.toStringAsFixed(0)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
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
