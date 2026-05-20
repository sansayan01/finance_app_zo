import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/progress_gauge.dart';
import '../../data/providers/customer_loans_providers.dart';

class CustomerLoanDetailPage extends ConsumerWidget {
  final String loanId;

  const CustomerLoanDetailPage({super.key, required this.loanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loanAsync = ref.watch(customerLoanDetailProvider(loanId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Details'),
      ),
      body: loanAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (loan) {
          if (loan == null) {
            return const Center(child: Text('Loan not found'));
          }
          final theme = Theme.of(context);
          final paidAmount = loan.amount - loan.outstandingBalance;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(customerLoanDetailProvider(loanId));
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // Status & Loan Number
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        loan.loanNumber ?? 'Loan',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    StatusBadge(
                      label:
                          loan.status[0].toUpperCase() + loan.status.substring(1),
                      type: loan.status == 'active'
                          ? StatusType.active
                          : loan.status == 'completed' || loan.status == 'closed'
                              ? StatusType.completed
                              : StatusType.pending,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Progress
                GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Repayment Progress',
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '\u20b9${paidAmount.toStringAsFixed(0)} paid',
                            style: theme.textTheme.bodySmall,
                          ),
                          Text(
                            '\u20b9${loan.outstandingBalance.toStringAsFixed(0)} remaining',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      LinearProgressBar(
                        value: loan.paidPercentage / 100,
                        height: 10,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        progressColor: loan.isOverdue
                            ? Colors.red
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${loan.paidPercentage.toStringAsFixed(1)}% complete',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Loan details
                GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      _buildDetailRow(
                          context, 'Loan Amount', '\u20b9${loan.amount.toStringAsFixed(0)}'),
                      _buildDetailRow(context, 'Outstanding Balance',
                          '\u20b9${loan.outstandingBalance.toStringAsFixed(0)}'),
                      _buildDetailRow(context, 'EMI Amount',
                          '\u20b9${loan.emiAmount.toStringAsFixed(0)}'),
                      _buildDetailRow(context, 'Interest Rate',
                          '${loan.interestRate.toStringAsFixed(1)}%'),
                      _buildDetailRow(
                          context, 'Tenure', '${loan.tenureMonths} months'),
                      _buildDetailRow(
                          context, 'Frequency', loan.frequency.toUpperCase()),
                      if (loan.disbursementDate != null)
                        _buildDetailRow(
                            context,
                            'Disbursed On',
                            '${loan.disbursementDate!.day}/${loan.disbursementDate!.month}/${loan.disbursementDate!.year}'),
                      if (loan.purpose != null)
                        _buildDetailRow(context, 'Purpose', loan.purpose!),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // View EMI Schedule button
                FilledButton.icon(
                  onPressed: () =>
                      context.push('/customer/loans/$loanId/schedule'),
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: const Text('View EMI Schedule'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
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
