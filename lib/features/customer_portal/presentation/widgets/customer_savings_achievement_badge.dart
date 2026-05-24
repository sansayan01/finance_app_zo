import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';

/// A premium achievement badge for savings milestones.
/// Unlocked badges have gradient borders, glow effects, and scale-in animation.
class CustomerSavingsAchievementBadge extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isUnlocked;

  const CustomerSavingsAchievementBadge({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isUnlocked,
  });

  @override
  State<CustomerSavingsAchievementBadge> createState() =>
      _CustomerSavingsAchievementBadgeState();
}

class _CustomerSavingsAchievementBadgeState
    extends State<CustomerSavingsAchievementBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: AppSpacing.animationSlower,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _scaleController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Badge circle ---
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    widget.isUnlocked
                        ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            widget.color,
                            widget.color.withValues(alpha: 0.7),
                          ],
                        )
                        : null,
                color: widget.isUnlocked
                    ? null
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04)),
                border: Border.all(
                  color: widget.isUnlocked
                      ? widget.color.withValues(alpha: 0.5)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06)),
                  width: widget.isUnlocked ? 2.0 : 1.0,
                ),
                boxShadow: widget.isUnlocked
                    ? [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.35),
                          blurRadius: 16,
                          spreadRadius: 0,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.15),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Icon(
                  widget.icon,
                  size: 28,
                  color: widget.isUnlocked
                      ? Colors.white
                      : (isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // --- Title ---
            Text(
              widget.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: widget.isUnlocked ? FontWeight.w700 : FontWeight.w500,
                color: widget.isUnlocked
                    ? (isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight)
                    : (isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight),
                letterSpacing: -0.1,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),

            // --- Subtitle ---
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: widget.isUnlocked
                    ? widget.color.withValues(alpha: 0.8)
                    : (isDark
                        ? AppColors.textTertiaryDark.withValues(alpha: 0.6)
                        : AppColors.textTertiaryLight.withValues(alpha: 0.6)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
