import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/utils/formatters.dart' show AppFormatters;
import '../../../../providers/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../home/data/providers/dashboard_providers.dart'
    show dashboardLoansProvider, dashboardTransactionsProvider, activeLoansProvider, loanSummaryProvider;
import '../../../../core/providers/branding_provider.dart';
import '../../../../core/providers/sms_provider.dart';
import '../../../savings/data/models/savings_model.dart';
import '../../../savings/data/models/savings_installment_model.dart';
import '../../../savings/data/providers/savings_providers.dart' show allSavingsProvider;
import '../../../staff/data/providers/staff_providers.dart' show staffProfileProvider;
import '../../data/models/emi_schedule_model.dart';
import '../../data/models/loan_model.dart';
import '../providers/loan_providers.dart';
import 'emi_payment_selector.dart';
import '../../../savings/presentation/widgets/savings_payment_selector.dart';

/// Collection mode -- determines which collection type to process
enum CollectionMode { loan, savings }

class CollectionSheet extends ConsumerStatefulWidget {
  /// Loan mode: provide [loan]
  final LoanModel? loan;
  final EMIScheduleModel? emi;

  /// Savings mode: provide [savingsPlan]
  final SavingsModel? savingsPlan;

  /// Required: which mode to use
  final CollectionMode mode;

  const CollectionSheet({
    super.key,
    this.loan,
    this.emi,
    this.savingsPlan,
    this.mode = CollectionMode.loan,
  }) : assert(
          mode == CollectionMode.loan ? loan != null : savingsPlan != null,
          'loan is required for loan mode, savingsPlan for savings mode',
        );

  /// Convenience constructor for savings collection mode
  // ignore: prefer_const_constructors_in_immutables
  CollectionSheet.savings({
    super.key,
    required SavingsModel savingsPlan,
    // ignore: unnecessary_this
  })  : loan = null,
        emi = null,
        // ignore: unnecessary_this, prefer_initializing_formals
        this.savingsPlan = savingsPlan,
        mode = CollectionMode.savings;

  @override
  ConsumerState<CollectionSheet> createState() => _CollectionSheetState();
}

class _CollectionSheetState extends ConsumerState<CollectionSheet> {
  String _selectedMode = 'cash';
  bool _isSubmitting = false;
  bool _isBackdated = false;
  DateTime? _customCollectionDate;

  List<EMIScheduleModel> _allEMIs = [];
  /// IDs of EMIs the user has selected for payment.
  final Set<String> _selectedEmiIds = {};

  // Savings mode state
  List<SavingsInstallment> _savingsSchedule = [];
  final Set<String> _selectedSavingsDates = {};

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    if (widget.mode == CollectionMode.savings) {
      await _loadSavingsSchedule();
      return;
    }
    try {
      final schedule =
          await ref.read(emiScheduleProvider(widget.loan!.id).future);

      if (mounted) {
        setState(() {
          _allEMIs = schedule;
          // Auto-select first unpaid EMI if none selected yet
          if (_selectedEmiIds.isEmpty && schedule.isNotEmpty) {
            final unpaid = schedule
                .where((e) =>
                    e.status != EMIStatus.paid &&
                    e.status != EMIStatus.waived)
                .toList()
              ..sort((a, b) => a.emiNumber.compareTo(b.emiNumber));
            if (unpaid.isNotEmpty) {
              _selectedEmiIds.add(unpaid.first.id);
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSavingsSchedule() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final plan = widget.savingsPlan!;
      final paidDates = await SavingsScheduleGenerator.fetchPaidDates(
        client: client,
        planId: plan.id,
      );
      final schedule = SavingsScheduleGenerator.generate(
        plan: plan,
        paidDates: paidDates,
      );
      if (mounted) {
        setState(() {
          _savingsSchedule = schedule;
          // Auto-select first unpaid installment
          final firstUnpaid = schedule.where((s) => !s.isPaid).toList();
          if (firstUnpaid.isNotEmpty) {
            _selectedSavingsDates.add(_dateKey(firstUnpaid.first.dueDate));
          }
        });
      }
    } catch (_) {}
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// The currently selected unpaid EMIs (looked up from the full schedule).
  List<EMIScheduleModel> get _selectedEMIs =>
      _allEMIs.where((e) => _selectedEmiIds.contains(e.id)).toList();

  /// The primary (first) selected EMI, used as the collection's
  /// `selected_schedule_id`.
  EMIScheduleModel? get _primarySelectedEMI =>
      _selectedEMIs.isNotEmpty ? _selectedEMIs.first : null;

  /// Whether we have any selection (EMI or savings dates).
  bool get _hasSelection {
    if (widget.mode == CollectionMode.savings) {
      return _selectedSavingsDates.isNotEmpty;
    }
    return _selectedEmiIds.isNotEmpty;
  }

  /// Sum of all selected EMIs or savings installments.
  double get _totalAmount {
    if (widget.mode == CollectionMode.savings) {
      return _savingsSchedule
          .where((s) => _selectedSavingsDates.contains(_dateKey(s.dueDate)))
          .fold<double>(0.0, (sum, s) => sum + s.amount);
    }
    return _selectedEMIs.fold<double>(0.0, (sum, e) => sum + e.emiAmount);
  }

  /// Returns created_at timestamp: backdated date when active, else now.
  String _getCreatedAt() {
    if (_isBackdated && _customCollectionDate != null) {
      final now = DateTime.now();
      final backdated = DateTime(
        _customCollectionDate!.year,
        _customCollectionDate!.month,
        _customCollectionDate!.day,
        now.hour, now.minute, now.second,
      );
      final ist = backdated.toUtc().add(const Duration(hours: 5, minutes: 30));
      return ist.toIso8601String().replaceFirst('Z', '+05:30');
    }
    return AppFormatters.nowIST();
  }

  // ─── Theme Helpers ───
  bool get _isDark =>
      Theme.of(context).brightness == Brightness.dark;

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
      if (widget.mode == CollectionMode.savings) {
        await _submitSavings();
      } else {
        await _submitLoan();
      }

      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.mode == CollectionMode.savings
                  ? '${_selectedSavingsDates.length} installment${_selectedSavingsDates.length > 1 ? 's' : ''} \u00b7 '
                      '\u20b9${_totalAmount.toStringAsFixed(0)} deposited for ${widget.savingsPlan!.planName}'
                  : '${_selectedEMIs.length > 1 ? '${_selectedEMIs.length} EMIs \u00b7 ' : ''}'
                      '\u20b9${_totalAmount.toStringAsFixed(0)} collected from ${widget.loan!.customerName}',
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

  // ─── Loan (EMI) Collection ───
  Future<void> _submitLoan() async {
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

    // Resolve member name: prefer joined data, fallback to DB lookup
    String memberName = widget.loan!.customerName ?? '';
    if (memberName.isEmpty) {
      final memberId = widget.loan!.customerId.isNotEmpty
          ? widget.loan!.customerId
          : widget.loan!.memberId;
      if (memberId != null) {
        try {
          final member = await client
              .from('members')
              .select('full_name')
              .eq('id', memberId)
              .maybeSingle();
          memberName = member?['full_name']?.toString() ?? '';
        } catch (_) {}
      }
    }
    if (memberName.isEmpty) memberName = 'Unknown';

    // 1. Insert ONE collection per selected EMI (each targets exactly one EMI)
    for (final emi in _selectedEMIs) {
      await client.from('collections').insert({
        'org_id': user.orgId!,
        'staff_id': staffId,
        'loan_id': widget.loan!.id,
        'member_id': widget.loan!.memberId,
        'member_name': memberName,
        'member_phone': widget.loan!.customerPhone,
        'loan_number': widget.loan!.loanNumber,
        'amount_expected': widget.loan!.emiAmount,
        'amount_collected': widget.loan!.emiAmount,
        'is_partial': false,
        'collection_type': 'emi',
        'payment_mode': _selectedMode,
        'collection_date': _isBackdated && _customCollectionDate != null
            ? DateFormat('yyyy-MM-dd').format(_customCollectionDate!)
            : today,
        'collection_time': timeStr,
        'sync_status': 'synced',
        'selected_schedule_id': emi.id,
      });
    }

    // 2. Single transaction record for the total
    await client.from('transactions').insert({
      'loan_id': widget.loan!.id,
      'member_id': widget.loan!.memberId,
      'member_name': memberName,
      'type': TransactionType.emiPayment.name,
      'amount': amount,
      'payment_mode': _selectedMode,
      'description': selectedCount > 1
            ? '$selectedCount EMIs paid via $_selectedMode'
            : 'EMI #${_primarySelectedEMI?.emiNumber ?? ''} payment via $_selectedMode',
      'org_id': user.orgId!,
      'created_at': _getCreatedAt(),
    });

    // 3. Update loan balance
    final loanResp = await client
        .from('loans')
        .select('outstanding_amount, outstanding_balance')
        .eq('id', widget.loan!.id)
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

      await client.from('loans').update(updateData).eq('id', widget.loan!.id);

      // 3b. Dispatch SMS
      try {
        debugPrint('CollectionSheet: initiating SMS dispatch...');
        String? phone = widget.loan!.customerPhone;
        bool smsEnabled = true;

        // Always fetch sms_enabled from members table
        try {
          final memberInfo = await client
              .from('members')
              .select('phone, sms_enabled')
              .eq('id', widget.loan!.customerId)
              .maybeSingle();
          if (phone == null || phone.isEmpty) {
            phone = memberInfo?['phone']?.toString();
          }
          smsEnabled = memberInfo?['sms_enabled'] as bool? ?? true;
        } catch (_) {}

        final branding = ref.read(brandingProvider).valueOrNull;
        if (phone != null && phone.isNotEmpty) {
          debugPrint('CollectionSheet: enqueuing SMS to $phone (memberId: ${widget.loan!.customerId})');
          await ref.read(collectionSmsSenderProvider.notifier).enqueueCollection(
                phone: phone,
                memberId: widget.loan!.customerId,
                memberName: memberName,
                loanNumber: widget.loan!.loanNumber,
                amount: amount,
                outstandingBalance: newBalance,
                collectorName: profile?['full_name'] ?? 'Staff',
                sentBy: staffId,
                orgName: branding?.displayName,
                smsEnabled: smsEnabled,
              );
        } else {
          debugPrint('CollectionSheet: skipping SMS, phone number still null or empty');
        }
      } catch (e) {
        debugPrint('SMS collection dispatch failed: $e');
      }
    }

    // 4. Activity log
    try {
      await client.from('activity_logs').insert({
        'org_id': user.orgId!,
        'staff_id': staffId,
        'action': 'collection_recorded',
        'entity_type': 'collection',
        'entity_id': widget.loan!.id,
        'details':
            'Collected Rs${amount.toStringAsFixed(0)} from ${widget.loan!.customerName}',
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
    ref.invalidate(emiScheduleProvider(widget.loan!.id));
    ref.invalidate(loanDetailProvider(widget.loan!.id));
    ref.invalidate(paymentHistoryProvider(widget.loan!.id));
    ref.invalidate(loansProvider);
    ref.invalidate(dashboardLoansProvider);
    ref.invalidate(dashboardTransactionsProvider);
    ref.invalidate(activeLoansProvider);
    ref.invalidate(loanSummaryProvider);
  }

  // ─── Savings Collection ───
  Future<void> _submitSavings() async {
    final client = ref.read(supabaseClientProvider);
    final profile = await ref.read(staffProfileProvider.future);
    if (profile == null) throw Exception('Staff profile not found');

    final plan = widget.savingsPlan!;
    final now = DateTime.now();
    final today = now.toIso8601String().split('T').first;
    final amount = _totalAmount;

    // 1. Create transaction
    final txResult = await client.from('transactions').insert({
      'member_id': plan.memberId,
      'member_name': plan.memberName,
      'savings_id': plan.id,
      'amount': amount,
      'type': 'savingsDeposit',
      'payment_mode': _selectedMode,
      'description': '${_selectedSavingsDates.length} installments deposited via $_selectedMode',
      'org_id': profile.orgId,
      'created_at': _getCreatedAt(),
    }).select('id').single();
    final transactionId = txResult['id'] as String;

    // 2. Record collection
    await client.from('savings_collections').insert({
      'org_id': profile.orgId,
      'savings_plan_id': plan.id,
      'member_id': plan.memberId,
      'member_name': plan.memberName,
      'amount_expected': amount,
      'amount_collected': amount,
      'is_partial': false,
      'payment_mode': _selectedMode,
      'collection_date': _isBackdated && _customCollectionDate != null
          ? DateFormat('yyyy-MM-dd').format(_customCollectionDate!)
          : today,
      'collected_at': DateTime.now().toUtc().toIso8601String(),
      'staff_id': profile.id,
      'collected_by_name': profile.fullName,
      'collected_by_role': profile.role.dbValue,
      'collected_by_user_id': profile.id,
      'sync_status': 'synced',
      'transaction_id': transactionId,
    });

    // 3. Update plan balance and advance next_due_date
    // Use the LATEST selected date as the reference point (not DateTime.now())
    // This ensures backdated payments advance next_due_date correctly.
    final lastSelectedDate = _selectedSavingsDates
        .map((key) => DateTime.parse(key))
        .reduce((a, b) => a.isAfter(b) ? a : b);

    // Advance exactly one period from the last paid date.
    // installmentCount is irrelevant here — lastSelectedDate already
    // represents the furthest date being paid.
    DateTime nextDue;
    switch (plan.collectionType) {
      case 'weekly':
        nextDue = lastSelectedDate.add(const Duration(days: 7));
        break;
      case 'monthly':
        int targetMonth = lastSelectedDate.month + 1;
        int targetYear = lastSelectedDate.year + ((targetMonth - 1) ~/ 12);
        targetMonth = ((targetMonth - 1) % 12) + 1;
        int targetDay = lastSelectedDate.day;
        int daysInMonth = DateTime(targetYear, targetMonth + 1, 0).day;
        if (targetDay > daysInMonth) targetDay = daysInMonth;
        nextDue = DateTime(targetYear, targetMonth, targetDay);
        break;
      default:
        nextDue = lastSelectedDate.add(const Duration(days: 1));
    }

    final selectedCount = _selectedSavingsDates.length;

    await client.from('savings_plans').update({
      'next_due_date': nextDue.toIso8601String().split('T').first,
      'current_amount': plan.currentAmount + amount,
      'installments_paid': plan.installmentsPaid + selectedCount,
      'last_payment_date': lastSelectedDate.toIso8601String().split('T').first,
      'updated_at': now.toIso8601String(),
    }).eq('id', plan.id);

    // 3b. Dispatch SMS
    try {
      final memberInfo = await client
          .from('members')
          .select('phone, sms_enabled')
          .eq('id', plan.memberId)
          .maybeSingle();
      final phone = memberInfo?['phone']?.toString();
      final smsEnabled = memberInfo?['sms_enabled'] as bool? ?? true;

      final branding = ref.read(brandingProvider).valueOrNull;
      await ref.read(collectionSmsSenderProvider.notifier).enqueueSavings(
            phone: phone,
            memberId: plan.memberId,
            memberName: plan.memberName,
            planName: plan.planName,
            amount: amount,
            newBalance: plan.currentAmount + amount,
            collectorName: profile.fullName,
            sentBy: profile.id,
            orgName: branding?.displayName,
            smsEnabled: smsEnabled,
          );
    } catch (e) {
      debugPrint('SMS savings dispatch failed: $e');
    }

    // 4. Activity log
    try {
      await client.from('activity_logs').insert({
        'org_id': profile.orgId,
        'staff_id': profile.id,
        'action': 'savings_collection_recorded',
        'entity_type': 'savings_collection',
        'entity_id': plan.id,
        'details':
            'Deposited Rs${amount.toStringAsFixed(0)} for ${plan.memberName} (${plan.planName})',
        'metadata': {
          'amount': amount,
          'installment_count': _selectedSavingsDates.length,
          'payment_mode': _selectedMode,
          'savings_plan_id': plan.id,
        },
        'created_at': now.toIso8601String(),
      });
    } catch (_) {}

    // 5. Invalidate savings providers
    try {
      ref.invalidate(allSavingsProvider);
      ref.invalidate(dashboardTransactionsProvider);
    } catch (_) {}
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
                        // Frosted glass pill for customer/plan info
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.mode == CollectionMode.savings
                                ? '${widget.savingsPlan!.memberName} \u00b7 ${widget.savingsPlan!.planName}'
                                : '${widget.loan!.customerName} \u00b7 ${widget.loan!.loanNumber}',
                            style: TextStyle(
                                color:
                                    Colors.white.withValues(alpha: 0.9),
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // EMI / Savings amount badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      widget.mode == CollectionMode.savings
                          ? 'Savings \u20b9${widget.savingsPlan!.monthlyDeposit.toStringAsFixed(0)}'
                          : 'EMI \u20b9${widget.loan!.emiAmount.toStringAsFixed(0)}',
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

              // Schedule selector (scrollable) -- mode-dependent
              Expanded(
                child: widget.mode == CollectionMode.savings
                    ? _buildSavingsBody(currencyFormat)
                    : _buildLoanBody(currencyFormat),
              ),

              const SizedBox(height: 16),

              // ─── 5. Payment Mode Chips -- Gradient Selection ───
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

              // ─── 6. Action Buttons -- Premium Style ───
              Row(
                children: [
                  // Cancel -- frosted glass
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
                  // Collect -- gradient with glow
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _isSubmitting || !_hasSelection
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
                          boxShadow: _isSubmitting || !_hasSelection
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

  /// Build the loan (EMI) mode body.
  Widget _buildBackdatePill() {
    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: _customCollectionDate ?? now,
          firstDate: now.subtract(const Duration(days: 365)),
          lastDate: now,
        );
        if (picked != null) {
          setState(() {
            _isBackdated = true;
            _customCollectionDate = picked;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: _isBackdated
              ? LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.accent.withValues(alpha: 0.15),
                  ],
                )
              : null,
          color: _isBackdated ? null : _fillColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isBackdated ? AppColors.primary : _separator,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 14,
              color: _isBackdated ? AppColors.primary : _textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              _isBackdated && _customCollectionDate != null
                  ? DateFormat('dd MMM yyyy').format(_customCollectionDate!)
                  : 'Backdate',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _isBackdated ? AppColors.primary : _textSecondary,
              ),
            ),
            if (_isBackdated) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isBackdated = false;
                    _customCollectionDate = null;
                  });
                },
                child: Icon(
                  Icons.close_rounded,
                  size: 12,
                  color: AppColors.primary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoanBody(NumberFormat currencyFormat) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: "EMI Schedule" + backdate pill
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Text(
                  'EMI Schedule',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const Spacer(),
                _buildBackdatePill(),
              ],
            ),
          ),
          EmiPaymentSelector(
            emis: _allEMIs,
            emiAmount: widget.loan!.emiAmount,
            initialSelectedIds: _selectedEmiIds.toList(),
            onSelectionChanged: (selected) {
              setState(() {
                _selectedEmiIds
                  ..clear()
                  ..addAll(selected.map((e) => e.id));
              });
            },
          ),
        ],
      ),
    );
  }

  /// Build the savings mode body: installment calendar.
  Widget _buildSavingsBody(NumberFormat currencyFormat) {
    final selectedCount = _selectedSavingsDates.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: "Savings Schedule" + backdate pill
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Text(
                  'Savings Schedule',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const Spacer(),
                _buildBackdatePill(),
              ],
            ),
          ),
          // Selection summary
          if (selectedCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '$selectedCount installment${selectedCount > 1 ? 's' : ''} selected',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ),

          // Savings payment selector (Quick Pay + Calendar)
          if (_savingsSchedule.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Loading schedule...',
                  style: TextStyle(color: _textSecondary),
                ),
              ),
            )
          else
            SavingsPaymentSelector(
              installments: _savingsSchedule,
              installmentAmount: widget.savingsPlan!.monthlyDeposit,
              totalInstallments: widget.savingsPlan!.totalInstallments,
              initialSelectedDateKeys: _selectedSavingsDates.toList(),
              onSelectionChanged: (selected) {
                setState(() {
                  _selectedSavingsDates
                    ..clear()
                    ..addAll(selected.map((s) => _dateKey(s.dueDate)));
                });
              },
            ),
        ],
      ),
    );
  }

}
