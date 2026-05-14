import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/providers/customer_portal_providers.dart';
// import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

class CustomerSavingsPage extends ConsumerWidget {
  const CustomerSavingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberId = ref.watch(currentMemberIdProvider);
    final savingsAsync = memberId != null
        ? ref.watch(customerSavingsProvider(memberId))
        : null;

    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Savings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/customer/transactions'),
          ),
        ],
      ),
      body: savingsAsync == null
          ? const Center(child: Text('Please login to continue'))
          : savingsAsync.when(
              data: (savings) {
                final totalBalance = savings.fold<double>(
                  0.0,
                  (sum, s) => sum + ((s['balance'] as num?)?.toDouble() ?? 0.0),
                );

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total Savings Card
                      _buildTotalSavingsCard(theme, currencyFormat, totalBalance),
                      const SizedBox(height: 16),

                      // Quick Actions
                      _buildQuickActionsCard(context, ref, theme),
                      const SizedBox(height: 16),

                      // Savings Accounts
                      Text(
                        'Savings Accounts',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (savings.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('No savings accounts yet'),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: savings.length,
                          itemBuilder: (context, index) {
                            final account = savings[index];
                            return _buildSavingsAccountCard(context, ref, account, currencyFormat)
                                .animate()
                                .fadeIn(duration: 300.ms, delay: Duration(milliseconds: index * 50));
                          },
                        ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDepositDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Deposit'),
      ),
      bottomNavigationBar: _buildBottomNav(context, 2),
    );
  }

  Widget _buildTotalSavingsCard(ThemeData theme, NumberFormat currencyFormat, double totalBalance) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.savings,
              color: theme.colorScheme.onPrimaryContainer,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Total Savings',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
              ),
            ),
            Text(
              currencyFormat.format(totalBalance),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildQuickActionsCard(BuildContext context, WidgetRef ref, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildQuickAction(
              context,
              Icons.arrow_downward,
              'Deposit',
              Colors.green,
              () => _showDepositDialog(context, ref),
            ),
            _buildQuickAction(
              context,
              Icons.arrow_upward,
              'Withdraw',
              Colors.orange,
              () => _showWithdrawDialog(context, ref),
            ),
            _buildQuickAction(
              context,
              Icons.history,
              'History',
              Colors.blue,
              () => context.push('/customer/transactions'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingsAccountCard(
    BuildContext context,
    WidgetRef ref,
    dynamic account,
    NumberFormat currencyFormat,
  ) {
    final theme = Theme.of(context);
    final accountType = account['savings_plan']?['name'] ?? 'Regular Savings';
    final balance = (account['balance'] as num?)?.toDouble() ?? 0.0;
    final interestRate = (account['interest_rate'] as num?)?.toDouble() ?? 5.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      accountType,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Account #${(account['id'] as String?)?.substring(0, 8) ?? ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$interestRate% p.a.',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currencyFormat.format(balance),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Available Balance',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showWithdrawDialog(context, ref, accountId: account['id']),
                    child: const Text('Withdraw'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showDepositDialog(context, ref, accountId: account['id']),
                    child: const Text('Deposit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDepositDialog(BuildContext context, WidgetRef ref, {String? accountId}) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deposit Savings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Deposit will be collected by your field agent'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text) ?? 0;
              if (amount <= 0) return;

              Navigator.pop(context);
              // Process deposit
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Deposit request submitted')),
              );
            },
            child: const Text('Deposit'),
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog(BuildContext context, WidgetRef ref, {String? accountId}) {
    final controller = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw Savings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Withdrawal requires branch manager approval'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text) ?? 0;
              if (amount <= 0) return;

              Navigator.pop(context);
              // Process withdrawal request
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Withdrawal request submitted')),
              );
            },
            child: const Text('Request'),
          ),
        ],
      ),
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
