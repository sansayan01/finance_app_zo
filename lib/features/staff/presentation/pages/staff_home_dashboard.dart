import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
import '../widgets/sync_status_card.dart';
import '../widgets/activity_feed_timeline.dart';
import '../widgets/on_duty_toggle.dart';
import '../widgets/duty_status_card.dart';
import '../../data/providers/duty_providers.dart';

import '../widgets/leaderboard_snapshot.dart';
import '../../../../core/widgets/branded_loading.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
// ignore: unused_import
import '../../../../core/widgets/glass_button.dart';
import '../widgets/premium_helpers.dart';
import '../../../home/data/providers/dashboard_providers.dart'
    show dashboardLoansProvider, dashboardSavingsProvider;
import '../../../loans/data/models/loan_model.dart';
import '../../../savings/data/models/savings_model.dart';
import '../../../../core/constants/enums.dart';

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
      backgroundColor:
          isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF8F9FE),
      body: AuroraBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            HapticService.light();
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
            ref.invalidate(onDutyProvider);
            ref.invalidate(todayDutyMinutesProvider);
            ref.invalidate(activeDutySessionProvider);
            await Future.delayed(const Duration(milliseconds: 800));
          },
          child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverHeader(theme, profileAsync, isDark),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildDashboardItem(index, theme, isDark),
                  childCount: 15, // 8 widgets + 7 spacers
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSliverHeader(
      ThemeData theme, AsyncValue profileAsync, bool isDark) {
    final hour = DateTime.now().hour;
    String greeting = hour < 12
        ? 'Good Morning'
        : (hour < 17 ? 'Good Afternoon' : 'Good Evening');
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
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground
        ],
        background: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                      : [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.8)
                        ],
                ),
              ),
            ),
            Positioned(
              right: -50,
              top: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              left: -30,
              bottom: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.03),
                ),
              ),
            ),
            Positioned(
              right: 80,
              bottom: 30,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
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
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile?.fullName ?? 'Agent',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1.0,
                                      ),
                                    ),
                                    DynamicBrandText(
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.6),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                      uppercase: true,
                                    ),
                                  ],
                                ),
                              ),
                              const Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  OnDutyToggle(),
                                  SizedBox(height: 4),
                                  GpsStatusChip(
                                      status: GpsStatus.active, accuracy: 5),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  profile?.staffCode ?? 'S-001',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              if (profile?.branchName != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.business_rounded,
                                          size: 10,
                                          color: Colors.white
                                              .withValues(alpha: 0.7)),
                                      const SizedBox(width: 4),
                                      Text(
                                        profile!.branchName!,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.8),
                                          fontSize: 10,
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _shiftColor(profile.shift.displayName)
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    profile.shift.displayName.toUpperCase(),
                                    style: TextStyle(
                                      color: _shiftColor(profile.shift.displayName)
                                          .withValues(alpha: 0.9),
                                      fontSize: 9,
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
                              if (activity == null) {
                                return const SizedBox.shrink();
                              }
                              final (label, color) = _activityDisplay(activity);
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                          color: color, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      label,
                                      style: TextStyle(
                                          color: color,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600),
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
                      error: (_, __) => const Text('Field Commander',
                          style: TextStyle(color: Colors.white)),
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

  Widget _buildDashboardItem(int index, ThemeData theme, bool isDark) {
    final itemIndex = index ~/ 2;
    final isSpacer = index.isOdd;

    if (isSpacer) {
      // Spacers: after items 0-2 use 16, after items 3-7 use 24/28
      final spacerHeight = itemIndex < 3 ? 16.0 : (itemIndex == 3 ? 28.0 : 24.0);
      return SizedBox(height: spacerHeight);
    }

    switch (itemIndex) {
      case 0:
        return PremiumHelpers.staggeredAnimation(const SyncStatusCard(), index: 0);
      case 1:
        return PremiumHelpers.staggeredAnimation(const DutyStatusCard(), index: 1);
      case 2:
        return PremiumHelpers.staggeredAnimation(_buildFinancialOverview(theme, isDark), index: 2);
      case 3:
        return PremiumHelpers.staggeredAnimation(_buildQuickActions(theme, isDark), index: 3);
      case 4:
        return PremiumHelpers.staggeredAnimation(_buildActiveLoansSection(theme, isDark), index: 4);
      case 5:
        return PremiumHelpers.staggeredAnimation(_buildSavingsOverviewSection(theme, isDark), index: 5);
      case 6:
        return PremiumHelpers.staggeredAnimation(_buildAgendaSection(theme), index: 6);
      case 7:
        return PremiumHelpers.staggeredAnimation(const ActivityFeedTimeline(), index: 7);
      case 8:
        return PremiumHelpers.staggeredAnimation(_buildStatsSummary(theme, isDark), index: 8);
      case 9:
        return PremiumHelpers.staggeredAnimation(const LeaderboardSnapshot(), index: 9);
      default:
        return const SizedBox.shrink();
    }
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

    return Column(
      children: [
        _buildDailyTargetCompact(dailyTargetAsync, streakAsync, theme, isDark),
      ],
    );
  }

  Widget _buildDailyTargetCompact(AsyncValue dailyTargetAsync,
      AsyncValue streakAsync, ThemeData theme, bool isDark) {
    return dailyTargetAsync.when(
      data: (target) {
        if (target == null) return const SizedBox.shrink();
        return streakAsync.when(
          data: (streak) => GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TargetProgressRing(
                    target: target,
                    streak: streak,
                    size: 64,
                    onTap: () => context.push('/staff/targets')),
                const SizedBox(height: 8),
                Text('${(target.progress * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w900)),
                Text('Daily',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5))),
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



  Widget _buildWalletSection(ThemeData theme) {
    final walletAsync = ref.watch(staffWalletProvider);
    return walletAsync.when(
      data: (wallet) {
        if (wallet == null) return const SizedBox.shrink();
        return WalletCard(
            wallet: wallet,
            onDeposit: () => _showDepositSheet(wallet.cashInHand));
      },
      loading: () => const ShimmerCard(height: 200),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildQuickActions(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumHelpers.sectionHeader(theme, 'Operations',
            trailing: TextButton(
              onPressed: () {},
              child: Text('View All',
                  style: TextStyle(color: AppColors.primary, fontSize: 12)),
            )),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _buildActionCard(
                    icon: Icons.receipt_long_rounded,
                    label: 'Payments',
                    color: const Color(0xFF667EEA),
                    onTap: () => context.push('/staff/payments'),
                    isDark: isDark)),
            const SizedBox(width: 8),
            Expanded(
                child: _buildActionCard(
                    icon: Icons.people_rounded,
                    label: 'User Hub',
                    color: const Color(0xFF10B981),
                    onTap: () => context.push('/staff/user-hub'),
                    isDark: isDark)),
            const SizedBox(width: 8),
            Expanded(
                child: _buildActionCard(
                    icon: Icons.timeline_rounded,
                    label: 'Timeline',
                    color: const Color(0xFFF59E0B),
                    onTap: () => context.push('/staff/timeline'),
                    isDark: isDark)),
            const SizedBox(width: 8),
            Expanded(
                child: _buildActionCard(
                    icon: Icons.map_rounded,
                    label: 'Map',
                    color: const Color(0xFF06B6D4),
                    onTap: () => context.push('/staff/map'),
                    isDark: isDark)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _buildActionCard(
                    icon: Icons.login_rounded,
                    label: 'Check In',
                    color: const Color(0xFF06B6D4),
                    onTap: () => context.push('/staff/visit'),
                    isDark: isDark)),
            const SizedBox(width: 8),
            Expanded(
                child: _buildActionCard(
                    icon: Icons.coffee_outlined,
                    label: 'Break',
                    color: const Color(0xFFF97316),
                    onTap: () => context.push('/staff/break'),
                    isDark: isDark)),
            const SizedBox(width: 8),
            Expanded(
                child: _buildActionCard(
                    icon: Icons.emoji_events_outlined,
                    label: 'Rewards',
                    color: const Color(0xFFF59E0B),
                    onTap: () => context.push('/staff/gamification'),
                    isDark: isDark)),
            const SizedBox(width: 8),
            Expanded(
                child: _buildActionCard(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    color: const Color(0xFF64748B),
                    onTap: () => context.push('/staff/settings'),
                    isDark: isDark)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _buildActionCard(
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'UPI Verify',
                    color: const Color(0xFF00BFA5),
                    onTap: () => context.push('/staff/upi-confirmations'),
                    isDark: isDark)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap,
      required bool isDark}) {
    final theme = Theme.of(context);
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(vertical: 14),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        children: [
          PremiumHelpers.gradientIconContainer(icon, color, size: 36, iconSize: 18),
          const SizedBox(height: 6),
          Text(label,
              style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildAgendaSection(ThemeData theme) {
    final emisAsync = ref.watch(todayDueEmisProvider);
    final profileAsync = ref.watch(staffProfileProvider);
    return emisAsync.when(
      data: (emis) => profileAsync.when(
        data: (profile) => TodayAgendaList(
            emis: emis,
            staffId: profile?.id,
            onRefresh: () {
              ref.invalidate(todayDueEmisProvider);
            }),
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
            return GlassCard(
              padding: const EdgeInsets.all(24),
              borderRadius: 28,
              elevated: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PremiumHelpers.sectionHeader(theme, 'Daily Analytics',
                      trailing: Icon(Icons.insights_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.3))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: _buildSummaryItem(
                              theme,
                              'Collection',
                              '₹${(stats['total_collected'] ?? 0).toStringAsFixed(0)}',
                              AppColors.primary)),
                      _buildDivider(theme),
                      Expanded(
                          child: _buildSummaryItem(
                              theme,
                              'Cash',
                              '₹${(stats['cash_collected'] ?? 0).toStringAsFixed(0)}',
                              Colors.greenAccent)),
                      _buildDivider(theme),
                      Expanded(
                          child: _buildSummaryItem(
                              theme,
                              'Digital',
                              '₹${(stats['digital_collected'] ?? 0).toStringAsFixed(0)}',
                              Colors.purpleAccent)),
                      _buildDivider(theme),
                      Expanded(
                          child: _buildSummaryItem(
                              theme,
                              'Count',
                              '${stats['collection_count'] ?? 0}',
                              Colors.orangeAccent)),
                    ],
                  ),
                  if ((savings['total_savings'] as num?)?.toDouble() != 0) ...[
                    const SizedBox(height: 16),
                    Container(
                        height: 1,
                        color: theme.dividerColor.withValues(alpha: 0.2)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                            child: _buildSummaryItem(
                                theme,
                                'Savings',
                                '₹${(savings['total_savings'] as num).toStringAsFixed(0)}',
                                AppColors.teal)),
                        _buildDivider(theme),
                        Expanded(
                            child: _buildSummaryItem(
                                theme,
                                'Savings Cash',
                                '₹${(savings['cash_savings'] as num).toStringAsFixed(0)}',
                                Colors.greenAccent)),
                        _buildDivider(theme),
                        Expanded(
                            child: _buildSummaryItem(
                                theme,
                                'Savings Dig.',
                                '₹${(savings['digital_savings'] as num).toStringAsFixed(0)}',
                                Colors.purpleAccent)),
                        _buildDivider(theme),
                        Expanded(
                            child: _buildSummaryItem(
                                theme,
                                'Count',
                                '${savings['savings_count']}',
                                Colors.orangeAccent)),
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
    return Container(
        width: 1, height: 40, color: theme.dividerColor.withValues(alpha: 0.2));
  }

  Widget _buildSummaryItem(
      ThemeData theme, String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 4),
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
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
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.of(ctx).viewInsets.bottom +
                  MediaQuery.of(ctx).padding.bottom +
                  100),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              Text('Deposit to Bank',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Available: ₹${cashInHand.toStringAsFixed(0)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              const SizedBox(height: 20),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  hintText: '0',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
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
                            color: isSelected
                                ? AppColors.primary
                                : theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.transparent),
                          ),
                          child: Center(
                            child: Text(
                              mode.toUpperCase(),
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: isSelected
                                    ? Colors.white
                                    : theme.colorScheme.onSurface,
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
                        const SnackBar(
                            content: Text('Invalid amount'),
                            backgroundColor: Colors.red),
                      );
                      return;
                    }
                    final messenger = ScaffoldMessenger.of(context);
                    final profile = await ref.read(staffProfileProvider.future);
                    if (profile != null) {
                      final repo = ref.read(staffRepositoryProvider);
                      await repo.recordDeposit(
                          staffId: profile.id,
                          amount: amount,
                          depositMode: selectedMode);
                    }
                    if (!context.mounted) return;
                    Navigator.pop(ctx);
                    ref.invalidate(staffWalletProvider);
                    messenger.showSnackBar(
                      SnackBar(
                          content: Text(
                              '₹${amount.toStringAsFixed(0)} deposited successfully'),
                          backgroundColor: Colors.green),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Confirm Deposit',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Active Loans Section ───

  Widget _buildActiveLoansSection(ThemeData theme, bool isDark) {
    final loansAsync = ref.watch(dashboardLoansProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.primary, AppColors.accent],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Active Loans',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => context.push('/staff/loans'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                      AppColors.accent.withValues(alpha: isDark ? 0.1 : 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: AppColors.primary,
                      size: 10,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        loansAsync.when(
          data: (loans) {
            if (loans.isEmpty) {
              return GlassCard(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.account_balance_outlined,
                          size: 32,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.3)),
                      const SizedBox(height: 8),
                      Text(
                        'No active loans',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: loans
                  .take(3)
                  .map((loan) => Padding(
                        key: ValueKey(loan.id),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: StaffLoanCard(
                          loan: loan,
                          onTap: () => context.push('/staff/loans/${loan.id}'),
                        ),
                      ))
                  .toList(),
            );
          },
          loading: () => Column(
            children: List.generate(
                2,
                (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: ShimmerCard(height: 120),
                    )),
          ),
          error: (_, __) => GlassCard(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text('Unable to load loans',
                  style: theme.textTheme.bodySmall),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Savings Overview Section ───

  Widget _buildSavingsOverviewSection(ThemeData theme, bool isDark) {
    final savingsAsync = ref.watch(dashboardSavingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.teal, AppColors.mint],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Savings',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => context.push('/staff/savings'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.teal.withValues(alpha: isDark ? 0.15 : 0.08),
                      AppColors.mint.withValues(alpha: isDark ? 0.1 : 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        AppColors.teal.withValues(alpha: isDark ? 0.2 : 0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        color: AppColors.teal,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: AppColors.teal,
                      size: 10,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        savingsAsync.when(
          data: (savings) {
            if (savings.isEmpty) {
              return GlassCard(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.savings_outlined,
                          size: 32,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.3)),
                      const SizedBox(height: 8),
                      Text(
                        'No savings plans',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: savings
                  .take(3)
                  .map((plan) => Padding(
                        key: ValueKey(plan.id),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: StaffSavingsCard(
                          savings: plan,
                          onTap: () =>
                              context.push('/staff/savings/${plan.id}'),
                        ),
                      ))
                  .toList(),
            );
          },
          loading: () => Column(
            children: List.generate(
                2,
                (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: ShimmerCard(height: 120),
                    )),
          ),
          error: (_, __) => GlassCard(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text('Unable to load savings',
                  style: theme.textTheme.bodySmall),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Staff Loan Card ───

class StaffLoanCard extends StatelessWidget {
  final LoanModel loan;
  final VoidCallback? onTap;

  const StaffLoanCard({super.key, required this.loan, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = loan.totalRepayable > 0
        ? (1 - (loan.outstandingBalance / loan.totalRepayable)).clamp(0.0, 1.0)
        : 0.0;

    final statusColor = loan.status == LoanStatus.active
        ? AppColors.success
        : loan.status == LoanStatus.defaultStatus
            ? AppColors.error
            : AppColors.warning;

    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.15),
                        AppColors.primary.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      (loan.customerName ?? '?')[0].toUpperCase(),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loan.customerName ?? 'Unknown',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loan.loanNumber,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          fontFamily: 'JetBrains Mono',
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    loan.status.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StaffStat(
                  label: 'Principal',
                  value: currencyFmt.format(loan.amount),
                ),
                _StaffStat(
                  label: 'EMI',
                  value: currencyFmt.format(loan.emiAmount),
                ),
                _StaffStat(
                  label: 'Outstanding',
                  value: currencyFmt.format(loan.outstandingBalance),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Staff Savings Card ───

class StaffSavingsCard extends StatelessWidget {
  final SavingsModel savings;
  final VoidCallback? onTap;

  const StaffSavingsCard({super.key, required this.savings, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = savings.targetAmount > 0
        ? (savings.currentAmount / savings.targetAmount).clamp(0.0, 1.0)
        : 0.0;

    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.teal.withValues(alpha: 0.15),
                        AppColors.teal.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.savings_rounded,
                      color: AppColors.teal,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        savings.planName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        savings.memberName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    savings.status.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.teal,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.teal),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StaffStat(
                  label: 'Target',
                  value: currencyFmt.format(savings.targetAmount),
                ),
                _StaffStat(
                  label: 'Monthly',
                  value: currencyFmt.format(savings.monthlyDeposit),
                ),
                _StaffStat(
                  label: 'Saved',
                  value: currencyFmt.format(savings.currentAmount),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stat helper ───

class _StaffStat extends StatelessWidget {
  final String label;
  final String value;

  const _StaffStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}
