import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/customer_emi_model.dart';
import '../../data/providers/customer_loans_providers.dart';
import '../../../payments/presentation/widgets/upi_payment_sheet.dart';

class CustomerLoanQuickPayPage extends ConsumerStatefulWidget {
  final String loanId;
  const CustomerLoanQuickPayPage({super.key, required this.loanId});
  @override
  ConsumerState<CustomerLoanQuickPayPage> createState() =>
      _CustomerLoanQuickPayPageState();
}

class _CustomerLoanQuickPayPageState
    extends ConsumerState<CustomerLoanQuickPayPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _installmentCount = 1;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<CustomerEmiModel> _unpaidEmis(List<CustomerEmiModel> emis) {
    return emis.where((e) => !e.isPaid).toList()
      ..sort((a, b) => a.emiNumber.compareTo(b.emiNumber));
  }

  void _applyQuickPay(List<CustomerEmiModel> unpaid, int count) {
    final take = math.min(count, unpaid.length);
    final selected = unpaid.take(take).toList();
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(selected.map((e) => e.id));
      _installmentCount = count;
    });
  }

  @override
  Widget build(BuildContext context) {
    final emisAsync = ref.watch(customerEmiScheduleProvider(widget.loanId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay via UPI'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.bolt_rounded, size: 18), text: 'Quick Pay'),
            Tab(icon: Icon(Icons.checklist_rounded, size: 18), text: 'Choose Dates'),
          ],
        ),
      ),
      body: emisAsync.when(
        data: (emis) {
          final unpaid = _unpaidEmis(emis);
          if (unpaid.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('All EMIs are paid!', style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          final emiAmount = unpaid.first.emiAmount;

          // Sync selected IDs with current unpaid list
          _selectedIds.removeWhere((id) => !unpaid.any((e) => e.id == id));
          if (_tabController.index == 0) {
            // Quick Pay mode — sync count
            if (_installmentCount > unpaid.length) {
              _installmentCount = unpaid.length;
            }
            _applyQuickPay(unpaid, _installmentCount);
          }

          return Column(
            children: [
              // Header summary
              _buildHeader(emiAmount, unpaid.length, emis.length),
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildQuickPayTab(unpaid, emiAmount),
                    _buildChooseDatesTab(unpaid),
                  ],
                ),
              ),
              // Bottom bar
              _buildBottomBar(),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildHeader(double emiAmount, int unpaidCount, int totalCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹${emiAmount.toStringAsFixed(0)} / EMI',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$unpaidCount of $totalCount installments remaining',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPayTab(List<CustomerEmiModel> unpaid, double emiAmount) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Counter
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCounterButton(
                    icon: Icons.remove_rounded,
                    onTap: _installmentCount > 1
                        ? () {
                            HapticFeedback.selectionClick();
                            _applyQuickPay(unpaid, _installmentCount - 1);
                          }
                        : null,
                  ),
                  const SizedBox(width: 24),
                  Text(
                    '$_installmentCount',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 24),
                  _buildCounterButton(
                    icon: Icons.add_rounded,
                    onTap: _installmentCount < unpaid.length
                        ? () {
                            HapticFeedback.selectionClick();
                            _applyQuickPay(unpaid, _installmentCount + 1);
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'EMI${_installmentCount > 1 ? 's' : ''}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          // Breakdown
          _buildBreakdown(unpaid),
        ],
      ),
    );
  }

  Widget _buildChooseDatesTab(List<CustomerEmiModel> unpaid) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: unpaid.length,
      itemBuilder: (context, index) {
        final emi = unpaid[index];
        final isSelected = _selectedIds.contains(emi.id);
        final isOverdue = emi.isOverdue;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Checkbox(
              value: isSelected,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedIds.add(emi.id);
                  } else {
                    _selectedIds.remove(emi.id);
                  }
                });
              },
              activeColor: AppColors.primary,
            ),
            title: Text(
              'EMI #${emi.emiNumber}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              emi.dueDate != null ? DateFormat('dd MMM yyyy').format(emi.dueDate!) : 'N/A',
              style: TextStyle(
                color: isOverdue ? Colors.red : Colors.grey[600],
                fontSize: 13,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isOverdue)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Overdue', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w600)),
                  ),
                Text(
                  '₹${emi.emiAmount.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBreakdown(List<CustomerEmiModel> unpaid) {
    final overdue = unpaid.where((e) => e.isOverdue).length;
    final dueToday = unpaid.where((e) {
      if (e.dueDate == null || e.isPaid) return false;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final due = DateTime(e.dueDate!.year, e.dueDate!.month, e.dueDate!.day);
      return due == today;
    }).length;

    final overdueToPay = math.min(_installmentCount, overdue);
    final todayToPay = math.min(math.max(_installmentCount - overdueToPay, 0), dueToday);
    final advanceToPay = math.max(_installmentCount - overdueToPay - todayToPay, 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payment Breakdown', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        if (overdueToPay > 0)
          _buildBreakdownRow(Icons.warning_amber_rounded, Colors.red, 'Overdue EMIs', overdueToPay),
        if (todayToPay > 0)
          _buildBreakdownRow(Icons.schedule_rounded, AppColors.orange, "Today's EMI", todayToPay),
        if (advanceToPay > 0)
          _buildBreakdownRow(Icons.fast_forward_rounded, AppColors.primary, 'Advance EMIs', advanceToPay),
      ],
    );
  }

  Widget _buildBreakdownRow(IconData icon, Color color, String label, int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          Text('₹${(count * (ref.read(customerEmiScheduleProvider(widget.loanId)).value?.first.emiAmount ?? 0)).toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildCounterButton({required IconData icon, VoidCallback? onTap}) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: enabled ? AppColors.primary : Colors.grey[200],
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(icon, size: 28, color: enabled ? Colors.white : Colors.grey),
      ),
    );
  }

  Widget _buildBottomBar() {
    final emisAsync = ref.watch(customerEmiScheduleProvider(widget.loanId));
    final emis = emisAsync.value ?? [];
    final unpaid = _unpaidEmis(emis);
    final emiAmount = unpaid.isNotEmpty ? unpaid.first.emiAmount : 0.0;
    final totalSelected = _selectedIds.length * emiAmount;
    final count = _selectedIds.length;
    final isEnabled = count > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Selected: $count · ₹${totalSelected.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isEnabled ? AppColors.primary : Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isEnabled ? _openUpiPayment : null,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text('Pay ₹${totalSelected.toStringAsFixed(0)} via UPI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openUpiPayment() {
    final emisAsync = ref.read(customerEmiScheduleProvider(widget.loanId));
    final emis = emisAsync.value ?? [];
    final unpaid = _unpaidEmis(emis);
    final selectedEmis = unpaid.where((e) => _selectedIds.contains(e.id)).toList();
    final totalAmount = selectedEmis.fold<double>(0, (sum, e) => sum + e.emiAmount);
    final emiIds = selectedEmis.map((e) => e.id).toList();
    final emiAmounts = selectedEmis.map((e) => e.emiAmount).toList();
    final emiNumbers = selectedEmis.map((e) => e.emiNumber).toList();

    final note = 'EMI #${emiNumbers.join(", ")} · ₹${totalAmount.toStringAsFixed(0)}';

    HapticFeedback.lightImpact();
    UpiPaymentSheet.show(
      context,
      amount: totalAmount,
      loanId: widget.loanId,
      emiScheduleIds: emiIds,
      emiAmounts: emiAmounts,
      transactionNoteOverride: note,
    );
  }
}
