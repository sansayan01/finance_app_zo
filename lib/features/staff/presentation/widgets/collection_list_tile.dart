import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/formatters.dart';

class CollectionListTile extends StatelessWidget {
  final Map<String, dynamic> emi;
  final VoidCallback? onTap;
  final VoidCallback? onQuickCollect;
  final bool isOverdue;
  final bool isPaid;
  final bool showQuickAction;

  const CollectionListTile({
    super.key,
    required this.emi,
    this.onTap,
    this.onQuickCollect,
    this.isOverdue = false,
    this.isPaid = false,
    this.showQuickAction = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final memberName = emi['member_name'] ?? emi['memberName'] ?? 'Unknown';
    final memberPhone = emi['member_phone'] ?? emi['memberPhone'] ?? '';
    final loanNumber = emi['loan_number'] ?? emi['loanNumber'] ?? '';
    final amount = (emi['emi'] ?? emi['amount'] ?? 0).toDouble();
    final area = emi['area'] ?? emi['member_area'] ?? '';
    final period = emi['period'] ?? 0;
    
    // Status color
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    if (isPaid) {
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle;
      statusText = 'Paid';
    } else if (isOverdue) {
      statusColor = AppColors.error;
      statusIcon = Icons.warning_amber;
      statusText = 'Overdue';
    } else {
      statusColor = AppColors.info;
      statusIcon = Icons.schedule;
      statusText = 'Due Today';
    }

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOverdue 
              ? statusColor.withValues(alpha: 0.3) 
              : theme.colorScheme.outline.withValues(alpha: 0.2),
          width: isOverdue ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              // Header row
              Row(
                children: [
                  // Status indicator
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      statusIcon,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  
                  // Member info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                memberName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (area.isNotEmpty) ...[
                              SizedBox(width: AppSpacing.xs),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  area,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              'Loan: $loanNumber',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (period > 0) ...[
                              SizedBox(width: AppSpacing.sm),
                              Text(
                                '•',
                                style: theme.textTheme.bodySmall,
                              ),
                              SizedBox(width: AppSpacing.sm),
                              Text(
                                'EMI #$period',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${AppFormatters.formatCompactCurrency(amount)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isPaid 
                              ? AppColors.success 
                              : (isOverdue ? AppColors.error : null),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        statusText,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              // Quick action button (if not paid and showing quick action)
              if (!isPaid && showQuickAction) ...[
                SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    // Phone button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: memberPhone.isNotEmpty
                            ? () async {
                                HapticFeedback.selectionClick();
                                final uri = Uri.parse('tel:$memberPhone');
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                }
                              }
                            : null,
                        icon: const Icon(Icons.phone_outlined, size: 18),
                        label: const Text('Call'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    
                    // Quick collect button
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: onQuickCollect,
                        icon: const Icon(Icons.payments_outlined, size: 18),
                        label: const Text('Collect'),
                        style: FilledButton.styleFrom(
                          backgroundColor: statusColor,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
