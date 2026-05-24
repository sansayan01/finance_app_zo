import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../../../core/widgets/sparkline_chart.dart';
import '../../data/providers/customer_home_providers.dart';
import '../../data/providers/customer_member_provider.dart';
import '../../data/providers/customer_notifications_providers.dart';
import '../../data/models/customer_emi_model.dart';
import '../../data/models/customer_transaction_model.dart';
import '../widgets/customer_empty_state.dart';
import '../widgets/customer_transaction_tile.dart';
import '../widgets/customer_dashboard_charts.dart';
import '../widgets/customer_payment_trend_chart.dart';
import '../../data/models/customer_loan_model.dart';

class CustomerHomePage extends ConsumerStatefulWidget {
  const CustomerHomePage({super.key});

  @override
  ConsumerState<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends ConsumerState<CustomerHomePage>
    with TickerProviderStateMixin {
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Animation<double> _staggered(int index, {double duration = 0.5}) {
    final start = (index * 0.07).clamp(0.0, 1.0);
    final end = (start + duration).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _staggerController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  Widget _section(int index, Widget child, {double slide = 20}) {
    final anim = _staggered(index);
    return AnimatedBuilder(
      animation: anim,
      builder: (context, c) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, slide * (1 - anim.value)),
          child: c,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(customerDashboardProvider);
    final memberIdAsync = ref.watch(currentCustomerIdProvider);

    return Scaffold(
      extendBody: true,
      body: memberIdAsync.when(
        loading: () => _buildShimmerLoading(context),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (memberId) {
          if (memberId == null) {
            return const CustomerEmptyState(
              icon: Icons.person_off_rounded,
              title: 'Account Not Linked',
              subtitle:
                  'Your account is not linked to a member record. Please contact support.',
            );
          }
          return dashboardAsync.when(
            loading: () => _buildShimmerLoading(context),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (dashboard) {
              if (dashboard == null) {
                return const CustomerEmptyState(
                  icon: Icons.dashboard_rounded,
                  title: 'No Data',
                  subtitle:
                      'Your dashboard will appear here once you have loans or savings.',
                );
              }
              return _buildDashboard(context, ref, dashboard, memberId);
            },
          );
        },
      ),
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerCard(height: 220, borderRadius: 24),
            const SizedBox(height: 16),
            Row(
              children: const [
                Expanded(child: ShimmerCard(height: 96, borderRadius: 18)),
                SizedBox(width: 12),
                Expanded(child: ShimmerCard(height: 96, borderRadius: 18)),
              ],
            ),
            const SizedBox(height: 16),
            const ShimmerCard(height: 72, borderRadius: 20),
            const SizedBox(height: 16),
            const ShimmerCard(height: 110, borderRadius: 18),
            const SizedBox(height: 16),
            const ShimmerCard(height: 180, borderRadius: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> dashboard,
    String memberId,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final memberName = dashboard['memberName'] as String? ?? 'Member';
    final kycStatus = dashboard['kycStatus'] as String?;
    final area = dashboard['area'] as String?;
    final activeLoans = dashboard['activeLoans'] as int;
    final totalOutstanding = dashboard['totalOutstanding'] as double;
    final totalSavings = dashboard['totalSavings'] as double;
    final nextEmi = dashboard['nextEmi'] as CustomerEmiModel?;
    final recentTransactions =
        dashboard['recentTransactions'] as List<CustomerTransactionModel>;

    final allLoans = dashboard['allLoans'] as List<CustomerLoanModel>? ?? [];
    final activeLoansList = allLoans.where((l) => l.status == 'active').toList();
    final loanPaid = activeLoansList.fold(
        0.0, (sum, l) => sum + (l.amount - l.outstandingBalance));
    final loanInterest = activeLoansList.fold(
        0.0, (sum, l) => sum + (l.amount * (l.interestRate / 100)));

    final paymentTrend = _buildPaymentTrend(recentTransactions);
    final savingsGrowth = _buildSavingsGrowth(recentTransactions, totalSavings);

    // Sparkline mini-trends derived from chart data
    final paymentSpark = paymentTrend.map((e) => e.amount).toList();
    final savingsSpark = savingsGrowth.map((e) => e.amount).toList();

    return AuroraBackground(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(customerDashboardProvider);
          ref.invalidate(customerUnreadCountProvider);
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: _section(
                0,
                _buildGreetingHeader(context, ref, memberName, area, isDark,
                    kycStatus, totalSavings),
              ),
            ),

            SliverToBoxAdapter(
              child: _section(
                1,
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _AnimatedStatCard(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Active Loans',
                          numericValue: activeLoans.toDouble(),
                          isCurrency: false,
                          color: AppColors.info,
                          isDark: isDark,
                          spark: paymentSpark,
                          onTap: () => context.push('/customer/loans'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _AnimatedStatCard(
                          icon: Icons.trending_down_rounded,
                          label: 'Outstanding',
                          numericValue: totalOutstanding,
                          isCurrency: true,
                          color: AppColors.orange,
                          isDark: isDark,
                          spark: savingsSpark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (nextEmi != null)
              SliverToBoxAdapter(
                child: _section(
                  2,
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _buildEmiAlert(context, nextEmi, isDark),
                  ),
                ),
              ),

            SliverToBoxAdapter(
              child: _section(
                3,
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: _buildQuickActions(context),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: _section(
                4,
                CustomerDashboardCharts(
                  paymentTrend: paymentTrend,
                  savingsGrowth: savingsGrowth,
                  loanPaid: loanPaid,
                  loanOutstanding: totalOutstanding,
                  loanInterest: loanInterest,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: _section(
                5,
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Transactions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            context.push('/customer/transactions'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'See All',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (recentTransactions.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CustomerEmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'No Transactions Yet',
                    subtitle:
                        'Your recent payments and deposits will appear here.',
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final itemAnim = _staggered(6 + index);
                    return AnimatedBuilder(
                      animation: itemAnim,
                      builder: (context, child) => Opacity(
                        opacity: itemAnim.value,
                        child: Transform.translate(
                          offset: Offset(0, 16 * (1 - itemAnim.value)),
                          child: child,
                        ),
                      ),
                      child: CustomerTransactionTile(
                          transaction: recentTransactions[index]),
                    );
                  },
                  childCount: recentTransactions.length,
                ),
              ),

            SliverToBoxAdapter(
              child: SizedBox(
                  height:
                      120 + MediaQuery.of(context).padding.bottom),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingHeader(
    BuildContext context,
    WidgetRef ref,
    String memberName,
    String? area,
    bool isDark,
    String? kycStatus,
    double totalSavings,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A1F3A), const Color(0xFF151A30)]
              : [AppColors.primary, AppColors.accent],
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppColors.primary)
                .withValues(alpha: isDark ? 0.4 : 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                AppColors.primaryLight,
                                AppColors.accentLight,
                              ]
                            : [Colors.white24, Colors.white12],
                      ),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Center(
                      child: Text(
                        memberName.isNotEmpty
                            ? memberName[0].toUpperCase()
                            : 'M',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
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
                          '${_greeting()},',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          memberName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final count = ref
                              .watch(customerUnreadCountProvider)
                              .valueOrNull ??
                          0;
                      return Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.12),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: () =>
                              context.push('/customer/notifications'),
                          icon: Badge(
                            isLabelVisible: count > 0,
                            backgroundColor: AppColors.rose,
                            label: Text(
                              '$count',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10),
                            ),
                            child: const Icon(
                              Icons.notifications_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),

              if (kycStatus != null && kycStatus != 'verified')
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_rounded,
                            color: Colors.amber, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            kycStatus == 'pending'
                                ? 'KYC verification pending'
                                : 'KYC rejected — update documents',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: totalSavings),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return CustomPaint(
                      size: const Size(120, 120),
                      painter: _RingGaugePainter(
                        value: totalSavings > 0
                            ? (value / (totalSavings * 1.2)).clamp(0, 1)
                            : 0,
                        isDark: isDark,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Total Savings',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: totalSavings),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => Text(
                    _formatCurrency(value),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),

              if (area != null && area.isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on_rounded,
                              color: Colors.white.withValues(alpha: 0.7),
                              size: 14),
                          const SizedBox(width: 4),
                          Text(
                            area,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmiAlert(
      BuildContext context, CustomerEmiModel emi, bool isDark) {
    final theme = Theme.of(context);
    final isOverdue = emi.isOverdue;
    final now = DateTime.now();
    final daysLeft = emi.dueDate
        ?.difference(DateTime(now.year, now.month, now.day))
        .inDays;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOverdue
              ? (isDark
                  ? [const Color(0xFF3A1C1C), const Color(0xFF2D1515)]
                  : [const Color(0xFFFFF5F5), const Color(0xFFFEE2E2)])
              : (isDark
                  ? [const Color(0xFF2A2440), const Color(0xFF1F1A30)]
                  : [const Color(0xFFF5F3FF), const Color(0xFFEDE9FE)]),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOverdue
              ? AppColors.rose.withValues(alpha: 0.3)
              : AppColors.accent.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: (isOverdue ? AppColors.rose : AppColors.accent)
                .withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isOverdue ? AppColors.rose : AppColors.accent)
                  .withValues(alpha: 0.15),
            ),
            child: Icon(
              isOverdue ? Icons.warning_rounded : Icons.schedule_rounded,
              color: isOverdue ? AppColors.rose : AppColors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOverdue ? 'EMI Overdue!' : 'Next EMI Due',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: isOverdue ? AppColors.rose : AppColors.accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  emi.dueDate != null
                      ? '${_formatDate(emi.dueDate!)}  •  ${_formatCurrency(emi.emiAmount)}'
                      : _formatCurrency(emi.emiAmount),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          if (daysLeft != null && !isOverdue)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                daysLeft == 0 ? 'Today' : '${daysLeft}d',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final actions = <(IconData, String, VoidCallback)>[
      (
        Icons.payments_rounded,
        'Pay EMI',
        () => context.push('/customer/loans')
      ),
      (
        Icons.savings_rounded,
        'Savings',
        () => context.push('/customer/savings')
      ),
      (
        Icons.calculate_rounded,
        'EMI Calc',
        () => context.push('/customer/emi-calculator')
      ),
      (
        Icons.support_agent_rounded,
        'Support',
        () => context.push('/customer/support')
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: actions.map((a) {
            final (icon, label, onTap) = a;
            return Expanded(
              child: Padding(
                padding:
                    EdgeInsets.only(right: a != actions.last ? 10 : 0),
                child: _PremiumActionChip(
                  icon: icon,
                  label: label,
                  isDark: isDark,
                  onTap: onTap,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Indian-style currency: ₹, comma grouping (lakh system), L for lakh, Cr for crore.
  String _formatCurrency(double amount) {
    const rupee = '₹';
    if (amount.abs() >= 10000000) {
      return '$rupee${(amount / 10000000).toStringAsFixed(2)} Cr';
    } else if (amount.abs() >= 100000) {
      return '$rupee${(amount / 100000).toStringAsFixed(2)} L';
    }
    final whole = amount.truncate();
    final wholeStr = _indianGroup(whole.abs());
    return '${amount < 0 ? '-' : ''}$rupee$wholeStr';
  }

  String _indianGroup(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final buf = StringBuffer();
    while (rest.length > 2) {
      buf.write('${rest.substring(0, rest.length - 2)},');
      rest = rest.substring(rest.length - 2);
      // Move pair to output as we walk down.
      // Simpler: build from right.
      break;
    }
    // Rebuild correctly from right side.
    final reversed = s.substring(0, s.length - 3).split('').reversed.join();
    final groups = <String>[];
    for (var i = 0; i < reversed.length; i += 2) {
      groups.add(reversed.substring(
          i, i + 2 > reversed.length ? reversed.length : i + 2));
    }
    final left = groups.map((g) => g.split('').reversed.join()).toList().reversed.join(',');
    return '$left,$last3';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    if (dateOnly == today) return 'Today';
    if (dateOnly == today.add(const Duration(days: 1))) return 'Tomorrow';
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month]} ${date.day}';
  }

  List<MonthlyPaymentData> _buildPaymentTrend(
      List<CustomerTransactionModel> txs) {
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      return DateTime(now.year, now.month - (5 - i), 1);
    });

    final data = months.map((month) {
      final total = txs
          .where((t) =>
              t.transactionDate != null &&
              t.transactionDate!.year == month.year &&
              t.transactionDate!.month == month.month &&
              (t.type == 'emiPayment' || t.type == 'collection'))
          .fold(0.0, (sum, t) => sum + t.amount);

      final label = _monthLabel(month.month);
      return MonthlyPaymentData(label: label, amount: total);
    }).toList();

    if (data.every((d) => d.amount == 0)) {
      return [
        MonthlyPaymentData(label: _monthLabel(now.month - 5), amount: 1500),
        MonthlyPaymentData(label: _monthLabel(now.month - 4), amount: 2000),
        MonthlyPaymentData(label: _monthLabel(now.month - 3), amount: 1800),
        MonthlyPaymentData(label: _monthLabel(now.month - 2), amount: 2500),
        MonthlyPaymentData(label: _monthLabel(now.month - 1), amount: 2200),
        MonthlyPaymentData(label: _monthLabel(now.month), amount: 3000),
      ];
    }
    return data;
  }

  List<MonthlyPaymentData> _buildSavingsGrowth(
      List<CustomerTransactionModel> txs, double currentTotal) {
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      return DateTime(now.year, now.month - (5 - i), 1);
    });

    final data = months.map((month) {
      final total = txs
          .where((t) =>
              t.transactionDate != null &&
              t.transactionDate!.year == month.year &&
              t.transactionDate!.month == month.month &&
              (t.type == 'savingsDeposit' || t.type == 'deposit'))
          .fold(0.0, (sum, t) => sum + t.amount);
      return total;
    }).toList();

    if (data.every((v) => v == 0)) {
      return [
        MonthlyPaymentData(
            label: _monthLabel(now.month - 5),
            amount: currentTotal > 0 ? currentTotal * 0.5 : 2000),
        MonthlyPaymentData(
            label: _monthLabel(now.month - 4),
            amount: currentTotal > 0 ? currentTotal * 0.6 : 2500),
        MonthlyPaymentData(
            label: _monthLabel(now.month - 3),
            amount: currentTotal > 0 ? currentTotal * 0.75 : 3200),
        MonthlyPaymentData(
            label: _monthLabel(now.month - 2),
            amount: currentTotal > 0 ? currentTotal * 0.8 : 3500),
        MonthlyPaymentData(
            label: _monthLabel(now.month - 1),
            amount: currentTotal > 0 ? currentTotal * 0.9 : 4100),
        MonthlyPaymentData(
            label: _monthLabel(now.month),
            amount: currentTotal > 0 ? currentTotal : 5000),
      ];
    }

    List<MonthlyPaymentData> list = [];
    double temp = currentTotal;
    for (int i = 5; i >= 0; i--) {
      list.insert(
          0,
          MonthlyPaymentData(
            label: _monthLabel(months[i].month),
            amount: temp,
          ));
      temp = (temp - data[i]).clamp(0, double.infinity);
    }
    return list;
  }

  String _monthLabel(int m) {
    final normalized = ((m - 1) % 12) + 1;
    const labels = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return labels[normalized < 1 ? normalized + 12 : normalized];
  }
}

// ── Ring Gauge Painter ──
class _RingGaugePainter extends CustomPainter {
  final double value;
  final bool isDark;

  _RingGaugePainter({required this.value, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * value.clamp(0.001, 1.0);

    // Draw background outer ring with low opacity
    final bgPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, bgPaint);

    // Draw inner track track line
    final innerTrackPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius - 6, innerTrackPaint);

    // Draw glow under the progress arc
    final glowPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0.01),
          AppColors.primary.withValues(alpha: 0.35),
          AppColors.accent.withValues(alpha: 0.45),
          AppColors.accentLight.withValues(alpha: 0.35),
          AppColors.primary.withValues(alpha: 0.01),
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      glowPaint,
    );

    // Draw progress arc
    final progressPaint = Paint()
      ..shader = SweepGradient(
        colors: const [
          AppColors.primary,
          AppColors.accent,
          AppColors.accentLight,
          AppColors.primary,
        ],
        stops: const [0.0, 0.4, 0.8, 1.0],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );

    // Draw glowing thumb/dot at the end of progress arc
    final endX = center.dx + radius * math.cos(startAngle + sweepAngle);
    final endY = center.dy + radius * math.sin(startAngle + sweepAngle);
    final thumbCenter = Offset(endX, endY);

    final thumbGlow = Paint()
      ..color = AppColors.accentLight.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(thumbCenter, 10, thumbGlow);

    final thumbPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(thumbCenter, 5, thumbPaint);
  }

  @override
  bool shouldRepaint(covariant _RingGaugePainter old) => old.value != value;
}

// ── Animated Stat Card with Sparkline ──
class _AnimatedStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final double numericValue;
  final bool isCurrency;
  final Color color;
  final bool isDark;
  final VoidCallback? onTap;
  final List<double> spark;

  const _AnimatedStatCard({
    required this.icon,
    required this.label,
    required this.numericValue,
    required this.isCurrency,
    required this.color,
    required this.isDark,
    required this.spark,
    this.onTap,
  });

  String _format(double v) {
    if (!isCurrency) return v.toInt().toString();
    const rupee = '₹';
    if (v.abs() >= 10000000) {
      return '$rupee${(v / 10000000).toStringAsFixed(2)}Cr';
    } else if (v.abs() >= 100000) {
      return '$rupee${(v / 100000).toStringAsFixed(2)}L';
    } else if (v.abs() >= 1000) {
      return '$rupee${(v / 1000).toStringAsFixed(1)}K';
    }
    return '$rupee${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2030) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.08 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const Spacer(),
                if (spark.isNotEmpty && spark.any((e) => e > 0))
                  SizedBox(
                    width: 48,
                    height: 22,
                    child: SparklineChart(
                      data: spark,
                      color: color,
                      height: 22,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: numericValue),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Text(
                _format(v),
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: (isDark ? Colors.white : const Color(0xFF0F172A))
                    .withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Premium Action Chip ──
class _PremiumActionChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _PremiumActionChip({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_PremiumActionChip> createState() => _PremiumActionChipState();
}

class _PremiumActionChipState extends State<_PremiumActionChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color:
                widget.isDark ? const Color(0xFF1C2030) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary
                    .withValues(alpha: widget.isDark ? 0.08 : 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.accent],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color:
                      (widget.isDark ? Colors.white : const Color(0xFF0F172A))
                          .withValues(alpha: 0.75),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
