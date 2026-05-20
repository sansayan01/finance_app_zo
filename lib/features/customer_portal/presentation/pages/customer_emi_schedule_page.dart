import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../data/providers/customer_loans_providers.dart';
import '../widgets/customer_emi_tile.dart';
import '../widgets/customer_empty_state.dart';

class CustomerEmiSchedulePage extends ConsumerWidget {
  final String loanId;

  const CustomerEmiSchedulePage({super.key, required this.loanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emiAsync = ref.watch(customerEmiScheduleProvider(loanId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('EMI Schedule'),
      ),
      body: emiAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (emis) {
          if (emis.isEmpty) {
            return const CustomerEmptyState(
              icon: Icons.calendar_month_rounded,
              title: 'No EMIs',
              subtitle: 'No EMI schedule found for this loan.',
            );
          }

          final paidCount = emis.where((e) => e.isPaid).length;
          final totalPaid =
              emis.where((e) => e.isPaid).fold(0.0, (s, e) => s + e.amountPaid);
          final totalRemaining = emis
              .where((e) => !e.isPaid)
              .fold(0.0, (s, e) => s + e.emiAmount);

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(customerEmiScheduleProvider(loanId)),
            child: CustomScrollView(
              slivers: [
                // Summary card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(AppSpacing.lg),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryItem(
                              context, 'Paid', '$paidCount/${emis.length}'),
                          _buildSummaryItem(context, 'Total Paid',
                              '\u20b9${totalPaid.toStringAsFixed(0)}'),
                          _buildSummaryItem(context, 'Remaining',
                              '\u20b9${totalRemaining.toStringAsFixed(0)}'),
                        ],
                      ),
                    ),
                  ),
                ),

                // Header row
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 32),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          flex: 2,
                          child: Text('Due Date',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                          child: Text('Amount',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600),
                              textAlign: TextAlign.right),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        const SizedBox(width: 70),
                      ],
                    ),
                  ),
                ),

                // EMI list
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => CustomerEmiTile(emi: emis[index]),
                    childCount: emis.length,
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xl),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
