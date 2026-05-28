import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/providers/gamification_providers.dart';
import 'premium_helpers.dart';

class LeaderboardSnapshot extends ConsumerWidget {
  const LeaderboardSnapshot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final leaderboardAsync = ref.watch(staffLeaderboardProvider);

    return leaderboardAsync.when(
      data: (leaderboard) {
        if (leaderboard.entries.isEmpty) return const SizedBox.shrink();

        final myEntry = leaderboard.currentUserStaffId != null
            ? leaderboard.entries
                .where((e) => e.staffId == leaderboard.currentUserStaffId)
                .firstOrNull
            : null;
        final myRank =
            myEntry != null ? leaderboard.entries.indexOf(myEntry) + 1 : null;
        final top3 = leaderboard.entries.take(3).toList();

        return GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumHelpers.sectionHeader(
                theme,
                'Leaderboard',
                icon: Icons.leaderboard_rounded,
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Today',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...top3.asMap().entries.map((entry) {
                final index = entry.key;
                final e = entry.value;
                final isMe = e.staffId == leaderboard.currentUserStaffId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: index == 0
                              ? Colors.amber.shade400
                              : index == 1
                                  ? Colors.grey.shade400
                                  : Colors.brown.shade300,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (index == 0
                                      ? Colors.amber.shade400
                                      : index == 1
                                          ? Colors.grey.shade400
                                          : Colors.brown.shade300)
                                  .withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e.staffName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight:
                                isMe ? FontWeight.w800 : FontWeight.w500,
                            color: isMe ? AppColors.primary : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '₹${e.totalCollected.toStringAsFixed(0)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (myRank != null && myRank > 3) ...[
                const Divider(height: 4),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$myRank',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You',
                        style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary),
                      ),
                    ),
                    Text(
                      '₹${(myEntry?.totalCollected ?? 0).toStringAsFixed(0)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => context.push('/staff/gamification'),
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.primary),
                  child: const Text('View Full Leaderboard',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
