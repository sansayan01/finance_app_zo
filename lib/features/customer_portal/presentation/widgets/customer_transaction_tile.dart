import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/customer_transaction_model.dart';

class CustomerTransactionTile extends StatelessWidget {
  final CustomerTransactionModel transaction;

  const CustomerTransactionTile({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isCredit = transaction.isCredit;
    final accentColor = isCredit ? AppColors.success : AppColors.orange;

    return Column(
      children: [
        InkWell(
          onTap: () {
            context.push(
              '/customer/receipt',
              extra: {
                'transactionId': transaction.id,
                'amount': transaction.amount,
                'type': transaction.type,
                'date': transaction.transactionDate ?? DateTime.now(),
                'memberName': transaction.memberName,
                'paymentMode': transaction.paymentMode,
                'referenceNumber': transaction.referenceNumber,
                'description': transaction.description,
                'status': transaction.status,
              },
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              children: [
                // Rounded square icon with gradient
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentColor.withValues(alpha: isDark ? 0.25 : 0.15),
                        accentColor.withValues(alpha: isDark ? 0.15 : 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
                    boxShadow: [
                      BoxShadow(
                        color:
                            accentColor.withValues(alpha: isDark ? 0.15 : 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getIcon(),
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                // Title + description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTitle(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (transaction.description != null &&
                          transaction.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            transaction.description!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                // Amount + date
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isCredit ? '+' : '-'}\u20b9${transaction.amount.toStringAsFixed(0)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (transaction.transactionDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          _formatDate(transaction.transactionDate!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Divider line
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Divider(
            height: 1,
            thickness: 0.5,
            color: isDark
                ? AppColors.separatorDark
                : AppColors.separatorLight,
          ),
        ),
      ],
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
