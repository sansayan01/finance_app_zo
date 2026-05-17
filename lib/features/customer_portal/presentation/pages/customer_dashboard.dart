import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/providers/customer_portal_providers.dart';

class CustomerDashboard extends ConsumerWidget {
  const CustomerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberId = ref.watch(currentMemberIdProvider);
    final dashboardAsync = memberId != null
        ? ref.watch(customerDashboardProvider(memberId))
        : null;

    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/customer/notifications'),
          ),
        ],
      ),
      body: dashboardAsync == null
          ? const Center(child: Text('Please login to continue'))
          : dashboardAsync.when(
              data: (dashboard) {
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(customerDashboardProvider);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Card
                        _buildWelcomeCard(theme, dashboard),
                        const SizedBox(height: 16),

                        // Quick Stats
                        _buildQuickStatsCard(theme, dashboard, currencyFormat),
                        const SizedBox(height: 16),

                        // Next EMI Alert
                        if (dashboard['next_emi'] != null)
                          _buildNextEMICard(
                              context, theme, dashboard, currencyFormat),
                        const SizedBox(height: 16),

                        // Savings Progress
                        _buildSavingsProgressCard(
                            theme, dashboard, currencyFormat),
                        const SizedBox(height: 16),

                        // Recent Transactions
                        _buildRecentTransactionsCard(context, theme, dashboard),
                        const SizedBox(height: 16),

                        // Quick Actions
                        _buildQuickActionsCard(context, theme),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: ${error.toString()}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          ref.invalidate(customerDashboardProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _buildBottomNav(context, 0),
    );
  }

  Widget _buildWelcomeCard(ThemeData theme, Map<String, dynamic> dashboard) {
    final name = dashboard['member_name'] ?? 'Member';

    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.person,
                color: theme.colorScheme.onPrimaryContainer,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer
                          .withValues(alpha: 0.8),
                    ),
                  ),
                  Text(
                    name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildQuickStatsCard(ThemeData theme, Map<String, dynamic> dashboard,
      NumberFormat currencyFormat) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Overview',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    theme,
                    Icons.account_balance_wallet,
                    'Total Loans',
                    '${dashboard['active_loans'] ?? 0}',
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    theme,
                    Icons.savings,
                    'Total Savings',
                    currencyFormat.format(dashboard['total_savings'] ?? 0),
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    theme,
                    Icons.payment,
                    'Outstanding',
                    currencyFormat
                        .format(dashboard['outstanding_balance'] ?? 0),
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    theme,
                    Icons.check_circle,
                    'EMIs Paid',
                    '${dashboard['emis_paid'] ?? 0}',
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildStatItem(
      ThemeData theme, IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNextEMICard(BuildContext context, ThemeData theme,
      Map<String, dynamic> dashboard, NumberFormat currencyFormat) {
    final nextEmi = dashboard['next_emi'] as Map<String, dynamic>? ?? {};
    final dueDate =
        DateTime.tryParse(nextEmi['due_date'] ?? '') ?? DateTime.now();
    final isOverdue = dueDate.isBefore(DateTime.now());

    return Card(
      color: isOverdue
          ? Colors.red.withValues(alpha: 0.1)
          : theme.colorScheme.tertiaryContainer,
      child: InkWell(
        onTap: () => context.push('/customer/loans'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                isOverdue ? Icons.warning : Icons.event,
                color: isOverdue
                    ? Colors.red
                    : theme.colorScheme.onTertiaryContainer,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOverdue ? 'Overdue EMI' : 'Next EMI Due',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isOverdue
                            ? Colors.red
                            : theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                    Text(
                      '${currencyFormat.format(nextEmi['amount'] ?? 0)} • Due: ${DateFormat('MMM d').format(dueDate)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isOverdue
                            ? Colors.red.withValues(alpha: 0.8)
                            : theme.colorScheme.onTertiaryContainer
                                .withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: isOverdue
                    ? Colors.red
                    : theme.colorScheme.onTertiaryContainer,
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildSavingsProgressCard(ThemeData theme,
      Map<String, dynamic> dashboard, NumberFormat currencyFormat) {
    final goal = (dashboard['savings_goal'] ?? 100000) as num;
    final current = (dashboard['total_savings'] ?? 0) as num;
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Savings Goal Progress',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: const AlwaysStoppedAnimation(Colors.green),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Saved: ${currencyFormat.format(current)}'),
                Text('Goal: ${currencyFormat.format(goal)}'),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }

  Widget _buildRecentTransactionsCard(
      BuildContext context, ThemeData theme, Map<String, dynamic> dashboard) {
    final transactions =
        dashboard['recent_transactions'] as List<dynamic>? ?? [];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/customer/transactions'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('No recent transactions')),
              )
            else
              Column(
                children: transactions.take(5).map<Widget>((tx) {
                  return _buildTransactionItem(theme, tx);
                }).toList(),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 400.ms);
  }

  Widget _buildTransactionItem(ThemeData theme, Map<String, dynamic> tx) {
    final isCredit = (tx['type'] ?? '') == 'credit';
    final amount = (tx['amount'] ?? 0) as num;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isCredit
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isCredit ? Icons.arrow_downward : Icons.arrow_upward,
          color: isCredit ? Colors.green : Colors.red,
        ),
      ),
      title: Text(tx['description'] ?? 'Transaction'),
      subtitle: Text(tx['date'] ?? ''),
      trailing: Text(
        '${isCredit ? '+' : '-'}₹$amount',
        style: theme.textTheme.titleSmall?.copyWith(
          color: isCredit ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard(BuildContext context, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildQuickActionChip(
                  context,
                  Icons.payment,
                  'Pay EMI',
                  () => context.push('/customer/loans'),
                ),
                _buildQuickActionChip(
                  context,
                  Icons.savings,
                  'Deposit',
                  () => context.push('/customer/savings'),
                ),
                _buildQuickActionChip(
                  context,
                  Icons.history,
                  'History',
                  () => context.push('/customer/transactions'),
                ),
                _buildQuickActionChip(
                  context,
                  Icons.support_agent,
                  'Support',
                  () => context.push('/customer/support'),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 500.ms);
  }

  Widget _buildQuickActionChip(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: theme.colorScheme.secondaryContainer,
      labelStyle: TextStyle(color: theme.colorScheme.onSecondaryContainer),
    );
  }

  Widget _buildBottomNav(BuildContext context, int currentIndex) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            context.go('/customer');
            break;
          case 1:
            context.go('/customer/loans');
            break;
          case 2:
            context.go('/customer/savings');
            break;
          case 3:
            context.go('/customer/profile');
            break;
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_balance_outlined),
          selectedIcon: Icon(Icons.account_balance),
          label: 'Loans',
        ),
        NavigationDestination(
          icon: Icon(Icons.savings_outlined),
          selectedIcon: Icon(Icons.savings),
          label: 'Savings',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
