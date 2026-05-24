import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/customer_home_providers.dart';
import '../../data/providers/customer_member_provider.dart';
import '../../data/providers/customer_notifications_providers.dart';
import '../../data/models/customer_emi_model.dart';
import '../../data/models/customer_transaction_model.dart';
import '../widgets/customer_empty_state.dart';
import '../widgets/customer_transaction_tile.dart';

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
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Animation<double> _staggered(int index, {double duration = 0.5}) {
    final start = (index * 0.1).clamp(0.0, 1.0);
    final end = (start + duration).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _staggerController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(customerDashboardProvider);
    final memberIdAsync = ref.watch(currentCustomerIdProvider);

    return Scaffold(
      body: memberIdAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
            loading: () => const Center(child: CircularProgressIndicator()),
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

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(customerDashboardProvider);
        ref.invalidate(customerUnreadCountProvider);
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Premium gradient greeting
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _staggered(0),
              builder: (context, child) => Opacity(
                opacity: _staggered(0).value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - _staggered(0).value)),
                  child: child,
                ),
              ),
              child: _buildGreetingHeader(context, ref, memberName, area,
                  isDark, kycStatus, totalSavings),
            ),
          ),

          // Stats row
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _staggered(1),
              builder: (context, child) => Opacity(
                opacity: _staggered(1).value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - _staggered(1).value)),
                  child: child,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _AnimatedStatCard(
                        controller: _staggerController,
                        index: 1,
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'Active Loans',
                        value: '$activeLoans',
                        color: AppColors.info,
                        isDark: isDark,
                        onTap: () => context.push('/customer/loans'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AnimatedStatCard(
                        controller: _staggerController,
                        index: 2,
                        icon: Icons.trending_down_rounded,
                        label: 'Outstanding',
                        value: _formatCurrency(totalOutstanding),
                        color: AppColors.orange,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Next EMI
          if (nextEmi != null)
            SliverToBoxAdapter(
              child: AnimatedBuilder(
                animation: _staggered(2),
                builder: (context, child) => Opacity(
                  opacity: _staggered(2).value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - _staggered(2).value)),
                    child: child,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _buildEmiAlert(context, nextEmi, isDark),
                ),
              ),
            ),

          // Quick actions
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _staggered(3),
              builder: (context, child) => Opacity(
                opacity: _staggered(3).value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - _staggered(3).value)),
                  child: child,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _buildQuickActions(context),
              ),
            ),
          ),

          // Recent transactions header
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _staggered(4),
              builder: (context, child) => Opacity(
                opacity: _staggered(4).value,
                child: child!,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Transactions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/customer/transactions'),
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

          // Transactions
          if (recentTransactions.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CustomerEmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: 'No Transactions',
                  subtitle: 'Your transactions will appear here.',
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final itemAnim = _staggered(5 + index);
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

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
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
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: avatar + notification
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
                        memberName.isNotEmpty ? memberName[0].toUpperCase() : 'M',
                        style: const TextStyle(
                          color: Colors.white,
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
                          'Welcome back,',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          memberName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final count =
                          ref.watch(customerUnreadCountProvider).valueOrNull ?? 0;
                      return Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => context.push('/customer/notifications'),
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

              // KYC warning
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

              // Savings ring gauge
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
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

              // Area
              if (area != null && area.isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
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
      ),
      child: Row(
        children: [
          // Icon with pulse effect
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
                    color: isOverdue ? AppColors.rose : AppColors.accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  emi.dueDate != null
                      ? '${_formatDate(emi.dueDate!)} • \u20b9${emi.emiAmount.toStringAsFixed(0)}'
                      : '\u20b9${emi.emiAmount.toStringAsFixed(0)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          if (daysLeft != null && !isOverdue)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                daysLeft == 0 ? 'Today' : '${daysLeft}d',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
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
    final actions = [
      (Icons.account_balance_rounded, 'Loans', () => context.push('/customer/loans')),
      (Icons.savings_rounded, 'Savings', () => context.push('/customer/savings')),
      (Icons.receipt_long_rounded, 'History', () => context.push('/customer/transactions')),
      (Icons.support_agent_rounded, 'Support', () => context.push('/customer/support')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: actions.map((a) {
            final (icon, label, onTap) = a;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    right: a != actions.last ? 10 : 0),
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

  String _formatCurrency(double amount) {
    if (amount >= 100000) {
      return '\u20b9${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '\u20b9${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '\u20b9${amount.toStringAsFixed(0)}';
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
}

// ── Ring Gauge Painter ──
class _RingGaugePainter extends CustomPainter {
  final double value;
  final bool isDark;

  _RingGaugePainter({required this.value, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * value.clamp(0, 1);

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc with glow
    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..shader = const SweepGradient(
            startAngle: 0,
            endAngle: math.pi * 2,
            colors: [Color(0xFFFFFFFF), Color(0xFFE0E7FF)],
          ).createShader(Rect.fromCircle(center: center, radius: radius))
          ..strokeWidth = 8
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );

      // Glow layer
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.3)
          ..strokeWidth = 14
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingGaugePainter old) => old.value != value;
}

// ── Animated Stat Card ──
class _AnimatedStatCard extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  final VoidCallback? onTap;

  const _AnimatedStatCard({
    required this.controller,
    required this.index,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    this.onTap,
  });

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
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: (isDark ? Colors.white : const Color(0xFF0F172A))
                    .withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Premium Action Chip ──
class _PremiumActionChip extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2030) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                    AppColors.accent.withValues(alpha: isDark ? 0.15 : 0.08),
                  ],
                ),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: (isDark ? Colors.white : const Color(0xFF0F172A))
                    .withValues(alpha: 0.7),
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
