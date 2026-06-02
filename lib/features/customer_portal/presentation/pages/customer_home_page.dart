import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../../../core/widgets/sparkline_chart.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/providers/customer_connection_provider.dart';
import '../../data/providers/customer_home_providers.dart';
import '../../data/providers/customer_member_provider.dart';
import '../../data/providers/customer_notifications_providers.dart';
import '../../data/providers/customer_realtime_providers.dart';
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
  late AnimationController _pulseController;
  late AnimationController _backgroundController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _pulseController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  Animation<double> _staggered(int index, {double duration = 0.5}) {
    final start = (index * 0.08).clamp(0.0, 1.0);
    final end = (start + duration).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _staggerController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  Widget _section(int index, Widget child, {double slide = 24}) {
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
    ref.watch(realtimeNotificationsProvider);
    ref.watch(realtimeMemberProfileProvider);
    final dashboardAsync = ref.watch(customerDashboardProvider);
    final memberIdAsync = ref.watch(currentCustomerIdProvider);

    // Auto-retry when connectivity is restored
    ref.listen<AsyncValue<bool>>(isOnlineProvider, (prev, next) {
      final wasOffline = prev?.valueOrNull == false;
      final isOnline = next.valueOrNull == true;
      if (isOnline && wasOffline) {
        ref.invalidate(customerDashboardProvider);
        ref.invalidate(currentCustomerIdProvider);
      }
    });

    return Scaffold(
      extendBody: true,
      body: memberIdAsync.when(
        loading: () => _buildShimmerLoading(context),
        error: (e, _) => _buildErrorState(
          context,
          e,
          onRetry: () => ref.invalidate(currentCustomerIdProvider),
        ),
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
            error: (e, _) => _buildErrorState(
              context,
              e,
              onRetry: () => ref.invalidate(customerDashboardProvider),
            ),
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

  Widget _buildErrorState(
    BuildContext context,
    Object error, {
    required VoidCallback onRetry,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: (AppColors.error).withValues(alpha: isDark ? 0.15 : 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.premiumGradient,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: -0.1,
                      ),
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

  Widget _buildShimmerLoading(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerCard(height: 300, borderRadius: 32),
            const SizedBox(height: 16),
            Row(
              children: const [
                Expanded(child: ShimmerCard(height: 100, borderRadius: 20)),
                SizedBox(width: 12),
                Expanded(child: ShimmerCard(height: 100, borderRadius: 20)),
              ],
            ),
            const SizedBox(height: 16),
            const ShimmerCard(height: 76, borderRadius: 20),
            const SizedBox(height: 16),
            ShimmerCard(
                height: 120, borderRadius: 20),
            const SizedBox(height: 16),
            const ShimmerCard(height: 200, borderRadius: 20),
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

    final netWorth = totalSavings - totalOutstanding;
    final paymentTrend = _buildPaymentTrend(recentTransactions);
    final savingsGrowth = _buildSavingsGrowth(recentTransactions, totalSavings);
    final paymentSpark = paymentTrend.map((e) => e.amount).toList();
    final savingsSpark = savingsGrowth.map((e) => e.amount).toList();

    return _EnhancedBackground(
      controller: _backgroundController,
      isDark: isDark,
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
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle.light.copyWith(
                  statusBarColor: Colors.transparent,
                ),
                child: _section(
                  0,
                  _buildPremiumHeader(
                    context, ref, memberName, area, isDark,
                    kycStatus, totalSavings, totalOutstanding,
                  ),
                ),
              ),
            ),

            // Net Worth Card
            SliverToBoxAdapter(
              child: _section(
                1,
                _buildNetWorthCard(
                  context, isDark, totalSavings, totalOutstanding, netWorth,
                ),
              ),
            ),

            // Stat Cards Row
            SliverToBoxAdapter(
              child: _section(
                2,
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _PremiumStatCard(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Active Loans',
                          numericValue: activeLoans.toDouble(),
                          isCurrency: false,
                          gradientColors: [const Color(0xFF6366F1), const Color(0xFF818CF8)],
                          spark: paymentSpark,
                          onTap: () => context.push('/customer/loans'),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PremiumStatCard(
                          icon: Icons.trending_down_rounded,
                          label: 'Outstanding',
                          numericValue: totalOutstanding,
                          isCurrency: true,
                          gradientColors: [const Color(0xFFF59E0B), const Color(0xFFF97316)],
                          spark: savingsSpark,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // EMI Alert
            if (nextEmi != null)
              SliverToBoxAdapter(
                child: _section(
                  3,
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _buildPremiumEmiAlert(context, nextEmi, isDark, totalOutstanding, activeLoansList),
                  ),
                ),
              ),

            // Quick Actions
            SliverToBoxAdapter(
              child: _section(
                4,
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: _buildPremiumQuickActions(context),
                ),
              ),
            ),

            // Charts Section
            SliverToBoxAdapter(
              child: _section(
                5,
                CustomerDashboardCharts(
                  paymentTrend: paymentTrend,
                  savingsGrowth: savingsGrowth,
                  loanPaid: activeLoansList.fold(0.0, (sum, l) => sum + (l.amount - l.outstandingBalance)),
                  loanOutstanding: totalOutstanding,
                  loanInterest: activeLoansList.fold(0.0, (sum, l) => sum + (l.amount * (l.interestRate / 100))),
                ),
              ),
            ),

            // Transactions Header
            SliverToBoxAdapter(
              child: _section(
                6,
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                  child: Row(
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
                                colors: [AppColors.indigo, AppColors.accent],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Recent Transactions',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => context.push('/customer/transactions'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'See All',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Transactions List
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
                    final itemAnim = _staggered(7 + index);
                    return AnimatedBuilder(
                      animation: itemAnim,
                      builder: (context, child) => Opacity(
                        opacity: itemAnim.value,
                        child: Transform.translate(
                          offset: Offset(0, 16 * (1 - itemAnim.value)),
                          child: child,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          bottom: index == recentTransactions.length - 1 ? 0 : 2,
                        ),
                        child: CustomerTransactionTile(
                            transaction: recentTransactions[index]),
                      ),
                    );
                  },
                  childCount: recentTransactions.length,
                ),
              ),

            SliverToBoxAdapter(
              child: SizedBox(
                  height: 120 + MediaQuery.of(context).padding.bottom),
            ),
          ],
        ),
      ),
    );
  }

  // ─── PREMIUM HEADER ───────────────────────────────────────────────────────

  Widget _buildPremiumHeader(
    BuildContext context,
    WidgetRef ref,
    String memberName,
    String? area,
    bool isDark,
    String? kycStatus,
    double totalSavings,
    double totalOutstanding,
  ) {
    final pulseValue = _pulseController;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
        margin: const EdgeInsets.only(top: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: AnimatedBuilder(
          animation: _backgroundController,
          builder: (context, _) {
            return Container(
              decoration: BoxDecoration(
                gradient: _buildHeaderGradient(isDark),
              ),
              child: Stack(
                children: [
                  // Ambient glow orbs
                  ..._buildAmbientOrbs(isDark),
                  // Frosted overlay
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  // Content
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar + Greeting Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Premium Avatar with glow
                              AnimatedBuilder(
                                animation: pulseValue,
                                builder: (context, _) {
                                  final glow = 0.3 + (pulseValue.value * 0.2);
                                  return Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          AppColors.primaryLight,
                                          AppColors.accentLight,
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryLight
                                              .withValues(alpha: glow),
                                          blurRadius: 16 + (pulseValue.value * 8),
                                          spreadRadius: 2,
                                        ),
                                        BoxShadow(
                                          color: AppColors.accent
                                              .withValues(alpha: glow * 0.5),
                                          blurRadius: 24,
                                          spreadRadius: -2,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        memberName.isNotEmpty
                                            ? memberName[0].toUpperCase()
                                            : 'M',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _greeting(),
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      memberName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.4,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Notification Bell
                              Consumer(
                                builder: (context, ref, _) {
                                  final count = ref
                                      .watch(customerUnreadCountProvider)
                                      .valueOrNull ?? 0;
                                  return GestureDetector(
                                    onTap: () =>
                                        context.push('/customer/notifications'),
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withValues(alpha: 0.1),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.15),
                                        ),
                                      ),
                                      child: Center(
                                        child: Badge(
                                          isLabelVisible: count > 0,
                                          backgroundColor: AppColors.rose,
                                          textColor: Colors.white,
                                          label: Text(
                                            '$count',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.notifications_rounded,
                                            color: Colors.white.withValues(alpha: 0.85),
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),

                          // Location badge
                          if (area != null && area.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.location_on_rounded,
                                        color: Colors.white.withValues(alpha: 0.6), size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      area,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.75),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // KYC alert
                          if (kycStatus != null && kycStatus != 'verified')
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.25),
                                  ),
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

                          // Savings Ring Gauge
                          Center(
                            child: Column(
                              children: [
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: totalSavings),
                                  duration: const Duration(milliseconds: 1200),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, _) {
                                    final ratio = totalSavings > 0
                                        ? (value / (totalSavings * 1.2)).clamp(0.0, 1.0).toDouble()
                                        : 0.0;
                                    return CustomPaint(
                                      size: const Size(130, 130),
                                      painter: _PremiumRingGaugePainter(
                                        value: ratio,
                                        isDark: isDark,
                                        pulse: _pulseController.value,
                                        gradientColors: const [
                                          Color(0xFF4F46E5),
                                          Color(0xFF7C3AED),
                                          Color(0xFFA855F7),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Total Savings',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: totalSavings),
                                  duration: const Duration(milliseconds: 1000),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, _) => Text(
                                    _formatCurrency(value),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.8,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      ),
    );
  }

  LinearGradient _buildHeaderGradient(bool isDark) {
    if (isDark) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0xFF1A1F3A),
          Color(0xFF1E1B3A),
          Color(0xFF151A30),
        ],
      );
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: const [
        Color(0xFF4F46E5),
        Color(0xFF6D28D9),
        Color(0xFF7C3AED),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  List<Widget> _buildAmbientOrbs(bool isDark) {
    final baseColor = isDark
        ? AppColors.primaryDark.withValues(alpha: 0.08)
        : AppColors.primaryLight.withValues(alpha: 0.12);

    return [
      Positioned(
        top: -40,
        right: -30,
        child: AnimatedBuilder(
          animation: _backgroundController,
          builder: (context, _) {
            final dx = 10 * math.sin(_backgroundController.value * 2 * math.pi);
            final dy = 10 * math.cos(_backgroundController.value * 3 * math.pi);
            return Transform.translate(
              offset: Offset(dx, dy),
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      baseColor.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      Positioned(
        bottom: -50,
        left: -40,
        child: AnimatedBuilder(
          animation: _backgroundController,
          builder: (context, _) {
            final dx = 8 * math.sin(_backgroundController.value * 2.5 * math.pi + 1);
            final dy = 8 * math.cos(_backgroundController.value * 2 * math.pi + 1);
            return Transform.translate(
              offset: Offset(dx, dy),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (isDark ? AppColors.accentDark : AppColors.accent)
                          .withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  // ─── NET WORTH CARD ──────────────────────────────────────────────────────

  Widget _buildNetWorthCard(
    BuildContext context,
    bool isDark,
    double totalSavings,
    double totalOutstanding,
    double netWorth,
  ) {
    final theme = Theme.of(context);
    final netPositive = netWorth >= 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: GlassCard(
        borderRadius: 20,
        padding: EdgeInsets.zero,
        elevated: true,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF1A1F3A).withValues(alpha: 0.6),
                      const Color(0xFF1C2030).withValues(alpha: 0.4),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.95),
                      Colors.white.withValues(alpha: 0.9),
                    ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: netPositive
                            ? [AppColors.success, const Color(0xFF14B8A6)]
                            : [AppColors.rose, AppColors.orange],
                      ),
                    ),
                    child: Icon(
                      netPositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Financial Position',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Three metrics row
              Row(
                children: [
                  Expanded(
                    child: _buildMiniMetric(
                      'Savings',
                      totalSavings,
                      AppColors.success,
                      isDark,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: isDark
                        ? AppColors.separatorDark
                        : AppColors.separatorLight,
                  ),
                  Expanded(
                    child: _buildMiniMetric(
                      'Outstanding',
                      totalOutstanding,
                      AppColors.orange,
                      isDark,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: isDark
                        ? AppColors.separatorDark
                        : AppColors.separatorLight,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: netWorth.abs()),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) => Text(
                            '${netPositive ? '+' : '-'}${_formatSmallCurrency(value)}',
                            style: TextStyle(
                              color: netPositive ? AppColors.success : AppColors.rose,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        Text(
                          'Net',
                          style: TextStyle(
                            color: (isDark ? Colors.white : const Color(0xFF0F172A))
                                .withValues(alpha: 0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniMetric(String label, double value, Color color, bool isDark) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => Text(
            _formatSmallCurrency(v),
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: (isDark ? Colors.white : const Color(0xFF0F172A))
                .withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ─── PREMIUM EMI ALERT ────────────────────────────────────────────────────

  Widget _buildPremiumEmiAlert(
    BuildContext context,
    CustomerEmiModel emi,
    bool isDark,
    double totalOutstanding,
    List<CustomerLoanModel> activeLoans,
  ) {
    final theme = Theme.of(context);
    final isOverdue = emi.isOverdue;
    final now = DateTime.now();
    final daysLeft = emi.dueDate
        ?.difference(DateTime(now.year, now.month, now.day))
        .inDays;

    // Calculate overall repayment progress
    double overallProgress = 0;
    if (activeLoans.isNotEmpty) {
      final totalDisbursed = activeLoans.fold(0.0, (sum, l) => sum + l.amount);
      final totalPaid = totalDisbursed - totalOutstanding;
      overallProgress = totalDisbursed > 0
          ? (totalPaid / totalDisbursed).clamp(0, 1).toDouble()
          : 0.0;
    }

    final accentColor = isOverdue ? AppColors.rose : AppColors.accent;

    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isOverdue
                        ? [AppColors.rose, AppColors.error]
                        : [AppColors.accent, AppColors.primary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: isDark ? 0.3 : 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  isOverdue ? Icons.warning_rounded : Icons.schedule_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOverdue ? 'EMI Overdue' : 'Next EMI Due',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      emi.dueDate != null
                          ? '${_formatDate(emi.dueDate!)}  ·  ${_formatCurrency(emi.emiAmount)}'
                          : _formatCurrency(emi.emiAmount),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: (isDark ? Colors.white : const Color(0xFF0F172A))
                            .withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              if (daysLeft != null && !isOverdue)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                        accentColor.withValues(alpha: isDark ? 0.1 : 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentColor.withValues(alpha: isDark ? 0.3 : 0.15),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        daysLeft == 0 ? 'Today' : '$daysLeft',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      if (daysLeft != 0)
                        Text(
                          'days',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),

          // Repayment progress bar
          if (activeLoans.isNotEmpty && totalOutstanding > 0) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Repayment Progress',
                  style: TextStyle(
                    color: (isDark ? Colors.white : const Color(0xFF0F172A))
                        .withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  '${(overallProgress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: overallProgress),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.fillDark
                        : AppColors.fillLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            isOverdue ? AppColors.rose : AppColors.accent,
                            isOverdue ? AppColors.error : AppColors.primary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: isDark ? 0.3 : 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── PREMIUM QUICK ACTIONS ───────────────────────────────────────────────

  Widget _buildPremiumQuickActions(BuildContext context) {
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
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.indigo, AppColors.accent],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Quick Actions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: actions.map((a) {
            final (icon, label, onTap) = a;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: a != actions.last ? 10 : 0),
                child: _SuperPremiumActionChip(
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

  // ─── HELPERS ──────────────────────────────────────────────────────────────

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatCurrency(double amount) {
    const rupee = '\u20b9';
    if (amount.abs() >= 10000000) {
      return '$rupee${(amount / 10000000).toStringAsFixed(2)} Cr';
    } else if (amount.abs() >= 100000) {
      return '$rupee${(amount / 100000).toStringAsFixed(2)} L';
    }
    final whole = amount.truncate();
    final wholeStr = _indianGroup(whole.abs());
    return '${amount < 0 ? '-' : ''}$rupee$wholeStr';
  }

  String _formatSmallCurrency(double amount) {
    const rupee = '\u20b9';
    if (amount.abs() >= 100000) {
      return '$rupee${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount.abs() >= 1000) {
      return '$rupee${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '$rupee${amount.toStringAsFixed(0)}';
  }

  String _indianGroup(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
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
      return [];
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
      return [];
    }

    List<MonthlyPaymentData> list = [];
    double temp = currentTotal;
    for (int i = 5; i >= 0; i--) {
      list.insert(0,
          MonthlyPaymentData(label: _monthLabel(months[i].month), amount: temp));
      temp = (temp - data[i]).clamp(0, double.infinity).toDouble();
    }
    return list;
  }

  String _monthLabel(int m) {
    final normalized = ((m - 1) % 12) + 1;
    const labels = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return labels[normalized < 1 ? normalized + 12 : normalized];
  }
}

// ─── AMBIENT BACKGROUND ───────────────────────────────────────────────────

class _EnhancedBackground extends StatelessWidget {
  final AnimationController controller;
  final bool isDark;
  final Widget child;

  const _EnhancedBackground({
    required this.controller,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _AmbientBlobPainter(
                progress: controller.value,
                isDark: isDark,
                primaryColor: AppColors.primary.withValues(alpha: isDark ? 0.06 : 0.04),
                accentColor: AppColors.accent.withValues(alpha: isDark ? 0.05 : 0.03),
              ),
              size: Size.infinite,
            );
          },
        ),
        child,
      ],
    );
  }
}

class _AmbientBlobPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final Color primaryColor;
  final Color accentColor;

  _AmbientBlobPainter({
    required this.progress,
    required this.isDark,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120);

    // Three gently drifting blobs
    _drawBlob(canvas, size,
        0.15 + 0.08 * math.sin(progress * 2 * math.pi),
        0.25 + 0.06 * math.cos(progress * 2.3 * math.pi + 1),
        160, primaryColor, paint);
    _drawBlob(canvas, size,
        0.85 + 0.06 * math.cos(progress * 1.7 * math.pi),
        0.15 + 0.08 * math.sin(progress * 2 * math.pi + 2),
        180, accentColor, paint);
    _drawBlob(canvas, size,
        0.5 + 0.07 * math.sin(progress * 1.3 * math.pi + 0.5),
        0.75 + 0.05 * math.cos(progress * 2 * math.pi + 1.5),
        140, primaryColor.withValues(alpha: isDark ? 0.03 : 0.02), paint);
  }

  void _drawBlob(Canvas canvas, Size size, double xFactor, double yFactor,
      double radius, Color color, Paint paint) {
    paint.color = color;
    canvas.drawCircle(
      Offset(size.width * xFactor, size.height * yFactor),
      radius,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AmbientBlobPainter old) =>
      old.progress != progress;
}

// ─── PREMIUM RING GAUGE PAINTER ──────────────────────────────────────────

class _PremiumRingGaugePainter extends CustomPainter {
  final double value;
  final bool isDark;
  final double pulse;
  final List<Color> gradientColors;

  _PremiumRingGaugePainter({
    required this.value,
    required this.isDark,
    required this.pulse,
    required this.gradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * value.clamp(0.001, 1.0);

    // Outer glow ring
    final outerGlowPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.white.withValues(alpha: 0.02),
          Colors.white.withValues(alpha: 0.05),
          Colors.white.withValues(alpha: 0.02),
        ],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius + 6))
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius + 6, outerGlowPaint);

    // Background arc
    final bgPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.04)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Inner track
    final innerPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.03)
          : Colors.black.withValues(alpha: 0.02)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius - 7, innerPaint);

    // Deep glow behind the arc
    final glowPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          gradientColors[0].withValues(alpha: 0.1),
          gradientColors[1].withValues(alpha: 0.3 + pulse * 0.15),
          gradientColors[2].withValues(alpha: 0.4 + pulse * 0.15),
          gradientColors[1].withValues(alpha: 0.3 + pulse * 0.15),
          gradientColors[0].withValues(alpha: 0.1),
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = 20
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      glowPaint,
    );

    // Main progress arc
    final progressPaint = Paint()
      ..shader = SweepGradient(
        colors: gradientColors,
        stops: const [0.0, 0.5, 1.0],
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

    // Glowing thumb at the end of arc
    if (sweepAngle > 0.1) {
      final endX = center.dx + radius * math.cos(startAngle + sweepAngle);
      final endY = center.dy + radius * math.sin(startAngle + sweepAngle);
      final thumbCenter = Offset(endX, endY);

      // Outer glow
      final thumbOuterGlow = Paint()
        ..color = gradientColors.last.withValues(alpha: 0.4 + pulse * 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(thumbCenter, 12, thumbOuterGlow);

      // Inner glow
      final thumbInnerGlow = Paint()
        ..color = gradientColors.last.withValues(alpha: 0.6 + pulse * 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(thumbCenter, 8, thumbInnerGlow);

      // White core
      final thumbPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(thumbCenter, 4.5, thumbPaint);

      // Subtle border
      final thumbBorder = Paint()
        ..color = gradientColors[1].withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(thumbCenter, 4.5, thumbBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _PremiumRingGaugePainter old) =>
      old.value != value || old.pulse != pulse;
}

// ─── PREMIUM STAT CARD ──────────────────────────────────────────────────

class _PremiumStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final double numericValue;
  final bool isCurrency;
  final List<Color> gradientColors;
  final VoidCallback? onTap;
  final List<double> spark;
  final bool isDark;

  const _PremiumStatCard({
    required this.icon,
    required this.label,
    required this.numericValue,
    required this.isCurrency,
    required this.gradientColors,
    required this.spark,
    this.onTap,
    required this.isDark,
  });

  String _format(double v) {
    const rupee = '\u20b9';
    if (!isCurrency) return v.toInt().toString();
    if (v.abs() >= 10000000) return '$rupee${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v.abs() >= 100000) return '$rupee${(v / 100000).toStringAsFixed(2)}L';
    if (v.abs() >= 1000) return '$rupee${(v / 1000).toStringAsFixed(1)}K';
    return '$rupee${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors[0].withValues(alpha: isDark ? 0.3 : 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const Spacer(),
              if (spark.isNotEmpty && spark.any((e) => e > 0))
                SizedBox(
                  width: 52,
                  height: 24,
                  child: SparklineChart(
                    data: spark,
                    color: gradientColors[0],
                    height: 24,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: numericValue),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(
              _format(v),
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: (isDark ? Colors.white : const Color(0xFF0F172A))
                  .withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SUPER PREMIUM ACTION CHIP ──────────────────────────────────────────

class _SuperPremiumActionChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _SuperPremiumActionChip({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_SuperPremiumActionChip> createState() =>
      _SuperPremiumActionChipState();
}

class _SuperPremiumActionChipState extends State<_SuperPremiumActionChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _pressAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _pressAnimation = CurvedAnimation(
      parent: _pressController,
      curve: Curves.elasticOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) => _pressController.reverse(),
      onTapCancel: () => _pressController.reverse(),
      child: AnimatedBuilder(
        animation: _pressAnimation,
        builder: (context, child) {
          final scale = 1.0 - (_pressAnimation.value * 0.05);
          return Transform.scale(scale: scale, child: child);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.isDark
                  ? [
                      const Color(0xFF1C2030),
                      const Color(0xFF1A1F3A),
                    ]
                  : [Colors.white, Colors.white.withValues(alpha: 0.95)],
            ),
            borderRadius: BorderRadius.circular(20),
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
                width: 48,
                height: 48,
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
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.2),
                      blurRadius: 18,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 10),
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
