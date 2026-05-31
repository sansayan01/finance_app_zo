import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/widgets/payment_mode_chips.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../home/data/providers/dashboard_providers.dart'
    show dashboardLoansProvider, activeLoansProvider, loanSummaryProvider;
import '../../../savings/data/providers/savings_providers.dart';
import '../../data/models/emi_schedule_model.dart';
import '../../data/models/loan_model.dart';
import '../providers/loan_providers.dart';

class CollectionSheet extends ConsumerStatefulWidget {
  final LoanModel loan;
  final EMIScheduleModel? emi;

  const CollectionSheet({
    super.key,
    required this.loan,
    this.emi,
  });

  @override
  ConsumerState<CollectionSheet> createState() => _CollectionSheetState();
}

class _CollectionSheetState extends ConsumerState<CollectionSheet> {
  int _installmentCount = 1;
  String _selectedMode = 'cash';
  bool _isSubmitting = false;
  bool _isLoadingSchedule = true;

  List<EMIScheduleModel> _unpaidEMIs = [];
  int _overdueCount = 0;
  bool _hasCurrent = false;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    try {
      final schedule =
          await ref.read(emiScheduleProvider(widget.loan.id).future);
      final today = DateTime.now();
      // Strip time so we compare dates only (dueDate is midnight, today has time)
      final todayDate = DateTime(today.year, today.month, today.day);
      final unpaid = schedule
          .where((e) => e.status != EMIStatus.paid)
          .toList()
        ..sort((a, b) => a.emiNumber.compareTo(b.emiNumber));

      if (mounted) {
        setState(() {
          _unpaidEMIs = unpaid;
          _overdueCount =
              unpaid.where((e) => e.dueDate.isBefore(todayDate)).length;
          _hasCurrent = unpaid.length > _overdueCount;
          _isLoadingSchedule = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingSchedule = false);
      }
    }
  }

  int get _overdueToPay =>
      _installmentCount < _overdueCount
          ? _installmentCount
          : _overdueCount;

  int get _remainingAfterOverdue => _installmentCount - _overdueToPay;

  int get _currentToPay =>
      _remainingAfterOverdue > 0 && _hasCurrent ? 1 : 0;

  int get _advanceToPay => _remainingAfterOverdue - _currentToPay;

  double get _totalAmount => _installmentCount * widget.loan.emiAmount;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
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
      final now = DateTime.now();
      final today = now.toIso8601String().split('T').first;
      final amount = _totalAmount;
      final installmentCount = _installmentCount;

      // 1. Record collection log
      await client.from('collections').insert({
        'org_id': user.orgId!,
        'staff_id': staffId,
        'loan_id': widget.loan.id,
        'member_id': widget.loan.memberId,
        'member_name': widget.loan.customerName ?? 'Unknown',
        'member_phone': widget.loan.customerPhone,
        'loan_number': widget.loan.loanNumber,
        'amount_expected': widget.loan.emiAmount * installmentCount,
        'amount_collected': amount,
        'is_partial': false,
        'collection_type': 'emi',
        'payment_mode': _selectedMode,
        'collection_date': today,
        'collection_time':
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
        'sync_status': 'synced',
      });

      // 2. Transaction record (trigger handles EMI marking)
      await client.from('transactions').insert({
        'loan_id': widget.loan.id,
        'member_id': widget.loan.memberId,
        'member_name': widget.loan.customerName ?? 'Unknown',
        'type': TransactionType.emiPayment.name,
        'amount': amount,
        'payment_mode': _selectedMode,
        'description': installmentCount > 1
            ? '$installmentCount EMIs paid via $_selectedMode'
            : 'EMI payment via $_selectedMode',
        'org_id': user.orgId!,
        'created_at': now.toIso8601String(),
      });

      // 3. Update loan balance
      final loanResp = await client
          .from('loans')
          .select('outstanding_amount, outstanding_balance')
          .eq('id', widget.loan.id)
          .maybeSingle();

      if (loanResp != null) {
        final currentBalance =
            ((loanResp['outstanding_amount'] ?? loanResp['outstanding_balance'])
                    as num?)
                ?.toDouble() ?? 0;
        final newBalance = (currentBalance - amount).clamp(0.0, currentBalance);

        final updateData = <String, dynamic>{
          'outstanding_amount': newBalance,
          'outstanding_balance': newBalance,
          'updated_at': now.toIso8601String(),
        };

        if (newBalance <= 0) {
          updateData['status'] = 'closed';
          updateData['closed_date'] = today;
        }

        await client.from('loans').update(updateData).eq('id', widget.loan.id);
      }

      // 4. Activity log
      try {
        await client.from('activity_logs').insert({
          'org_id': user.orgId!,
          'staff_id': staffId,
          'action': 'collection_recorded',
          'entity_type': 'collection',
          'entity_id': widget.loan.id,
          'details':
              'Collected Rs${amount.toStringAsFixed(0)} from ${widget.loan.customerName}',
          'metadata': {
            'amount': amount,
            'installment_count': installmentCount,
            'payment_mode': _selectedMode,
          },
          'created_at': now.toIso8601String(),
        });
      } catch (_) {}

      // 5. Invalidate providers
      ref.invalidate(emiScheduleProvider(widget.loan.id));
      ref.invalidate(loanDetailProvider(widget.loan.id));
      ref.invalidate(paymentHistoryProvider(widget.loan.id));
      ref.invalidate(loansProvider);
      ref.invalidate(dashboardLoansProvider);
      ref.invalidate(activeLoansProvider);
      ref.invalidate(loanSummaryProvider);
      ref.invalidate(allSavingsProvider);

      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${installmentCount > 1 ? '$installmentCount installments \u00b7 ' : ''}'
              '\u20b9${amount.toStringAsFixed(0)} collected from ${widget.loan.customerName}',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Collection failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat =
        NumberFormat.currency(symbol: '\u20b9', decimalDigits: 0);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            20,
        left: 20,
        right: 20,
        top: 12,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
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
                      '${widget.loan.customerName} \u00b7 ${widget.loan.loanNumber}'
                      '${widget.loan.emiAmount > 0 ? ' \u00b7 EMI \u20b9${widget.loan.emiAmount.toStringAsFixed(0)}' : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Info row
          if (!_isLoadingSchedule) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  if (_overdueCount > 0) ...[
                    const Icon(Icons.warning_amber_rounded,
                        size: 16, color: AppColors.error),
                    const SizedBox(width: 6),
                    Text(
                      '$_overdueCount overdue',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(width: 1, height: 14, color: Colors.grey.shade300),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    'EMI \u20b9${widget.loan.emiAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const Spacer(),
                  if (_unpaidEMIs.isNotEmpty) ...[
                    Text(
                      '${_unpaidEMIs.length} remaining',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
          ] else ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Installment count selector
          const Text('Number of Installments',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  onPressed: _installmentCount > 1
                      ? () => setState(() {
                            _installmentCount--;
                          })
                      : null,
                  icon:
                      const Icon(Icons.remove_circle_outline_rounded),
                  color: AppColors.primary,
                  disabledColor: Colors.grey.shade300,
                ),
                Column(
                  children: [
                    Text(
                      '$_installmentCount',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      _installmentCount == 1
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
                  onPressed: _installmentCount < 12
                      ? () => setState(() {
                            _installmentCount++;
                          })
                      : null,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  color: AppColors.primary,
                  disabledColor: Colors.grey.shade300,
                ),
              ],
            ),
          ),
          if (_installmentCount > 1) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '$_installmentCount \u00d7 ${currencyFormat.format(widget.loan.emiAmount)} = ${currencyFormat.format(_totalAmount)}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Read-only total amount
          const Text('Total Amount',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          TextFormField(
            readOnly: true,
            controller: TextEditingController(
                text: _totalAmount.toStringAsFixed(0)),
            keyboardType: TextInputType.none,
            decoration: InputDecoration(
              prefixText: '\u20b9 ',
              prefixStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.success,
                fontSize: 20,
              ),
              hintText: 'Amount',
              filled: true,
              fillColor: AppColors.success.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                    color: AppColors.success, width: 2),
              ),
            ),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),

          // Distribution breakdown
          if (!_isLoadingSchedule && (_overdueToPay > 0 || _currentToPay > 0 || _advanceToPay > 0)) ...[
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
                  if (_overdueToPay > 0)
                    _buildDistributionRow(
                        '$_overdueToPay Overdue',
                        currencyFormat.format(
                            _overdueToPay * widget.loan.emiAmount),
                        AppColors.error,
                        Icons.warning_amber_rounded),
                  if (_currentToPay > 0)
                    _buildDistributionRow(
                        '$_currentToPay Current',
                        currencyFormat.format(
                            _currentToPay * widget.loan.emiAmount),
                        AppColors.warning,
                        Icons.schedule_rounded),
                  if (_advanceToPay > 0)
                    _buildDistributionRow(
                        '$_advanceToPay Advance',
                        currencyFormat.format(
                            _advanceToPay * widget.loan.emiAmount),
                        AppColors.info,
                        Icons.trending_up_rounded),
                  const Divider(height: 20),
                  _buildDistributionRow(
                    'Total',
                    currencyFormat.format(_totalAmount),
                    AppColors.success,
                    null,
                    isTotal: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Payment mode chips
          const Text('Payment Mode',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: PaymentModeChip(
                  icon: Icons.money_rounded,
                  label: 'Cash',
                  isSelected: _selectedMode == 'cash',
                  onTap: () => setState(() => _selectedMode = 'cash'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PaymentModeChip(
                  icon: Icons.qr_code_rounded,
                  label: 'UPI',
                  isSelected: _selectedMode == 'upi',
                  onTap: () => setState(() => _selectedMode = 'upi'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PaymentModeChip(
                  icon: Icons.account_balance_rounded,
                  label: 'Bank',
                  isSelected: _selectedMode == 'bank_transfer',
                  onTap: () => setState(
                      () => _selectedMode = 'bank_transfer'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PaymentModeChip(
                  icon: Icons.receipt_rounded,
                  label: 'Cheque',
                  isSelected: _selectedMode == 'cheque',
                  onTap: () =>
                      setState(() => _selectedMode = 'cheque'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
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
                  onPressed: _isSubmitting
                      ? null
                      : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded,
                          size: 18),
                  label: Text(
                    _isSubmitting
                        ? 'Processing...'
                        : 'Collect ${currencyFormat.format(_totalAmount)}',
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
  }

  Widget _buildDistributionRow(String label, String value, Color color,
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
              color: isTotal ? color : color,
            ),
          ),
        ],
      ),
    );
  }
}
