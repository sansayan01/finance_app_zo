import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/models/statement_org_info.dart';
import '../../../../core/utils/statement_formatters.dart';
import '../models/loan_model.dart';
import '../models/emi_schedule_model.dart';

/// Backward-compatible alias — now backed by the shared [StatementOrgInfo].
typedef LoanStatementOrgInfo = StatementOrgInfo;

class LoanStatementPayment {
  final DateTime date;
  final double amount;
  final String mode;
  final String? referenceNumber;
  final String? notes;
  final String? collectedByName;
  final String? collectedByRole;

  const LoanStatementPayment({
    required this.date,
    required this.amount,
    required this.mode,
    this.referenceNumber,
    this.notes,
    this.collectedByName,
    this.collectedByRole,
  });
}

enum StatementVariant { customerStatement }

class LoanStatementPdfService {
  static final _dateFmt = DateFormat('dd MMM yyyy');

  /// Delegates to shared [StatementFormatters.money].
  static String _money(num v) => StatementFormatters.money(v);

  static String _date(DateTime d) => _dateFmt.format(d);

  static pw.Widget _kv(String k, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 88,
            child: pw.Text(k,
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey700)),
          ),
          pw.Expanded(
            child: pw.Text(v,
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ───── Customer Statement (simple, customer-facing) ─────
  static Future<Uint8List> buildCustomerStatement({
    required LoanModel loan,
    required List<EMIScheduleModel> schedule,
    required List<LoanStatementPayment> payments,
    required LoanStatementOrgInfo org,
    String? generatedByName,
    Uint8List? qrPngBytes,
  }) async {
    final pdf = pw.Document(
      title: 'Repayment Statement - ${loan.loanNumber}',
      author: org.name,
    );

    final sortedPayments = List<LoanStatementPayment>.from(payments)
      ..sort((a, b) => a.date.compareTo(b.date));

    final totalPaid = sortedPayments.fold<double>(0, (s, p) => s + p.amount);
    final emisRemaining = (schedule.length - sortedPayments.length).clamp(0, schedule.length);
    final nextEmi = schedule.skip(sortedPayments.length).toList();

    double runningOutstanding = loan.totalRepayable;
    int idx = 1;
    final tableData = sortedPayments.map((p) {
      runningOutstanding -= p.amount;
      return [
        '${idx++}',
        _date(p.date),
        _money(p.amount),
        p.mode,
        _money(runningOutstanding),
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft: 32,
          marginRight: 32,
          marginTop: 32,
          marginBottom: 36,
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
          ),
          child: pw.Text(
            'Generated on ${_date(DateTime.now())}${generatedByName != null ? ' by $generatedByName' : ''} | ${org.name}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) => [
          // ── Organization Header ──
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (org.logoBytes != null)
                pw.Container(
                  width: 48,
                  height: 48,
                  margin: const pw.EdgeInsets.only(right: 12),
                  child: pw.Image(pw.MemoryImage(org.logoBytes!)),
                ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(org.name.toUpperCase(),
                        style: pw.TextStyle(
                            fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    if (org.fullAddress.isNotEmpty)
                      pw.Text(org.fullAddress,
                          style: const pw.TextStyle(fontSize: 9)),
                    if ((org.phone ?? '').isNotEmpty)
                      pw.Text('Phone: ${org.phone}',
                          style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
              if (qrPngBytes != null)
                pw.Container(
                  width: 48,
                  height: 48,
                  child: pw.Image(pw.MemoryImage(qrPngBytes)),
                ),
            ],
          ),
          pw.SizedBox(height: 16),

          // ── Title ──
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: const pw.BoxDecoration(color: PdfColors.indigo900),
            child: pw.Text('LOAN REPAYMENT STATEMENT',
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    letterSpacing: 0.5)),
          ),
          pw.SizedBox(height: 16),

          // ── Customer & Loan Info (side by side) ──
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CUSTOMER DETAILS',
                          style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey700,
                              letterSpacing: 0.5)),
                      pw.SizedBox(height: 6),
                      _kv('Name', loan.customerName ?? '—'),
                      _kv('Phone', loan.customerPhone ?? '—'),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('LOAN DETAILS',
                          style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey700,
                              letterSpacing: 0.5)),
                      pw.SizedBox(height: 6),
                      _kv('Loan No.', loan.loanNumber),
                      _kv('Principal', _money(loan.amount)),
                      _kv('Interest', '${loan.interestRate}%'),
                      _kv('EMI Amount', _money(loan.emiAmount)),
                      _kv('Total Payable', _money(loan.totalRepayable)),
                      _kv('Start Date', loan.disbursementDate != null
                          ? _date(loan.disbursementDate!)
                          : '—'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // ── Summary Box ──
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              border: pw.Border.all(color: PdfColors.green200),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _summaryItem('Total Paid', _money(totalPaid), PdfColors.green800),
                _summaryItem('Outstanding', _money(loan.outstandingBalance), PdfColors.red800),
                _summaryItem('EMIs Paid', '${sortedPayments.length} / ${schedule.length}', PdfColors.indigo800),
                _summaryItem('Next Due', nextEmi.isNotEmpty ? _date(nextEmi.first.dueDate) : 'Completed', PdfColors.orange800),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // ── Payment History Table ──
          pw.Text('PAYMENT HISTORY',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.5)),
          pw.SizedBox(height: 8),

          if (sortedPayments.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              alignment: pw.Alignment.center,
              child: pw.Text('No payments recorded yet.',
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey600)),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: ['#', 'Date', 'Amount', 'Mode', 'Balance After'],
              data: tableData,
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.indigo800),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
              },
              cellPadding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom:
                      pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                ),
              ),
            ),
          pw.SizedBox(height: 20),

          // ── Upcoming EMIs (next 5) ──
          if (nextEmi.isNotEmpty) ...[
            pw.Text('UPCOMING INSTALLMENTS',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.5)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['#', 'Due Date', 'Amount'],
              data: nextEmi.take(5).map((emi) {
                return [
                  '${emi.emiNumber}',
                  _date(emi.dueDate),
                  _money(emi.emiAmount),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.orange800),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerRight,
              },
              cellPadding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            ),
            if (emisRemaining > 5)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Text(
                    '... and ${emisRemaining - 5} more installments remaining',
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey600)),
              ),
          ],
          pw.SizedBox(height: 24),

          // ── Footer note ──
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Note:',
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text(
                    'This is a computer-generated statement. Please contact us for any discrepancies.',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                if ((org.phone ?? '').isNotEmpty)
                  pw.Text('Contact: ${org.phone}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _summaryItem(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
        pw.SizedBox(height: 2),
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      ],
    );
  }
}
