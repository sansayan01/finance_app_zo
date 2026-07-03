// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../../../core/widgets/sparkline_chart.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../loans/data/models/loan_model.dart';
import '../../../savings/data/models/savings_model.dart';
import '../../../home/presentation/widgets/live_agents_map_card.dart';
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
      ref.invalidate(branchStatsProvider);
      ref.invalidate(branchLoansProvider);
      ref.invalidate(branchSavingsProvider);
      ref.invalidate(branchSavingsSummaryProvider);
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
              ref.invalidate(branchStatsProvider);
              ref.invalidate(branchLoansProvider);
              ref.invalidate(branchSavingsProvider);
              ref.invalidate(branchSavingsSummaryProvider);
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
                  _buildHeader(context, branchId),
                  const SizedBox(height: 20),
                  _buildHeroCard(context, branchId),
                  const SizedBox(height: 16),
                  _buildFinancialSummaryStrip(context, branchId),
                  const SizedBox(height: 28),
                  _buildQuickActions(context),
                  const SizedBox(height: 28),
                  const LiveAgentsMapCard(),
                  const SizedBox(height: 28),
                  _buildActiveLoansSection(context, branchId),
                  const SizedBox(height: 28),
                  _buildSavingsSection(context, branchId),
                  const SizedBox(height: 28),
                  _buildRecentTransactions(context, branchId),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header ───

  Widget _buildHeader(BuildContext context, String branchId) {
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(greeting,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      )),
                  const SizedBox(width: 6),
                  Icon(greetingIcon,
                      size: 14,
                      color: theme.colorScheme.primary.withValues(alpha: 0.6)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(firstName,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        fontSize: 28,
                      )),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('BRANCH MGR',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        )),
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
                onTap: () => context.push('/branch/payments'),
              ),
              const SizedBox(width: 12),
              _HeaderIconBtn(
                icon: Icons.search_rounded,
                onTap: () => context.push('/branch/members'),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.05, end: 0);
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
        final parRate = stats.activeLoansCount > 0
            ? (stats.overdueLoans / stats.activeLoansCount * 100)
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
                      child: Row(children: [
                        Icon(Icons.refresh_rounded, size: 20),
                        SizedBox(width: 12),
                        Text('Refresh Dashboard'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'analytics',
                      child: Row(children: [
                        Icon(Icons.analytics_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('View Analytics'),
                      ]),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppFormatters.formatCurrency(
                        stats.outstandingAmount),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      fontSize: 36,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Total Outstanding',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 14)),
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
                          value: AppFormatters.formatCurrency(
                              todayCollection),
                          icon: Icons.payments_rounded,
                          color: isDark
                              ? AppColors.successDark
                              : AppColors.success,
                          onTap: () => context.push('/branch/payments'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _HeroStat(
                          label: 'PAR Rate',
                          value: '${parRate.toStringAsFixed(1)}%',
                          icon: Icons.trending_down_rounded,
                          color: parRate > 5
                              ? (isDark ? AppColors.errorDark : AppColors.error)
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

  // ─── Financial Summary Strip ───

  Widget _buildFinancialSummaryStrip(
      BuildContext context, String branchId) {
    final statsAsync = ref.watch(branchStatsProvider(branchId));

    return statsAsync.when(
      data: (stats) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _SummaryChip(
              label: 'Disbursed',
              value: AppFormatters.formatCurrency(
                  stats.totalDisbursements),
              icon: Icons.outbond_rounded,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            _SummaryChip(
              label: 'Collected',
              value: AppFormatters.formatCurrency(
                  stats.totalCollections),
              icon: Icons.move_to_inbox_rounded,
              color: AppColors.success,
            ),
            const SizedBox(width: 10),
            _SummaryChip(
              label: 'Members',
              value: '${stats.totalMembers}',
              icon: Icons.people_rounded,
              color: AppColors.accentLight,
            ),
          ],
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ─── Quick Actions ───

  Widget _buildQuickActions(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
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
                    onTap: () => context.push('/branch/loans/new'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionBtn(
                    icon: Icons.savings_rounded,
                    label: 'New Savings',
                    color: theme.colorScheme.secondary,
                    onTap: () => context.push('/branch/savings/new'),
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
                    icon: Icons.history_rounded,
                    label: 'Payments',
                    color: isDark
                        ? AppColors.orange.withValues(alpha: 0.8)
                        : AppColors.orange,
                    onTap: () => context.push('/branch/payments'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickActionBtn(
                    icon: Icons.location_on_rounded,
                    label: 'Live Map',
                    color: const Color(0xFF00BFA5),
                    onTap: () => context.push('/branch/map'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionBtn(
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'UPI Verify',
                    color: const Color(0xFF00BFA5),
                    onTap: () => context.push('/staff/upi-confirmations'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionBtn(
                    icon: Icons.assessment_rounded,
                    label: 'Reports',
                    color: const Color(0xFF7C3AED),
                    onTap: () => context.push('/branch/reports'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionBtn(
                    icon: Icons.analytics_outlined,
                    label: 'Analytics',
                    color: const Color(0xFF2196F3),
                    onTap: () => context.push('/branch/analytics'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.05, end: 0);
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
            Text('Active Loans',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            GestureDetector(
              onTap: () => context.push('/branch/loans'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('View All',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    )),
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
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05, end: 0);
  }

  // ─── Savings Section ───

  Widget _buildSavingsSection(BuildContext context, String branchId) {
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
            Text('Savings Dashboard',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            Row(
              children: [
                GestureDetector(
                  onTap: () => context.push('/branch/savings'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: successColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('View All',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: successColor,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                ),
              ],
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
                    value: AppFormatters.formatCurrency(
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
                    label: 'Active Accounts',
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
                          saving: saving,
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
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.05, end: 0);
  }

  // ─── Recent Transactions ───

  Widget _buildRecentTransactions(
      BuildContext context, String branchId) {
    final transactionsAsync =
        ref.watch(branchRecentTransactionsProvider(branchId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Transactions',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.3)),
            GestureDetector(
              onTap: () => context.push('/branch/payments'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View All',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded,
                        size: 12, color: theme.colorScheme.primary),
                  ],
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
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_rounded,
                          size: 40,
                          color: theme.textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.2)),
                      const SizedBox(height: 12),
                      Text('No recent transactions',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              );
            }
            return GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: transactions.take(5).toList().asMap().entries.map((entry) {
                  final index = entry.key;
                  final t = entry.value;
                  final amount = (t['amount'] as num?)?.toDouble() ?? 0;
                  final type = (t['type'] as String?) ?? 'other';
                  final memberName = (t['member_name'] as String?) ?? '';
                  final paymentMode = (t['payment_mode'] as String?) ?? 'cash';
                  final createdAtStr = t['created_at'] as String?;
                  final createdAt = createdAtStr != null
                      ? DateTime.tryParse(createdAtStr)
                      : null;
                  final description = t['description'] as String?;

                  return Column(
                    children: [
                      _TransactionItem(
                        amount: amount,
                        type: type,
                        memberName: memberName,
                        paymentMode: paymentMode,
                        createdAt: createdAt,
                        description: description,
                        isDark: isDark,
                      ),
                      if (index < transactions.take(5).length - 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Divider(
                              height: 1,
                              color: theme.dividerColor
                                  .withValues(alpha: 0.08)),
                        ),
                    ],
                  );
                }).toList(),
              ),
            );
          },
          loading: () => const ShimmerCard(height: 200),
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
}

// ─── Sub-Widgets ───

class _TransactionItem extends StatelessWidget {
  final double amount;
  final String type;
  final String memberName;
  final String paymentMode;
  final DateTime? createdAt;
  final String? description;
  final bool isDark;

  const _TransactionItem({
    required this.amount,
    required this.type,
    required this.memberName,
    required this.paymentMode,
    required this.createdAt,
    required this.description,
    required this.isDark,
  });

  IconData _getIcon() {
    switch (type) {
      case 'emiPayment':
        return Icons.payments_rounded;
      case 'savingsDeposit':
        return Icons.savings_rounded;
      case 'savingsWithdrawal':
        return Icons.account_balance_wallet_outlined;
      case 'loanDisbursement':
        return Icons.outbond_rounded;
      case 'penalty':
        return Icons.warning_amber_rounded;
      case 'staffCashDeposit':
        return Icons.point_of_sale_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  String _getLabel() {
    switch (type) {
      case 'emiPayment':
        return 'EMI Payment';
      case 'savingsDeposit':
        return 'Savings Deposit';
      case 'savingsWithdrawal':
        return 'Savings Withdrawal';
      case 'loanDisbursement':
        return 'Disbursement';
      case 'penalty':
        return 'Penalty';
      case 'staffCashDeposit':
        return 'Cash Deposit';
      default:
        return 'Transaction';
    }
  }

  Color _getColor() {
    switch (type) {
      case 'emiPayment':
      case 'savingsDeposit':
      case 'staffCashDeposit':
        return isDark ? AppColors.successDark : AppColors.success;
      case 'loanDisbursement':
      case 'savingsWithdrawal':
        return isDark ? AppColors.errorDark : AppColors.error;
      case 'penalty':
        return isDark ? AppColors.warningDark : AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  bool _isCredit() {
    return type == 'emiPayment' ||
        type == 'savingsDeposit' ||
        type == 'staffCashDeposit';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getColor();
    final isCredit = _isCredit();

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Icon(_getIcon(), color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  memberName.isNotEmpty ? memberName : _getLabel(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: -0.2,
                  )),
              const SizedBox(height: 3),
              Row(
                children: [
                  Text(_getLabel(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      )),
                  const SizedBox(width: 6),
                  Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      )),
                  const SizedBox(width: 6),
                  Text(
                      createdAt != null
                          ? AppFormatters.formatRelativeTime(createdAt!)
                          : '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.5),
                      )),
                ],
              ),
            ],
          ),
        ),
        Text(
            '${isCredit ? '+' : '-'}${AppFormatters.formatCurrency(amount)}',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            )),
      ],
    );
  }
}

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
  const _QuickActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

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
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
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
    final progress =
        1 - (loan.outstandingBalance / (loan.amount > 0 ? loan.amount : 1));
    final statusType = loan.status.name == 'active'
        ? StatusType.standard
        : loan.status.name == 'defaulted'
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
                    Text(loan.customerName ?? 'Unknown',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        )),
                    const SizedBox(height: 2),
                    Text(loan.loanNumber,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          fontFamily: 'JetBrains Mono',
                        )),
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
                  value: AppFormatters.formatCurrency(loan.amount)),
              _LoanStat(
                  label: 'EMI',
                  value: AppFormatters.formatCurrency(loan.emiAmount)),
              _LoanStat(
                  label: 'Outstanding',
                  value: AppFormatters.formatCurrency(
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
  final SavingsModel saving;
  final Color successColor;

  const _SavingsCard({required this.saving, required this.successColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress =
        saving.targetAmount > 0 ? saving.currentAmount / saving.targetAmount : 0.0;
    final daysRemaining = saving.maturityDate.difference(DateTime.now()).inDays;
    final isCompleted = progress >= 1.0;
    final isNearMaturity = daysRemaining <= 30;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      onTap: () {},
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
                    Text(saving.memberName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                        saving.planName.isNotEmpty
                            ? saving.planName
                            : 'Recurring Savings',
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(progress * 100).toInt()}% Complete',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? successColor : null,
                  )),
              Text(
                  '${AppFormatters.formatCurrency(saving.targetAmount - saving.currentAmount)} remaining',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    color: theme.textTheme.bodySmall?.color,
                  )),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SavingsMetric(
                  label: 'Current',
                  value: AppFormatters.formatCurrency(
                      saving.currentAmount),
                  icon: Icons.account_balance_outlined,
                  color: successColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SavingsMetric(
                  label: 'Monthly',
                  value: AppFormatters.formatCurrency(
                      saving.monthlyDeposit),
                  icon: Icons.calendar_today_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SavingsMetric(
                  label:
                      daysRemaining > 0 ? '$daysRemaining days' : 'Matured',
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
                    Text('+${saving.interestRate.toStringAsFixed(1)}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: successColor,
                        )),
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
    final baseAmount = saving.currentAmount * 0.3;
    final growth = (saving.currentAmount - baseAmount) / 6;
    return List.generate(
        7,
        (i) =>
            baseAmount + (growth * i) + (i * saving.monthlyDeposit * 0.5));
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
        Text(value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            )),
        const SizedBox(height: 2),
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(fontSize: 10)),
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
          Text(value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: color,
              )),
          Text(label,
              style: theme.textTheme.labelSmall?.copyWith(fontSize: 9)),
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
              Text(value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  )),
              Text(label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.6),
                  )),
            ],
          ),
        ],
      ),
    );
  }
}
