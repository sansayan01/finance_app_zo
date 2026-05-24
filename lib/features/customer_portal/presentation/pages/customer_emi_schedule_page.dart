import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../data/providers/customer_loans_providers.dart';
import '../widgets/customer_emi_tile.dart';
import '../widgets/customer_empty_state.dart';

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
      duration: const Duration(milliseconds: 1200),
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

  @override
  Widget build(BuildContext context) {
    final emiAsync = ref.watch(customerEmiScheduleProvider(widget.loanId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: emiAsync.when(
        loading: () => _buildLoadingState(isDark),
        error: (e, _) => _buildErrorState(e, isDark),
        data: (emis) {
          if (emis.isEmpty) {
            return _buildEmptyGradientWrapper(isDark);
          }

          final paidCount = emis.where((e) => e.isPaid).length;
          final totalPaid =
              emis.where((e) => e.isPaid).fold(0.0, (s, e) => s + e.amountPaid);
          final totalRemaining = emis
              .where((e) => !e.isPaid)
              .fold(0.0, (s, e) => s + e.emiAmount);
          final totalPenalty = emis.fold(
              0.0, (s, e) => s + (e.penaltyAmount ?? 0));
          final progress = emis.isEmpty ? 0.0 : paidCount / emis.length;

          // Kick off stagger animation once data arrives
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_staggerController.status == AnimationStatus.dismissed) {
              _staggerController.forward();
            }
          });

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              _staggerController.reset();
              ref.invalidate(customerEmiScheduleProvider(widget.loanId));
              await Future.delayed(const Duration(milliseconds: 300));
              _staggerController.forward();
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                // ── Gradient Header ──
                SliverToBoxAdapter(
                  child: _GradientHeader(
                    fadeAnimation: _fadeAnimation,
                    isDark: isDark,
                    theme: theme,
                  ),
                ),

                // ── Summary Glass Cards ──
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _SummarySection(
                      paidCount: paidCount,
                      totalEmis: emis.length,
                      totalPaid: totalPaid,
                      totalRemaining: totalRemaining,
                      totalPenalty: totalPenalty,
                      progress: progress,
                      isDark: isDark,
                      theme: theme,
                    ),
                  ),
                ),

                // ── Section Label ──
                SliverToBoxAdapter(
                  child: _buildSectionLabel(theme, isDark),
                ),

                // ── Staggered EMI Tiles ──
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return _StaggeredTile(
                        index: index,
                        controller: _staggerController,
                        isDark: isDark,
                        child: CustomerEmiTile(emi: emis[index]),
                      );
                    },
                    childCount: emis.length,
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xxl),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Container(
      color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primary,
                backgroundColor:
                    isDark ? AppColors.fillDark : AppColors.fillLight,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Loading schedule...',
              style: TextStyle(
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error, bool isDark) {
    return Container(
      color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.error.withValues(alpha: 0.6),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$error',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyGradientWrapper(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF1A1E2E), AppColors.backgroundDark]
              : [AppColors.primary.withValues(alpha: 0.04), AppColors.backgroundLight],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Back button
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 8),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                    size: 22,
                  ),
                ),
              ),
            ),
            const Expanded(
              child: CustomerEmptyState(
                icon: Icons.calendar_month_rounded,
                title: 'No EMIs',
                subtitle: 'No EMI schedule found for this loan.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
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
            'Payment Schedule',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Gradient Header ───

class _GradientHeader extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final bool isDark;
  final ThemeData theme;

  const _GradientHeader({
    required this.fadeAnimation,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E2235),
                  const Color(0xFF252A3A),
                  AppColors.cardDark,
                ]
              : [
                  AppColors.primary,
                  AppColors.accent,
                  AppColors.accent.withValues(alpha: 0.85),
                ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
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
        opacity: fadeAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar with back button
            Row(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
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
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'EMI Schedule',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Repayment',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.7),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Schedule',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.8,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Track every installment and payment milestone',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.6),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Summary Section ───

class _SummarySection extends StatelessWidget {
  final int paidCount;
  final int totalEmis;
  final double totalPaid;
  final double totalRemaining;
  final double totalPenalty;
  final double progress;
  final bool isDark;
  final ThemeData theme;

  const _SummarySection({
    required this.paidCount,
    required this.totalEmis,
    required this.totalPaid,
    required this.totalRemaining,
    required this.totalPenalty,
    required this.progress,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Column(
        children: [
          // ── Progress Ring Card ──
          _GlassCard(
            isDark: isDark,
            child: Row(
              children: [
                // Progress ring
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 7,
                          backgroundColor: isDark
                              ? AppColors.fillDark
                              : AppColors.fillLight,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress >= 1.0
                                ? AppColors.success
                                : AppColors.primary,
                          ),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'done',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                // Count and label
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$paidCount',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                letterSpacing: -1.5,
                              ),
                            ),
                            TextSpan(
                              text: ' / $totalEmis',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'EMIs Completed',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow chip
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Stat Grid ──
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Total Paid',
                  value: _formatCurrency(totalPaid),
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.success,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatCard(
                  label: 'Remaining',
                  value: _formatCurrency(totalRemaining),
                  icon: Icons.pending_actions_rounded,
                  color: AppColors.warning,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          if (totalPenalty > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            _StatCard(
              label: 'Total Penalties',
              value: _formatCurrency(totalPenalty),
              icon: Icons.warning_amber_rounded,
              color: AppColors.error,
              isDark: isDark,
              fullWidth: true,
            ),
          ],
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 100000) {
      return '\u20b9${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '\u20b9${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '\u20b9${amount.toStringAsFixed(0)}';
  }
}

// ─── Glass Card ───

class _GlassCard extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const _GlassCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? AppColors.separatorDark
              : AppColors.separatorLight,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── Stat Card ───

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;
  final bool fullWidth;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.separatorDark : AppColors.separatorLight,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: fullWidth
          ? Row(
              children: [
                _buildIconBadge(),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIconBadge(),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildIconBadge() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

// ─── Staggered Tile (single CurvedAnimation per tile, disposed properly) ───

class _StaggeredTile extends StatefulWidget {
  final int index;
  final AnimationController controller;
  final bool isDark;
  final Widget child;

  const _StaggeredTile({
    required this.index,
    required this.controller,
    required this.isDark,
    required this.child,
  });

  @override
  State<_StaggeredTile> createState() => _StaggeredTileState();
}

class _StaggeredTileState extends State<_StaggeredTile> {
  late final CurvedAnimation _animation;

  @override
  void initState() {
    super.initState();
    final intervalStart = (widget.index * 0.08).clamp(0.0, 0.8);
    final intervalEnd = (intervalStart + 0.3).clamp(0.0, 1.0);
    _animation = CurvedAnimation(
      parent: widget.controller,
      curve: Interval(intervalStart, intervalEnd, curve: Curves.easeOutCubic),
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
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(_animation),
        child: _EmiTileWrapper(
          isDark: widget.isDark,
          child: widget.child,
        ),
      ),
    );
  }
}

// ─── EMI Tile Wrapper (section card feel) ───

class _EmiTileWrapper extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const _EmiTileWrapper({
    required this.child,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 3,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? AppColors.separatorDark
                : AppColors.separatorLight,
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: child,
        ),
      ),
    );
  }
}
