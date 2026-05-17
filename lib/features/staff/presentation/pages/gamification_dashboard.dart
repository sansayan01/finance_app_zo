import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/staff_providers.dart';
import '../../data/providers/gamification_providers.dart';

class GamificationDashboard extends ConsumerStatefulWidget {
  const GamificationDashboard({super.key});

  @override
  ConsumerState<GamificationDashboard> createState() =>
      _GamificationDashboardState();
}

class _GamificationDashboardState extends ConsumerState<GamificationDashboard>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_rounded,
                color: isDark ? Colors.white70 : Colors.black87)),
        title: const Text('Gamification',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(staffStreakProvider);
          ref.invalidate(staffPointsProvider);
          ref.invalidate(staffRankProvider);
          ref.invalidate(todayTargetProvider);
          ref.invalidate(staffLeaderboardProvider);
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _streakCard(theme),
              const SizedBox(height: 24),
              _statsRow(theme, isDark),
              const SizedBox(height: 24),
              _targetRing(theme, isDark),
              const SizedBox(height: 24),
              _achievements(theme, isDark),
              const SizedBox(height: 24),
              _milestones(theme, isDark),
              const SizedBox(height: 24),
              _leaderboard(theme, isDark),
              const SizedBox(height: 32),
              _motivation(theme),
            ]
                .animate(interval: 80.ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
          ),
        ),
      ),
    );
  }

  Widget _streakCard(ThemeData theme) {
    return ref.watch(staffStreakProvider).when(
          data: (s) {
            final cur = s?.currentStreak ?? 0;
            final best = s?.longestStreak ?? 0;
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.4),
                      blurRadius: 40,
                      offset: const Offset(0, 20)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Mesh Gradient Simulation
                  Container(
                    height: 320,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade600,
                          Colors.deepOrange.shade800
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -100,
                    right: -100,
                    child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.yellow.withValues(alpha: 0.15))),
                  ),
                  Positioned(
                    bottom: -50,
                    left: -50,
                    child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.withValues(alpha: 0.2))),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        const Text('CURRENT STREAK',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 2.5)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedBuilder(
                              animation: _pulseCtrl,
                              builder: (_, ch) => Transform.scale(
                                  scale: 1.0 + _pulseCtrl.value * 0.1,
                                  child: ch),
                              child: const Icon(
                                  Icons.local_fire_department_rounded,
                                  color: Colors.white,
                                  size: 48),
                            ),
                            Text('$cur',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 110,
                                    fontWeight: FontWeight.w900,
                                    height: 0.9,
                                    letterSpacing: -5)),
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text('days',
                                  style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2))),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.emoji_events_rounded,
                                  color: Colors.yellow.shade400, size: 20),
                              const SizedBox(width: 10),
                              Text('Personal Best: $best days',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(7, (i) {
                            final d =
                                DateTime.now().subtract(Duration(days: 6 - i));
                            final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                            final lastD = s?.lastCollectionDate;
                            final active = lastD != null &&
                                !d.isAfter(DateTime(
                                    lastD.year, lastD.month, lastD.day));
                            return Column(
                              children: [
                                Text(labels[d.weekday - 1],
                                    style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.6),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: active
                                        ? null
                                        : Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.2)),
                                    boxShadow: active
                                        ? [
                                            BoxShadow(
                                                color: Colors.white
                                                    .withValues(alpha: 0.3),
                                                blurRadius: 10)
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: active
                                        ? Icon(Icons.check_rounded,
                                            color: Colors.deepOrange.shade800,
                                            size: 20,
                                            weight: 800)
                                        : Text('${d.day}',
                                            style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.6),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => _skeleton(theme, 320),
          error: (_, __) => _skeleton(theme, 320),
        );
  }

  Widget _statsRow(ThemeData theme, bool isDark) {
    final points = ref.watch(staffPointsProvider).valueOrNull ?? 0;
    final rank = ref.watch(staffRankProvider).valueOrNull;
    final streak = ref.watch(staffStreakProvider).valueOrNull;
    final totalCollections = streak?.totalCollections ?? 0;

    return Row(
      children: [
        Expanded(
            child: _statCard(theme, Icons.auto_awesome_rounded, '$points',
                'Points', AppColors.accent, isDark)),
        const SizedBox(width: 10),
        Expanded(
            child: _statCard(
                theme,
                Icons.leaderboard_rounded,
                rank != null ? '#$rank' : '-',
                'Rank',
                AppColors.primary,
                isDark)),
        const SizedBox(width: 10),
        Expanded(
            child: _statCard(theme, Icons.payments_rounded, '$totalCollections',
                'Colls', AppColors.info, isDark)),
      ],
    );
  }

  Widget _statCard(ThemeData theme, IconData icon, String value, String label,
      Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: isDark ? 0.05 : 0.03),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1.1,
                  letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _targetRing(ThemeData theme, bool isDark) {
    return ref.watch(todayTargetProvider).when(
          data: (t) {
            final pct = t?.progress ?? 0.0;
            final achieved = t?.achievedAmount ?? 0.0;
            final goal = t?.targetAmount ?? 1.0;
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF181C24) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04)),
                boxShadow: [
                  BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                      blurRadius: 24,
                      offset: const Offset(0, 10))
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: Stack(alignment: Alignment.center, children: [
                      SizedBox(
                          width: 90,
                          height: 90,
                          child: CircularProgressIndicator(
                              value: pct.clamp(0, 1),
                              strokeWidth: 7,
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : theme.colorScheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(pct >= 1
                                  ? AppColors.success
                                  : AppColors.primary))),
                      Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${(pct * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: pct >= 1
                                        ? AppColors.success
                                        : AppColors.primary,
                                    height: 1.1)),
                            Text('Today',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.35))),
                          ]),
                    ]),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Daily Target',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark ? Colors.white : Colors.black87)),
                          const SizedBox(height: 4),
                          Text(
                              '₹${achieved.toStringAsFixed(0)} of ₹${goal.toStringAsFixed(0)}',
                              style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5))),
                          if (pct >= 1)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                    color: AppColors.success
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.celebration,
                                          color: AppColors.success, size: 14),
                                      const SizedBox(width: 4),
                                      Text('Completed!',
                                          style: TextStyle(
                                              color: AppColors.success,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11)),
                                    ]),
                              ),
                            ),
                        ]),
                  ),
                ],
              ),
            );
          },
          loading: () => _skeleton(theme, 100),
          error: (_, __) => _skeleton(theme, 100),
        );
  }

  Widget _achievements(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ACHIEVEMENTS',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      letterSpacing: 1.5)),
              Text('8 OF 12',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              _achievementCard(
                  theme,
                  Icons.workspace_premium_rounded,
                  'Early Bird',
                  'First 10 collections before 10 AM',
                  AppColors.primary,
                  true,
                  isDark),
              _achievementCard(theme, Icons.auto_awesome_rounded, 'Streak King',
                  'Maintain a 14-day streak', Colors.orange, true, isDark),
              _achievementCard(
                  theme,
                  Icons.shield_rounded,
                  'Trust Shield',
                  'Zero overdue in your portfolio',
                  AppColors.success,
                  false,
                  isDark),
              _achievementCard(
                  theme,
                  Icons.diamond_rounded,
                  'Elite Agent',
                  'Collect over ₹1L in a single day',
                  Colors.cyan,
                  false,
                  isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _achievementCard(ThemeData theme, IconData icon, String title,
      String desc, Color color, bool unlocked, bool isDark) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C24) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: unlocked
                ? color.withValues(alpha: 0.3)
                : (isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.05))),
        boxShadow: [
          BoxShadow(
              color: (unlocked ? color : Colors.black).withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: (unlocked ? color : Colors.grey).withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: Icon(icon, color: unlocked ? color : Colors.grey, size: 18),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 4),
          Text(desc,
              style: TextStyle(
                  fontSize: 9,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  height: 1.2),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _milestones(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C24) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MILESTONE PATH',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  letterSpacing: 1.5)),
          const SizedBox(height: 24),
          _milestoneItem(
              theme, '50 Collections', 'Unlocked a new badge!', true, true),
          _milestoneItem(
              theme, '75 Collections', '₹500 Bonus Reward', false, true),
          _milestoneItem(
              theme, '100 Collections', 'Elite Tier Status', false, false),
        ],
      ),
    );
  }

  Widget _milestoneItem(
      ThemeData theme, String title, String sub, bool done, bool current) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: done
                      ? AppColors.success
                      : (current
                          ? AppColors.primary
                          : Colors.grey.withValues(alpha: 0.2)),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                        color: (done ? AppColors.success : AppColors.primary)
                            .withValues(alpha: 0.3),
                        blurRadius: 8)
                  ],
                ),
                child: done
                    ? const Icon(Icons.check, color: Colors.white, size: 12)
                    : null,
              ),
              Expanded(
                  child: Container(
                      width: 2,
                      color: done
                          ? AppColors.success.withValues(alpha: 0.3)
                          : Colors.grey.withValues(alpha: 0.1))),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: done || current ? 1.0 : 0.4))),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaderboard(ThemeData theme, bool isDark) {
    return ref.watch(staffLeaderboardProvider).when(
          data: (lb) {
            final entries = lb.entries.take(5).toList();
            if (entries.isEmpty) return const SizedBox.shrink();

            final top3 = entries.take(3).toList();
            final others = entries.skip(3).toList();

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF181C24) : Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04)),
                boxShadow: [
                  BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
                      blurRadius: 20)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.leaderboard_rounded,
                                size: 20, color: AppColors.primary)),
                        const SizedBox(width: 12),
                        Text('Elite Performers',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black87)),
                      ]),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10)),
                          child: Text('DAILY',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1))),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Podium
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (top3.length >= 2)
                        _podiumItem(theme, top3[1], 2, Colors.grey.shade400, 70,
                            isDark),
                      if (top3.isNotEmpty)
                        _podiumItem(theme, top3[0], 1, Colors.amber.shade600,
                            95, isDark),
                      if (top3.length >= 3)
                        _podiumItem(theme, top3[2], 3, Colors.brown.shade400,
                            60, isDark),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  ...others.asMap().entries.map((e) {
                    final entry = e.value;
                    final isMe = entry.staffId == lb.currentUserStaffId;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                shape: BoxShape.circle),
                            child: Center(
                                child: Text('${e.key + 4}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.5)))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(entry.staffName,
                                style: TextStyle(
                                    fontWeight: isMe
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: isMe
                                        ? AppColors.primary
                                        : (isDark
                                            ? Colors.white70
                                            : Colors.black87))),
                          ),
                          Text('₹${entry.totalCollected.toStringAsFixed(0)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontSize: 14)),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => context.push('/staff/gamification'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('View Full Leaderboard',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13)),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => _skeleton(theme, 300),
          error: (_, __) => _skeleton(theme, 300),
        );
  }

  Widget _podiumItem(ThemeData theme, dynamic entry, int rank, Color color,
      double height, bool isDark) {
    return Container(
      width: 85,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: color.withValues(alpha: 0.3), blurRadius: 12)
                  ],
                ),
                child: Center(
                    child: Icon(Icons.person_rounded,
                        color: color.withValues(alpha: 0.5), size: 30)),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color:
                              isDark ? const Color(0xFF181C24) : Colors.white,
                          width: 2)),
                  child: Center(
                      child: Text('$rank',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(entry.staffName,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('₹${entry.totalCollected.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 8),
          Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                color.withValues(alpha: 0.2),
                color.withValues(alpha: 0.05)
              ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _motivation(ThemeData theme) {
    final quotes = [
      'Every collection counts. Keep going!',
      'You\'re making a real difference.',
      'Consistency is the key to success.',
      'Your dedication is truly inspiring.',
      'Small wins add up to big results.',
    ];
    final q = quotes[math.Random().nextInt(quotes.length)];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.primary.withValues(alpha: 0.06),
          AppColors.accent.withValues(alpha: 0.03)
        ]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: Icon(Icons.lightbulb_outline_rounded,
                color: Colors.amber.shade600, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
              child: Text(q,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6)))),
        ],
      ),
    );
  }

  Widget _skeleton(ThemeData theme, double h) {
    return Container(
      height: h,
      decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(28)),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
