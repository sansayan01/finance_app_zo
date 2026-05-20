import 'package:flutter/material.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../data/models/customer_transaction_model.dart';

class CustomerTransactionTile extends StatelessWidget {
  final CustomerTransactionModel transaction;

  const CustomerTransactionTile({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCredit = transaction.isCredit;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isCredit ? Colors.green : Colors.orange)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            child: Icon(
              _getIcon(),
              color: isCredit ? Colors.green : Colors.orange,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTitle(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (transaction.description != null &&
                    transaction.description!.isNotEmpty)
                  Text(
                    transaction.description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color
                          ?.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'}\u20b9${transaction.amount.toStringAsFixed(0)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isCredit ? Colors.green : Colors.orange,
                ),
              ),
              if (transaction.transactionDate != null)
                Text(
                  _formatDate(transaction.transactionDate!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIcon() {
    return switch (transaction.type) {
      'emiPayment' => Icons.payment_rounded,
      'savingsDeposit' => Icons.savings_rounded,
      'savingsWithdrawal' => Icons.account_balance_rounded,
      'loanDisbursement' => Icons.money_rounded,
      'deposit' => Icons.add_circle_rounded,
      'withdrawal' => Icons.remove_circle_rounded,
      'penalty' => Icons.warning_rounded,
      _ => Icons.receipt_rounded,
    };
  }

  String _getTitle() {
    return switch (transaction.type) {
      'emiPayment' => 'EMI Payment',
      'savingsDeposit' => 'Savings Deposit',
      'savingsWithdrawal' => 'Savings Withdrawal',
      'loanDisbursement' => 'Loan Disbursement',
      'deposit' => 'Deposit',
      'withdrawal' => 'Withdrawal',
      'penalty' => 'Penalty',
      'collection' => 'Collection',
      _ => transaction.type[0].toUpperCase() + transaction.type.substring(1),
    };
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Today';
    if (dateOnly == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }
}
