import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/glass_card.dart';

/// A premium widget showing savings goal milestones with animated celebrations.
class CustomerSavingsMilestones extends StatefulWidget {
  final double currentAmount;
  final double targetAmount;
  final String planName;

  const CustomerSavingsMilestones({
    super.key,
    required this.currentAmount,
    required this.targetAmount,
    required this.planName,
  });

  @override
  State<CustomerSavingsMilestones> createState() =>
      _CustomerSavingsMilestonesState();
}

class _CustomerSavingsMilestonesState extends State<CustomerSavingsMilestones>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late AnimationController _milestoneController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _milestoneController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _progressController.forward().then((_) {
      _milestoneController.forward();
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    _milestoneController.dispose();
    super.dispose();
  }

  double get _progress =>
      widget.targetAmount > 0
          ? (widget.currentAmount / widget.targetAmount).clamp(0.0, 1.0)
          : 0.0;

  static const List<_MilestoneData> _milestones = [
    _MilestoneData(percent: 0.25, label: 'Starter', emoji: ''),
    _MilestoneData(percent: 0.50, label: 'Halfway', emoji: ''),
    _MilestoneData(percent: 0.75, label: 'Almost There', emoji: ''),
    _MilestoneData(percent: 1.0, label: 'Goal Reached', emoji: ''),
  ];

  _MilestoneData? get _currentMilestone {
    for (int i = _milestones.length - 1; i >= 0; i--) {
      if (_progress >= _milestones[i].percent) return _milestones[i];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isGoalReached = _progress >= 1.0;
    final remaining = (widget.targetAmount - widget.currentAmount)
        .clamp(0.0, double.infinity);
    final currentMilestone = _currentMilestone;

    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: AppSpacing.borderRadiusXl,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusXl),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors:
                isGoalReached
                    ? [
                      AppColors.warning.withValues(alpha: isDark ? 0.15 : 0.08),
                      AppColors.orange.withValues(alpha: isDark ? 0.06 : 0.03),
                    ]
                    : [
                      AppColors.primary.withValues(alpha: isDark ? 0.1 : 0.05),
                      AppColors.success.withValues(alpha: isDark ? 0.06 : 0.03),
                    ],
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header ---
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        isGoalReached
                            ? AppColors.warning.withValues(alpha: isDark ? 0.25 : 0.15)
                            : AppColors.primary.withValues(
                              alpha: isDark ? 0.2 : 0.12,
                            ),
                    borderRadius: BorderRadius.circular(
                      AppSpacing.borderRadiusMd,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            isGoalReached
                                ? AppColors.warning.withValues(alpha: 0.2)
                                : AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 12,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    isGoalReached
                        ? Icons.emoji_events_rounded
                        : Icons.track_changes_rounded,
                    color:
                        isGoalReached
                            ? AppColors.warning
                            : AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Goal Milestones',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color:
                              isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.planName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg + 4),

            // --- Progress bar with milestones ---
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, _) {
                final animatedProgress = _progressAnimation.value * _progress;
                return _buildProgressBar(
                  context,
                  isDark,
                  animatedProgress,
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // --- Celebration message ---
            if (currentMilestone != null) ...[
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
                  );
                },
                child: _buildCelebrationBanner(
                  isDark,
                  currentMilestone,
                  isGoalReached,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // --- Goal reached golden card ---
            if (isGoalReached) ...[
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.9 + (0.1 * value),
                    child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
                  );
                },
                child: _buildGoalReachedCard(isDark, theme),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // --- Mini stats ---
            _buildMiniStats(isDark, theme, remaining),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(
    BuildContext context,
    bool isDark,
    double animatedProgress,
  ) {
    const barHeight = 14.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth;

        return SizedBox(
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Track background
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: Container(
                  height: barHeight,
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(barHeight / 2),
                  ),
                ),
              ),

              // Filled progress
              Positioned(
                top: 20,
                left: 0,
                child: AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, _) {
                    return Container(
                      height: barHeight,
                      width: barWidth * animatedProgress,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(barHeight / 2),
                        gradient: const LinearGradient(
                          colors: [AppColors.success, AppColors.primary],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Milestone markers
              ..._milestones.asMap().entries.map((entry) {
                final index = entry.key;
                final milestone = entry.value;
                final xPos = barWidth * milestone.percent;
                final isReached = animatedProgress >= milestone.percent;

                return Positioned(
                  top: 20 + (barHeight / 2) - 7,
                  left: xPos - 7,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: 0.0,
                      end: isReached ? 1.0 : 0.0,
                    ),
                    duration: Duration(milliseconds: 500 + (index * 100)),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: 0.6 + (0.4 * value),
                        child: child,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            isReached
                                ? AppColors.success
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06)),
                        border: Border.all(
                          color:
                              isReached
                                  ? AppColors.success
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : Colors.black.withValues(alpha: 0.12)),
                          width: 1.5,
                        ),
                        boxShadow:
                            isReached
                                ? [
                                  BoxShadow(
                                    color: AppColors.success.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                  ),
                                ]
                                : null,
                      ),
                      child:
                          isReached
                              ? const Icon(
                                Icons.check_rounded,
                                size: 10,
                                color: Colors.white,
                              )
                              : null,
                    ),
                  ),
                );
              }),

              // Pulsing current position dot
              Positioned(
                top: 20 + (barHeight / 2) - 6,
                left: (barWidth * animatedProgress) - 6,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Milestone labels below bar
              ..._milestones.asMap().entries.map((entry) {
                final milestone = entry.value;
                final xPos = barWidth * milestone.percent;
                final isReached = animatedProgress >= milestone.percent;

                return Positioned(
                  top: 42,
                  left: xPos - 30,
                  width: 60,
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 400),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight:
                          isReached ? FontWeight.w700 : FontWeight.w500,
                      color:
                          isReached
                              ? AppColors.success
                              : (isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight),
                    ),
                    textAlign: TextAlign.center,
                    child: Text(
                      '${(milestone.percent * 100).toInt()}% ${milestone.label}',
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCelebrationBanner(
    bool isDark,
    _MilestoneData milestone,
    bool isGoalReached,
  ) {
    final color =
        isGoalReached ? AppColors.warning : AppColors.success;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: isDark ? 0.15 : 0.1),
            color.withValues(alpha: isDark ? 0.06 : 0.04),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.25 : 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isGoalReached ? 'Goal Champion!' : "You're a ${milestone.label}!",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: color,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isGoalReached ? 'All milestones achieved!' : 'Keep it up!',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalReachedCard(bool isDark, ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use the actual card width so confetti positions scale with parent.
        final cardWidth = constraints.maxWidth;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.warning.withValues(alpha: isDark ? 0.18 : 0.12),
                AppColors.orange.withValues(alpha: isDark ? 0.1 : 0.06),
              ],
            ),
            border: Border.all(
              color: AppColors.warning.withValues(alpha: isDark ? 0.3 : 0.2),
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              // Confetti-style decorative icons
              ...List.generate(6, (i) {
                final random = math.Random(i * 37);
                return Positioned(
                  left: random.nextDouble() * (cardWidth - 20),
                  top: random.nextDouble() * 40,
                  child: Icon(
                    [
                      Icons.star_rounded,
                      Icons.diamond_rounded,
                      Icons.auto_awesome_rounded,
                      Icons.local_fire_department_rounded,
                      Icons.bolt_rounded,
                      Icons.favorite_rounded,
                    ][i],
                    size: 10 + random.nextDouble() * 6,
                    color: [
                      AppColors.warning,
                      AppColors.orange,
                      AppColors.error,
                      AppColors.success,
                      AppColors.primary,
                      AppColors.accent,
                    ][i].withValues(alpha: 0.25),
                  ),
                );
              }),
              // Main content
              Column(
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    color: AppColors.warning,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Goal Achieved!',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.warning,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Congratulations! You have reached your savings goal.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.warning.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniStats(
    bool isDark,
    ThemeData theme,
    double remaining,
  ) {
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            label: 'Saved',
            value: '₹${_formatAmount(widget.currentAmount)}',
            color: AppColors.success,
            isDark: isDark,
            theme: theme,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatChip(
            label: 'Goal',
            value: '₹${_formatAmount(widget.targetAmount)}',
            color: AppColors.primary,
            isDark: isDark,
            theme: theme,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatChip(
            label: 'Remaining',
            value: '₹${_formatAmount(remaining)}',
            color: remaining > 0 ? AppColors.warning : AppColors.success,
            isDark: isDark,
            theme: theme,
          ),
        ),
      ],
    );
  }

  String _formatAmount(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '',
      decimalDigits: 0,
    ).format(amount);
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  final ThemeData theme;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
        color: color.withValues(alpha: isDark ? 0.1 : 0.06),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.15 : 0.08)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneData {
  final double percent;
  final String label;
  final String emoji;

  const _MilestoneData({
    required this.percent,
    required this.label,
    required this.emoji,
  });
}
