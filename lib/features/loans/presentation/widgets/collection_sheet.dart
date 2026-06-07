import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../home/data/providers/dashboard_providers.dart'
    show dashboardLoansProvider, activeLoansProvider, loanSummaryProvider;
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

  List<EMIScheduleModel> _allEMIs = [];
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

      if (mounted) {
        setState(() {
          _allEMIs = schedule;
        });
      }
    } catch (_) {}
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

  // ─── Theme Helpers ───
  bool get _isDark =>
      Theme.of(context).brightness == Brightness.dark;

  Color get _cardColor =>
      _isDark ? AppColors.cardDark : AppColors.cardLight;

  Color get _textPrimary =>
      _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

  Color get _textSecondary =>
      _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

  Color get _fillColor =>
      _isDark ? AppColors.fillDark : AppColors.fillLight;

  Color get _separator =>
      _isDark ? AppColors.separatorDark : AppColors.separatorLight;

  // ─── Premium Payment Mode Chip ───
  Widget _buildPaymentModeChip({
    required IconData icon,
    required String label,
    required String mode,
  }) {
    final isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: isSelected
            ? BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                    spreadRadius: -2,
                  ),
                ],
              )
            : BoxDecoration(
                color: _fillColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _separator,
                  width: 1,
                ),
              ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? Colors.white
                  : _textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
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
      // ─── 1. Premium Gradient AppBar ───
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.accent],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Close button with frosted glass circle
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Quick Collect',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3)),
                        const SizedBox(height: 4),
                        // Frosted glass pill for customer info
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${widget.loan.customerName} \u00b7 ${widget.loan.loanNumber}',
                            style: TextStyle(
                                color:
                                    Colors.white.withValues(alpha: 0.9),
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // EMI amount badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'EMI \u20b9${widget.loan.emiAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // EMI selector (scrollable)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: EmiPaymentSelector(
                    emis: _allEMIs,
                    emiAmount: widget.loan.emiAmount,
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

              // ─── 4. Total Amount → Premium Display ───
              GlassCard(
                padding: const EdgeInsets.all(14),
                borderRadius: 16,
                backgroundColor: _totalAmount > 0
                    ? AppColors.success.withValues(alpha: 0.06)
                    : _cardColor,
                borderColor: _totalAmount > 0
                    ? AppColors.success.withValues(alpha: 0.2)
                    : null,
                elevated: _totalAmount > 0,
                child: Row(
                  children: [
                    // Gradient circle with currency symbol
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _totalAmount > 0
                              ? AppColors.successGradient
                              : AppColors.premiumGradient,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          '\u20b9',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Amount',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          AnimatedSwitcher(
                            duration:
                                const Duration(milliseconds: 300),
                            child: Text(
                              currencyFormat
                                  .format(_totalAmount),
                              key: ValueKey(
                                  _totalAmount.toStringAsFixed(0)),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: _totalAmount > 0
                                    ? AppColors.success
                                    : _textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── 5. Payment Mode Chips → Gradient Selection ───
              const Text('Payment Mode',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildPaymentModeChip(
                      icon: Icons.money_rounded,
                      label: 'Cash',
                      mode: 'cash',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPaymentModeChip(
                      icon: Icons.qr_code_rounded,
                      label: 'UPI',
                      mode: 'upi',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPaymentModeChip(
                      icon: Icons.account_balance_rounded,
                      label: 'Bank',
                      mode: 'bank_transfer',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPaymentModeChip(
                      icon: Icons.receipt_rounded,
                      label: 'Cheque',
                      mode: 'cheque',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ─── 6. Action Buttons → Premium Style ───
              Row(
                children: [
                  // Cancel — frosted glass
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: _fillColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _separator,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: _textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Collect — gradient with glow
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _isSubmitting || _selectedEmiIds.isEmpty
                          ? null
                          : _submit,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            AppColors.success,
                            AppColors.mint,
                          ]),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _isSubmitting ||
                                  _selectedEmiIds.isEmpty
                              ? []
                              : [
                                  BoxShadow(
                                    color: AppColors.success
                                        .withValues(alpha: 0.35),
                                    blurRadius: 16,
                                    offset:
                                        const Offset(0, 6),
                                    spreadRadius: -4,
                                  ),
                                ],
                        ),
                        child: Center(
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisSize:
                                      MainAxisSize.min,
                                  children: [
                                    const Icon(
                                        Icons
                                            .check_circle_rounded,
                                        size: 20,
                                        color:
                                            Colors.white),
                                    const SizedBox(
                                        width: 8),
                                    Text(
                                      'Collect ${currencyFormat.format(_totalAmount)}',
                                      style: const TextStyle(
                                        fontWeight:
                                            FontWeight.w700,
                                        fontSize: 15,
                                        color:
                                            Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
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
