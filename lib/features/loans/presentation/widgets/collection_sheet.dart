import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/loan_providers.dart' hide loanSummaryProvider;
import '../../data/models/emi_schedule_model.dart';
import '../../data/models/loan_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../home/data/providers/dashboard_providers.dart'
    show dashboardLoansProvider, activeLoansProvider, loanSummaryProvider;

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
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  PaymentMode _selectedMode = PaymentMode.cash;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.emi?.emiAmount.toStringAsFixed(2) ??
        widget.loan.emiAmount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final repository = ref.read(emiRepositoryProvider);
      final user = ref.read(currentUserProvider);

      final amount = double.tryParse(_amountController.text) ?? 0;
      if (amount <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a valid amount')),
          );
        }
        return;
      }

      if (widget.emi != null) {
        // Record payment against specific EMI
        await repository.recordPayment(
          emiId: widget.emi!.id,
          loanId: widget.loan.id,
          amount: amount,
          paymentMode: _selectedMode.name,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          agentId: user?.id,
        );
      } else {
        // Record payment without EMI schedule (manual collection)
        await repository.recordManualPayment(
          loanId: widget.loan.id,
          amount: amount,
          paymentMode: _selectedMode.name,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          agentId: user?.id,
        );
      }

      // Invalidate providers to refresh UI
      ref.invalidate(emiScheduleProvider(widget.loan.id));
      ref.invalidate(loanDetailProvider(widget.loan.id));
      ref.invalidate(loansProvider);
      ref.invalidate(dashboardLoansProvider);
      ref.invalidate(activeLoansProvider);
      ref.invalidate(loanSummaryProvider);

      if (mounted) {
        Navigator.pop(context);
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Collected ${AppFormatters.formatCurrency(amount)} successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Collection failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    final primary = theme.colorScheme.primary;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            AppSpacing.xxl +
            20, // Extra buffer for custom bottom bars
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.emi != null
                          ? 'Collect Installment'
                          : 'Collect Payment',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      widget.emi != null
                          ? 'EMI #${widget.emi!.emiNumber} · ${widget.loan.loanNumber}'
                          : '${widget.loan.loanNumber} · Manual Collection',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // EMI Info Card or Loan Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primary.withValues(alpha: 0.15)),
              ),
              child: widget.emi != null
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Due Date',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.emi!.dueDate.day}/${widget.emi!.dueDate.month}/${widget.emi!.dueDate.year}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Expected Amount',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppFormatters.formatCurrency(
                                  widget.emi!.emiAmount),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Outstanding Balance',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppFormatters.formatCurrency(
                                  widget.loan.status == LoanStatus.closed
                                      ? 0.0
                                      : widget.loan.outstandingBalance),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'EMI Amount',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppFormatters.formatCurrency(
                                  widget.loan.emiAmount),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Text(
              'COLLECTION AMOUNT',
              style: theme.textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w900, color: primary),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: theme.textTheme.headlineSmall
                    ?.copyWith(color: primary, fontWeight: FontWeight.w900),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.red),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'PAYMENT MODE',
              style: theme.textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildModeOption(PaymentMode.cash, Icons.payments_outlined),
                const SizedBox(width: 12),
                _buildModeOption(PaymentMode.upi, Icons.qr_code_2_rounded),
                const SizedBox(width: 12),
                _buildModeOption(
                    PaymentMode.bankTransfer, Icons.account_balance_rounded),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'NOTES (OPTIONAL)',
              style: theme.textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Add a note about this collection...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Confirm Collection',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption(PaymentMode mode, IconData icon) {
    final isSelected = _selectedMode == mode;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? primary.withValues(alpha: 0.1)
                : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? primary
                  : theme.dividerColor.withValues(alpha: 0.2),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? primary : theme.colorScheme.onSurface,
                  size: 24),
              const SizedBox(height: 8),
              Text(
                mode.name.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected ? primary : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
