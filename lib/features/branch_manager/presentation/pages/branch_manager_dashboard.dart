// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/providers/branch_manager_providers.dart';
import '../../data/providers/branch_scoped_providers.dart';

class BranchManagerDashboard extends ConsumerStatefulWidget {
  const BranchManagerDashboard({super.key});

  @override
  ConsumerState<BranchManagerDashboard> createState() =>
      _BranchManagerDashboardState();
}

class _BranchManagerDashboardState
    extends ConsumerState<BranchManagerDashboard> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.invalidate(branchManagerDashboardProvider);
      ref.invalidate(branchStatsProvider);
      ref.invalidate(branchLoansProvider);
      ref.invalidate(branchSavingsProvider);
      ref.invalidate(branchTodayCollectionsProvider);
      ref.invalidate(branchCollectionStatsProvider);
      ref.invalidate(branchMemberCountProvider);
      ref.invalidate(staffPerformanceProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final branchId = user?.branchId;

    if (branchId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Branch Dashboard')),
        body: const Center(
          child: Text('No branch assigned to your profile.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(branchManagerDashboardProvider);
              ref.invalidate(branchStatsProvider);
              ref.invalidate(branchLoansProvider);
              ref.invalidate(branchSavingsProvider);
              ref.invalidate(branchTodayCollectionsProvider);
              ref.invalidate(branchCollectionStatsProvider);
              ref.invalidate(branchMemberCountProvider);
              ref.invalidate(staffPerformanceProvider);
            },
            displacement: 20,
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).cardColor,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 24),
                  _buildPendingAlert(context, branchId),
                  const SizedBox(height: 24),
                  _buildHeroCard(context, branchId),
                  const SizedBox(height: 28),
                  _buildQuickActions(context),
                  const SizedBox(height: 28),
                  _buildStaffPerformance(context, branchId),
                  const SizedBox(height: 28),
                  _buildActiveLoansSection(context, branchId),
                  const SizedBox(height: 28),
                  _buildSavingsSection(context, branchId),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header ───

  Widget _buildHeader(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    final String greeting;
    final IconData greetingIcon;
    if (hour >= 5 && hour < 12) {
      greeting = 'Good Morning';
      greetingIcon = Icons.wb_sunny_rounded;
    } else if (hour >= 12 && hour < 17) {
      greeting = 'Good Afternoon';
      greetingIcon = Icons.wb_cloudy_rounded;
    } else if (hour >= 17 && hour < 21) {
      greeting = 'Good Evening';
      greetingIcon = Icons.dark_mode_rounded;
    } else {
      greeting = 'Good Night';
      greetingIcon = Icons.nights_stay_rounded;
    }
    final firstName = user != null && user.fullName.trim().isNotEmpty
        ? user.fullName.trim().split(RegExp(r'\s+')).first
        : 'Manager';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      greeting,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(greetingIcon,
                      size: 14,
                      color:
                          theme.colorScheme.primary.withValues(alpha: 0.6)),
                ],
              ),
            ),
            _HeaderIconBtn(
              icon: Icons.notifications_outlined,
              onTap: () => context.push('/branch/approvals'),
            ),
            const SizedBox(width: 10),
            _HeaderIconBtn(
              icon: Icons.settings_outlined,
              onTap: () => context.push('/branch/settings'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Flexible(
              child: Text(
                firstName,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  fontSize: 28,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'BRANCH MGR',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.05, end: 0);
  }

  // ─── Pending Approvals Alert ───

  Widget _buildPendingAlert(BuildContext context, String branchId) {
    final dashboardAsync = ref.watch(branchManagerDashboardProvider);
    final theme = Theme.of(context);

    return dashboardAsync.when(
      data: (data) {
        final count = data['pending_approvals_count'] as int? ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => context.push('/branch/approvals'),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.warning.withValues(alpha: 0.15),
                  AppColors.warning.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.pending_actions_rounded,
                      color: AppColors.warning, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$count Pending Approval${count > 1 ? 's' : ''}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.warning,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Requests awaiting your review',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: AppColors.warning.withValues(alpha: 0.5)),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ─── Hero Card ───

  Widget _buildHeroCard(BuildContext context, String branchId) {
    final statsAsync = ref.watch(branchStatsProvider(branchId));
    final collectionAsync =
        ref.watch(branchCollectionStatsProvider(branchId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return statsAsync.when(
      data: (stats) {
        final todayCollection = collectionAsync.valueOrNull != null
            ? (collectionAsync.valueOrNull!['today_total'] as num?)
                    ?.toDouble() ??
                0
            : 0.0;
        return GlassCard(
          elevated: true,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: -8,
                right: -12,
                child: PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz,
                      color: theme.textTheme.bodySmall?.color, size: 24),
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'refresh') {
                      ref.invalidate(branchStatsProvider(branchId));
                      ref.invalidate(
                          branchCollectionStatsProvider(branchId));
                    } else if (value == 'analytics') {
                      context.push('/branch/analytics');
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh_rounded, size: 20),
                          SizedBox(width: 12),
                          Text('Refresh Dashboard'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'analytics',
                      child: Row(
                        children: [
                          Icon(Icons.analytics_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('View Analytics'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppFormatters.formatCompactCurrency(
                        stats.outstandingAmount),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      fontSize: 36,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Branch Outstanding',
                    style:
                        theme.textTheme.bodySmall?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _HeroStat(
                          label: 'Active Loans',
                          value: stats.activeLoansCount.toString(),
                          icon: Icons.account_balance_rounded,
                          color: isDark
                              ? AppColors.accentDark
                              : AppColors.accentLight,
                          onTap: () => context.push('/branch/loans'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _HeroStat(
                          label: "Today's Collection",
                          value: AppFormatters.formatCompactCurrency(
                              todayCollection),
                          icon: Icons.payments_rounded,
                          color: isDark
                              ? AppColors.successDark
                              : AppColors.success,
                          onTap: () => context.push('/branch/collections'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _HeroStat(
                          label: 'PAR Rate',
                          value: stats.totalCollections > 0
                              ? '${((stats.overdueLoans / (stats.activeLoansCount > 0 ? stats.activeLoansCount : 1)) * 100).toStringAsFixed(1)}%'
                              : '0%',
                          icon: Icons.trending_down_rounded,
                          color: stats.overdueLoans > 3
                              ? (isDark
                                  ? AppColors.errorDark
                                  : AppColors.error)
                              : (isDark
                                  ? AppColors.warningDark
                                  : AppColors.warning),
                          onTap: () => context.push('/branch/analytics'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const ShimmerCard(height: 220),
      error: (_, __) => GlassCard(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text('Unable to load dashboard',
              style: theme.textTheme.bodySmall),
        ),
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.06, end: 0);
  }

  // ─── Quick Actions ───

  Widget _buildQuickActions(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _QuickActionBtn(
                icon: Icons.request_quote_rounded,
                label: 'New Loan',
                color: theme.colorScheme.primary,
                onTap: () => context.push('/branch/loans/new'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionBtn(
                icon: Icons.person_add_alt_1_rounded,
                label: 'Add Member',
                color:
                    isDark ? AppColors.accentDark : AppColors.accentLight,
                onTap: () => context.push('/branch/members'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionBtn(
                icon: Icons.people_alt_rounded,
                label: 'Staff',
                color: isDark
                    ? AppColors.orange.withValues(alpha: 0.8)
                    : AppColors.orange,
                onTap: () => context.push('/branch/staff'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionBtn(
                icon: Icons.assessment_rounded,
                label: 'Reports',
                color: const Color(0xFF00BFA5),
                onTap: () => context.push('/branch/reports'),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.05, end: 0);
  }

  // ─── Staff Performance ───

  Widget _buildStaffPerformance(
      BuildContext context, String branchId) {
    final statsAsync = ref.watch(branchStatsProvider(branchId));
    final _ = ref.watch(branchStaffProvider(branchId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Staff Performance',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            GestureDetector(
              onTap: () => context.push('/branch/staff'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'View All',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _SavingsStat(
                  label: 'Total Staff',
                  value: statsAsync.when(
                    data: (s) => '${s.totalStaff}',
                    loading: () => '...',
                    error: (_, __) => '0',
                  ),
                  icon: Icons.people_outline,
                  color: AppColors.primary,
                ),
              ),
              Container(
                  height: 40,
                  width: 1,
                  color: theme.dividerColor.withValues(alpha: 0.2)),
              Expanded(
                child: _SavingsStat(
                  label: 'Members',
                  value: statsAsync.when(
                    data: (s) => '${s.totalMembers}',
                    loading: () => '...',
                    error: (_, __) => '0',
                  ),
                  icon: Icons.groups_outlined,
                  color: isDark
                      ? AppColors.successDark
                      : AppColors.success,
                ),
              ),
              Container(
                  height: 40,
                  width: 1,
                  color: theme.dividerColor.withValues(alpha: 0.2)),
              Expanded(
                child: _SavingsStat(
                  label: 'Total Loans',
                  value: statsAsync.when(
                    data: (s) => '${s.totalLoans}',
                    loading: () => '...',
                    error: (_, __) => '0',
                  ),
                  icon: Icons.account_balance_outlined,
                  color: AppColors.accentLight,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05, end: 0),
      ],
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05, end: 0);
  }

  // ─── Active Loans Section ───

  Widget _buildActiveLoansSection(
      BuildContext context, String branchId) {
    final loansAsync = ref.watch(branchLoansProvider(branchId));
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active Loans',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            GestureDetector(
              onTap: () => context.push('/branch/loans'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'View All',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        loansAsync.when(
          data: (loans) {
            final active =
                loans.where((l) => l.status.name == 'active').toList();
            if (active.isEmpty) {
              return GlassCard(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text('No active loans',
                      style: theme.textTheme.bodySmall),
                ),
              );
            }
            return Column(
              children: active
                  .take(3)
                  .map((loan) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _LoanCard(loan: loan),
                      ))
                  .toList(),
            );
          },
          loading: () => Column(
            children: List.generate(
                2,
                (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: ShimmerCard(height: 160),
                    )),
          ),
          error: (_, __) => GlassCard(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text('Unable to load loans',
                  style: theme.textTheme.bodySmall),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.05, end: 0);
  }

  // ─── Savings Section ───

  Widget _buildSavingsSection(
      BuildContext context, String branchId) {
    final savingsAsync = ref.watch(branchSavingsProvider(branchId));
    final summaryAsync = ref.watch(branchSavingsSummaryProvider(branchId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final successColor = isDark ? AppColors.successDark : AppColors.success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Savings',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            GestureDetector(
              onTap: () => context.push('/branch/savings'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: successColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'View All',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: successColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        summaryAsync.when(
          data: (summary) => GlassCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: _SavingsStat(
                    label: 'Total Savings',
                    value: AppFormatters.formatCompactCurrency(
                        (summary['total_balance'] as num?)?.toDouble() ?? 0),
                    icon: Icons.account_balance_wallet_outlined,
                    color: successColor,
                  ),
                ),
                Container(
                    height: 40,
                    width: 1,
                    color: theme.dividerColor.withValues(alpha: 0.2)),
                Expanded(
                  child: _SavingsStat(
                    label: 'Active Plans',
                    value: '${summary['active_count'] ?? 0}',
                    icon: Icons.people_outline,
                    color: AppColors.primary,
                  ),
                ),
                Container(
                    height: 40,
                    width: 1,
                    color: theme.dividerColor.withValues(alpha: 0.2)),
                Expanded(
                  child: _SavingsStat(
                    label: 'Matured',
                    value: '${summary['matured_count'] ?? 0}',
                    icon: Icons.check_circle_outline,
                    color: AppColors.accentLight,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05, end: 0),
          loading: () => const ShimmerCard(height: 100),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        savingsAsync.when(
          data: (savings) {
            if (savings.isEmpty) {
              return GlassCard(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text('No savings plans',
                      style: theme.textTheme.bodySmall),
                ),
              );
            }
            return Column(
              children: savings
                  .take(3)
                  .map((saving) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SavingsCard(
                          memberName: saving.memberName,
                          planName: saving.planName,
                          currentAmount: saving.currentAmount,
                          targetAmount: saving.targetAmount,
                          monthlyDeposit: saving.monthlyDeposit,
                          status: saving.status,
                          successColor: successColor,
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
                      child: ShimmerCard(height: 180),
                    )),
          ),
          error: (_, __) => GlassCard(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text('Unable to load savings',
                  style: theme.textTheme.bodySmall),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.05, end: 0);
  }
}

// ─── Sub-Widgets ───

class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            width: 0.5,
          ),
        ),
        child: Icon(icon,
            size: 22,
            color: Theme.of(context).textTheme.bodyLarge?.color),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _HeroStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: color.withValues(alpha: 0.08), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 10),
            Text(value,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: theme.textTheme.labelSmall?.copyWith(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 18),
      borderRadius: 20,
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.15),
                  color.withValues(alpha: 0.05)
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: theme.textTheme.bodySmall
                ?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SavingsStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SavingsStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
        ),
      ],
    );
  }
}

class _LoanCard extends StatelessWidget {
  final dynamic loan;
  const _LoanCard({required this.loan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress =
        1.0 - (loan.outstandingBalance / (loan.amount > 0 ? loan.amount : 1)).toDouble();

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.15),
                      theme.colorScheme.primary.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    (loan.customerName ?? '?')[0].toUpperCase(),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan.customerName ?? 'Unknown',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loan.loanNumber,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        fontFamily: 'JetBrains Mono',
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: loan.status.name.toUpperCase(),
                type: loan.status.name == 'active'
                    ? StatusType.standard
                    : StatusType.pending,
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: theme.brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              valueColor:
                  AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LoanStat(
                  label: 'Principal',
                  value:
                      AppFormatters.formatCompactCurrency(loan.amount)),
              _LoanStat(
                  label: 'EMI',
                  value: AppFormatters.formatCurrency(loan.emiAmount)),
              _LoanStat(
                  label: 'Outstanding',
                  value: AppFormatters.formatCompactCurrency(
                      loan.outstandingBalance)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoanStat extends StatelessWidget {
  final String label;
  final String value;
  const _LoanStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
      ],
    );
  }
}

class _SavingsCard extends StatelessWidget {
  final String memberName;
  final String planName;
  final double currentAmount;
  final double targetAmount;
  final double monthlyDeposit;
  final String status;
  final Color successColor;

  const _SavingsCard({
    required this.memberName,
    required this.planName,
    required this.currentAmount,
    required this.targetAmount,
    required this.monthlyDeposit,
    required this.status,
    required this.successColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = targetAmount > 0 ? currentAmount / targetAmount : 0.0;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      successColor.withValues(alpha: 0.15),
                      successColor.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    memberName.isNotEmpty ? memberName[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: successColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memberName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      planName.isNotEmpty ? planName : 'Recurring Savings',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 'active'
                      ? successColor.withValues(alpha: 0.12)
                      : theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: status == 'active'
                        ? successColor
                        : theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              valueColor: AlwaysStoppedAnimation<Color>(successColor),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toInt()}% Complete',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${AppFormatters.formatCompactCurrency(targetAmount - currentAmount)} remaining',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SavingsMetric(
                  label: 'Current',
                  value: AppFormatters.formatCompactCurrency(currentAmount),
                  icon: Icons.account_balance_outlined,
                  color: successColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SavingsMetric(
                  label: 'Monthly',
                  value: AppFormatters.formatCompactCurrency(monthlyDeposit),
                  icon: Icons.calendar_today_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SavingsMetric(
                  label: 'Target',
                  value: AppFormatters.formatCompactCurrency(targetAmount),
                  icon: Icons.flag_outlined,
                  color: AppColors.accentLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SavingsMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SavingsMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
          ),
        ],
      ),
    );
  }
}
