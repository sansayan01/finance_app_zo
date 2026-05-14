import '../../../../core/widgets/shimmer_card.dart';
import '../../../../core/widgets/branded_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/sparkline_chart.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../branches/presentation/pages/branch_management_page.dart';
import '../../../loans/data/models/loan_model.dart';
import '../../../savings/data/models/savings_model.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/org_provider.dart';
import '../../data/providers/dashboard_providers.dart';

class HomePage extends ConsumerWidget {
  final VoidCallback onViewAllLoans;
  final VoidCallback onViewAllSavings;
  final VoidCallback onQuickAction;

  const HomePage({
    super.key,
    required this.onViewAllLoans,
    required this.onViewAllSavings,
    required this.onQuickAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackground(
        child: SafeArea(
          bottom: false, // Bottom is handled by the nav bar padding
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(loanSummaryProvider);
              ref.invalidate(dashboardLoansProvider);
              ref.invalidate(dashboardSavingsProvider);
              ref.invalidate(dashboardTransactionsProvider);
              ref.invalidate(todayStatsProvider);
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
                  _buildHeader(context, ref),
                  const SizedBox(height: 20),
                  _buildOverdueBanner(context, ref),
                  const SizedBox(height: 28),
                  _buildHeroCard(context, ref),
                  const SizedBox(height: 16),
                  _buildFinancialSummaryStrip(context, ref),
                  const SizedBox(height: 28),
                  _buildQuickActions(context, ref),
                  const SizedBox(height: 28),
                  _buildTodayAgenda(context, ref),
                  const SizedBox(height: 28),
                  _buildActiveLoansSection(context, ref),
                  const SizedBox(height: 28),
                  _buildSavingsSection(context, ref),
                  const SizedBox(height: 28),
                  _buildRecentTransactions(context, ref),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverdueBanner(BuildContext context, WidgetRef ref) {
    final overdueAsync = ref.watch(overdueLoansProvider);
    final theme = Theme.of(context);

    return overdueAsync.when(
      data: (overdue) {
        if (overdue.isEmpty) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => context.push('/analytics'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.error.withValues(alpha: 0.15),
                  AppColors.error.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: AppColors.error, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attention Required',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${overdue.length} accounts are currently in default',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: AppColors.error.withValues(alpha: 0.5)),
              ],
            ),
          ).animate().shake(delay: 500.ms, duration: 600.ms),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildFinancialSummaryStrip(BuildContext context, WidgetRef ref) {
    final loanSummaryAsync = ref.watch(loanSummaryProvider);

    return loanSummaryAsync.when(
      data: (summary) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _SummaryChip(
              label: 'Disbursed',
              value: AppFormatters.formatCompactCurrency(summary.totalDisbursed),
              icon: Icons.outbond_rounded,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            _SummaryChip(
              label: 'Collected',
              value: AppFormatters.formatCompactCurrency(summary.totalCollected),
              icon: Icons.move_to_inbox_rounded,
              color: AppColors.success,
            ),
            const SizedBox(width: 10),
            _SummaryChip(
              label: 'Overdue',
              value: AppFormatters.formatCompactCurrency(summary.overdueAmount),
              icon: Icons.timer_rounded,
              color: AppColors.error,
            ),
          ],
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildTodayAgenda(BuildContext context, WidgetRef ref) {
    final agendaAsync = ref.watch(todayAgendaProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Today's Agenda",
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Due Today',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        agendaAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return GlassCard(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text('No collections due today',
                      style: theme.textTheme.bodySmall),
                ),
              );
            }
            return Column(
              children: items.map((item) {
                final isLoan = item is LoanModel;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    onTap: () {
                      if (isLoan) {
                        context.push('/loans/${item.id}');
                      } else {
                        context.push('/savings/${item.id}');
                      }
                    },
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (isLoan ? AppColors.primary : AppColors.orange)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isLoan ? Icons.payments_rounded : Icons.savings_rounded,
                            color: isLoan ? AppColors.primary : AppColors.orange,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isLoan ? item.customerName ?? 'Unknown' : item.memberName,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                isLoan ? 'Loan EMI Due' : 'Savings Installment',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              AppFormatters.formatCurrency(
                                isLoan ? item.emiAmount : item.monthlyDeposit,
                              ),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              'Tap to collect',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => ShimmerCard(height: 150),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    // Dynamic greeting based on time
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

    // Get first name
    final firstName = user != null && user.fullName.trim().isNotEmpty
        ? user.fullName.trim().split(RegExp(r'\s+')).first
        : 'User';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    greeting,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodySmall?.color
                          ?.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(greetingIcon,
                      size: 14,
                      color: theme.colorScheme.primary.withValues(alpha: 0.6)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    firstName,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DynamicBrandText(
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                      uppercase: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              _HeaderIconBtn(
                icon: Icons.notifications_outlined,
                onTap: () => context.push('/notifications'),
              ),
              const SizedBox(width: 12),
              _HeaderIconBtn(
                icon: Icons.search_rounded,
                onTap: () => context.push('/search'),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.05, end: 0);
  }

  Widget _buildHeroCard(BuildContext context, WidgetRef ref) {
    final loanSummaryAsync = ref.watch(loanSummaryProvider);
    final todayStatsAsync = ref.watch(todayStatsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return loanSummaryAsync
        .when(
          data: (summary) {
            final collected =
                todayStatsAsync.valueOrNull?['collected'] as double? ?? 0.0;
            return GlassCard(
              elevated: true,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Action Menu - Positioned to the top right to save vertical space
                  Positioned(
                    top: -8,
                    right: -12,
                    child: PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz,
                          color: theme.textTheme.bodySmall?.color, size: 24),
                      padding: EdgeInsets.zero,
                      onSelected: (value) {
                        if (value == 'refresh') {
                          ref.invalidate(loanSummaryProvider);
                          ref.invalidate(todayStatsProvider);
                        } else if (value == 'analytics') {
                          context.push('/analytics');
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
                            summary.totalOutstanding),
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.2,
                          fontSize: 36,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total Outstanding',
                        style:
                            theme.textTheme.bodySmall?.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _HeroStat(
                              label: 'Active Members',
                              value: summary.activeLoans.toString(),
                              icon: Icons.people_rounded,
                              color: isDark
                                  ? AppColors.accentDark
                                  : AppColors.accentLight,
                              onTap: () => context.push('/users'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _HeroStat(
                              label: "Today's Collection",
                              value: AppFormatters.formatCompactCurrency(
                                  collected),
                              icon: Icons.payments_rounded,
                              color: isDark
                                  ? AppColors.successDark
                                  : AppColors.success,
                              onTap: () {},
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _HeroStat(
                              label: 'PAR Rate',
                              value:
                                  '${summary.parPercentage.toStringAsFixed(1)}%',
                              icon: Icons.trending_down_rounded,
                              color: summary.parPercentage > 5
                                  ? (isDark
                                      ? AppColors.errorDark
                                      : AppColors.error)
                                  : (isDark
                                      ? AppColors.warningDark
                                      : AppColors.warning),
                              onTap: () => context.push('/analytics'),
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
          loading: () => ShimmerCard(height: 220),
          error: (_, __) => GlassCard(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text('Unable to load dashboard',
                  style: theme.textTheme.bodySmall),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: 100.ms)
        .slideY(begin: 0.06, end: 0);
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasManager = ref.watch(hasBranchManagerProvider).valueOrNull ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _QuickActionBtn(
                    icon: Icons.request_quote_rounded,
                    label: 'New Loan',
                    color: theme.colorScheme.primary,
                    onTap: () => context.push('/loans/new'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionBtn(
                    icon: Icons.savings_rounded,
                    label: 'Savings',
                    color: theme.colorScheme.secondary,
                    onTap: () => context.push('/savings/new'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionBtn(
                    icon: Icons.person_add_alt_1_rounded,
                    label: 'Add User',
                    color: isDark ? AppColors.accentDark : AppColors.accentLight,
                    onTap: () => context.push('/users/new'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionBtn(
                    icon: Icons.history_rounded,
                    label: 'Timeline',
                    color: isDark
                        ? AppColors.orange.withValues(alpha: 0.8)
                        : AppColors.orange,
                    onTap: () => context.push('/transactions'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickActionBtn(
                    icon: Icons.business_rounded,
                    label: 'Branches',
                    color: AppColors.pink,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BranchManagementPage())),
                  ),
                ),
                if (!hasManager) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionBtn(
                      icon: Icons.rocket_launch_rounded,
                      label: 'Quick Setup',
                      color: Colors.green,
                      onTap: () => context.push('/setup'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildActiveLoansSection(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(dashboardLoansProvider);
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
              onTap: onViewAllLoans,
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
            if (loans.isEmpty) {
              return GlassCard(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child:
                      Text('No active loans', style: theme.textTheme.bodySmall),
                ),
              );
            }
            return Column(
              children: loans
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
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildSavingsSection(BuildContext context, WidgetRef ref) {
    final savingsAsync = ref.watch(dashboardSavingsProvider);
    final summaryAsync = ref.watch(savingsSummaryProvider);
    final pendingAsync = ref.watch(pendingDepositsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final successColor = isDark ? AppColors.successDark : AppColors.success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with Create Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Savings Dashboard',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: () => context.push('/savings/new'),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          successColor.withValues(alpha: 0.9),
                          successColor.withValues(alpha: 0.7)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'New Plan',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onViewAllSavings,
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
          ],
        ),
        const SizedBox(height: 16),

        // Summary Hero Card
        summaryAsync.when(
          data: (summary) => GlassCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: _SavingsStat(
                    label: 'Total Savings',
                    value: AppFormatters.formatCompactCurrency(
                        summary.totalSavings),
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
                    label: 'Active Accounts',
                    value: summary.activeAccounts.toString(),
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
                    label: 'Interest Earned',
                    value: AppFormatters.formatCompactCurrency(
                        summary.interestEarned),
                    icon: Icons.trending_up_outlined,
                    color: AppColors.accentLight,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05, end: 0),
          loading: () => ShimmerCard(height: 100),
          error: (_, __) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 16),

        // Active Savings Plans
        savingsAsync.when(
          data: (savings) {
            if (savings.isEmpty) {
              return GlassCard(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.savings_outlined,
                          size: 48,
                          color: theme.textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text('No active savings plans',
                          style: theme.textTheme.bodySmall),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.push('/savings/new'),
                        child: const Text('Create First Plan'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: savings
                  .take(3)
                  .map((saving) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SavingsCard(saving: saving),
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

        const SizedBox(height: 16),

        // Upcoming Maturities
        pendingAsync.when(
          data: (pending) {
            final upcoming = pending
                .where((s) =>
                    s.maturityDate.difference(DateTime.now()).inDays <= 30)
                .toList();
            if (upcoming.isEmpty) return const SizedBox.shrink();

            return GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event_available_outlined,
                          size: 18, color: AppColors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Maturities This Month',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.orange,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${upcoming.length} plans',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 11,
                            color: AppColors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...upcoming.take(2).map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.orange.withValues(alpha: 0.15),
                                    AppColors.orange.withValues(alpha: 0.05)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.person_outline,
                                  size: 18, color: AppColors.orange),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.memberName,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Maturing on ${AppFormatters.formatDate(s.maturityDate)}',
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              AppFormatters.formatCurrency(s.targetAmount),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.orange,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0);
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildRecentTransactions(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(dashboardTransactionsProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Transactions',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            GestureDetector(
              onTap: () => context.push('/transactions'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'View All',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        transactionsAsync.when(
          data: (transactions) {
            if (transactions.isEmpty) {
              return GlassCard(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text('No recent transactions',
                      style: theme.textTheme.bodySmall),
                ),
              );
            }
            return GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: transactions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final transaction = entry.value;
                  return Column(
                    children: [
                      _buildTransactionItem(context, transaction),
                      if (index < transactions.length - 1)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1),
                        ),
                    ],
                  );
                }).toList(),
              ),
            );
          },
          loading: () => ShimmerCard(height: 200),
          error: (_, __) => GlassCard(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text('Unable to load transactions',
                  style: theme.textTheme.bodySmall),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildTransactionItem(
      BuildContext context, TransactionModel transaction) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDeposit = transaction.type == TransactionType.emiPayment ||
        transaction.type == TransactionType.savingsDeposit;
    final icon =
        isDeposit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
    final iconColor = isDeposit
        ? (isDark ? AppColors.successDark : AppColors.success)
        : (isDark ? AppColors.errorDark : AppColors.error);

    String title;
    switch (transaction.type) {
      case TransactionType.emiPayment:
        title = 'EMI Payment - ${transaction.memberName}';
        break;
      case TransactionType.loanDisbursement:
        title = 'Loan Disbursement - ${transaction.memberName}';
        break;
      case TransactionType.savingsDeposit:
        title = 'Savings Deposit - ${transaction.memberName}';
        break;
      case TransactionType.savingsWithdrawal:
        title = 'Savings Withdrawal - ${transaction.memberName}';
        break;
      case TransactionType.penalty:
        title = 'Penalty - ${transaction.memberName}';
        break;
      default:
        title = transaction.description ?? 'Transaction';
    }

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                AppFormatters.formatRelativeTime(transaction.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
        Text(
          AppFormatters.formatCurrency(transaction.amount),
          style: TextStyle(
            color: iconColor,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
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
            size: 22, color: Theme.of(context).textTheme.bodyLarge?.color),
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
          border: Border.all(color: color.withValues(alpha: 0.08), width: 0.5),
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

class _LoanCard extends StatelessWidget {
  final LoanModel loan;
  const _LoanCard({required this.loan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = 1 - (loan.outstandingBalance / loan.amount);
    final statusType = loan.status == LoanStatus.active
        ? StatusType.standard
        : loan.status == LoanStatus.defaultStatus
            ? StatusType.defaultStatus
            : StatusType.pending;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      onTap: () {},
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
                  label: loan.status.name.toUpperCase(), type: statusType),
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
                  value: AppFormatters.formatCompactCurrency(loan.amount)),
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
        Text(label, style: theme.textTheme.labelSmall?.copyWith(fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
      ],
    );
  }
}

class _SavingsCard extends StatelessWidget {
  final SavingsModel saving;
  const _SavingsCard({required this.saving});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final successColor = isDark ? AppColors.successDark : AppColors.success;
    final progress = saving.currentAmount / saving.targetAmount;
    final daysRemaining = saving.maturityDate.difference(DateTime.now()).inDays;
    final isCompleted = progress >= 1.0;
    final isNearMaturity = daysRemaining <= 30;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Status
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
                    saving.memberName.isNotEmpty
                        ? saving.memberName[0].toUpperCase()
                        : '?',
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
                      saving.memberName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      saving.planName.isNotEmpty
                          ? saving.planName
                          : 'Recurring Savings',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? successColor.withValues(alpha: 0.12)
                      : isNearMaturity
                          ? AppColors.orange.withValues(alpha: 0.12)
                          : theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isCompleted
                      ? 'COMPLETED'
                      : isNearMaturity
                          ? 'MATURING'
                          : saving.status.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isCompleted
                        ? successColor
                        : isNearMaturity
                            ? AppColors.orange
                            : theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Progress Bar (linear - consistent with loans)
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              valueColor: AlwaysStoppedAnimation<Color>(
                isCompleted ? successColor : theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Progress Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toInt()}% Complete',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isCompleted ? successColor : null,
                ),
              ),
              Text(
                '${AppFormatters.formatCompactCurrency(saving.targetAmount - saving.currentAmount)} remaining',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Metrics Grid
          Row(
            children: [
              Expanded(
                child: _SavingsMetric(
                  label: 'Current',
                  value:
                      AppFormatters.formatCompactCurrency(saving.currentAmount),
                  icon: Icons.account_balance_outlined,
                  color: successColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SavingsMetric(
                  label: 'Monthly',
                  value: AppFormatters.formatCompactCurrency(
                      saving.monthlyDeposit),
                  icon: Icons.calendar_today_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SavingsMetric(
                  label: daysRemaining > 0 ? '$daysRemaining days' : 'Matured',
                  value: AppFormatters.formatPercent(saving.interestRate),
                  icon: daysRemaining > 0
                      ? Icons.hourglass_empty_outlined
                      : Icons.check_circle_outlined,
                  color:
                      daysRemaining > 0 ? AppColors.accentLight : successColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Sparkline Trend
          Row(
            children: [
              Expanded(
                child: SparklineChart(
                  data: _generateSavingsTrend(saving),
                  color: successColor,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: successColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trending_up, size: 12, color: successColor),
                    const SizedBox(width: 4),
                    Text(
                      '+${saving.interestRate.toStringAsFixed(1)}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: successColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<double> _generateSavingsTrend(SavingsModel saving) {
    // Generate mock trend data based on current progress
    final baseAmount = saving.currentAmount * 0.3;
    final growth = (saving.currentAmount - baseAmount) / 6;
    return List.generate(7,
        (i) => baseAmount + (growth * i) + (i * saving.monthlyDeposit * 0.5));
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

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
