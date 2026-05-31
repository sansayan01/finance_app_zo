import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/branding_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../../core/providers/sms_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../home/data/providers/dashboard_providers.dart' show dashboardLoansProvider, loanSummaryProvider, todayAgendaProvider;
import '../../../staff/data/providers/collection_providers.dart';
import '../../data/models/today_payment_model.dart';
import '../../data/providers/payment_providers.dart';
import '../../data/utils/payment_export.dart';
import '../../../loans/presentation/providers/loan_providers.dart';
import '../../../savings/data/providers/savings_providers.dart';

class TodayPaymentsPage extends ConsumerStatefulWidget {
  const TodayPaymentsPage({super.key});

  @override
  ConsumerState<TodayPaymentsPage> createState() => _TodayPaymentsPageState();
}

class _TodayPaymentsPageState extends ConsumerState<TodayPaymentsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref.read(paymentFilterProvider.notifier).setSearchQuery(query);
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(paymentFilterProvider.notifier).setSearchQuery('');
    setState(() => _showSearch = false);
  }

  Future<void> _pickDate() async {
    final filters = ref.read(paymentFilterProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: filters.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      ref.read(paymentFilterProvider.notifier).setDate(picked);
    }
  }

  void _showSortSheet() {
    final filters = ref.read(paymentFilterProvider);
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
                    ref.read(paymentFilterProvider.notifier).setSortBy(sort);
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
    final filters = ref.read(paymentFilterProvider);
    final branchesAsync = ref.read(paymentBranchesProvider);
    final agentsAsync = ref.read(paymentAgentsProvider);

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
                      ref.read(paymentFilterProvider.notifier).resetFilters();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Branch',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              branchesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (branches) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All Branches'),
                      selected: filters.branchId == null,
                      onSelected: (_) {
                        ref.read(paymentFilterProvider.notifier).setBranch(null);
                      },
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.primary,
                    ),
                    ...branches.map((b) => FilterChip(
                          label: Text(b['name']!),
                          selected: filters.branchId == b['id'],
                          onSelected: (_) {
                            ref
                                .read(paymentFilterProvider.notifier)
                                .setBranch(b['id']);
                          },
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          checkmarkColor: AppColors.primary,
                        )),
                  ],
                ),
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
                        ref.read(paymentFilterProvider.notifier).setAgent(null);
                      },
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.primary,
                    ),
                    ...agents.map((a) => FilterChip(
                          label: Text(a['name']!),
                          selected: filters.agentId == a['id'],
                          onSelected: (_) {
                            ref
                                .read(paymentFilterProvider.notifier)
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
                  onPressed: () => Navigator.pop(ctx),
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
    final filters = ref.read(paymentFilterProvider);
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
        content: Text(
            'Send payment reminder to ${payment.memberName}'
            '${payment.agentName != null ? ' and agent ${payment.agentName}' : ''}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
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
              NumberFormat.currency(symbol: '₹', decimalDigits: 0);

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
                            ? () => setSheetState(() {
                                  installmentCount--;
                                })
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
                            ? () => setSheetState(() {
                                  installmentCount++;
                                })
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
                      '$installmentCount × ${currencyFormat.format(payment.amountExpected)} = ${currencyFormat.format(payment.amountExpected * installmentCount)}',
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
                  readOnly: true,
                  controller: TextEditingController(
                      text: totalAmount().toStringAsFixed(0)),
                  keyboardType: TextInputType.none,
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
                        onTap: () =>
                            setSheetState(() => selectedMode = 'cash'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModeChip(
                        icon: Icons.qr_code_rounded,
                        label: 'UPI',
                        isSelected: selectedMode == 'upi',
                        onTap: () =>
                            setSheetState(() => selectedMode = 'upi'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModeChip(
                        icon: Icons.account_balance_rounded,
                        label: 'Bank',
                        isSelected: selectedMode == 'bank_transfer',
                        onTap: () =>
                            setSheetState(() => selectedMode = 'bank_transfer'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModeChip(
                        icon: Icons.receipt_rounded,
                        label: 'Cheque',
                        isSelected: selectedMode == 'cheque',
                        onTap: () =>
                            setSheetState(() => selectedMode = 'cheque'),
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
                                final amount = totalAmount();
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

                                  navigator.pop();
                                  messenger.showSnackBar(SnackBar(
                                    content: Text(
                                        '${installmentCount > 1 ? '$installmentCount installments · ' : ''}\u20b9${amount.toStringAsFixed(0)} collected from ${payment.memberName}'),
                                    backgroundColor: AppColors.success,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ));
                                  ref.invalidate(todayPaymentsProvider);
                                  try {
                                    ref.invalidate(todayCollectionsProvider);
                                    ref.invalidate(todayCollectionStatsProvider);
                                    ref.invalidate(todayDueEmisProvider);
                                    ref.invalidate(dashboardLoansProvider);
                                    ref.invalidate(loanSummaryProvider);
                                    ref.invalidate(todayStatsProvider);
                                    ref.invalidate(todayAgendaProvider);
                                    
                                    // Invalidate specific loan providers if loanId exists
                                    if (payment.loanId != null) {
                                      ref.invalidate(loansProvider);
                                      ref.invalidate(loanDetailProvider(payment.loanId!));
                                      ref.invalidate(emiScheduleProvider(payment.loanId!));
                                      ref.invalidate(paymentHistoryProvider(payment.loanId!));
                                    }
                                    
                                    // Invalidate savings providers
                                    if (payment.type == PaymentType.savings) {
                                      ref.invalidate(allSavingsProvider);
                                      ref.invalidate(savingsSummaryProvider);
                                      ref.invalidate(savingDetailProvider(payment.id));
                                      ref.invalidate(savingTransactionsProvider(payment.id));
                                      ref.invalidate(savingTxPagerProvider(payment.id));
                                    }
                                  } catch (_) {}
                                  } catch (e) {
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
                              : 'Collect ${currencyFormat.format(totalAmount())}',
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
    final client = Supabase.instance.client;
    final user = ref.read(currentUserProvider);
    if (user == null || user.orgId == null) {
      throw Exception('User not found');
    }

    final profile = await client
        .from('profiles')
        .select('id, full_name')
        .eq('user_id', user.id)
        .maybeSingle();
    final staffId = profile?['id'] as String?;
    if (staffId == null) {
      throw Exception('Staff profile not found');
    }
    final collectorName = profile?['full_name'] as String? ?? 'Admin';

    final now = DateTime.now();
    final today = now.toIso8601String().split('T').first;

    if (payment.type == PaymentType.savings) {
      // 1. Record collection log
      await client.from('savings_collections').insert({
        'org_id': user.orgId!,
        'savings_plan_id': payment.id,
        'member_id': payment.memberId,
        'member_name': payment.memberName,
        'member_phone': payment.memberPhone,
        'amount_expected': payment.amountExpected * installmentCount,
        'amount_collected': amount,
        'is_partial': amount < (payment.amountExpected * installmentCount),
        'payment_mode': paymentMode,
        'collection_date': today,
        'staff_id': staffId,
        'sync_status': 'synced',
      });

      // 2. Advance next_due_date by installmentCount periods
      final plan = await client
          .from('savings_plans')
          .select('collection_type, collection_day_of_week, collection_day_of_month, current_amount')
          .eq('id', payment.id)
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
      }).eq('id', payment.id);

      // 4. Transaction record
      await client.from('transactions').insert({
        'member_id': payment.memberId,
        'member_name': payment.memberName,
        'savings_id': payment.id,
        'amount': amount,
        'type': 'savingsDeposit',
        'payment_mode': paymentMode,
        'description': installmentCount > 1
            ? '$installmentCount installments deposited via $paymentMode'
            : 'Savings deposit via $paymentMode',
        'org_id': user.orgId!,
        'created_at': now.toIso8601String(),
      });

      // 5. Send SMS notification (non-blocking, fire-and-forget)
      _sendSavingsSms(
        memberPhone: payment.memberPhone,
        memberName: payment.memberName,
        memberId: payment.memberId,
        amount: amount,
        planName: payment.planName,
        newBalance: currentBalance + amount,
        staffId: staffId,
        collectorName: collectorName,
      );
    } else {
      // EMI Payment flow

      // 1. Record collection log
      await client.from('collections').insert({
        'org_id': user.orgId!,
        'staff_id': staffId,
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
        'sync_status': 'synced',
      });

      // 2. Mark EMIs as paid (handled by DB trigger on collection insert)
      // The trigger 'update_schedule_on_collection' automatically marks
      // the correct number of EMIs based on amount_collected.
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
        'org_id': user.orgId!,
        'created_at': now.toIso8601String(),
      });

      // 5. Send SMS notification (non-blocking, fire-and-forget)
      _sendEmiSms(
        memberPhone: payment.memberPhone,
        memberName: payment.memberName,
        memberId: payment.memberId,
        loanNumber: payment.loanNumber,
        amount: amount,
        outstandingBalance: null, // already updated above
        staffId: staffId,
        collectorName: collectorName,
      );
    }

    // Log activity for timeline (non-blocking)
    try {
      await client.from('activity_logs').insert({
        'org_id': user.orgId!,
        'staff_id': staffId,
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

  /// Sends SMS for savings deposit. Fire-and-forget, never blocks collection.
  void _sendSavingsSms({
    required String? memberPhone,
    required String memberName,
    required String? memberId,
    required double amount,
    required String? planName,
    required double newBalance,
    required String staffId,
    required String collectorName,
  }) async {
    try {
      if (memberPhone == null || memberPhone.isEmpty) {
        await _logSms(
          memberId: memberId,
          memberPhone: memberPhone ?? '',
          message: '',
          status: 'skipped',
          errorMessage: 'No phone number',
          staffId: staffId,
        );
        return;
      }

      final smsService = ref.read(smsServiceProvider);
      final branding = ref.read(brandingProvider).valueOrNull;
      final orgName = branding?.displayName ?? 'MicroFlow Finance';

      final message = smsService.buildSavingsSms(
        amount: '\u20b9${amount.toStringAsFixed(0)}',
        collectorName: collectorName,
        orgName: orgName,
        planName: planName,
        newBalance: newBalance,
        date: DateTime.now(),
      );

      final sent = await smsService.sendSms(
        phoneNumber: memberPhone,
        message: message,
      );

      await _logSms(
        memberId: memberId,
        memberPhone: memberPhone,
        message: message,
        status: sent ? 'sent' : 'failed',
        staffId: staffId,
        recipientName: memberName,
      );
    } catch (e) {
      debugPrint('Savings SMS error: $e');
      await _logSms(
        memberId: memberId,
        memberPhone: memberPhone ?? '',
        message: '',
        status: 'failed',
        errorMessage: e.toString(),
        staffId: staffId,
      );
    }
  }

  /// Sends SMS for EMI payment. Fire-and-forget, never blocks collection.
  void _sendEmiSms({
    required String? memberPhone,
    required String memberName,
    required String? memberId,
    required String? loanNumber,
    required double amount,
    required double? outstandingBalance,
    required String staffId,
    required String collectorName,
  }) async {
    try {
      if (memberPhone == null || memberPhone.isEmpty) {
        await _logSms(
          memberId: memberId,
          memberPhone: memberPhone ?? '',
          message: '',
          status: 'skipped',
          errorMessage: 'No phone number',
          staffId: staffId,
        );
        return;
      }

      final smsService = ref.read(smsServiceProvider);
      final branding = ref.read(brandingProvider).valueOrNull;
      final orgName = branding?.displayName ?? 'MicroFlow Finance';

      final balance = outstandingBalance != null
          ? '\u20b9${outstandingBalance.toStringAsFixed(0)}'
          : 'N/A';

      final message = smsService.buildCollectionSms(
        amount: '\u20b9${amount.toStringAsFixed(0)}',
        collectorName: collectorName,
        orgName: orgName,
        loanNumber: loanNumber ?? 'N/A',
        outstandingBalance: balance,
        date: DateTime.now(),
      );

      final sent = await smsService.sendSms(
        phoneNumber: memberPhone,
        message: message,
      );

      await _logSms(
        memberId: memberId,
        memberPhone: memberPhone,
        message: message,
        status: sent ? 'sent' : 'failed',
        staffId: staffId,
        recipientName: memberName,
      );
    } catch (e) {
      debugPrint('EMI SMS error: $e');
      await _logSms(
        memberId: memberId,
        memberPhone: memberPhone ?? '',
        message: '',
        status: 'failed',
        errorMessage: e.toString(),
        staffId: staffId,
      );
    }
  }

  /// Logs SMS to sms_notifications table for audit trail.
  Future<void> _logSms({
    String? memberId,
    required String memberPhone,
    required String message,
    required String status,
    String? errorMessage,
    required String staffId,
    String? recipientName,
  }) async {
    try {
      final client = Supabase.instance.client;
      final orgId = ref.read(currentOrgIdProvider);

      await client.from('sms_notifications').insert({
        'org_id': orgId,
        'member_id': memberId,
        'member_phone': memberPhone,
        'recipient_phone': memberPhone,
        'recipient_name': recipientName,
        'collector_name': staffId,
        'message': message,
        'status': status,
        'error_message': errorMessage,
        'sent_by': staffId,
      });
    } catch (e) {
      debugPrint('SMS log error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final paymentsAsync = ref.watch(todayPaymentsProvider);
    final filters = ref.watch(paymentFilterProvider);

    ref.watch(autoRefreshTimerProvider);

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
              onPressed: () => setState(() => _showSearch = true),
            ),
            IconButton(
              icon: Icon(
                Icons.filter_list_rounded,
                color: (filters.branchId != null || filters.agentId != null)
                    ? AppColors.primary
                    : null,
              ),
              onPressed: _showFilterSheet,
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
                  onTap: () => ref
                      .read(paymentFilterProvider.notifier)
                      .toggleAutoRefresh(),
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
                  onTap: () => ref.invalidate(todayPaymentsProvider),
                ),
              ],
            ),
          ],
        ],
      ),
      body: paymentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
                  onPressed: () => ref.invalidate(todayPaymentsProvider),
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
              // ─── Scrollable header ───
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSummaryHero(summary, isDark),
                      _buildQuickStats(summary, isDark),
                      if (filters.branchId != null ||
                          filters.agentId != null)
                        _buildActiveFilters(filters, isDark),
                      const SizedBox(height: 8),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.fillDark
                              : AppColors.fillLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          labelColor: Colors.white,
                          unselectedLabelColor: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          dividerColor: Colors.transparent,
                          labelStyle: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                          unselectedLabelStyle: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 13),
                          tabs: [
                            Tab(text: 'Pending (${pending.length})'),
                            Tab(text: 'Overdue (${overdue.length})'),
                            Tab(text: 'Collected (${collected.length})'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // ─── Tab content fills remaining space ───
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPaymentList(pending, isDark, 'No pending payments',
                        Icons.schedule_rounded),
                    _buildPaymentList(overdue, isDark, 'No overdue payments',
                        Icons.warning_amber_rounded),
                    _buildPaymentList(collected, isDark, 'No collections yet',
                        Icons.check_circle_outline_rounded),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: paymentsAsync.maybeWhen(
        data: (data) => FloatingActionButton.extended(
          onPressed: () => _showShareSheet(data),
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

  // ─── Summary Hero Card ───
  Widget _buildSummaryHero(TodayPaymentSummary summary, bool isDark) {
    final currencyFormat =
        NumberFormat.currency(symbol: '\u20b9', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.accent],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Due Today',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currencyFormat.format(summary.totalDue),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${summary.countDue} payments',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: summary.countDue > 0
                  ? summary.countCollected / summary.countDue
                  : 0,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${summary.countCollected} of ${summary.countDue} collected',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${summary.completionPercent}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Quick Stats Row ───
  Widget _buildQuickStats(TodayPaymentSummary summary, bool isDark) {
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
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon: Icons.warning_amber_rounded,
              label: 'Overdue',
              value: currencyFormat.format(summary.totalPending),
              count: '${summary.countOverdue}',
              color: AppColors.error,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Active Filters ───
  Widget _buildActiveFilters(PaymentFilterState filters, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_rounded,
              size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Filtered by: '
              '${filters.branchId != null ? 'Branch' : ''}'
              '${filters.branchId != null && filters.agentId != null ? ' + ' : ''}'
              '${filters.agentId != null ? 'Agent' : ''}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: () =>
                ref.read(paymentFilterProvider.notifier).resetFilters(),
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

  // ─── Payment List ───
  Widget _buildPaymentList(
      List<TodayPayment> payments, bool isDark, String emptyMessage, IconData emptyIcon) {
    if (payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(emptyIcon,
                  size: 48,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(todayPaymentsProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: payments.length,
        itemBuilder: (context, index) {
          final p = payments[index];
          return _PaymentCard(
            payment: p,
            isDark: isDark,
            onCall: p.memberPhone != null
                ? () => _makePhoneCall(p.memberPhone!)
                : null,
            onRemind: () => _sendReminder(p),
            onTap: () => _showPaymentDetails(p),
            onCollect: !p.isCollected
                ? () => _showQuickCollect(p)
                : null,

          );
        },
      ),
    );
  }

  Future<void> _makePhoneCall(String phone) async {
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
                    if (payment.branchName != null)
                      _DetailRow('Branch', payment.branchName!),
                    if (payment.agentName != null)
                      _DetailRow('Agent', payment.agentName!),
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

// ─── Stat Card ───
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String count;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.count,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.separatorDark : AppColors.separatorLight,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
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
    );
  }
}

// ─── Detail Row ───
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

// ─── Payment Card ───
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
                          onTap: onCall!,
                        ),
                      if (onCall != null) const SizedBox(width: 6),
                      _CompactAction(
                        icon: Icons.notifications_active_rounded,
                        color: AppColors.warning,
                        onTap: onRemind,
                      ),
                      if (onCollect != null) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: onCollect,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: AppColors.successGradient,
                              ),
                              borderRadius: BorderRadius.circular(8),
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
