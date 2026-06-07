import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/sms_provider.dart';
import '../../../payments/data/models/today_payment_model.dart';
import '../../../payments/data/providers/payment_providers.dart' show TodayPaymentData;
import '../../../payments/data/utils/payment_export.dart';
import '../../../loans/presentation/providers/loan_providers.dart';
import '../../../branch_manager/data/providers/branch_payment_providers.dart';
import '../../data/providers/staff_branch_providers.dart';
import '../../data/providers/staff_providers.dart';

class StaffTodayPaymentsPage extends ConsumerStatefulWidget {
  const StaffTodayPaymentsPage({super.key});

  @override
  ConsumerState<StaffTodayPaymentsPage> createState() =>
      _StaffTodayPaymentsPageState();
}

class _StaffTodayPaymentsPageState
    extends ConsumerState<StaffTodayPaymentsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        HapticFeedback.selectionClick();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref.read(branchPaymentFilterProvider.notifier).setSearchQuery(query);
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(branchPaymentFilterProvider.notifier).setSearchQuery('');
    setState(() => _showSearch = false);
  }

  Future<void> _pickDate() async {
    final filters = ref.read(branchPaymentFilterProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: filters.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      HapticFeedback.selectionClick();
      ref.read(branchPaymentFilterProvider.notifier).setDate(picked);
    }
  }

  void _showSortSheet() {
    final filters = ref.read(branchPaymentFilterProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Sort By',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            ...PaymentSortBy.values.map((sort) => ListTile(
                  title: Text(sort.label),
                  trailing: filters.sortBy == sort
                      ? Icon(Icons.check_circle, color: AppColors.primary)
                      : null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(branchPaymentFilterProvider.notifier).setSortBy(sort);
                    Navigator.pop(ctx);
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet() {
    final filters = ref.read(branchPaymentFilterProvider);
    final branchId = ref.read(staffBranchIdProvider).valueOrNull;
    if (branchId == null) return;

    final agentsAsync = ref.read(branchPaymentAgentsProvider(branchId));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Filters',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(branchPaymentFilterProvider.notifier)
                          .resetFilters();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Agent',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              agentsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (agents) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All Agents'),
                      selected: filters.agentId == null,
                      onSelected: (_) {
                        ref
                            .read(branchPaymentFilterProvider.notifier)
                            .setAgent(null);
                      },
                      selectedColor:
                          AppColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.primary,
                    ),
                    ...agents.map((a) => FilterChip(
                          label: Text(a['name']!),
                          selected: filters.agentId == a['id'],
                          onSelected: (_) {
                            ref
                                .read(branchPaymentFilterProvider.notifier)
                                .setAgent(a['id']);
                          },
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          checkmarkColor: AppColors.primary,
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Apply Filters',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShareSheet(TodayPaymentData data) {
    final filters = ref.read(branchPaymentFilterProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Export & Share',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.share_rounded,
                    color: AppColors.primary, size: 20),
              ),
              title: const Text('Share Summary'),
              subtitle: const Text('Share text summary via any app'),
              onTap: () async {
                HapticFeedback.selectionClick();
                Navigator.pop(ctx);
                final text = PaymentExport.generateSummaryText(
                    data, filters.dateLabel);
                await SharePlus.instance.share(
                  ShareParams(
                    text: text,
                    subject: 'Payments - ${filters.dateLabel}',
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.table_chart_rounded,
                    color: AppColors.success, size: 20),
              ),
              title: const Text('Export CSV'),
              subtitle: const Text('Download payment data as CSV file'),
              onTap: () async {
                HapticFeedback.selectionClick();
                Navigator.pop(ctx);
                try {
                  await PaymentExport.shareCsv(
                      data.allPayments, filters.dateLabel);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Export failed: $e'),
                      backgroundColor: Colors.redAccent,
                    ));
                  }
                }
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.copy_rounded,
                    color: AppColors.info, size: 20),
              ),
              title: const Text('Copy Summary'),
              subtitle: const Text('Copy summary to clipboard'),
              onTap: () async {
                HapticFeedback.selectionClick();
                Navigator.pop(ctx);
                final text = PaymentExport.generateSummaryText(
                    data, filters.dateLabel);
                await Clipboard.setData(ClipboardData(text: text));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Summary copied to clipboard'),
                    backgroundColor: AppColors.success,
                  ));
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _sendReminder(TodayPayment payment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Send Reminder'),
        content: Text('Send payment reminder to ${payment.memberName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Reminder sent to ${payment.memberName}'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showQuickCollect(TodayPayment payment) {
    int installmentCount = 1;
    final amountController = TextEditingController(
        text: payment.amountExpected.toStringAsFixed(0));
    String selectedMode = 'cash';
    bool isSubmitting = false;
    int overdueCount = 0;
    bool hasCurrent = false;
    bool dataLoaded = false;

    Future<void> loadQuickCollectOverdue(StateSetter setSheetState) async {
      if (payment.type == PaymentType.emi && payment.loanId != null) {
        try {
          final schedule =
              await ref.read(emiScheduleProvider(payment.loanId!).future);
          final today = DateTime.now();
          final todayDate = DateTime(today.year, today.month, today.day);
          final unpaid =
              schedule.where((e) => e.status != EMIStatus.paid).toList();
          if (mounted) {
            setSheetState(() {
              overdueCount =
                  unpaid.where((e) => e.dueDate.isBefore(todayDate)).length;
              hasCurrent = unpaid.length > overdueCount;
            });
          }
        } catch (_) {}
      } else if (payment.type == PaymentType.savings) {
        if (mounted) {
          setSheetState(() {
            overdueCount = payment.isOverdue ? 1 : 0;
            hasCurrent = !payment.isOverdue;
          });
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final currencyFormat =
              NumberFormat.currency(symbol: '\u20b9', decimalDigits: 0);

          void updateAmount() {
            amountController.text =
                (payment.amountExpected * installmentCount).toStringAsFixed(0);
          }

          // Load overdue data on first build
          if (!dataLoaded) {
            dataLoaded = true;
            loadQuickCollectOverdue(setSheetState);
          }

          double totalAmount() =>
              installmentCount * payment.amountExpected;
          int overdueToPay() =>
              installmentCount < overdueCount
                  ? installmentCount
                  : overdueCount;
          int remainingAfterOverdue() =>
              installmentCount - overdueToPay();
          int currentToPay() =>
              remainingAfterOverdue() > 0 && hasCurrent ? 1 : 0;
          int advanceToPay() =>
              remainingAfterOverdue() - currentToPay();

          Widget buildDistRow(String label, String value, Color color,
              IconData? icon,
              {bool isTotal = false}) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: isTotal ? 13 : 12,
                      fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
                      color: isTotal ? Colors.black87 : Colors.grey.shade700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: isTotal ? 14 : 12,
                      fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom +
                  MediaQuery.of(ctx).padding.bottom +
                  20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: AppColors.successGradient,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.payment_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quick Collect',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${payment.memberName} \u00b7 ${payment.typeLabel}'
                            '${payment.loanNumber != null ? ' \u00b7 ${payment.loanNumber}' : ''}'
                            '${payment.planName != null ? ' \u00b7 ${payment.planName}' : ''}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Installment count selector
                const Text('Number of Installments',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: installmentCount > 1
                            ? () {
                                HapticFeedback.selectionClick();
                                setSheetState(() {
                                  installmentCount--;
                                  updateAmount();
                                });
                              }
                            : null,
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                        color: AppColors.primary,
                        disabledColor: Colors.grey.shade300,
                      ),
                      Column(
                        children: [
                          Text(
                            '$installmentCount',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            installmentCount == 1
                                ? 'installment'
                                : 'installments',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: installmentCount < 12
                            ? () {
                                HapticFeedback.selectionClick();
                                setSheetState(() {
                                  installmentCount++;
                                  updateAmount();
                                });
                              }
                            : null,
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        color: AppColors.primary,
                        disabledColor: Colors.grey.shade300,
                      ),
                    ],
                  ),
                ),
                if (installmentCount > 1) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '$installmentCount \u00d7 ${currencyFormat.format(payment.amountExpected)} = ${currencyFormat.format(payment.amountExpected * installmentCount)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Amount field
                const Text('Total Amount',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    prefixText: '\u20b9 ',
                    prefixStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                      fontSize: 20,
                    ),
                    hintText: 'Enter amount',
                    filled: true,
                    fillColor: AppColors.success.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppColors.success, width: 2),
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),

                // Payment distribution breakdown
                if (overdueToPay() > 0 ||
                    currentToPay() > 0 ||
                    advanceToPay() > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        const Text('Payment Distribution',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 12)),
                        const SizedBox(height: 10),
                        if (overdueToPay() > 0)
                          buildDistRow(
                              '${overdueToPay()} Overdue',
                              currencyFormat.format(
                                  overdueToPay() * payment.amountExpected),
                              AppColors.error,
                              Icons.warning_amber_rounded),
                        if (currentToPay() > 0)
                          buildDistRow(
                              '${currentToPay()} Current',
                              currencyFormat.format(
                                  currentToPay() * payment.amountExpected),
                              AppColors.warning,
                              Icons.schedule_rounded),
                        if (advanceToPay() > 0)
                          buildDistRow(
                              '${advanceToPay()} Advance',
                              currencyFormat.format(
                                  advanceToPay() * payment.amountExpected),
                              AppColors.info,
                              Icons.trending_up_rounded),
                        const Divider(height: 20),
                        buildDistRow(
                          'Total',
                          currencyFormat.format(totalAmount()),
                          AppColors.success,
                          null,
                          isTotal: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Payment mode
                const Text('Payment Mode',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ModeChip(
                        icon: Icons.money_rounded,
                        label: 'Cash',
                        isSelected: selectedMode == 'cash',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setSheetState(() => selectedMode = 'cash');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModeChip(
                        icon: Icons.qr_code_rounded,
                        label: 'UPI',
                        isSelected: selectedMode == 'upi',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setSheetState(() => selectedMode = 'upi');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModeChip(
                        icon: Icons.account_balance_rounded,
                        label: 'Bank',
                        isSelected: selectedMode == 'bank_transfer',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setSheetState(
                              () => selectedMode = 'bank_transfer');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModeChip(
                        icon: Icons.receipt_rounded,
                        label: 'Cheque',
                        isSelected: selectedMode == 'cheque',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setSheetState(() => selectedMode = 'cheque');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final amount = double.tryParse(
                                        amountController.text) ??
                                    0;
                                if (amount <= 0) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                    content: Text('Enter a valid amount'),
                                    backgroundColor: Colors.redAccent,
                                  ));
                                  return;
                                }

                                final navigator = Navigator.of(ctx);
                                final messenger = ScaffoldMessenger.of(context);

                                setSheetState(() => isSubmitting = true);

                                try {
                                  await _recordCollection(
                                    payment: payment,
                                    amount: amount,
                                    paymentMode: selectedMode,
                                    installmentCount: installmentCount,
                                  );

                                  HapticFeedback.heavyImpact();
                                  navigator.pop();
                                  messenger.showSnackBar(SnackBar(
                                    content: Text(
                                        '${installmentCount > 1 ? '$installmentCount installments \u00b7 ' : ''}\u20b9${amount.toStringAsFixed(0)} collected from ${payment.memberName}'),
                                    backgroundColor: AppColors.success,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ));
                                  final branchId = ref.read(currentStaffBranchIdProvider);
                                  if (branchId != null) {
                                    ref.invalidate(branchTodayPaymentsProvider(branchId));
                                  }
                                } catch (e) {
                                  HapticFeedback.heavyImpact();
                                  setSheetState(
                                      () => isSubmitting = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text('Collection failed: $e'),
                                      backgroundColor: Colors.redAccent,
                                    ));
                                  }
                                }
                              },
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_rounded,
                                size: 18),
                        label: Text(
                          isSubmitting
                              ? 'Processing...'
                              : 'Collect ${currencyFormat.format(double.tryParse(amountController.text) ?? 0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _recordCollection({
    required TodayPayment payment,
    required double amount,
    required String paymentMode,
    int installmentCount = 1,
  }) async {
    final client = ref.read(supabaseClientProvider);
    final profile = await ref.read(staffProfileProvider.future);
    if (profile == null) throw Exception('Staff profile not found');

    final now = DateTime.now();
    final today = now.toIso8601String().split('T').first;

    if (payment.type == PaymentType.savings) {
      final planId = payment.id.endsWith('_today')
          ? payment.id.substring(0, payment.id.length - 6)
          : payment.id;

      // 1. Create transaction FIRST so we can link it to the collection
      final txResult = await client.from('transactions').insert({
        'member_id': payment.memberId,
        'member_name': payment.memberName,
        'savings_id': planId,
        'amount': amount,
        'type': 'savingsDeposit',
        'payment_mode': paymentMode,
        'description': installmentCount > 1
            ? '$installmentCount installments deposited via $paymentMode'
            : 'Savings deposit via $paymentMode',
        'org_id': profile.orgId,
        'created_at': now.toIso8601String(),
      }).select('id').single();
      final transactionId = txResult['id'] as String;

      // 2. Record collection log (linked to transaction)
      await client.from('savings_collections').insert({
        'org_id': profile.orgId,
        'savings_plan_id': planId,
        'member_id': payment.memberId,
        'member_name': payment.memberName,
        'member_phone': payment.memberPhone,
        'amount_expected': payment.amountExpected * installmentCount,
        'amount_collected': amount,
        'is_partial': amount < (payment.amountExpected * installmentCount),
        'payment_mode': paymentMode,
        'collection_date': today,
        'staff_id': profile.id,
        'collected_by_name': profile.fullName,
        'collected_by_role': profile.role.dbValue,
        'sync_status': 'synced',
        'transaction_id': transactionId,
      });

      // 2. Advance next_due_date by installmentCount periods
      final plan = await client
          .from('savings_plans')
          .select('collection_type, collection_day_of_week, collection_day_of_month, current_amount')
          .eq('id', planId)
          .maybeSingle();

      DateTime nextDue;
      final collectionType = plan?['collection_type'] ?? 'daily';
      switch (collectionType) {
        case 'weekly':
          nextDue = now.add(Duration(days: 7 * installmentCount));
          break;
        case 'monthly':
          final targetDay = plan?['collection_day_of_month'] ?? now.day;
          final targetMonth = now.month + installmentCount;
          final targetYear = now.year + ((targetMonth - 1) ~/ 12);
          final adjustedMonth = ((targetMonth - 1) % 12) + 1;
          final daysInMonth = DateTime(targetYear, adjustedMonth + 1, 0).day;
          nextDue = DateTime(targetYear, adjustedMonth,
              targetDay > daysInMonth ? daysInMonth : targetDay);
          break;
        default: // daily
          nextDue = now.add(Duration(days: installmentCount));
      }

      final currentBalance =
          ((plan?['current_amount']) as num?)?.toDouble() ?? 0.0;

      // 3. Update savings plan
      await client.from('savings_plans').update({
        'next_due_date': nextDue.toIso8601String().split('T').first,
        'current_amount': currentBalance + amount,
        'updated_at': now.toIso8601String(),
      }).eq('id', planId);

      // 4. Send SMS notification (non-blocking, fire-and-forget)
      ref.read(collectionSmsSenderProvider.notifier).enqueueCollection(
        phone: payment.memberPhone,
        memberId: payment.memberId,
        memberName: payment.memberName,
        loanNumber: null,
        amount: amount,
        outstandingBalance: currentBalance + amount,
        collectorName: profile.fullName,
        sentBy: profile.id,
      );
    } else {
      // EMI Payment flow

      // 1. Record collection log
      await client.from('collections').insert({
        'org_id': profile.orgId,
        'staff_id': profile.id,
        'loan_id': payment.loanId,
        'member_id': payment.memberId,
        'member_name': payment.memberName,
        'member_phone': payment.memberPhone,
        'loan_number': payment.loanNumber,
        'amount_expected': payment.amountExpected * installmentCount,
        'amount_collected': amount,
        'is_partial': amount < (payment.amountExpected * installmentCount),
        'collection_type': 'emi',
        'payment_mode': paymentMode,
        'collection_date': today,
        'collection_time':
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
        'collected_by_name': profile.fullName,
        'collected_by_role': profile.role.dbValue,
        'sync_status': 'synced',
      });

      // 2. Mark EMIs as paid (handled by DB trigger on collection insert)
      // The trigger 'update_schedule_on_collection' automatically marks
      // the correct number of EMIs based on amount_collected.
      // No need to do it here — doing it twice causes double-marking.

      if (payment.loanId != null) {
        // 3. Update loan outstanding balance
        final loan = await client
            .from('loans')
            .select('outstanding_amount, outstanding_balance')
            .eq('id', payment.loanId!)
            .maybeSingle();

        if (loan != null) {
          final currentBalance = ((loan['outstanding_amount'] ??
                      loan['outstanding_balance']) as num?)
                  ?.toDouble() ??
              0.0;
          final newBalance =
              (currentBalance - amount).clamp(0.0, currentBalance);

          final updateData = <String, dynamic>{
            'outstanding_amount': newBalance,
            'outstanding_balance': newBalance,
            'updated_at': now.toIso8601String(),
          };

          if (newBalance <= 0) {
            updateData['status'] = 'closed';
            updateData['closed_date'] = today;
          }

          await client
              .from('loans')
              .update(updateData)
              .eq('id', payment.loanId!);
        }
      }

      // 4. Transaction record
      await client.from('transactions').insert({
        'loan_id': payment.loanId,
        'member_id': payment.memberId,
        'member_name': payment.memberName,
        'type': 'emiPayment',
        'amount': amount,
        'payment_mode': paymentMode,
        'description': installmentCount > 1
            ? '$installmentCount EMIs paid via $paymentMode'
            : 'EMI payment via $paymentMode',
        'org_id': profile.orgId,
        'created_at': now.toIso8601String(),
      });

      // 5. Send SMS notification (non-blocking, fire-and-forget)
      ref.read(collectionSmsSenderProvider.notifier).enqueueCollection(
        phone: payment.memberPhone,
        memberId: payment.memberId,
        memberName: payment.memberName,
        loanNumber: payment.loanNumber,
        amount: amount,
        outstandingBalance: 0.0,
        collectorName: profile.fullName,
        sentBy: profile.id,
      );
    }

    // Log activity for timeline (non-blocking)
    try {
      await client.from('activity_logs').insert({
        'org_id': profile.orgId,
        'staff_id': profile.id,
        'action': payment.type == PaymentType.savings
            ? 'savings_collection_recorded'
            : 'collection_recorded',
        'entity_type':
            payment.type == PaymentType.savings ? 'savings' : 'collection',
        'entity_id': payment.id,
        'details':
            'Collected Rs${amount.toStringAsFixed(0)} from ${payment.memberName}',
        'metadata': {
          'amount': amount,
          'member_name': payment.memberName,
          'payment_mode': paymentMode,
          'installment_count': installmentCount,
          'type': payment.type == PaymentType.savings ? 'savings' : 'emi',
        },
        'created_at': now.toIso8601String(),
      });
    } catch (e) {
      debugPrint('Failed to log activity: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final branchAsync = ref.watch(staffBranchIdProvider);

    if (branchAsync.isLoading) {
      return Scaffold(
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        appBar: AppBar(title: const Text('Today\'s Payments')),
        body: const _ShimmerLoading(),
      );
    }

    final branchId = branchAsync.valueOrNull;

    if (branchId == null) {
      return Scaffold(
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        appBar: AppBar(title: const Text('Today\'s Payments')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'No branch assigned to your profile.\nContact your admin to assign a branch.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final paymentsAsync = ref.watch(branchTodayPaymentsProvider(branchId));
    final filters = ref.watch(branchPaymentFilterProvider);

    // Auto-refresh timer
    ref.listen<BranchPaymentFilterState>(branchPaymentFilterProvider,
        (prev, next) {
      if (next.autoRefresh && next.isToday) {
        ref.watch(branchAutoRefreshTimerProvider);
      }
    });

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: _showSearch
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _clearSearch,
              )
            : null,
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search customer, phone, loan...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38),
                ),
                style:
                    TextStyle(color: isDark ? Colors.white : Colors.black),
              )
            : GestureDetector(
                onTap: _pickDate,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      filters.isToday
                          ? "Today's Payments"
                          : 'Payments - ${filters.dateLabel}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ],
                ),
              ),
        actions: [
          if (!_showSearch) ...[
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _showSearch = true);
              },
            ),
            IconButton(
              icon: Icon(
                Icons.filter_list_rounded,
                color: filters.agentId != null
                    ? AppColors.primary
                    : null,
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                _showFilterSheet();
              },
            ),
            PopupMenuButton(
              icon: const Icon(Icons.more_vert_rounded),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  child: ListTile(
                    leading: Icon(
                      filters.autoRefresh
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      size: 20,
                    ),
                    title: Text(filters.autoRefresh
                        ? 'Pause Auto-refresh'
                        : 'Enable Auto-refresh'),
                    dense: true,
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref
                        .read(branchPaymentFilterProvider.notifier)
                        .toggleAutoRefresh();
                  },
                ),
                PopupMenuItem(
                  child: const ListTile(
                    leading: Icon(Icons.sort_rounded, size: 20),
                    title: Text('Sort'),
                    dense: true,
                  ),
                  onTap: () =>
                      Future.delayed(Duration.zero, () => _showSortSheet()),
                ),
                PopupMenuItem(
                  child: const ListTile(
                    leading: Icon(Icons.refresh_rounded, size: 20),
                    title: Text('Refresh'),
                    dense: true,
                  ),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ref.invalidate(branchTodayPaymentsProvider(branchId));
                  },
                ),
              ],
            ),
          ],
        ],
      ),
      body: paymentsAsync.when(
        loading: () => const _ShimmerLoading(),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline,
                      size: 48, color: AppColors.error),
                ),
                const SizedBox(height: 16),
                Text('Something went wrong',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight)),
                const SizedBox(height: 8),
                Text('$e',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.invalidate(branchTodayPaymentsProvider(branchId));
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          final summary = data.summary;
          final pending = data.pendingPayments;
          final collected = data.collectedPayments;
          final overdue = data.overduePayments;

          return Column(
            children: [
              // Scrollable header
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSummaryHero(summary, isDark),
                      _buildQuickStats(summary, isDark, branchId),
                      if (filters.agentId != null) _buildActiveFilters(filters, isDark),
                      const SizedBox(height: 8),
                      _buildSegmentedTabs(pending.length, overdue.length, collected.length, isDark),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // Tab content fills remaining space
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPaymentList(pending, isDark, 'No pending payments',
                        'Everything is up to date!', Icons.schedule_rounded, AppColors.warning, branchId),
                    _buildPaymentList(overdue, isDark, 'No overdue payments',
                        'No one is behind schedule', Icons.warning_amber_rounded, AppColors.error, branchId),
                    _buildPaymentList(collected, isDark, 'No collections yet',
                        'Payments you collect will appear here', Icons.check_circle_outline_rounded, AppColors.success, branchId),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: paymentsAsync.maybeWhen(
        data: (data) => FloatingActionButton.extended(
          onPressed: () {
            HapticFeedback.lightImpact();
            _showShareSheet(data);
          },
          icon: const Icon(Icons.ios_share_rounded, size: 20),
          label: const Text('Export',
              style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        orElse: () => null,
      ),
    );
  }

  // Summary Hero Card — premium animated version
  Widget _buildSummaryHero(TodayPaymentSummary summary, bool isDark) {
    final currencyFormat =
        NumberFormat.currency(symbol: '\u20b9', decimalDigits: 0);
    final progress = summary.countDue > 0
        ? (summary.countCollected / summary.countDue).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.auroraGradient,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: label + amount
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'TODAY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Total Due Today',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _AnimatedCurrencyCounter(
                      value: summary.totalDue,
                      currencyFormat: currencyFormat,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.people_rounded,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${summary.countDue} payments',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right: circular progress ring
              _CircularProgressRing(
                progress: progress,
                centerText: '${summary.completionPercent}%',
                subtext: 'done',
                size: 92,
                strokeWidth: 8,
                trackColor: Colors.white.withValues(alpha: 0.2),
                progressColor: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${summary.countCollected} of ${summary.countDue} collected',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.payments_rounded,
                        color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      currencyFormat.format(summary.totalCollected),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, curve: Curves.easeOut)
        .slideY(
            begin: -0.05,
            end: 0,
            duration: 400.ms,
            curve: Curves.easeOutCubic);
  }

  // Quick Stats Row — tappable to switch tabs
  Widget _buildQuickStats(
      TodayPaymentSummary summary, bool isDark, String branchId) {
    final currencyFormat =
        NumberFormat.currency(symbol: '\u20b9', decimalDigits: 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.check_circle_rounded,
              label: 'Collected',
              value: currencyFormat.format(summary.totalCollected),
              count: '${summary.countCollected}',
              color: AppColors.success,
              isDark: isDark,
              index: 2,
              tabController: _tabController,
              delayMs: 0,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon: Icons.schedule_rounded,
              label: 'Pending',
              value: currencyFormat.format(summary.totalPending),
              count: '${summary.countPending}',
              color: AppColors.warning,
              isDark: isDark,
              index: 0,
              tabController: _tabController,
              delayMs: 60,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon: Icons.warning_amber_rounded,
              label: 'Overdue',
              value: currencyFormat.format(summary.totalOverdue),
              count: '${summary.countOverdue}',
              color: AppColors.error,
              isDark: isDark,
              index: 1,
              tabController: _tabController,
              delayMs: 120,
            ),
          ),
        ],
      ),
    );
  }

  // Premium Segmented Tab Bar
  Widget _buildSegmentedTabs(
      int pendingCount, int overdueCount, int collectedCount, bool isDark) {
    final tabs = [
      _TabInfo('Pending', pendingCount, Icons.schedule_rounded, AppColors.warning),
      _TabInfo('Overdue', overdueCount, Icons.warning_amber_rounded, AppColors.error),
      _TabInfo('Collected', collectedCount, Icons.check_circle_rounded, AppColors.success),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.fillDark : AppColors.fillLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: isDark
            ? AppColors.textTertiaryDark
            : AppColors.textTertiaryLight,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.premiumGradient,
          ),
          borderRadius: BorderRadius.circular(11),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        dividerColor: Colors.transparent,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 12.5),
        tabs: tabs.map((t) {
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(t.icon, size: 14),
                const SizedBox(width: 6),
                Text('${t.label} (${t.count})'),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Active Filters
  Widget _buildActiveFilters(BranchPaymentFilterState filters, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_rounded,
              size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Filtered by: Agent',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: () =>
                ref.read(branchPaymentFilterProvider.notifier).resetFilters(),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Clear',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Payment List — with staggered animations and swipe actions
  Widget _buildPaymentList(
      List<TodayPayment> payments, bool isDark, String emptyTitle,
      String emptySubtitle, IconData emptyIcon, Color emptyColor,
      String branchId) {
    if (payments.isEmpty) {
      return _AnimatedEmptyState(
        title: emptyTitle,
        subtitle: emptySubtitle,
        icon: emptyIcon,
        color: emptyColor,
        isDark: isDark,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.lightImpact();
        ref.invalidate(branchTodayPaymentsProvider(branchId));
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: payments.length,
        itemBuilder: (context, index) {
          final payment = payments[index];
          final card = _PaymentCard(
            payment: payment,
            isDark: isDark,
            onCall: payment.memberPhone != null
                ? () => _makePhoneCall(payment.memberPhone!)
                : null,
            onRemind: () => _sendReminder(payment),
            onTap: () => _showPaymentDetails(payment),
            onCollect: !payment.isCollected
                ? () => _showQuickCollect(payment)
                : null,
          );

          // Stagger animation
          final animatedCard = card
              .animate(delay: Duration(milliseconds: index * 35))
              .fadeIn(duration: 350.ms, curve: Curves.easeOut)
              .slideY(
                begin: 0.08,
                end: 0,
                duration: 350.ms,
                curve: Curves.easeOutCubic,
              );

          // Swipe-to-action (only for uncollected items)
          if (payment.isCollected) return animatedCard;
          return Dismissible(
            key: ValueKey('pay_${payment.id}'),
            direction: DismissDirection.horizontal,
            confirmDismiss: (_) async => false, // never auto-dismiss
            background: _buildSwipeBackground(
              isDark,
              payment.memberPhone != null
                  ? Icons.call_rounded
                  : Icons.notifications_active_rounded,
              payment.memberPhone != null ? 'Call' : 'Remind',
              payment.memberPhone != null
                  ? AppColors.success
                  : AppColors.warning,
              Alignment.centerLeft,
            ),
            secondaryBackground: _buildSwipeBackground(
              isDark,
              Icons.payment_rounded,
              'Collect',
              AppColors.primary,
              Alignment.centerRight,
            ),
            onUpdate: (details) {
              if (details.progress > 0.3 &&
                  details.progress < 0.35) {
                HapticFeedback.selectionClick();
              }
            },
            child: animatedCard,
          );
        },
      ),
    );
  }

  Widget _buildSwipeBackground(
      bool isDark, IconData icon, String label, Color color, Alignment align) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: align,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: align == Alignment.centerRight
            ? [
                Text(label,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                Icon(icon, color: color, size: 20),
              ]
            : [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w700)),
              ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phone) async {
    HapticFeedback.lightImpact();
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not launch phone dialer'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  void _showPaymentDetails(TodayPayment payment) {
    final currencyFormat =
        NumberFormat.currency(symbol: '\u20b9', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: payment.typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(payment.typeIcon,
                        color: payment.typeColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment.memberName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: payment.statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            payment.statusLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: payment.statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    currencyFormat.format(payment.amountExpected),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: payment.statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _DetailRow('Type', payment.typeLabel),
                    if (payment.loanNumber != null)
                      _DetailRow('Loan Number', payment.loanNumber!),
                    if (payment.emiNumber != null)
                      _DetailRow('EMI Number', '#${payment.emiNumber}'),
                    if (payment.planName != null)
                      _DetailRow('Savings Plan', payment.planName!),
                    _DetailRow('Due Date', dateFormat.format(payment.dueDate)),
                    if (payment.isOverdue)
                      _DetailRow('Overdue', payment.overdueLabel,
                          valueColor: Colors.red),
                    if (payment.penaltyAmount > 0)
                      _DetailRow('Penalty',
                          currencyFormat.format(payment.penaltyAmount),
                          valueColor: Colors.red),
                    if (payment.memberPhone != null)
                      _DetailRow('Phone', payment.memberPhone!),
                    if (payment.paymentMode != null)
                      _DetailRow(
                          'Payment Mode', payment.paymentMode!.toUpperCase()),
                    if (payment.collectedAt != null)
                      _DetailRow(
                          'Collected At',
                          DateFormat('dd MMM yyyy, hh:mm a')
                              .format(payment.collectedAt!)),
                    if (payment.remarks != null &&
                        payment.remarks!.isNotEmpty)
                      _DetailRow('Remarks', payment.remarks!),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  if (payment.memberPhone != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(ctx);
                          _makePhoneCall(payment.memberPhone!);
                        },
                        icon: const Icon(Icons.call_rounded, size: 18),
                        label: const Text('Call'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  if (payment.memberPhone != null && !payment.isCollected)
                    const SizedBox(width: 10),
                  if (!payment.isCollected)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(ctx);
                          _sendReminder(payment);
                        },
                        icon: const Icon(Icons.notifications_active_rounded,
                            size: 18),
                        label: const Text('Remind'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
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
}

// Tappable Stat Card with active-state styling and stagger animation
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String count;
  final Color color;
  final bool isDark;
  final int index;
  final TabController tabController;
  final int delayMs;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.count,
    required this.color,
    required this.isDark,
    required this.index,
    required this.tabController,
    required this.delayMs,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tabController,
      builder: (context, _) {
        final isActive = tabController.index == index;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            tabController.animateTo(index);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isActive
                  ? color.withValues(alpha: 0.12)
                  : (isDark ? AppColors.cardDark : AppColors.cardLight),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive
                    ? color.withValues(alpha: 0.4)
                    : (isDark
                        ? AppColors.separatorDark
                        : AppColors.separatorLight),
                width: isActive ? 1.5 : 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 14, color: color),
                    ),
                    const Spacer(),
                    Text(
                      count,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    )
        .animate(delay: Duration(milliseconds: 100 + delayMs))
        .fadeIn(duration: 350.ms, curve: Curves.easeOut)
        .slideY(
            begin: 0.15,
            end: 0,
            duration: 350.ms,
            curve: Curves.easeOutCubic);
  }
}

// Detail Row
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.grey.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Payment Card
class _PaymentCard extends StatelessWidget {
  final TodayPayment payment;
  final bool isDark;
  final VoidCallback? onCall;
  final VoidCallback onRemind;
  final VoidCallback onTap;
  final VoidCallback? onCollect;

  const _PaymentCard({
    required this.payment,
    required this.isDark,
    this.onCall,
    required this.onRemind,
    required this.onTap,
    this.onCollect,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(symbol: '\u20b9', decimalDigits: 0);
    final timeFormat = DateFormat('hh:mm a');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.separatorDark : AppColors.separatorLight,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  // Left icon
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: payment.typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      payment.typeIcon,
                      color: payment.typeColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Middle content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                payment.memberName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: payment.statusColor
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                payment.statusLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: payment.statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${payment.typeLabel}'
                          '${payment.loanNumber != null ? ' \u00b7 ${payment.loanNumber}' : ''}'
                          '${payment.emiNumber != null ? ' #${payment.emiNumber}' : ''}'
                          '${payment.planName != null ? ' \u00b7 ${payment.planName}' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Right: amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currencyFormat.format(payment.amountExpected),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: payment.statusColor,
                        ),
                      ),
                      if (payment.penaltyAmount > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          '+${currencyFormat.format(payment.penaltyAmount)} penalty',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                      if (payment.isCollected &&
                          payment.collectedAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          timeFormat.format(payment.collectedAt!),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              // Overdue + action buttons
              if (payment.isOverdue || !payment.isCollected) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (payment.isOverdue)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time_rounded,
                                size: 12, color: AppColors.error),
                            const SizedBox(width: 4),
                            Text(
                              payment.overdueLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    if (!payment.isCollected) ...[
                      if (onCall != null)
                        _CompactAction(
                          icon: Icons.call_rounded,
                          color: AppColors.success,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            onCall!();
                          },
                        ),
                      if (onCall != null) const SizedBox(width: 6),
                      _CompactAction(
                        icon: Icons.notifications_active_rounded,
                        color: AppColors.warning,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onRemind();
                        },
                      ),
                      if (onCollect != null) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            onCollect!();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: AppColors.successGradient,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.success
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.payment_rounded,
                                    size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Collect',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
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

class _CompactAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CompactAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.success.withValues(alpha: 0.12)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.success : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.success : Colors.grey.shade600,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.success : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PREMIUM HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _TabInfo {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  _TabInfo(this.label, this.count, this.icon, this.color);
}

// Animated currency counter that tweens from 0 to value
class _AnimatedCurrencyCounter extends StatelessWidget {
  final double value;
  final NumberFormat currencyFormat;
  final TextStyle style;
  const _AnimatedCurrencyCounter({
    required this.value,
    required this.currencyFormat,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return Text(
          currencyFormat.format(v),
          style: style,
        );
      },
    );
  }
}

// Circular progress ring with animated arc and center label
class _CircularProgressRing extends StatelessWidget {
  final double progress;
  final String centerText;
  final String subtext;
  final double size;
  final double strokeWidth;
  final Color trackColor;
  final Color progressColor;

  const _CircularProgressRing({
    required this.progress,
    required this.centerText,
    required this.subtext,
    this.size = 80,
    this.strokeWidth = 7,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, p, _) {
              return SizedBox(
                width: size,
                height: size,
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: p,
                    strokeWidth: strokeWidth,
                    trackColor: trackColor,
                    progressColor: progressColor,
                  ),
                ),
              );
            },
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerText,
                style: TextStyle(
                  color: progressColor,
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtext,
                style: TextStyle(
                  color: progressColor.withValues(alpha: 0.7),
                  fontSize: size * 0.11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final Color progressColor;

  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        rect,
        -3.14159 / 2, // start at top
        progress * 2 * 3.14159,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.progressColor != progressColor ||
      old.trackColor != trackColor;
}

// Shimmer loading state
class _ShimmerLoading extends StatelessWidget {
  const _ShimmerLoading();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppColors.fillDark : Colors.grey.shade300;
    final highlight = isDark ? AppColors.elevatedDark : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(
              3,
              (i) => Expanded(
                child: Container(
                  height: 90,
                  margin: EdgeInsets.only(right: i < 2 ? 10 : 0),
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(
            4,
            (i) => Container(
              height: 100,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Animated empty state with pulsing icon
class _AnimatedEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _AnimatedEmptyState({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.12),
                    color.withValues(alpha: 0.04),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: 0.15),
                  width: 2,
                ),
              ),
              child:
                  Icon(icon, size: 56, color: color.withValues(alpha: 0.7)),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  duration: 1800.ms,
                  begin: const Offset(1, 1),
                  end: const Offset(1.06, 1.06),
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 500.ms, curve: Curves.easeOut)
          .slideY(
              begin: 0.1,
              end: 0,
              duration: 500.ms,
              curve: Curves.easeOutCubic),
    );
  }
}
