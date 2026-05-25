// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';

import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/providers/branch_scoped_providers.dart';

/// Branch-scoped collections page for Branch Manager Portal.
/// Shows today's collection overview with stats and recent transactions.
class BranchCollectionsPage extends ConsumerStatefulWidget {
  const BranchCollectionsPage({super.key});

  @override
  ConsumerState<BranchCollectionsPage> createState() =>
      _BranchCollectionsPageState();
}

class _BranchCollectionsPageState extends ConsumerState<BranchCollectionsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authProvider).user;
    final branchId = user?.branchId;
    final currencyFormat = NumberFormat.currency(symbol: '\u20B9', decimalDigits: 0);

    if (branchId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Collections')),
        body: const Center(child: Text('No branch assigned to your profile.')),
      );
    }

    final statsAsync = ref.watch(branchCollectionStatsProvider(branchId));
    final collectionsAsync = ref.watch(branchTodayCollectionsProvider(branchId));

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF2F2F7),
      body: AuroraBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(branchCollectionStatsProvider(branchId));
            ref.invalidate(branchTodayCollectionsProvider(branchId));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // App Bar
              SliverAppBar(
                pinned: true,
                elevation: 0,
                backgroundColor: isDark
                    ? const Color(0xFF0A0A0C).withValues(alpha: 0.85)
                    : const Color(0xFFF2F2F7).withValues(alpha: 0.85),
                surfaceTintColor: Colors.transparent,
                title: Text(
                  'Collections',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                systemOverlayStyle: isDark
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark,
              ),

              // Stats Cards
              SliverToBoxAdapter(
                child: statsAsync.when(
                  data: (stats) => _buildStatsGrid(
                      theme, isDark, stats, currencyFormat),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: ShimmerCard(height: 160),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "Today's Collections",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // Collection Cards
              collectionsAsync.when(
                data: (collections) {
                  if (collections.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(theme, isDark),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.builder(
                      itemCount: collections.length,
                      itemBuilder: (context, index) {
                        final collection = collections[index];
                        return _buildCollectionCard(
                          context, theme, isDark, collection,
                          currencyFormat, index,
                        );
                      },
                    ),
                  );
                },
                loading: () => SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.builder(
                    itemCount: 6,
                    itemBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: ShimmerCard(height: 80),
                    ),
                  ),
                ),
                error: (error, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${error.toString()}'),
                      ],
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  // Stats Grid
  Widget _buildStatsGrid(
    ThemeData theme,
    bool isDark,
    Map<String, dynamic> stats,
    NumberFormat currencyFormat,
  ) {
    final todayTotal = (stats['today_total'] as num?)?.toDouble() ?? 0;
    final todayCount = (stats['today_count'] as int?) ?? 0;
    final weekTotal = (stats['week_total'] as num?)?.toDouble() ?? 0;
    final weekCount = (stats['week_count'] as int?) ?? 0;
    final monthTotal = (stats['month_total'] as num?)?.toDouble() ?? 0;
    final monthCount = (stats['month_count'] as int?) ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Hero card - Today
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.today_rounded,
                          color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Today's Collection",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  isDark ? Colors.white54 : Colors.black45,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currencyFormat.format(todayTotal),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$todayCount txn',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 12),
          // Week & Month row
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  theme, isDark,
                  icon: Icons.date_range_rounded,
                  label: 'This Week',
                  value: currencyFormat.format(weekTotal),
                  count: weekCount,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatTile(
                  theme, isDark,
                  icon: Icons.calendar_month_rounded,
                  label: 'This Month',
                  value: currencyFormat.format(monthTotal),
                  count: monthCount,
                  color: AppColors.accent,
                ),
              ),
            ],
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: 100.ms)
              .slideY(begin: 0.1, end: 0),
        ],
      ),
    );
  }

  Widget _buildStatTile(
    ThemeData theme,
    bool isDark, {
    required IconData icon,
    required String label,
    required String value,
    required int count,
    required Color color,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              Text(
                '$count txn',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Collection Card
  Widget _buildCollectionCard(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    Map<String, dynamic> collection,
    NumberFormat currencyFormat,
    int index,
  ) {
    final amount = (collection['amount'] as num?)?.toDouble() ?? 0;
    final paymentMode = collection['payment_mode']?.toString() ?? 'cash';
    final createdAt = collection['created_at']?.toString() ?? '';

    // Extract collector info
    final collector =
        collection['collector'] as Map<String, dynamic>?;
    final collectorName = collector?['full_name']?.toString() ?? 'Unknown';

    // Extract loan info
    final loan = collection['loan'] as Map<String, dynamic>?;
    final loanNumber = loan?['loan_number']?.toString() ?? '';
    final members = loan?['members'] as Map<String, dynamic>?;
    final memberName = members?['full_name']?.toString() ?? 'Unknown';

    final time = createdAt.isNotEmpty
        ? DateFormat('hh:mm a')
            .format(DateTime.tryParse(createdAt) ?? DateTime.now())
        : '';

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Amount badge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '\u20B9',
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  memberName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (loanNumber.isNotEmpty) ...[
                      Text(
                        loanNumber,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white54 : Colors.black45,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getPaymentModeColor(paymentMode)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        paymentMode.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: _getPaymentModeColor(paymentMode),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'By $collectorName${time.isNotEmpty ? ' at $time' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Amount
          Text(
            currencyFormat.format(amount),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(
          duration: 350.ms,
          delay: Duration(milliseconds: 50 * index.clamp(0, 10)),
        );
  }

  Color _getPaymentModeColor(String mode) {
    switch (mode.toLowerCase()) {
      case 'cash':
        return AppColors.success;
      case 'upi':
        return AppColors.info;
      case 'bank_transfer':
      case 'bank transfer':
        return AppColors.accent;
      case 'cheque':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  // Empty State
  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : AppColors.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 48,
              color: isDark
                  ? Colors.white24
                  : AppColors.primary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No collections today',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Collections recorded by staff will appear here',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}
