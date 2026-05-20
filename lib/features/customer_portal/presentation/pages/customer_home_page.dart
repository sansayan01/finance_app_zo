import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../data/providers/customer_home_providers.dart';
import '../../data/providers/customer_member_provider.dart';
import '../../data/providers/customer_notifications_providers.dart';
import '../../data/models/customer_emi_model.dart';
import '../../data/models/customer_transaction_model.dart';
import '../widgets/customer_stats_card.dart';
import '../widgets/customer_transaction_tile.dart';
import '../widgets/customer_empty_state.dart';

class CustomerHomePage extends ConsumerWidget {
  const CustomerHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  subtitle: 'Your dashboard will appear here once you have loans or savings.',
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
        slivers: [
          // Welcome header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, $memberName!',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          area != null && area.isNotEmpty
                              ? 'Here\'s your financial overview • $area'
                              : 'Here\'s your financial overview',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Notification bell
                  Consumer(
                    builder: (context, ref, _) {
                      final unreadAsync = ref.watch(customerUnreadCountProvider);
                      final count = unreadAsync.valueOrNull ?? 0;
                      return IconButton(
                        onPressed: () => context.push('/customer/notifications'),
                        icon: Badge(
                          isLabelVisible: count > 0,
                          label: Text('$count'),
                          child: const Icon(Icons.notifications_outlined),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // KYC warning
          if (kycStatus != null && kycStatus != 'verified')
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm + 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: Colors.orange, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          kycStatus == 'pending'
                              ? 'Your KYC verification is pending'
                              : 'Your KYC was rejected. Please update your documents.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Stats grid
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 1.6,
                children: [
                  CustomerStatsCard(
                    icon: Icons.account_balance_rounded,
                    label: 'Active Loans',
                    value: '$activeLoans',
                    color: Colors.blue,
                    onTap: () => context.push('/customer/loans'),
                  ),
                  CustomerStatsCard(
                    icon: Icons.savings_rounded,
                    label: 'Total Savings',
                    value: _formatCurrency(totalSavings),
                    color: Colors.green,
                    onTap: () => context.push('/customer/savings'),
                  ),
                  CustomerStatsCard(
                    icon: Icons.trending_down_rounded,
                    label: 'Outstanding',
                    value: _formatCurrency(totalOutstanding),
                    color: Colors.orange,
                  ),
                  CustomerStatsCard(
                    icon: Icons.calendar_today_rounded,
                    label: 'Next EMI',
                    value: nextEmi != null
                        ? _formatCurrency(nextEmi.emiAmount)
                        : 'None',
                    color: nextEmi != null && nextEmi.isOverdue
                        ? Colors.red
                        : Colors.purple,
                  ),
                ],
              ),
            ),
          ),

          // Next EMI alert
          if (nextEmi != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: _buildEmiAlert(context, nextEmi),
              ),
            ),

          // Quick actions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _buildQuickActions(context),
            ),
          ),

          // Recent transactions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Transactions',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/customer/transactions'),
                    child: const Text('See All'),
                  ),
                ],
              ),
            ),
          ),

          if (recentTransactions.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
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
                  return CustomerTransactionTile(
                    transaction: recentTransactions[index],
                  );
                },
                childCount: recentTransactions.length,
              ),
            ),

          // Bottom padding for nav bar
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  Widget _buildEmiAlert(BuildContext context, CustomerEmiModel emi) {
    final theme = Theme.of(context);
    final isOverdue = emi.isOverdue;
    final color = isOverdue ? Colors.red : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            isOverdue
                ? Icons.warning_rounded
                : Icons.calendar_month_rounded,
            color: color,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOverdue ? 'EMI Overdue!' : 'Next EMI Due',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  emi.dueDate != null
                      ? 'Due: ${emi.dueDate!.day}/${emi.dueDate!.month}/${emi.dueDate!.year} - \u20b9${emi.emiAmount.toStringAsFixed(0)}'
                      : '\u20b9${emi.emiAmount.toStringAsFixed(0)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _QuickAction(Icons.account_balance_rounded, 'Loans',
          () => context.push('/customer/loans')),
      _QuickAction(Icons.savings_rounded, 'Savings',
          () => context.push('/customer/savings')),
      _QuickAction(Icons.receipt_long_rounded, 'Transactions',
          () => context.push('/customer/transactions')),
      _QuickAction(Icons.support_agent_rounded, 'Support',
          () => context.push('/customer/support')),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: actions
          .map((a) => _buildActionButton(context, a.icon, a.label, a.onTap))
          .toList(),
    );
  }

  Widget _buildActionButton(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.md),
            ),
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 6),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
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
}

class _QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _QuickAction(this.icon, this.label, this.onTap);
}
