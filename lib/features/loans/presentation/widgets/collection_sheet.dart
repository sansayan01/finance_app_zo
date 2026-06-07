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
import 'emi_payment_selector.dart';

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
  String _selectedMode = 'cash';
  bool _isSubmitting = false;
  bool _isLoadingSchedule = true;

  List<EMIScheduleModel> _unpaidEMIs = [];
  List<EMIScheduleModel> _allEMIs = [];
  int _overdueCount = 0;
  /// IDs of EMIs the user has selected for payment.
  final Set<String> _selectedEmiIds = {};

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
          _allEMIs = schedule;
          _unpaidEMIs = unpaid;
          _overdueCount =
              unpaid.where((e) => e.dueDate.isBefore(todayDate)).length;
          _isLoadingSchedule = false;

          // Do NOT auto-select — user chooses via the calendar popup.
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingSchedule = false);
      }
    }
  }

  /// The currently selected unpaid EMIs (looked up from the full schedule).
  List<EMIScheduleModel> get _selectedEMIs =>
      _allEMIs.where((e) => _selectedEmiIds.contains(e.id)).toList();

  /// The primary (first) selected EMI, used as the collection's
  /// `selected_schedule_id`.
  EMIScheduleModel? get _primarySelectedEMI =>
      _selectedEMIs.isNotEmpty ? _selectedEMIs.first : null;

  /// Sum of all selected EMIs (each EMI may have a different amount).
  double get _totalAmount => _selectedEMIs.fold<double>(
      0.0, (sum, e) => sum + e.emiAmount);

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
      final selectedCount = _selectedEMIs.length;
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      // 1. Insert ONE collection per selected EMI (each targets exactly one EMI)
      for (final emi in _selectedEMIs) {
        await client.from('collections').insert({
          'org_id': user.orgId!,
          'staff_id': staffId,
          'loan_id': widget.loan.id,
          'member_id': widget.loan.memberId,
          'member_name': widget.loan.customerName ?? 'Unknown',
          'member_phone': widget.loan.customerPhone,
          'loan_number': widget.loan.loanNumber,
          'amount_expected': widget.loan.emiAmount,
          'amount_collected': widget.loan.emiAmount,
          'is_partial': false,
          'collection_type': 'emi',
          'payment_mode': _selectedMode,
          'collection_date': today,
          'collection_time': timeStr,
          'sync_status': 'synced',
          'selected_schedule_id': emi.id,
        });
      }

      // 2. Single transaction record for the total
      await client.from('transactions').insert({
        'loan_id': widget.loan.id,
        'member_id': widget.loan.memberId,
        'member_name': widget.loan.customerName ?? 'Unknown',
        'type': TransactionType.emiPayment.name,
        'amount': amount,
        'payment_mode': _selectedMode,
        'description': selectedCount > 1
            ? '$selectedCount EMIs paid via $_selectedMode'
            : 'EMI #${_primarySelectedEMI?.emiNumber ?? ''} payment via $_selectedMode',
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
            'emi_count': selectedCount,
            'payment_mode': _selectedMode,
            'selected_schedule_ids':
                _selectedEMIs.map((e) => e.id).toList(),
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
              '${selectedCount > 1 ? '$selectedCount EMIs \u00b7 ' : ''}'
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Collect',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            Text(
              '${widget.loan.customerName} \u00b7 ${widget.loan.loanNumber}'
              '${widget.loan.emiAmount > 0 ? ' \u00b7 EMI \u20b9${widget.loan.emiAmount.toStringAsFixed(0)}' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Info row
              if (!_isLoadingSchedule) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        Container(
                            width: 1, height: 14, color: Colors.grey.shade300),
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
                      if (_unpaidEMIs.isNotEmpty)
                        Text(
                          '${_unpaidEMIs.length} remaining',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // EMI payment summary
              if (_selectedEMIs.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      AppColors.primary.withValues(alpha: 0.08),
                      AppColors.primary.withValues(alpha: 0.03),
                    ]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedEMIs.length == 1
                            ? Icons.schedule_rounded
                            : Icons.payments_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedEMIs.length == 1
                                  ? 'Paying EMI #${_primarySelectedEMI!.emiNumber} (${DateFormat('dd MMM').format(_primarySelectedEMI!.dueDate)})'
                                  : 'Paying ${_selectedEMIs.length} EMIs',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_selectedEMIs.length} \u00d7 ${currencyFormat.format(widget.loan.emiAmount)} = ${currencyFormat.format(_totalAmount)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // EMI selector (scrollable)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: EmiPaymentSelector(
                    emis: _allEMIs,
                    emiAmount: widget.loan.emiAmount,
                    multiSelect: true,
                    initialSelectedIds: _selectedEmiIds.toList(),
                    onSelectionChanged: (selected) {
                      setState(() {
                        _selectedEmiIds
                          ..clear()
                          ..addAll(selected.map((e) => e.id));
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Read-only total amount
              const Text('Total Amount',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              TextFormField(
                readOnly: true,
                controller:
                    TextEditingController(text: _totalAmount.toStringAsFixed(0)),
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
                    borderSide:
                        const BorderSide(color: AppColors.success, width: 2),
                  ),
                ),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),

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
                      onTap: () =>
                          setState(() => _selectedMode = 'bank_transfer'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PaymentModeChip(
                      icon: Icons.receipt_rounded,
                      label: 'Cheque',
                      isSelected: _selectedMode == 'cheque',
                      onTap: () => setState(() => _selectedMode = 'cheque'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

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
                      onPressed:
                          _isSubmitting || _selectedEmiIds.isEmpty ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text(
                        _isSubmitting
                            ? 'Processing...'
                            : 'Collect ${currencyFormat.format(_totalAmount)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
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
        ),
      ),
    );
  }

}
