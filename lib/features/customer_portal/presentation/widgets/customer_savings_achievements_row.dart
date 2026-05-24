import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import 'customer_savings_achievement_badge.dart';

/// A horizontal scrollable row of savings achievement badges.
/// Shows all 5 tiers with locked/unlocked state based on progress.
class CustomerSavingsAchievementsRow extends StatelessWidget {
  final double currentAmount;
  final double targetAmount;
  final int depositCount;

  const CustomerSavingsAchievementsRow({
    super.key,
    required this.currentAmount,
    required this.targetAmount,
    required this.depositCount,
  });

  double get _progress =>
      targetAmount > 0
          ? (currentAmount / targetAmount).clamp(0.0, 1.0)
          : 0.0;

  List<_AchievementTier> _buildTiers() {
    return [
      _AchievementTier(
        title: 'First Deposit',
        subtitle: depositCount > 0 ? 'Unlocked' : 'Make 1st deposit',
        icon: Icons.savings_rounded,
        color: AppColors.teal,
        isUnlocked: depositCount > 0,
      ),
      _AchievementTier(
        title: 'Quarter Saver',
        subtitle: _progress >= 0.25 ? '25% reached' : 'Reach 25%',
        icon: Icons.star_rounded,
        color: AppColors.warning,
        isUnlocked: _progress >= 0.25,
      ),
      _AchievementTier(
        title: 'Halfway Hero',
        subtitle: _progress >= 0.50 ? '50% reached' : 'Reach 50%',
        icon: Icons.diamond_rounded,
        color: AppColors.indigo,
        isUnlocked: _progress >= 0.50,
      ),
      _AchievementTier(
        title: 'Almost Legend',
        subtitle: _progress >= 0.75 ? '75% reached' : 'Reach 75%',
        icon: Icons.military_tech_rounded,
        color: AppColors.orange,
        isUnlocked: _progress >= 0.75,
      ),
      _AchievementTier(
        title: 'Goal Champion',
        subtitle: _progress >= 1.0 ? 'Goal completed!' : 'Reach 100%',
        icon: Icons.workspace_premium_rounded,
        color: const Color(0xFFF59E0B),
        isUnlocked: _progress >= 1.0,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tiers = _buildTiers();
    final unlockedCount = tiers.where((t) => t.isUnlocked).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(
                Icons.emoji_events_rounded,
                size: 18,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 8),
              Text(
                'Achievements',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
                ),
                child: Text(
                  '$unlockedCount / ${tiers.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Scrollable badges
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: tiers.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final tier = tiers[index];
              return CustomerSavingsAchievementBadge(
                title: tier.title,
                subtitle: tier.subtitle,
                icon: tier.icon,
                color: tier.color,
                isUnlocked: tier.isUnlocked,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AchievementTier {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isUnlocked;

  const _AchievementTier({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isUnlocked,
  });
}
