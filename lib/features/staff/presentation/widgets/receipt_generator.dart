import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

/// Receipt Generator
/// 
/// Generates text receipts for collections that can be shared with customers.
/// No images or heavy files - just clean, printable text.
class ReceiptGenerator {
  static final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  /// Generate a text receipt for a collection
  static String generateTextReceipt({
    required String receiptNumber,
    required String collectorName,
    required String collectorId,
    required String customerName,
    required String? customerPhone,
    required String? loanNumber,
    required double amountCollected,
    required double? amountExpected,
    required String paymentMode,
    required DateTime collectionTime,
    required String? remarks,
    String? branchName,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('══════════════════════════════════════');
    buffer.writeln('          MICROFLOW PRO');
    buffer.writeln('       Collection Receipt');
    buffer.writeln('══════════════════════════════════════');
    buffer.writeln();
    buffer.writeln('Receipt No: $receiptNumber');
    buffer.writeln('Date: ${_dateFormat.format(collectionTime)}');
    buffer.writeln();
    buffer.writeln('────────────────────────────────────────');
    buffer.writeln('COLLECTOR DETAILS');
    buffer.writeln('────────────────────────────────────────');
    buffer.writeln('Name: $collectorName');
    buffer.writeln('ID: $collectorId');
    if (branchName != null) {
      buffer.writeln('Branch: $branchName');
    }
    buffer.writeln();
    buffer.writeln('────────────────────────────────────────');
    buffer.writeln('CUSTOMER DETAILS');
    buffer.writeln('────────────────────────────────────────');
    buffer.writeln('Name: $customerName');
    if (customerPhone != null) {
      buffer.writeln('Phone: $customerPhone');
    }
    if (loanNumber != null) {
      buffer.writeln('Loan No: $loanNumber');
    }
    buffer.writeln();
    buffer.writeln('────────────────────────────────────────');
    buffer.writeln('PAYMENT DETAILS');
    buffer.writeln('────────────────────────────────────────');
    buffer.writeln('Amount Collected: ${_currencyFormat.format(amountCollected)}');
    if (amountExpected != null && amountExpected != amountCollected) {
      buffer.writeln('Amount Expected: ${_currencyFormat.format(amountExpected)}');
      final remaining = amountExpected - amountCollected;
      if (remaining > 0) {
        buffer.writeln('Balance Due: ${_currencyFormat.format(remaining)}');
      }
    }
    buffer.writeln('Payment Mode: $paymentMode');
    buffer.writeln();
    if (remarks != null && remarks.isNotEmpty) {
      buffer.writeln('Remarks: $remarks');
      buffer.writeln();
    }
    buffer.writeln('────────────────────────────────────────');
    buffer.writeln('Thank you for your payment!');
    buffer.writeln('Keep this receipt for your records.');
    buffer.writeln('────────────────────────────────────────');
    buffer.writeln();
    buffer.writeln('For queries, contact your branch.');
    buffer.writeln('══════════════════════════════════════');

    return buffer.toString();
  }

  /// Generate a short SMS-style receipt
  static String generateSmsReceipt({
    required String receiptNumber,
    required String customerName,
    required double amountCollected,
    required String paymentMode,
    required DateTime collectionTime,
  }) {
    return 'MicroFlow Pro: Receipt #$receiptNumber\n'
        'Customer: $customerName\n'
        'Amount: ${_currencyFormat.format(amountCollected)}\n'
        'Mode: $paymentMode\n'
        'Date: ${_dateFormat.format(collectionTime)}\n'
        'Thank you for your payment!';
  }

  /// Generate receipt number
  static String generateReceiptNumber({
    required String staffId,
    required DateTime timestamp,
  }) {
    final dateStr = DateFormat('yyyyMMdd').format(timestamp);
    final timeStr = DateFormat('HHmmss').format(timestamp);
    final staffShort = staffId.length > 4 ? staffId.substring(0, 4) : staffId;
    return 'RCP-$dateStr-$timeStr-$staffShort'.toUpperCase();
  }

  /// Share receipt via system share sheet
  static Future<void> shareReceipt(String receiptText) async {
    await Share.share(
      receiptText,
      subject: 'Collection Receipt - MicroFlow Pro',
    );
  }
}

/// Receipt Preview Widget
class ReceiptPreview extends StatelessWidget {
  final String receiptText;
  final VoidCallback? onShare;
  final VoidCallback? onCopy;

  const ReceiptPreview({
    super.key,
    required this.receiptText,
    this.onShare,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Receipt Content
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!,
                style: BorderStyle.solid,
              ),
            ),
            child: Text(
              receiptText,
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.4,
              ),
              textAlign: TextAlign.left,
            ),
          ),
          const SizedBox(height: 16),
          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: onCopy ?? () => _copyToClipboard(context, receiptText),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy'),
              ),
              ElevatedButton.icon(
                onPressed: onShare ?? () => ReceiptGenerator.shareReceipt(receiptText),
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Share'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Receipt copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }
}

/// Collection Success Dialog with Receipt
class CollectionSuccessDialog extends StatelessWidget {
  final String receiptText;
  final String receiptNumber;
  final double amountCollected;
  final String customerName;
  final VoidCallback onDone;
  final VoidCallback? onNewCollection;

  const CollectionSuccessDialog({
    super.key,
    required this.receiptText,
    required this.receiptNumber,
    required this.amountCollected,
    required this.customerName,
    required this.onDone,
    this.onNewCollection,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              'Collection Successful!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            // Amount
            Text(
              ReceiptGenerator._currencyFormat.format(amountCollected),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
            Text(
              'from $customerName',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Receipt: $receiptNumber',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontFamily: 'Courier',
              ),
            ),
            const SizedBox(height: 20),
            // Receipt Preview
            ReceiptPreview(receiptText: receiptText),
            const SizedBox(height: 20),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDone,
                    child: const Text('Done'),
                  ),
                ),
                if (onNewCollection != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onNewCollection,
                      child: const Text('New Collection'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
