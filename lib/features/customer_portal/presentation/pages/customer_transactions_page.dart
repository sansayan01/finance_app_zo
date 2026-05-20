import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../data/providers/customer_home_providers.dart';
import '../../data/models/customer_transaction_model.dart';
import '../widgets/customer_transaction_tile.dart';
import '../widgets/customer_empty_state.dart';

class CustomerTransactionsPage extends ConsumerStatefulWidget {
  const CustomerTransactionsPage({super.key});

  @override
  ConsumerState<CustomerTransactionsPage> createState() =>
      _CustomerTransactionsPageState();
}

class _CustomerTransactionsPageState
    extends ConsumerState<CustomerTransactionsPage> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(customerAllTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded),
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(
                  value: 'emi', child: Text('EMI Payments')),
              const PopupMenuItem(
                  value: 'deposit', child: Text('Deposits')),
              const PopupMenuItem(
                  value: 'withdrawal', child: Text('Withdrawals')),
            ],
          ),
        ],
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (transactions) {
          final filtered = _filterTransactions(transactions);
          if (filtered.isEmpty) {
            return const CustomerEmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'No Transactions',
              subtitle: 'No transactions match this filter.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(customerAllTransactionsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                return CustomerTransactionTile(
                    transaction: filtered[index]);
              },
            ),
          );
        },
      ),
    );
  }

  List<CustomerTransactionModel> _filterTransactions(
      List<CustomerTransactionModel> transactions) {
    return switch (_filter) {
      'emi' => transactions.where((t) => t.type == 'emiPayment').toList(),
      'deposit' => transactions
          .where((t) =>
              t.type == 'savingsDeposit' || t.type == 'deposit' || t.type == 'collection')
          .toList(),
      'withdrawal' => transactions
          .where((t) =>
              t.type == 'savingsWithdrawal' || t.type == 'withdrawal')
          .toList(),
      _ => transactions,
    };
  }
}
