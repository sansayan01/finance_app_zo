import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import 'package:microflow_pro/core/constants/enums.dart' as cm;
import '../../data/models/collection_model.dart';
import '../../data/providers/collection_providers.dart';
import '../../../../core/services/location_service.dart';
import '../../data/providers/staff_providers.dart';
import '../../../../core/providers/branding_provider.dart';
import '../../../../core/services/haptic_service.dart';
import '../widgets/receipt_generator.dart';

import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/smokey_background.dart';
import '../../../../core/widgets/premium_calendar_sheet.dart';
import '../widgets/premium_helpers.dart';
import '../../../loans/presentation/providers/loan_providers.dart' show emiScheduleProvider;
import '../../../loans/data/models/emi_schedule_model.dart';

class CollectionFormPage extends ConsumerStatefulWidget {
  final String loanId;
  final Map<String, dynamic>? loanData;

  const CollectionFormPage({
    super.key,
    required this.loanId,
    this.loanData,
  });

  @override
  ConsumerState<CollectionFormPage> createState() => _CollectionFormPageState();
}

class _CollectionFormPageState extends ConsumerState<CollectionFormPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _remarksController = TextEditingController();
  final _backdateReasonController = TextEditingController();

  cm.PaymentMode _selectedPaymentMode = cm.PaymentMode.cash;
  bool _isSubmitting = false;
  bool _isPartial = false;
  double _amountExpected = 0;
  String _memberName = '';
  String _memberId = '';
  String _memberPhone = '';
  String? _loanScheduleId;

  // Collection-date (backdate) state.
  // null = "today"; non-null = a picked calendar date (time-of-day stays as
  // current local time on submit).
  DateTime? _customCollectionDate;

  // EMI selector state
  List<EMIScheduleModel> _unpaidEMIs = [];
  bool _isLoadingSchedule = true;
  EMIScheduleModel? _selectedEmi;
  bool _hasManuallyEditedAmount = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLoanData();
  }

  void _loadLoanData() {
    if (widget.loanData != null) {
      final schedule = widget.loanData!['current_schedule'] ?? {};
      final member = widget.loanData!['members'] ?? {};

      setState(() {
        _amountExpected = (schedule['emi'] as num?)?.toDouble() ??
            (schedule['emi_amount'] as num?)?.toDouble() ?? 0;
        _memberName =
            member['full_name'] ?? widget.loanData!['member_name'] ?? '';
        _memberId = member['id']?.toString() ??
            widget.loanData!['member_id']?.toString() ??
            '';
        _memberPhone = member['phone']?.toString() ?? '';
        _loanScheduleId = schedule['id']?.toString();
      });

      _amountController.text = _amountExpected.toStringAsFixed(0);
      _loadEmiSchedule();
    } else {
      _loadEmiSchedule();
    }
  }

  Future<void> _loadEmiSchedule() async {
    try {
      final schedule =
          await ref.read(emiScheduleProvider(widget.loanId).future);
      final unpaid = schedule
          .where((e) => e.status != cm.EMIStatus.paid &&
              e.status != cm.EMIStatus.waived)
          .toList()
        ..sort((a, b) => a.emiNumber.compareTo(b.emiNumber));

      if (!mounted) return;

      // Default to the current_schedule EMI if available, else the first unpaid
      EMIScheduleModel? defaultSelection;
      if (_loanScheduleId != null) {
        defaultSelection = unpaid
            .where((e) => e.id == _loanScheduleId)
            .firstOrNull;
      }
      defaultSelection ??= unpaid.firstOrNull;

      setState(() {
        _unpaidEMIs = unpaid;
        _selectedEmi = defaultSelection;
        _isLoadingSchedule = false;
      });

      // If we found a default selection and the user hasn't manually edited,
      // update the amount to match
      if (defaultSelection != null && !_hasManuallyEditedAmount) {
        final amt = defaultSelection.emiAmount;
        setState(() {
          _amountExpected = amt;
        });
        _amountController.text = amt.toStringAsFixed(0);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingSchedule = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _referenceController.dispose();
    _remarksController.dispose();
    _backdateReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final collectionState = ref.watch(collectionNotifierProvider);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A14) : const Color(0xFFF5F5F5),
      appBar: _buildAppBar(theme),
      body: SmokeyBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildMemberCard(theme, isDark),
                const SizedBox(height: 20),
                _buildAmountSection(theme, isDark),
                if (!_isLoadingSchedule && _unpaidEMIs.length > 1) ...[
                  const SizedBox(height: 20),
                  _buildEmiSelectorSection(theme, isDark),
                ],
                const SizedBox(height: 20),
                _buildCollectionDateSection(theme, isDark),
                const SizedBox(height: 20),
                _buildPaymentModeSection(theme, isDark),
                const SizedBox(height: 20),
                if (_selectedPaymentMode != cm.PaymentMode.cash) ...[
                  _buildReferenceSection(theme, isDark),
                  const SizedBox(height: 20),
                ],
                _buildRemarksSection(theme, isDark),
                const SizedBox(height: 24),
                _buildSubmitButton(theme, collectionState),
              ].animate(interval: 60.ms).fadeIn().slideY(begin: 0.04, end: 0),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      title: const Text('Record Collection'),
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded),
        onPressed: () => context.pop(),
      ),
    );
  }

  Widget _buildMemberCard(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
              : [
                  AppColors.primary.withValues(alpha: 0.9),
                  AppColors.primaryDark.withValues(alpha: 0.9)
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  _getInitials(_memberName),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _memberName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_memberPhone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.phone_rounded,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _memberPhone,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Expected amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Expected',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  AppFormatters.formatCurrency(_amountExpected),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountSection(ThemeData theme, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumHelpers.sectionHeader(theme, 'Collection Amount',
              icon: Icons.payments_rounded),
          const SizedBox(height: 16),

          // Amount input
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.transactionAmount],
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
              hintText: '0',
              hintStyle: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : theme.colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter amount';
              }
              final amount = double.tryParse(value);
              if (amount == null || amount <= 0) {
                return 'Please enter valid amount';
              }
              return null;
            },
            onChanged: (value) {
              final amount = double.tryParse(value) ?? 0;
              setState(() {
                _hasManuallyEditedAmount = true;
                _isPartial = amount < _amountExpected && amount > 0;
              });
            },
          ),

          // Quick amount buttons
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickAmountButton('Half', _amountExpected / 2),
              _buildQuickAmountButton('Full', _amountExpected),
              _buildQuickAmountButton('Double', _amountExpected * 2),
            ],
          ),

          // Partial payment indicator
          if (_isPartial) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.orangeAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Partial payment - ₹${(_amountExpected - (double.tryParse(_amountController.text) ?? 0)).toStringAsFixed(0)} remaining',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickAmountButton(String label, double amount) {
    final theme = Theme.of(context);

    return ActionChip(
      label: Text('$label (₹${amount.toStringAsFixed(0)})'),
      labelStyle: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: theme.colorScheme.surface,
      side: BorderSide(
        color: AppColors.primary.withValues(alpha: 0.3),
      ),
      onPressed: () {
        HapticFeedback.selectionClick();
        _amountController.text = amount.toStringAsFixed(0);
        setState(() {
          _isPartial = amount < _amountExpected && amount > 0;
        });
      },
    );
  }

  Widget _buildPaymentModeSection(ThemeData theme, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumHelpers.sectionHeader(theme, 'Payment Mode',
              icon: Icons.credit_card_rounded),
          const SizedBox(height: 16),
          Row(
            children: cm.PaymentMode.values
                .map((mode) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: mode != cm.PaymentMode.values.last ? 8 : 0,
                      ),
                      child: _buildPaymentModeButton(mode, theme),
                    ),
                  );
                })
                .take(3)
                .toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: cm.PaymentMode.values.skip(3).map((mode) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: mode != cm.PaymentMode.values.last ? 8 : 0,
                  ),
                  child: _buildPaymentModeButton(mode, theme),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentModeButton(cm.PaymentMode mode, ThemeData theme) {
    final isSelected = _selectedPaymentMode == mode;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedPaymentMode = mode;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.accent.withValues(alpha: 0.08),
                  ],
                )
              : null,
          color: isSelected
              ? null
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : theme.colorScheme.surface),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              _getPaymentIcon(mode),
              color:
                  isSelected ? AppColors.primary : theme.colorScheme.onSurface,
              size: 20,
            ),
            const SizedBox(height: 6),
            Text(
              _getPaymentLabel(mode),
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? AppColors.primary
                    : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPaymentIcon(cm.PaymentMode mode) {
    switch (mode) {
      case cm.PaymentMode.cash:
        return Icons.payments_rounded;
      case cm.PaymentMode.upi:
        return Icons.qr_code_rounded;
      case cm.PaymentMode.bankTransfer:
        return Icons.account_balance_rounded;
      case cm.PaymentMode.cheque:
        return Icons.receipt_long_rounded;
      case cm.PaymentMode.card:
        return Icons.credit_card_rounded;
    }
  }

  String _getPaymentLabel(cm.PaymentMode mode) {
    switch (mode) {
      case cm.PaymentMode.cash:
        return 'CASH';
      case cm.PaymentMode.upi:
        return 'UPI';
      case cm.PaymentMode.bankTransfer:
        return 'BANK';
      case cm.PaymentMode.cheque:
        return 'CHEQUE';
      case cm.PaymentMode.card:
        return 'CARD';
    }
  }

  Widget _buildReferenceSection(ThemeData theme, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumHelpers.sectionHeader(theme, 'Reference Number',
              icon: Icons.tag_rounded),
          const SizedBox(height: 12),
          TextFormField(
            controller: _referenceController,
            decoration: InputDecoration(
              hintText: 'Enter ${_selectedPaymentMode.name} reference',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : theme.colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmiSelectorSection(ThemeData theme, bool isDark) {
    if (_unpaidEMIs.isEmpty) return const SizedBox.shrink();

    final currencyFormat =
        NumberFormat.currency(symbol: '\u20b9', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy');
    bool isOverdue(EMIScheduleModel emi) {
      if (emi.status == cm.EMIStatus.paid || emi.status == cm.EMIStatus.waived) {
        return false;
      }
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return emi.dueDate.isBefore(today);
    }

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumHelpers.sectionHeader(theme, 'EMI Selection',
              icon: Icons.event_repeat_rounded),

          // Selected EMI summary banner
          if (_selectedEmi != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    AppColors.primary.withValues(alpha: 0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  PremiumHelpers.gradientIconContainer(
                    Icons.receipt_long_rounded,
                    AppColors.primary,
                    size: 36,
                    iconSize: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paying EMI #${_selectedEmi!.emiNumber}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${currencyFormat.format(_selectedEmi!.emiAmount)} due on ${dateFormat.format(_selectedEmi!.dueDate)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight)
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // EMI list
          Container(
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey.shade200,
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(4),
              itemCount: _unpaidEMIs.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey.shade200,
              ),
              itemBuilder: (context, index) {
                final emi = _unpaidEMIs[index];
                final isSelected = _selectedEmi?.id == emi.id;
                final overdue = isOverdue(emi);

                final statusColor = overdue
                    ? AppColors.error
                    : (emi.dueDate.day == DateTime.now().day &&
                            emi.dueDate.month == DateTime.now().month &&
                            emi.dueDate.year == DateTime.now().year)
                        ? AppColors.warning
                        : AppColors.info;

                final statusLabel = overdue
                    ? '${DateTime.now().difference(emi.dueDate).inDays}d overdue'
                    : 'Pending';

                return InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedEmi = emi;
                      _loanScheduleId = emi.id;
                      if (!_hasManuallyEditedAmount) {
                        _amountExpected = emi.emiAmount;
                        _amountController.text =
                            emi.emiAmount.toStringAsFixed(0);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.06)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        // Selection indicator
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark
                                      ? Colors.white38
                                      : Colors.grey.shade400),
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  size: 14, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),

                        // EMI info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'EMI #${emi.emiNumber}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? AppColors.primary
                                          : isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Due ${dateFormat.format(emi.dueDate)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Amount
                        Text(
                          currencyFormat.format(emi.emiAmount),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? AppColors.primary
                                : isDark
                                    ? Colors.white70
                                    : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Count info
          if (_unpaidEMIs.length > 1) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '${_unpaidEMIs.length} unpaid EMIs remaining',
                style: TextStyle(
                  fontSize: 12,
                  color: (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight)
                      .withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRemarksSection(ThemeData theme, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumHelpers.sectionHeader(theme, 'Remarks',
              icon: Icons.notes_rounded),
          const SizedBox(height: 12),
          TextFormField(
            controller: _remarksController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Add any notes...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : theme.colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionDateSection(ThemeData theme, bool isDark) {
    final isBackdated = _customCollectionDate != null;
    final dateString = _customCollectionDate != null
        ? DateFormat('dd MMM yyyy').format(_customCollectionDate!)
        : 'Select Date';

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumHelpers.sectionHeader(theme, 'Collection Date',
              icon: Icons.calendar_today_rounded),
          const SizedBox(height: 16),
          Row(
            children: [
              // Today button
              Expanded(
                child: _buildDateTypeButton(
                  isSelected: !isBackdated,
                  label: 'Today',
                  subLabel: DateFormat('dd MMM').format(DateTime.now()),
                  icon: Icons.today_rounded,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _customCollectionDate = null;
                      _backdateReasonController.clear();
                    });
                  },
                  theme: theme,
                ),
              ),
              const SizedBox(width: 12),
              // Custom/Backdate button
              Expanded(
                child: _buildDateTypeButton(
                  isSelected: isBackdated,
                  label: 'Backdate',
                  subLabel: dateString,
                  icon: Icons.edit_calendar_rounded,
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    final DateTime? picked = await PremiumCalendarSheet.show(
                      context: context,
                      initialDate: _customCollectionDate ?? DateTime.now().subtract(const Duration(days: 1)),
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      final now = DateTime.now();
                      final isToday = picked.year == now.year &&
                          picked.month == now.month &&
                          picked.day == now.day;
                      setState(() {
                        if (isToday) {
                          _customCollectionDate = null;
                          _backdateReasonController.clear();
                        } else {
                          _customCollectionDate = picked;
                        }
                      });
                    }
                  },
                  theme: theme,
                ),
              ),
            ],
          ),
          if (isBackdated) ...[
            const SizedBox(height: 16),
            // Reason text field
            TextFormField(
              controller: _backdateReasonController,
              decoration: InputDecoration(
                labelText: 'Reason for Backdating',
                hintText: 'Enter reason (required)...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : theme.colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              validator: (value) {
                if (isBackdated && (value == null || value.trim().isEmpty)) {
                  return 'Please enter a reason for backdating';
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateTypeButton({
    required bool isSelected,
    required String label,
    required String subLabel,
    required IconData icon,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.accent.withValues(alpha: 0.08),
                  ],
                )
              : null,
          color: isSelected
              ? null
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : theme.colorScheme.surface),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : theme.colorScheme.onSurface,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isSelected
                          ? AppColors.primary
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight)
                          .withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(
      ThemeData theme, AsyncValue<CollectionModel?> state) {
    return state.when(
      data: (collection) {
        if (collection != null && !_isSubmitting) {
          // Show success dialog and navigate back
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            HapticService.success();
            final branding = ref.read(brandingProvider).valueOrNull;
            final orgName = branding?.displayName;

            final profile = ref.read(staffProfileProvider).valueOrNull;

            final receiptText = ReceiptGenerator.generateTextReceipt(
              receiptNumber: ReceiptGenerator.generateReceiptNumber(
                staffId: collection.staffId,
                timestamp: collection.collectionTime,
              ),
              collectorName: profile?.fullName ?? 'Agent',
              collectorId: profile?.staffCode ?? collection.staffId,
              customerName: collection.memberName,
              customerPhone: collection.memberPhone,
              loanNumber: collection.loanNumber,
              amountCollected: collection.amountCollected,
              amountExpected: collection.amountExpected,
              paymentMode: collection.paymentMode.name.toUpperCase(),
              collectionTime: collection.collectionTime,
              remarks: collection.remarks,
              orgName: orgName,
            );

            if (!context.mounted) return;

            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => CollectionSuccessDialog(
                receiptText: receiptText,
                receiptNumber: ReceiptGenerator.generateReceiptNumber(
                  staffId: collection.staffId,
                  timestamp: collection.collectionTime,
                ),
                amountCollected: collection.amountCollected,
                customerName: collection.memberName,
                onDone: () {
                  Navigator.pop(ctx);
                  context.pop(true);
                },
              ),
            );
          });
        }

        return SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitCollection,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Record Collection',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
      loading: () => SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
          ),
          child: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          ),
        ),
      ),
      error: (error, _) => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed: ${error.toString()}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitCollection,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh_rounded, size: 22),
                  SizedBox(width: 10),
                  Text('Retry',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitCollection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    // Try to get staff profile first (for collectionAgent/manager)
    // Fall back to current user ID (for executiveAdmin without staff profile)
    String collectorId;

    final profile = await ref.read(staffProfileProvider.future);
    if (profile != null) {
      collectorId = profile.id;
    } else {
      // Executive admin or other user without staff profile
      final authState = ref.read(authStateProvider);
      final user = authState.when(
        data: (user) => user,
        loading: () => null,
        error: (_, __) => null,
      );

      if (user == null) {
        setState(() => _isSubmitting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Error: User not authenticated'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return;
      }

      collectorId = user.id;
    }

    final amountCollected = double.tryParse(_amountController.text) ?? 0;

    // Get current GPS location
    double gpsLat = 0;
    double gpsLng = 0;
    double? gpsAccuracy;

    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentLocation();
      if (position != null) {
        gpsLat = position.latitude;
        gpsLng = position.longitude;
        gpsAccuracy = position.accuracy;
      }
    } catch (e) {
      // GPS failed - show warning but continue
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Warning: Could not get GPS location'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }

    await ref.read(collectionNotifierProvider.notifier).recordCollection(
          staffId: collectorId,
          loanId: widget.loanId,
          loanScheduleId: _loanScheduleId,
          memberId: _memberId,
          memberName: _memberName,
          memberPhone: _memberPhone,
          loanNumber: widget.loanData?['loan_number'],
          amountExpected: _amountExpected,
          amountCollected: amountCollected,
          isPartial: _isPartial,
          paymentMode: _selectedPaymentMode,
          referenceNumber: _referenceController.text.isNotEmpty
              ? _referenceController.text
              : null,
          gpsLat: gpsLat,
          gpsLng: gpsLng,
          gpsAccuracy: gpsAccuracy,
          remarks: _remarksController.text.isNotEmpty
              ? _remarksController.text
              : null,
          outstandingBalance:
              (widget.loanData?['outstanding_amount'] as num?)?.toDouble(),
          collectionDate: _customCollectionDate,
          collectionTime: _customCollectionDate != null
              ? DateTime(
                  _customCollectionDate!.year,
                  _customCollectionDate!.month,
                  _customCollectionDate!.day,
                  DateTime.now().hour,
                  DateTime.now().minute,
                  DateTime.now().second,
                )
              : null,
          backdateReason: _customCollectionDate != null
              ? _backdateReasonController.text.isNotEmpty
                  ? _backdateReasonController.text
                  : null
              : null,
        );

    setState(() => _isSubmitting = false);
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
