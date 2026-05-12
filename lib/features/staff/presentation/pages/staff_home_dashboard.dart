import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../data/providers/staff_providers.dart';
import '../../data/providers/collection_providers.dart';
import '../../data/providers/sync_providers.dart';
import '../widgets/wallet_card.dart';
import '../widgets/target_progress_ring.dart';
import '../widgets/gps_status_chip.dart';
import '../widgets/today_agenda_list.dart';
import '../widgets/notification_bell.dart';
import '../widgets/check_in_card.dart';
import '../widgets/break_card.dart';
import '../widgets/sync_status_card.dart';
import '../widgets/activity_feed_timeline.dart';
import '../widgets/weekly_performance_chart.dart';
import '../widgets/leaderboard_snapshot.dart';

class StaffHomeDashboard extends ConsumerStatefulWidget {
  const StaffHomeDashboard({super.key});

  @override
  ConsumerState<StaffHomeDashboard> createState() => _StaffHomeDashboardState();
}

class _StaffHomeDashboardState extends ConsumerState<StaffHomeDashboard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final profileAsync = ref.watch(staffProfileProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF8F9FE),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(staffProfileProvider);
          ref.invalidate(staffWalletProvider);
          ref.invalidate(staffStreakProvider);
          ref.invalidate(todayTargetProvider);
          ref.invalidate(todayDueEmisProvider);
          ref.invalidate(todayCollectionsProvider);
          ref.invalidate(todayCollectionStatsProvider);
          ref.invalidate(unreadNotificationCountProvider);
          ref.invalidate(recentNotificationsProvider);
          ref.invalidate(activeVisitProvider);
          ref.invalidate(recentActivitiesProvider);
          ref.invalidate(todaySavingsStatsProvider);
          ref.invalidate(weeklyTrendProvider);
          ref.invalidate(nearbyOverdueCountProvider);
          ref.invalidate(syncStatusProvider);
          await Future.delayed(const Duration(milliseconds: 800));
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverHeader(theme, profileAsync, isDark),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Sync Status
                  const SyncStatusCard(),
                  const SizedBox(height: 16),

                  // Check-In / Check-Out
                  const CheckInCard(),
                  const SizedBox(height: 16),

                  // Performance Pulse (real data)
                  const WeeklyPerformanceChart(),
                  const SizedBox(height: 16),

                  // Break Card
                  const BreakCard(),
                  const SizedBox(height: 24),

                  // Smart Insights
                  _buildSmartInsights(theme, isDark),
                  const SizedBox(height: 24),

                  // Wallet & Target Grid
                  _buildFinancialOverview(theme, isDark),
                  const SizedBox(height: 24),

                  // Quick Actions
                  _buildQuickActions(theme, isDark),
                  const SizedBox(height: 28),

                  // Today's Agenda
                  _buildAgendaSection(theme),
                  const SizedBox(height: 24),

                  // Activity Feed
                  const ActivityFeedTimeline(),
                  const SizedBox(height: 24),

                  // Daily Analytics
                  _buildStatsSummary(theme, isDark),
                  const SizedBox(height: 24),

                  // Leaderboard Snapshot
                  const LeaderboardSnapshot(),
                ]),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.push('/staff/collections');
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Quick Collect', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildSliverHeader(ThemeData theme, AsyncValue profileAsync, bool isDark) {
    final hour = DateTime.now().hour;
    String greeting = hour < 12 ? 'Good Morning' : (hour < 17 ? 'Good Afternoon' : 'Good Evening');
    final profileValue = profileAsync.valueOrNull;
    final activityAsync = profileValue != null
        ? ref.watch(currentActivityProvider(profileValue.id))
        : const AsyncValue<String?>.data(null);

    return SliverAppBar(
      expandedHeight: 200,
      collapsedHeight: 80,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        background: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                    ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                    : [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
                ),
              ),
            ),
            Positioned(
              right: -50, top: -50,
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    profileAsync.when(
                      data: (profile) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  greeting,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 14, fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const NotificationBell(),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  profile?.fullName ?? 'Agent',
                                  style: const TextStyle(
                                    color: Colors.white, fontSize: 28,
                                    fontWeight: FontWeight.w900, letterSpacing: -1.0,
                                  ),
                                ),
                              ),
                              const GpsStatusChip(status: GpsStatus.active, accuracy: 5),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  profile?.staffCode ?? 'S-001',
                                  style: const TextStyle(
                                    color: Colors.white, fontSize: 10,
                                    fontWeight: FontWeight.w700, letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              if (profile?.branchName != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.business_rounded, size: 10, color: Colors.white.withValues(alpha: 0.7)),
                                      const SizedBox(width: 4),
                                      Text(
                                        profile!.branchName!,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.8), fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (profile != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _shiftColor(profile.shift.name).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    profile.shift.name.replaceAll('_', ' ').toUpperCase(),
                                    style: TextStyle(
                                      color: _shiftColor(profile.shift.name).withValues(alpha: 0.9), fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          activityAsync.when(
                            data: (activity) {
                              if (activity == null) return const SizedBox.shrink();
                              final (label, color) = _activityDisplay(activity);
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6, height: 6,
                                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      label,
                                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                      loading: () => const ShimmerCard(height: 80),
                      error: (_, __) => const Text('Field Commander', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, Color) _activityDisplay(String activity) {
    switch (activity) {
      case 'break':
        return ('On Break', Colors.orangeAccent);
      case 'collecting':
        return ('On Visit', Colors.greenAccent);
      case 'traveling':
        return ('Traveling', AppColors.primary);
      default:
        return ('Available', Colors.white70);
    }
  }

  Color _shiftColor(String shift) {
    switch (shift) {
      case 'morning':
        return Colors.orangeAccent;
      case 'evening':
        return Colors.indigoAccent;
      case 'full_day':
        return Colors.greenAccent;
      default:
        return Colors.white70;
    }
  }

  Widget _buildSmartInsights(ThemeData theme, bool isDark) {
    final streakAsync = ref.watch(staffStreakProvider);
    final overdueCountAsync = ref.watch(nearbyOverdueCountProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Smart Insights', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildInsightCard(
                theme, isDark,
                Icons.lightbulb_outline_rounded,
                'Peak Collection Time',
                'Best results between 10 AM - 12 PM',
                const Color(0xFF3B82F6),
              ),
              const SizedBox(width: 12),
              _buildInsightCard(
                theme, isDark,
                Icons.location_on_outlined,
                'Nearby Priority',
                overdueCountAsync.when(
                  data: (count) => count > 0 ? '$count overdue collections pending' : 'No overdue nearby',
                  loading: () => 'Loading...',
                  error: (_, __) => 'Check nearby overdue',
                ),
                const Color(0xFFEF4444),
              ),
              const SizedBox(width: 12),
              _buildInsightCard(
                theme, isDark,
                Icons.emoji_events_outlined,
                'Streak Bonus',
                streakAsync.when(
                  data: (streak) {
                    final current = streak?.currentStreak ?? 0;
                    if (current >= 7) return '🔥 $current-day streak! Keep it up!';
                    if (current > 0) return '$current-day streak — ${7 - current} days to Elite';
                    return 'Start collecting to build your streak!';
                  },
                  loading: () => 'Loading streak...',
                  error: (_, __) => 'Track your streak',
                ),
                const Color(0xFFF59E0B),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard(ThemeData theme, bool isDark, IconData icon, String title, String subtitle, Color color) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800, color: color)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialOverview(ThemeData theme, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: _buildWalletSection(theme)),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: _buildTargetColumn(theme, isDark)),
      ],
    );
  }

  Widget _buildTargetColumn(ThemeData theme, bool isDark) {
    final dailyTargetAsync = ref.watch(todayTargetProvider);
    final streakAsync = ref.watch(staffStreakProvider);
    final profileAsync = ref.watch(staffProfileProvider);

    return Column(
      children: [
        _buildDailyTargetCompact(dailyTargetAsync, streakAsync, theme, isDark),
        const SizedBox(height: 12),
        _buildMonthlyTargetCompact(profileAsync, theme, isDark),
      ],
    );
  }

  Widget _buildDailyTargetCompact(AsyncValue dailyTargetAsync, AsyncValue streakAsync, ThemeData theme, bool isDark) {
    return dailyTargetAsync.when(
      data: (target) {
        if (target == null) return const SizedBox.shrink();
        return streakAsync.when(
          data: (streak) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.05), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              children: [
                TargetProgressRing(target: target, streak: streak, size: 64, onTap: () => context.push('/staff/targets')),
                const SizedBox(height: 8),
                Text('${(target.progress * 100).toStringAsFixed(0)}%', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                Text('Daily', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ),
          loading: () => const ShimmerCard(height: 140),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const ShimmerCard(height: 140),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildMonthlyTargetCompact(AsyncValue profileAsync, ThemeData theme, bool isDark) {
    return profileAsync.when(
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();
        final monthlyTarget = profile.monthlyCollectionTarget;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.05), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            children: [
              Icon(Icons.calendar_month_rounded, size: 20, color: AppColors.accent.withValues(alpha: 0.6)),
              const SizedBox(height: 8),
              Text(
                '₹${monthlyTarget.toStringAsFixed(0)}',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: AppColors.accent),
              ),
              Text('Monthly', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
            ],
          ),
        );
      },
      loading: () => const ShimmerCard(height: 100),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildWalletSection(ThemeData theme) {
    final walletAsync = ref.watch(staffWalletProvider);
    return walletAsync.when(
      data: (wallet) {
        if (wallet == null) return const SizedBox.shrink();
        return WalletCard(wallet: wallet, onDeposit: () => _showDepositSheet(wallet.cashInHand));
      },
      loading: () => const ShimmerCard(height: 200),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildQuickActions(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Operations', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            TextButton(
              onPressed: () {},
              child: Text('View All', style: TextStyle(color: AppColors.primary, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildActionCard(icon: Icons.history_rounded, label: 'Logbook', color: const Color(0xFF6366F1), onTap: () => context.push('/staff/history'), isDark: isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildActionCard(icon: Icons.warning_amber_rounded, label: 'Overdue', color: const Color(0xFFF59E0B), onTap: () => context.push('/staff/overdue'), isDark: isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildActionCard(icon: Icons.map_outlined, label: 'Router', color: const Color(0xFF10B981), onTap: () => context.push('/staff/map'), isDark: isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildActionCard(icon: Icons.settings_outlined, label: 'Settings', color: const Color(0xFF64748B), onTap: () => context.push('/staff/settings'), isDark: isDark)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildActionCard(icon: Icons.login_rounded, label: 'Check In', color: const Color(0xFF06B6D4), onTap: () => context.push('/staff/visit'), isDark: isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildActionCard(icon: Icons.coffee_outlined, label: 'Break', color: const Color(0xFFF97316), onTap: () => context.push('/staff/break'), isDark: isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildActionCard(icon: Icons.analytics_outlined, label: 'Analytics', color: AppColors.accent, onTap: () => context.push('/staff/analytics'), isDark: isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildActionCard(icon: Icons.emoji_events_outlined, label: 'Gamification', color: const Color(0xFFF59E0B), onTap: () => context.push('/staff/gamification'), isDark: isDark)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({required IconData icon, required String label, required Color color, required VoidCallback onTap, required bool isDark}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(label, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800, color: isDark ? Colors.white70 : Colors.black87, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildAgendaSection(ThemeData theme) {
    final emisAsync = ref.watch(todayDueEmisProvider);
    final profileAsync = ref.watch(staffProfileProvider);
    return emisAsync.when(
      data: (emis) => profileAsync.when(
        data: (profile) => TodayAgendaList(emis: emis, staffId: profile?.id, onRefresh: () { ref.invalidate(todayDueEmisProvider); }),
        loading: () => const ShimmerCard(height: 200),
        error: (_, __) => const SizedBox.shrink(),
      ),
      loading: () => const ShimmerCard(height: 200),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildStatsSummary(ThemeData theme, bool isDark) {
    final statsAsync = ref.watch(todayCollectionStatsProvider);
    final savingsAsync = ref.watch(todaySavingsStatsProvider);

    return statsAsync.when(
      data: (stats) {
        return savingsAsync.when(
          data: (savings) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.05), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Daily Analytics', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      Icon(Icons.insights_rounded, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: _buildSummaryItem(theme, 'Collection', '₹${(stats['total_collected'] ?? 0).toStringAsFixed(0)}', AppColors.primary)),
                      _buildDivider(theme),
                      Expanded(child: _buildSummaryItem(theme, 'Cash', '₹${(stats['cash_collected'] ?? 0).toStringAsFixed(0)}', Colors.greenAccent)),
                      _buildDivider(theme),
                      Expanded(child: _buildSummaryItem(theme, 'Digital', '₹${(stats['digital_collected'] ?? 0).toStringAsFixed(0)}', Colors.purpleAccent)),
                      _buildDivider(theme),
                      Expanded(child: _buildSummaryItem(theme, 'Count', '${stats['collection_count'] ?? 0}', Colors.orangeAccent)),
                    ],
                  ),
                  if ((savings['total_savings'] as num?)?.toDouble() != 0) ...[
                    const SizedBox(height: 16),
                    Container(height: 1, color: theme.dividerColor.withValues(alpha: 0.2)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildSummaryItem(theme, 'Savings', '₹${(savings['total_savings'] as num).toStringAsFixed(0)}', AppColors.teal)),
                        _buildDivider(theme),
                        Expanded(child: _buildSummaryItem(theme, 'Savings Cash', '₹${(savings['cash_savings'] as num).toStringAsFixed(0)}', Colors.greenAccent)),
                        _buildDivider(theme),
                        Expanded(child: _buildSummaryItem(theme, 'Savings Dig.', '₹${(savings['digital_savings'] as num).toStringAsFixed(0)}', Colors.purpleAccent)),
                        _buildDivider(theme),
                        Expanded(child: _buildSummaryItem(theme, 'Count', '${savings['savings_count']}', Colors.orangeAccent)),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
          loading: () => const ShimmerCard(height: 120),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const ShimmerCard(height: 120),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Container(width: 1, height: 40, color: theme.dividerColor.withValues(alpha: 0.2));
  }

  Widget _buildSummaryItem(ThemeData theme, String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
      ],
    );
  }

  void _showDepositSheet(double cashInHand) {
    final theme = Theme.of(context);
    final amountController = TextEditingController();
    String selectedMode = 'bank';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              Text('Deposit to Bank', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Available: ₹${cashInHand.toStringAsFixed(0)}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              const SizedBox(height: 20),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  hintText: '0',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: ['bank', 'upi'].map((mode) {
                  final isSelected = selectedMode == mode;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: mode == 'bank' ? 8 : 0),
                      child: GestureDetector(
                        onTap: () => setModalState(() => selectedMode = mode),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent),
                          ),
                          child: Center(
                            child: Text(
                              mode.toUpperCase(),
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text);
                    if (amount == null || amount <= 0 || amount > cashInHand) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invalid amount'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    final messenger = ScaffoldMessenger.of(context);
                    final profile = await ref.read(staffProfileProvider.future);
                    if (profile != null) {
                      final repo = ref.read(staffRepositoryProvider);
                      await repo.recordDeposit(staffId: profile.id, amount: amount, depositMode: selectedMode);
                    }
                    if (!context.mounted) return;
                    Navigator.pop(ctx);
                    ref.invalidate(staffWalletProvider);
                    messenger.showSnackBar(
                      SnackBar(content: Text('₹${amount.toStringAsFixed(0)} deposited successfully'), backgroundColor: Colors.green),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Confirm Deposit', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
