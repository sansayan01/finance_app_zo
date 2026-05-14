import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/providers/customer_portal_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class CustomerLoansPage extends ConsumerWidget {
  const CustomerLoansPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberId = ref.watch(currentMemberIdProvider);
    final loansAsync = memberId != null
        ? ref.watch(customerLoansProvider(memberId))
        : null;

    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Loans'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterOptions(context),
          ),
        ],
      ),
      body: loansAsync == null
          ? const Center(child: Text('Please login to continue'))
          : loansAsync.when(
              data: (loans) => loans.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No active loans'),
                          SizedBox(height: 8),
                          Text('Apply for a loan from your branch'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: loans.length,
                      itemBuilder: (context, index) {
                        final loan = loans[index];
                        return _buildLoanCard(context, ref, loan, currencyFormat)
                            .animate()
                            .fadeIn(duration: 300.ms, delay: Duration(milliseconds: index * 50))
                            .slideX(begin: 0.1, end: 0);
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
      bottomNavigationBar: _buildBottomNav(context, 1),
    );
  }

  Widget _buildLoanCard(BuildContext context, WidgetRef ref, dynamic loan, NumberFormat currencyFormat) {
    final theme = Theme.of(context);
    final progress = (loan.paidAmount ?? 0) / (loan.totalAmount ?? 1);
    final isOverdue = loan.nextDueDate?.isBefore(DateTime.now()) ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOverdue ? Colors.red.withOpacity(0.5) : theme.colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: () => context.push('/customer/loans/${loan.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getLoanStatusColor(loan.status ?? 'active').withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      (loan.status ?? 'Active').toUpperCase(),
                      style: TextStyle(
                        color: _getLoanStatusColor(loan.status ?? 'active'),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    'Loan #${loan.id?.substring(0, 8) ?? ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
                        currencyFormat.format(loan.totalAmount ?? 0),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Total Amount',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${loan.emiCount ?? 0} EMIs',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${loan.emiAmount ?? 0}/month',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(
                    isOverdue ? Colors.red : theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Paid: ${currencyFormat.format(loan.paidAmount ?? 0)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    'Outstanding: ${currencyFormat.format(loan.outstandingAmount ?? 0)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              if (isOverdue) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Next EMI overdue - Pay now to avoid penalty',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/customer/loans/${loan.id}/schedule'),
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: const Text('Schedule'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showPaymentDialog(context, ref, loan),
                      icon: const Icon(Icons.payment, size: 18),
                      label: const Text('Pay EMI'),
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

  Color _getLoanStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'overdue':
        return Colors.red;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref, dynamic loan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pay EMI'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EMI Amount: ₹${loan.emiAmount ?? 0}'),
            const SizedBox(height: 16),
            const Text('Select Payment Mode:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('UPI'),
                  selected: true,
                  onSelected: (_) {},
                ),
                ChoiceChip(
                  label: const Text('Cash'),
                  selected: false,
                  onSelected: (_) {},
                ),
                ChoiceChip(
                  label: const Text('Bank'),
                  selected: false,
                  onSelected: (_) {},
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref.read(emiPaymentProvider.notifier).payEMI(
                loan.id ?? '',
                (loan.emiAmount ?? 0).toDouble(),
                'upi',
              );
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment successful!')),
                );
              }
            },
            child: const Text('Pay Now'),
          ),
        ],
      ),
    );
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter Loans',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('All Loans'),
              trailing: const Icon(Icons.check),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('Active Only'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('Completed'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('Overdue'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
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
