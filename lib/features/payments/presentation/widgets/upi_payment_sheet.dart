import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/services/upi_service.dart';
import '../../data/providers/upi_providers.dart';
import '../../../loans/data/services/qr_png.dart';

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
      ),
    );
  }

  @override
  ConsumerState<UpiPaymentSheet> createState() => _UpiPaymentSheetState();
}

class _UpiPaymentSheetState extends ConsumerState<UpiPaymentSheet> {
  bool _isProcessing = false;
  bool _hasPaid = false;
  Uint8List? _qrBytes;
  String? _upiUri;
  String? _vpa;

  @override
  void initState() {
    super.initState();
    _loadVpa();
  }

  Future<void> _loadVpa() async {
    final upiService = ref.read(upiServiceProvider);
    final vpaData = await upiService.getOrgVpa();
    if (vpaData == null || !mounted) return;

    final vpa = vpaData['upi_vpa'] as String?;
    final merchantName = vpaData['merchant_name'] as String? ?? '';
    if (vpa == null || vpa.isEmpty) return;

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
  }

  String _buildTransactionNote() {
    if (widget.loanId != null && widget.emiNumber != null) {
      return 'Loan ${widget.loanNumber ?? ''} EMI #${widget.emiNumber}';
    }
    if (widget.savingsPlanId != null && widget.installmentNumber != null) {
      return 'Savings ${widget.savingsPlanName ?? ''} Inst #${widget.installmentNumber}';
    }
    return 'Payment';
  }

  Future<void> _openUpiApp() async {
    if (_upiUri == null) return;
    final uri = Uri.parse(_upiUri!);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No UPI app found. Please install Google Pay, PhonePe, or Paytm.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _confirmPaid() async {
    if (_isProcessing || _vpa == null) return;
    setState(() => _isProcessing = true);

    try {
      final repository = ref.read(upiRepositoryProvider);
      await repository.createRequest(
        customerId: '',
        memberId: widget.memberId,
        loanId: widget.loanId,
        savingsPlanId: widget.savingsPlanId,
        emiScheduleId: widget.emiScheduleId,
        amount: widget.amount,
        upiVpa: _vpa!,
      );

      if (mounted) {
        setState(() => _hasPaid = true);
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

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  color: Colors.grey[300],
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
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              if (_qrBytes != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Image.memory(
                    _qrBytes!,
                    width: 200,
                    height: 200,
                  ),
                )
              else
                const SizedBox(
                  width: 200,
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
              const SizedBox(height: 12),
              if (_vpa != null)
                Text(
                  'VPA: $_vpa',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                _buildTransactionNote(),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _upiUri != null ? _openUpiApp : null,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open UPI App'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (!_hasPaid)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _confirmPaid,
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Payment submitted for verification',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
