import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/providers/staff_providers.dart';

class GamificationDashboard extends ConsumerStatefulWidget {
  const GamificationDashboard({super.key});

  @override
  ConsumerState<GamificationDashboard> createState() => _GamificationDashboardState();
}

class _GamificationDashboardState extends ConsumerState<GamificationDashboard>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).value;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final streakAsync = ref.watch(staffStreakProvider);
    final walletAsync = ref.watch(staffWalletProvider);
    final targetsAsync = ref.watch(todayTargetProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStreakHeader(streakAsync, theme),
          const SizedBox(height: 20),
          _buildProgressSection(targetsAsync, walletAsync, theme),
          const SizedBox(height: 20),
          _buildAchievementsSection(theme),
          const SizedBox(height: 20),
          _buildLeaderboardSection(theme),
          const SizedBox(height: 20),
          _buildMotivationCard(theme),
        ],
      ),
    );
  }

  Widget _buildStreakHeader(AsyncValue streakAsync, ThemeData theme) {
    return streakAsync.when(
      data: (streak) {
        final currentStreak = streak?.currentStreak ?? 0;
        final longestStreak = streak?.longestStreak ?? 0;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.shade400,
                Colors.orange.shade700,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFireIcon(),
                  const SizedBox(width: 12),
                  Text(
                    '$currentStreak',
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 64,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DAY',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'STREAK',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: Colors.yellow.shade200,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Best: $longestStreak days',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildStreakCalendar(theme),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildErrorCard('Failed to load streak', theme),
    );
  }

  Widget _buildFireIcon() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_pulseController.value * 0.1),
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.local_fire_department,
          color: Colors.white,
          size: 48,
        ),
      ),
    );
  }

  Widget _buildStreakCalendar(ThemeData theme) {
    // Show last 7 days
    final days = List.generate(7, (index) {
      final date = DateTime.now().subtract(Duration(days: 6 - index));
      final isActive = index >= 3; // Simulated active days
      return {'date': date, 'isActive': isActive};
    });

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: days.map((day) {
        final date = day['date'] as DateTime;
        final isActive = day['isActive'] as bool;
        final dayName = ['M', 'T', 'W', 'T', 'F', 'S', 'S'][date.weekday - 1];

        return Column(
          children: [
            Text(
              dayName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isActive
                    ? Icon(Icons.check, color: Colors.orange.shade700, size: 18)
                    : Text(
                        '${date.day}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildProgressSection(
    AsyncValue targetsAsync,
    AsyncValue walletAsync,
    ThemeData theme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _buildTargetProgress(targetsAsync, theme),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildQuickStats(walletAsync, theme),
        ),
      ],
    );
  }

  Widget _buildTargetProgress(AsyncValue targetsAsync, ThemeData theme) {
    return targetsAsync.when(
      data: (target) {
        final progress = (target?.progress ?? 0.0).clamp(0.0, 1.0);
        final achieved = target?.achievedAmount ?? 0.0;
        final goal = target?.targetAmount ?? 1.0;

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today\'s Target',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildCircularProgress(progress, theme),
              const SizedBox(height: 16),
              Text(
                '₹${achieved.toStringAsFixed(0)} / ₹${goal.toStringAsFixed(0)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              if (progress >= 1.0) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.celebration, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Target Achieved!',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const GlassCard(child: Center(child: CircularProgressIndicator())),
      error: (_, __) => _buildErrorCard('Failed to load target', theme),
    );
  }

  Widget _buildCircularProgress(double progress, ThemeData theme) {
    return Center(
      child: SizedBox(
        width: 120,
        height: 120,
        child: CustomPaint(
          painter: _ProgressPainter(
            progress: progress,
            color: progress >= 1.0
                ? Colors.green
                : theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
          child: Center(
            child: Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats(AsyncValue walletAsync, ThemeData theme) {
    return walletAsync.when(
      data: (wallet) {
        return Column(
          children: [
            _buildStatCard(
              'Collected',
              '₹${wallet?.totalCollectedToday.toStringAsFixed(0) ?? '0'}',
              Icons.payments,
              Colors.green,
              theme,
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              'Visits',
              '${wallet?.totalVisitsToday ?? 0}',
              Icons.place,
              Colors.blue,
              theme,
            ),
          ],
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => _buildErrorCard('Error', theme),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection(ThemeData theme) {
    final achievements = [
      {'icon': Icons.star, 'title': 'First Collection', 'unlocked': true},
      {'icon': Icons.speed, 'title': 'Speed Star', 'unlocked': true},
      {'icon': Icons.local_fire_department, 'title': '7 Day Streak', 'unlocked': true},
      {'icon': Icons.emoji_events, 'title': 'Top Collector', 'unlocked': false},
      {'icon': Icons.workspace_premium, 'title': '100% Target', 'unlocked': false},
      {'icon': Icons.diamond, 'title': 'Diamond Club', 'unlocked': false},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Achievements',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: achievements.length,
            itemBuilder: (context, index) {
              final a = achievements[index];
              return _buildAchievementBadge(
                a['icon'] as IconData,
                a['title'] as String,
                a['unlocked'] as bool,
                theme,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementBadge(
    IconData icon,
    String title,
    bool unlocked,
    ThemeData theme,
  ) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: unlocked
                  ? LinearGradient(
                      colors: [
                        Colors.amber.shade300,
                        Colors.amber.shade600,
                      ],
                    )
                  : null,
              color: unlocked ? null : theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
              border: unlocked
                  ? null
                  : Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.3),
                      width: 2,
                    ),
            ),
            child: Icon(
              icon,
              color: unlocked ? Colors.white : theme.colorScheme.outline,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: unlocked ? FontWeight.bold : null,
              color: unlocked ? null : theme.colorScheme.outline,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardSection(ThemeData theme) {
    final leaders = [
      {'rank': 1, 'name': 'Rahul K.', 'amount': 45000, 'avatar': Colors.red},
      {'rank': 2, 'name': 'Priya S.', 'amount': 42000, 'avatar': Colors.blue},
      {'rank': 3, 'name': 'Amit T.', 'amount': 38000, 'avatar': Colors.green},
    ];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Leaderboard',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'This Week',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...leaders.map((l) => _buildLeaderItem(l, theme)),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.leaderboard, size: 18),
              label: const Text('View Full Leaderboard'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderItem(Map<String, dynamic> leader, ThemeData theme) {
    final rank = leader['rank'] as int;
    final name = leader['name'] as String;
    final amount = leader['amount'] as int;
    final avatarColor = leader['avatar'] as Color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: rank == 1
                  ? Colors.amber
                  : rank == 2
                      ? Colors.grey.shade400
                      : Colors.brown.shade300,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 18,
            backgroundColor: avatarColor.withOpacity(0.2),
            child: Text(
              name[0],
              style: TextStyle(
                color: avatarColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '₹$amount',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotivationCard(ThemeData theme) {
    final quotes = [
      'Every collection counts! Keep going! 💪',
      'You\'re making a difference in people\'s lives! 🌟',
      'Consistency is key. Great work today! 🎯',
      'Your dedication is inspiring! 🚀',
      'Small steps lead to big achievements! 🏆',
    ];

    final random = math.Random();
    final quote = quotes[random.nextInt(quotes.length)];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lightbulb,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              quote,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message, ThemeData theme) {
    return GlassCard(
      child: Center(
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _ProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter oldDelegate) {
    return progress != oldDelegate.progress || color != oldDelegate.color;
  }
}
