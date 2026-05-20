import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../data/providers/customer_loans_providers.dart';
import '../../data/models/customer_loan_model.dart';
import '../widgets/customer_loan_card.dart';
import '../widgets/customer_empty_state.dart';

class CustomerLoansPage extends ConsumerStatefulWidget {
  const CustomerLoansPage({super.key});

  @override
  ConsumerState<CustomerLoansPage> createState() => _CustomerLoansPageState();
}

class _CustomerLoansPageState extends ConsumerState<CustomerLoansPage> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final loansAsync = ref.watch(customerLoansProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Loans'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded),
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'all', child: Text('All Loans')),
              const PopupMenuItem(value: 'active', child: Text('Active Only')),
              const PopupMenuItem(
                  value: 'completed', child: Text('Completed')),
              const PopupMenuItem(value: 'overdue', child: Text('Overdue')),
            ],
          ),
        ],
      ),
      body: loansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (loans) {
          final filtered = _filterLoans(loans);
          if (filtered.isEmpty) {
            return const CustomerEmptyState(
              icon: Icons.account_balance_rounded,
              title: 'No Loans Found',
              subtitle: 'You don\'t have any loans matching this filter.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(customerLoansProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: CustomerLoanCard(
                    loan: filtered[index],
                    onTap: () =>
                        context.push('/customer/loans/${filtered[index].id}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  List<CustomerLoanModel> _filterLoans(List<CustomerLoanModel> loans) {
    return switch (_filter) {
      'active' => loans.where((l) => l.status == 'active').toList(),
      'completed' =>
        loans.where((l) => l.status == 'completed' || l.status == 'closed').toList(),
      'overdue' => loans.where((l) => l.isOverdue).toList(),
      _ => loans,
    };
  }
}
