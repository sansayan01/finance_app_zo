import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/services/upi_service.dart';
import '../../data/providers/upi_providers.dart';
import '../../../loans/data/services/qr_png.dart';
import '../../../customer_portal/data/providers/customer_home_providers.dart';

class UpiPaymentSheet extends ConsumerStatefulWidget {
  final double amount;
  final String? loanId;
  final String? savingsPlanId;
  final String? emiScheduleId;
  final String? loanNumber;
  final int? emiNumber;
  final String? savingsPlanName;
  final int? installmentNumber;
  final String? memberId;
  final List<String>? emiScheduleIds;
  final List<double>? emiAmounts;
  final List<String>? savingsDateKeys;
  final List<double>? savingsAmounts;
  /// Optional per-installment due date matching each entry in
  /// [emiScheduleIds] / [savingsDateKeys] (length must match the
  /// corresponding ids list). Saved on each UPI payment request so
  /// the staff confirmations page can show the actual date the
  /// customer was paying for.
  final List<DateTime>? installmentDates;
  final String? transactionNoteOverride;

  const UpiPaymentSheet({
    super.key,
    required this.amount,
    this.loanId,
    this.savingsPlanId,
    this.emiScheduleId,
    this.loanNumber,
    this.emiNumber,
    this.savingsPlanName,
    this.installmentNumber,
    this.memberId,
    this.emiScheduleIds,
    this.emiAmounts,
    this.savingsDateKeys,
    this.savingsAmounts,
    this.installmentDates,
    this.transactionNoteOverride,
  });

  static Future<void> show(
    BuildContext context, {
    required double amount,
    String? loanId,
    String? savingsPlanId,
    String? emiScheduleId,
    String? loanNumber,
    int? emiNumber,
    String? savingsPlanName,
    int? installmentNumber,
    String? memberId,
    List<String>? emiScheduleIds,
    List<double>? emiAmounts,
    List<String>? savingsDateKeys,
    List<double>? savingsAmounts,
    List<DateTime>? installmentDates,
    String? transactionNoteOverride,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UpiPaymentSheet(
        amount: amount,
        loanId: loanId,
        savingsPlanId: savingsPlanId,
        emiScheduleId: emiScheduleId,
        loanNumber: loanNumber,
        emiNumber: emiNumber,
        savingsPlanName: savingsPlanName,
        installmentNumber: installmentNumber,
        memberId: memberId,
        emiScheduleIds: emiScheduleIds,
        emiAmounts: emiAmounts,
        savingsDateKeys: savingsDateKeys,
        savingsAmounts: savingsAmounts,
        installmentDates: installmentDates,
        transactionNoteOverride: transactionNoteOverride,
      ),
    );
  }

  @override
  ConsumerState<UpiPaymentSheet> createState() => _UpiPaymentSheetState();
}

class _UpiPaymentSheetState extends ConsumerState<UpiPaymentSheet> {
  bool _isProcessing = false;
  bool _hasPaid = false;
  bool _vpaLoadError = false;
  Uint8List? _qrBytes;
  String? _upiUri;
  String? _vpa;

  @override
  void initState() {
    super.initState();
    _loadVpa();
  }

  Future<void> _loadVpa() async {
    try {
      final upiService = ref.read(upiServiceProvider);
      final vpaData = await upiService.getOrgVpa();
      if (vpaData == null || !mounted) return;

      final vpa = vpaData['upi_vpa'] as String?;
      final merchantName = vpaData['merchant_name'] as String? ?? '';
      if (vpa == null || vpa.isEmpty) {
        if (mounted) setState(() => _vpaLoadError = true);
        return;
      }

      final note = _buildTransactionNote();
      final uri = UpiService.buildUpiUri(
        vpa: vpa,
        amount: widget.amount,
        merchantName: merchantName,
        transactionNote: note,
      );

      final qr = await QrPng.generate(uri, size: 250);

      if (mounted) {
        setState(() {
          _vpa = vpa;
          _upiUri = uri;
          _qrBytes = qr;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _vpaLoadError = true);
    }
  }

  String _buildTransactionNote() {
    if (widget.transactionNoteOverride != null) {
      return widget.transactionNoteOverride!;
    }
    if (widget.loanId != null && widget.emiNumber != null) {
      return 'Loan ${widget.loanNumber ?? ''} EMI #${widget.emiNumber}';
    }
    if (widget.savingsPlanId != null && widget.installmentNumber != null) {
      return 'Savings ${widget.savingsPlanName ?? ''} Inst #${widget.installmentNumber}';
    }
    return 'Payment';
  }

  Widget _buildGuidanceRow(IconData icon, String text, {required bool isDark}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.blue[400], size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : const Color(0xFF666666),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openUpiApp() async {
    if (_upiUri == null) return;
    final uri = Uri.parse(_upiUri!);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No UPI app found. You can scan the QR code or tap "I\'ve Paid" after paying via any UPI app.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _confirmPaid() async {
    if (_isProcessing || _vpa == null) return;

    // Validate amount
    if (widget.amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid amount. Please go back and try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final repository = ref.read(upiRepositoryProvider);

      // RLS INSERT policy requires customer_id = auth.uid().
      // Always use auth.uid() — memberId is for display only.
      final customerId =
          Supabase.instance.client.auth.currentUser?.id ?? '';

      if (customerId.isEmpty) {
        throw Exception('Unable to identify customer. Please re-login and try again.');
      }

      final hasBatchEmis = widget.emiScheduleIds != null && widget.emiScheduleIds!.isNotEmpty;
      final hasBatchSavings = widget.savingsDateKeys != null && widget.savingsDateKeys!.isNotEmpty;

      // Per-installment due date — either provided directly by the caller
      // (loan quick pay) or derived from the savings dateKey list
      // (savings quick pay: 'YYYY-MM-DD').
      DateTime? dateFor(int i) {
        if (widget.installmentDates != null && i < widget.installmentDates!.length) {
          return widget.installmentDates![i];
        }
        if (hasBatchSavings && i < widget.savingsDateKeys!.length) {
          return DateTime.tryParse(widget.savingsDateKeys![i]);
        }
        return null;
      }

      if (hasBatchEmis) {
        for (var i = 0; i < widget.emiScheduleIds!.length; i++) {
          await repository.createRequest(
            customerId: customerId,
            memberId: widget.memberId,
            loanId: widget.loanId,
            emiScheduleId: widget.emiScheduleIds![i],
            amount: widget.emiAmounts![i],
            upiVpa: _vpa!,
            installmentDate: dateFor(i),
          );
        }
        // Notify staff once for the entire batch (fire-and-forget)
        repository.notifyStaffUpiPayment(
          totalAmount: widget.amount,
          typeLabel: 'Loan EMI',
        );
      } else if (hasBatchSavings) {
        for (var i = 0; i < widget.savingsDateKeys!.length; i++) {
          await repository.createRequest(
            customerId: customerId,
            memberId: widget.memberId,
            savingsPlanId: widget.savingsPlanId,
            amount: widget.savingsAmounts![i],
            upiVpa: _vpa!,
            installmentDate: dateFor(i),
          );
        }
        // Notify staff once for the entire batch (fire-and-forget)
        repository.notifyStaffUpiPayment(
          totalAmount: widget.amount,
          typeLabel: 'Savings',
        );
      } else {
        await repository.createRequest(
          customerId: customerId,
          memberId: widget.memberId,
          loanId: widget.loanId,
          savingsPlanId: widget.savingsPlanId,
          emiScheduleId: widget.emiScheduleId,
          amount: widget.amount,
          upiVpa: _vpa!,
        );
        // Notify staff (fire-and-forget)
        final typeLabel = widget.loanId != null ? 'Loan EMI' : 'Savings';
        repository.notifyStaffUpiPayment(
          totalAmount: widget.amount,
          typeLabel: typeLabel,
        );
      }

      if (mounted) {
        setState(() => _hasPaid = true);
        // Refresh customer transaction list so pending payment appears
        ref.invalidate(customerRecentTransactionsProvider);
        ref.invalidate(customerAllTransactionsProvider);
        ref.invalidate(customerDashboardProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment submitted for verification'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final sheetColor = isDark ? const Color(0xFF1E2230) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white54 : Colors.grey;
    final borderColor = isDark ? Colors.white12 : Colors.grey[200]!;

    return Container(
      decoration: BoxDecoration(
        color: sheetColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Pay via UPI',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '₹${widget.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 20),

              // QR Code area
              if (_vpaLoadError)
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: AppColors.error, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        'Unable to load QR',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _vpaLoadError = false;
                            _qrBytes = null;
                            _upiUri = null;
                            _vpa = null;
                          });
                          _loadVpa();
                        },
                        child: Text(
                          'Tap to retry',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_qrBytes != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: sheetColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Image.memory(
                    _qrBytes!,
                    width: 200,
                    height: 200,
                  ),
                )
              else
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              if (_vpa != null)
                Text(
                  'VPA: $_vpa',
                  style: TextStyle(
                    fontSize: 14,
                    color: subtitleColor,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                _buildTransactionNote(),
                style: TextStyle(
                  fontSize: 13,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 24),

              // Open UPI App — disabled after payment
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: (!_hasPaid && _upiUri != null) ? _openUpiApp : null,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open UPI App'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // "I've Paid" button OR success message
              if (!_hasPaid)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: (_isProcessing || _vpa == null) ? null : _confirmPaid,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(_isProcessing ? 'Submitting...' : "I've Paid"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      disabledForegroundColor: Colors.green.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'Payment submitted for verification',
                            style: TextStyle(
                              color: isDark ? Colors.greenAccent : Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.12)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'What happens next?',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.lightBlueAccent : Colors.blue,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildGuidanceRow(
                            Icons.access_time,
                            'A staff member will verify your payment',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 8),
                          _buildGuidanceRow(
                            Icons.check_circle_outline,
                            'Once confirmed, it will appear in your transaction history',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 8),
                          _buildGuidanceRow(
                            Icons.help_outline,
                            'You can check status in your transaction page',
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
