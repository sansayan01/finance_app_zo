import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/constants/layout.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/utils/formatters.dart';
import '../../../home/data/providers/dashboard_providers.dart';
import '../../data/models/transaction_model.dart';

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(recentTransactionsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline',
            style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(recentTransactionsProvider);
        },
        displacement: 20,
        color: theme.colorScheme.primary,
        backgroundColor: theme.cardColor,
        child: transactionsAsync.when(
          data: (transactions) {
            if (transactions.isEmpty) {
              return CustomScrollView(
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_rounded,
                              size: 64,
                              color: AppColors.textTertiaryLight
                                  .withValues(alpha: 0.2)),
                          const SizedBox(height: 16),
                          Text('No transactions found',
                              style: theme.textTheme.bodyLarge),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(
                  20, 20, 20, 20 + kBottomNavSafeArea),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final tx = transactions[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TransactionTimelineTile(transaction: tx),
                )
                    .animate()
                    .fadeIn(delay: (index * 50).ms)
                    .slideY(begin: 0.05, end: 0);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }
}

class _TransactionTimelineTile extends StatelessWidget {
  final TransactionModel transaction;
  const _TransactionTimelineTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDeposit = transaction.type == TransactionType.emiPayment ||
        transaction.type == TransactionType.savingsDeposit;
    final color = isDeposit
        ? (isDark ? AppColors.successDark : AppColors.success)
        : (isDark ? AppColors.errorDark : AppColors.error);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isDeposit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description ??
                      transaction.type.name.toUpperCase(),
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  AppFormatters.formatDateTime(transaction.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            AppFormatters.formatCurrency(transaction.amount),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
