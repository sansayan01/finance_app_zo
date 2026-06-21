import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/customer_savings_model.dart';
import '../../data/providers/customer_savings_providers.dart';
import '../../../payments/presentation/widgets/upi_payment_sheet.dart';

/// Simple installment item for the savings quick pay page.
class _SavingsInst {
  final int number;
  final DateTime dueDate;
  final bool isPaid;
  final double amount;
  final String dateKey; // YYYY-MM-DD

  const _SavingsInst({
    required this.number,
    required this.dueDate,
    required this.isPaid,
    required this.amount,
    required this.dateKey,
  });
}

class CustomerSavingsQuickPayPage extends ConsumerStatefulWidget {
  final String savingsPlanId;
  const CustomerSavingsQuickPayPage({super.key, required this.savingsPlanId});
  @override
  ConsumerState<CustomerSavingsQuickPayPage> createState() =>
      _CustomerSavingsQuickPayPageState();
}

class _CustomerSavingsQuickPayPageState
    extends ConsumerState<CustomerSavingsQuickPayPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _installmentCount = 1;
  final Set<String> _selectedDateKeys = {};

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

  /// Generate installment list from plan data.
  /// Since CustomerSavingsModel doesn't have startDate, we use maturityDate
  /// and tenureMonths to generate installments going backwards from maturity.
  List<_SavingsInst> _generateInstallments(CustomerSavingsModel plan) {
    final installments = <_SavingsInst>[];
    final maturity = plan.maturityDate;
    final total = plan.tenureMonths ?? 12;
    final amount = plan.monthlyDeposit;
    final collectionType = plan.collectionType;

    if (maturity == null || amount <= 0 || total <= 0) return installments;

    // Calculate start date = maturity minus total period
    DateTime startDate;
    switch (collectionType) {
      case 'daily':
        startDate = maturity.subtract(Duration(days: total));
        break;
      case 'weekly':
        startDate = maturity.subtract(Duration(days: total * 7));
        break;
      case 'monthly':
      default:
        int startMonth = maturity.month - total;
        int startYear = maturity.year + ((startMonth - 1) ~/ 12);
        startMonth = ((startMonth - 1) % 12) + 1;
        int startDay = maturity.day;
        int daysInStartMonth = DateTime(startYear, startMonth + 1, 0).day;
        if (startDay > daysInStartMonth) startDay = daysInStartMonth;
        startDate = DateTime(startYear, startMonth, startDay);
        break;
    }

    DateTime currentDate = startDate;
    int number = 1;

    while (number <= total && !currentDate.isAfter(maturity)) {
      final dateKey =
          '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';

      installments.add(_SavingsInst(
        number: number,
        dueDate: currentDate,
        isPaid: false,
        amount: amount,
        dateKey: dateKey,
      ));

      // Advance to next date
      switch (collectionType) {
        case 'weekly':
          currentDate = currentDate.add(const Duration(days: 7));
          break;
        case 'monthly':
          int targetMonth = currentDate.month + 1;
          int targetYear = currentDate.year + ((targetMonth - 1) ~/ 12);
          targetMonth = ((targetMonth - 1) % 12) + 1;
          int targetDay = currentDate.day;
          int daysInTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
          if (targetDay > daysInTargetMonth) targetDay = daysInTargetMonth;
          currentDate = DateTime(targetYear, targetMonth, targetDay);
          break;
        default:
          currentDate = currentDate.add(const Duration(days: 1));
      }
      number++;
    }

    return installments;
  }

  List<_SavingsInst> _unpaid(List<_SavingsInst> all) =>
      all.where((i) => !i.isPaid).toList();

  void _applyQuickPay(List<_SavingsInst> unpaid, int count) {
    final take = math.min(count, unpaid.length);
    final selected = unpaid.take(take).toList();
    setState(() {
      _selectedDateKeys
        ..clear()
        ..addAll(selected.map((e) => e.dateKey));
      _installmentCount = count;
    });
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(customerSavingsDetailProvider(widget.savingsPlanId));

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
      body: planAsync.when(
        data: (plan) {
          if (plan == null) {
            return const Center(child: Text('Savings plan not found'));
          }

          final all = _generateInstallments(plan);
          final unpaid = _unpaid(all);

          if (unpaid.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('All installments are paid!', style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          // Sync
          _selectedDateKeys.removeWhere((dk) => !unpaid.any((i) => i.dateKey == dk));
          if (_tabController.index == 0) {
            if (_installmentCount > unpaid.length) _installmentCount = unpaid.length;
            _applyQuickPay(unpaid, _installmentCount);
          }

          return Column(
            children: [
              _buildHeader(plan, unpaid.length, all.length),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildQuickPayTab(unpaid),
                    _buildChooseDatesTab(unpaid),
                  ],
                ),
              ),
              _buildBottomBar(plan),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildHeader(CustomerSavingsModel plan, int unpaidCount, int totalCount) {
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
          const Icon(Icons.savings, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹${plan.monthlyDeposit.toStringAsFixed(0)} / installment',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$unpaidCount of $totalCount installments remaining · ${plan.displayName}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPayTab(List<_SavingsInst> unpaid) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
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
            'Installment${_installmentCount > 1 ? 's' : ''}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          _buildBreakdown(unpaid),
        ],
      ),
    );
  }

  Widget _buildChooseDatesTab(List<_SavingsInst> unpaid) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: unpaid.length,
      itemBuilder: (context, index) {
        final inst = unpaid[index];
        final isSelected = _selectedDateKeys.contains(inst.dateKey);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Checkbox(
              value: isSelected,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedDateKeys.add(inst.dateKey);
                  } else {
                    _selectedDateKeys.remove(inst.dateKey);
                  }
                });
              },
              activeColor: AppColors.primary,
            ),
            title: Text(
              'Installment #${inst.number}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              DateFormat('dd MMM yyyy').format(inst.dueDate),
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            trailing: Text(
              '₹${inst.amount.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBreakdown(List<_SavingsInst> unpaid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payment Breakdown',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.savings, size: 14, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Selected installments',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '$_installmentCount × ₹${(unpaid.isNotEmpty ? unpaid.first.amount : 0).toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
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

  Widget _buildBottomBar(CustomerSavingsModel plan) {
    final totalSelected = _selectedDateKeys.length * plan.monthlyDeposit;
    final count = _selectedDateKeys.length;
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
                onPressed: isEnabled ? () => _openUpiPayment(plan) : null,
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

  void _openUpiPayment(CustomerSavingsModel plan) {
    final totalAmount = _selectedDateKeys.length * plan.monthlyDeposit;
    final dateKeys = _selectedDateKeys.toList();
    final amounts = List.filled(dateKeys.length, plan.monthlyDeposit);

    final note = 'Installment${dateKeys.length > 1 ? 's' : ''} ${dateKeys.join(", ")} · ₹${totalAmount.toStringAsFixed(0)}';

    HapticFeedback.lightImpact();
    UpiPaymentSheet.show(
      context,
      amount: totalAmount,
      savingsPlanId: widget.savingsPlanId,
      savingsDateKeys: dateKeys,
      savingsAmounts: amounts,
      transactionNoteOverride: note,
    );
  }
}
