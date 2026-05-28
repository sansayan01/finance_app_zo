import 'dart:io';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Premium PDF receipt generation service for customer transactions.
///
/// Generates compact A5 receipts with a polished fintech layout including
/// organization header, transaction details, status badge, and QR placeholder.
class CustomerReceiptService {
  CustomerReceiptService._();

  static final _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');

  /// Manual Indian-style currency grouping (avoids locale initialization issues).
  static String _money(num v) {
    final negative = v < 0;
    final n = v.abs();
    final whole = n.truncate();
    final fraction = ((n - whole) * 100).round();
    final wholeStr = whole.toString();

    String grouped;
    if (wholeStr.length <= 3) {
      grouped = wholeStr;
    } else {
      final last3 = wholeStr.substring(wholeStr.length - 3);
      final rest = wholeStr.substring(0, wholeStr.length - 3);
      final restRev = rest.split('').reversed.join();
      final buf = StringBuffer();
      for (var i = 0; i < restRev.length; i++) {
        if (i > 0 && i % 2 == 0) buf.write(',');
        buf.write(restRev[i]);
      }
      grouped = '${buf.toString().split('').reversed.join()},$last3';
    }
    final fracStr = fraction.toString().padLeft(2, '0');
    return '${negative ? '-' : ''}\u20b9$grouped.$fracStr';
  }

  /// Generates a receipt number from a transaction ID (first 8 chars, uppercase).
  static String _receiptNumber(String transactionId) {
    final clean = transactionId.replaceAll('-', '').toUpperCase();
    return 'RCP-${clean.length >= 8 ? clean.substring(0, 8) : clean}';
  }

  /// Maps raw transaction type to a human-readable label.
  static String _typeLabel(String type) {
    switch (type) {
      case 'emiPayment':
        return 'EMI Payment';
      case 'savingsDeposit':
      case 'deposit':
        return 'Savings Deposit';
      case 'savingsWithdrawal':
      case 'withdrawal':
        return 'Savings Withdrawal';
      case 'loanDisbursement':
        return 'Loan Disbursement';
      case 'collection':
        return 'Collection';
      case 'penalty':
        return 'Penalty';
      default:
        return type.replaceAllMapped(
          RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}',
        ).replaceFirst(type[0], type[0].toUpperCase());
    }
  }

  /// Returns semantic color for the transaction type.
  static PdfColor _typeColor(String type) {
    switch (type) {
      case 'emiPayment':
      case 'collection':
        return PdfColors.indigo800;
      case 'savingsDeposit':
      case 'deposit':
        return PdfColors.teal700;
      case 'loanDisbursement':
        return PdfColors.green800;
      case 'savingsWithdrawal':
      case 'withdrawal':
        return PdfColors.orange800;
      case 'penalty':
        return PdfColors.red800;
      default:
        return PdfColors.blueGrey800;
    }
  }

  /// Generates a premium A5 PDF receipt document.
  static Future<pw.Document> generateReceipt({
    required String transactionId,
    required double amount,
    required String type,
    required DateTime date,
    String? memberName,
    String? paymentMode,
    String? referenceNumber,
    String? description,
    String status = 'synced',
    String orgName = 'MicroFlow Pro',
    String? orgPhone,
    String? orgEmail,
    String? orgAddress,
  }) async {
    final receiptNo = _receiptNumber(transactionId);
    final typeLabel = _typeLabel(type);
    final typeColor = _typeColor(type);
    final isSynced = status.toLowerCase() == 'synced';

    final pdf = pw.Document(
      title: 'Receipt $receiptNo',
      author: orgName,
      creator: orgName,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5.copyWith(
          marginLeft: 28,
          marginRight: 28,
          marginTop: 24,
          marginBottom: 24,
        ),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Organization Header ──
            _buildOrgHeader(orgName, orgPhone, orgEmail, orgAddress),
            pw.SizedBox(height: 16),

            // ── Title Bar ──
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: pw.BoxDecoration(
                color: PdfColors.indigo900,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'PAYMENT RECEIPT',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                  pw.Text(
                    receiptNo,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.indigo200,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // ── Date & Time ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Date: ${_dateTimeFmt.format(date)}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: isSynced ? PdfColors.green50 : PdfColors.orange50,
                    borderRadius: pw.BorderRadius.circular(3),
                    border: pw.Border.all(
                      color: isSynced ? PdfColors.green300 : PdfColors.orange300,
                      width: 0.5,
                    ),
                  ),
                  child: pw.Text(
                    isSynced ? 'SYNCED' : 'PENDING',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: isSynced ? PdfColors.green800 : PdfColors.orange800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            // ── Member Name ──
            if (memberName != null && memberName.isNotEmpty) ...[
              _infoRow('Member', memberName),
              pw.SizedBox(height: 6),
            ],

            // ── Transaction Type ──
            pw.Row(
              children: [
                pw.Text(
                  'Type: ',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: typeColor.shade(0.1),
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Text(
                    typeLabel,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: typeColor,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // ── Amount (Hero) ──
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'AMOUNT',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    _money(amount),
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.indigo900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // ── Details Section ──
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'TRANSACTION DETAILS',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  if (paymentMode != null && paymentMode.isNotEmpty)
                    _infoRow('Payment Mode', _formatPaymentMode(paymentMode)),
                  if (referenceNumber != null && referenceNumber.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    _infoRow('Reference No.', referenceNumber),
                  ],
                  if (description != null && description.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    _infoRow('Description', description),
                  ],
                  pw.SizedBox(height: 4),
                  _infoRow('Transaction ID', transactionId),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // ── QR Code Placeholder ──
            pw.Center(
              child: pw.Container(
                width: 80,
                height: 80,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                alignment: pw.Alignment.center,
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      'QR',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey400,
                      ),
                    ),
                    pw.Text(
                      receiptNo,
                      style: const pw.TextStyle(fontSize: 5, color: PdfColors.grey500),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                'Scan to verify',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
              ),
            ),

            pw.Spacer(),

            // ── Footer ──
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.only(top: 10),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'Thank you for your payment!',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.indigo800,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'This is a computer-generated receipt and does not require a signature.',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    [
                      orgName,
                      if (orgPhone != null && orgPhone.isNotEmpty) 'Tel: $orgPhone',
                      if (orgEmail != null && orgEmail.isNotEmpty) orgEmail,
                    ].join('  |  '),
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return pdf;
  }

  /// Generates the receipt PDF and opens the platform share sheet.
  static Future<void> shareReceipt({
    required String transactionId,
    required double amount,
    required String type,
    required DateTime date,
    String? memberName,
    String? paymentMode,
    String? referenceNumber,
    String? description,
    String status = 'synced',
    String orgName = 'MicroFlow Pro',
    String? orgPhone,
    String? orgEmail,
    String? orgAddress,
  }) async {
    final doc = await generateReceipt(
      transactionId: transactionId,
      amount: amount,
      type: type,
      date: date,
      memberName: memberName,
      paymentMode: paymentMode,
      referenceNumber: referenceNumber,
      description: description,
      status: status,
      orgName: orgName,
      orgPhone: orgPhone,
      orgEmail: orgEmail,
      orgAddress: orgAddress,
    );

    final bytes = await doc.save();
    final receiptNo = _receiptNumber(transactionId);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/receipt_$receiptNo.pdf');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Payment Receipt $receiptNo',
        text: 'Payment receipt for ${_money(amount)} - $receiptNo',
      ),
    );
  }

  /// Generates the receipt PDF and saves it to the device downloads directory.
  static Future<String> downloadReceipt({
    required String transactionId,
    required double amount,
    required String type,
    required DateTime date,
    String? memberName,
    String? paymentMode,
    String? referenceNumber,
    String? description,
    String status = 'synced',
    String orgName = 'MicroFlow Pro',
    String? orgPhone,
    String? orgEmail,
    String? orgAddress,
  }) async {
    final doc = await generateReceipt(
      transactionId: transactionId,
      amount: amount,
      type: type,
      date: date,
      memberName: memberName,
      paymentMode: paymentMode,
      referenceNumber: referenceNumber,
      description: description,
      status: status,
      orgName: orgName,
      orgPhone: orgPhone,
      orgEmail: orgEmail,
      orgAddress: orgAddress,
    );

    final bytes = await doc.save();
    final receiptNo = _receiptNumber(transactionId);

    // Prefer external storage / downloads on mobile, fall back to app documents
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/receipt_$receiptNo.pdf';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    return filePath;
  }

  /// Generates the receipt PDF and opens the native print dialog.
  static Future<void> printReceipt({
    required String transactionId,
    required double amount,
    required String type,
    required DateTime date,
    String? memberName,
    String? paymentMode,
    String? referenceNumber,
    String? description,
    String status = 'synced',
    String orgName = 'MicroFlow Pro',
    String? orgPhone,
    String? orgEmail,
    String? orgAddress,
  }) async {
    final doc = await generateReceipt(
      transactionId: transactionId,
      amount: amount,
      type: type,
      date: date,
      memberName: memberName,
      paymentMode: paymentMode,
      referenceNumber: referenceNumber,
      description: description,
      status: status,
      orgName: orgName,
      orgPhone: orgPhone,
      orgEmail: orgEmail,
      orgAddress: orgAddress,
    );

    final bytes = await doc.save();
    final receiptNo = _receiptNumber(transactionId);

    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'Receipt_$receiptNo',
      format: PdfPageFormat.a5,
    );
  }

  // ── Private PDF helpers ──

  static pw.Widget _buildOrgHeader(
    String name,
    String? phone,
    String? email,
    String? address,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Logo placeholder
        pw.Container(
          width: 40,
          height: 40,
          decoration: pw.BoxDecoration(
            color: PdfColors.indigo100,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          alignment: pw.Alignment.center,
          child: pw.Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'M',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.indigo800,
            ),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                name.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              if (address != null && address.isNotEmpty)
                pw.Text(address, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              if ((phone ?? '').isNotEmpty || (email ?? '').isNotEmpty)
                pw.Text(
                  [
                    if ((phone ?? '').isNotEmpty) 'Tel: $phone',
                    if ((email ?? '').isNotEmpty) email,
                  ].join('  '),
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 90,
          child: pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    );
  }

  static String _formatPaymentMode(String mode) {
    switch (mode.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'upi':
        return 'UPI';
      case 'bank_transfer':
      case 'banktransfer':
        return 'Bank Transfer';
      case 'cheque':
      case 'check':
        return 'Cheque';
      case 'online':
        return 'Online';
      case 'wallet':
        return 'Wallet';
      default:
        return mode.replaceAll('_', ' ').replaceFirst(
          mode[0], mode[0].toUpperCase(),
        );
    }
  }
}
