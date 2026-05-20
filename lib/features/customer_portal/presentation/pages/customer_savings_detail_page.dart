import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/progress_gauge.dart';
import '../../data/providers/customer_savings_providers.dart';
import '../widgets/customer_transaction_tile.dart';
import '../widgets/customer_empty_state.dart';

class CustomerSavingsDetailPage extends ConsumerWidget {
  final String savingsId;

  const CustomerSavingsDetailPage({super.key, required this.savingsId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savingsAsync = ref.watch(customerSavingsDetailProvider(savingsId));
    final transactionsAsync =
        ref.watch(customerSavingsTransactionsProvider(savingsId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Details'),
      ),
      body: savingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (savings) {
          if (savings == null) {
            return const Center(child: Text('Savings account not found'));
          }
          final theme = Theme.of(context);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(customerSavingsDetailProvider(savingsId));
              ref.invalidate(customerSavingsTransactionsProvider(savingsId));
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // Account header
                Text(
                  savings.displayName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Balance card
                GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Current Balance',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withValues(alpha: 0.6),
                              )),
                          Text(
                              'Target: \u20b9${savings.targetAmount.toStringAsFixed(0)}',
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '\u20b9${savings.currentAmount.toStringAsFixed(0)}',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${savings.progressPercentage.toStringAsFixed(1)}%',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      LinearProgressBar(
                        value: savings.progressPercentage / 100,
                        height: 8,
                        backgroundColor: theme
                            .colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        progressColor: Colors.green,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Account details
                GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      _buildDetailRow(context, 'Monthly Deposit',
                          '\u20b9${savings.monthlyDeposit.toStringAsFixed(0)}'),
                      _buildDetailRow(context, 'Interest Rate',
                          '${savings.interestRate.toStringAsFixed(1)}%'),
                      if (savings.tenureMonths != null)
                        _buildDetailRow(context, 'Tenure',
                            '${savings.tenureMonths} months'),
                      if (savings.maturityDate != null)
                        _buildDetailRow(
                            context,
                            'Maturity Date',
                            '${savings.maturityDate!.day}/${savings.maturityDate!.month}/${savings.maturityDate!.year}'),
                      _buildDetailRow(context, 'Status',
                          savings.status[0].toUpperCase() + savings.status.substring(1)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Transactions
                Text(
                  'Transactions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                transactionsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e'),
                  data: (transactions) {
                    if (transactions.isEmpty) {
                      return const CustomerEmptyState(
                        icon: Icons.receipt_long_rounded,
                        title: 'No Transactions',
                        subtitle:
                            'No transactions found for this savings account.',
                      );
                    }
                    return Column(
                      children: transactions
                          .map((t) => CustomerTransactionTile(transaction: t))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color:
                  theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
