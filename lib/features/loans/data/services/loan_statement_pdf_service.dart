import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/constants/enums.dart';
import '../models/loan_model.dart';
import '../models/emi_schedule_model.dart';class LoanStatementOrgInfo {
  final String name;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? phone;
  final String? email;
  final String? gstNumber;
  final Uint8List? logoBytes;

  const LoanStatementOrgInfo({
    required this.name,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.phone,
    this.email,
    this.gstNumber,
    this.logoBytes,
  });

  String get fullAddress {
    final parts = <String>[
      if (address != null && address!.trim().isNotEmpty) address!.trim(),
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
      if (state != null && state!.trim().isNotEmpty) state!.trim(),
      if (pincode != null && pincode!.trim().isNotEmpty) pincode!.trim(),
    ];
    return parts.join(', ');
  }
}

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

enum StatementVariant { fullSchedule, activityOnly, taxStatement }

class LoanStatementPdfService {
  static final _dateFmt = DateFormat('dd MMM yyyy');

  /// Manual Indian-style grouping so we don't need any locale data loaded
  /// (NumberFormat.currency with locale 'en_IN' throws when intl locale data
  /// isn't initialized, surfacing as "Unexpected null value").
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
    return '${negative ? '-' : ''}Rs. $grouped.$fracStr';
  }

  static String _date(DateTime d) => _dateFmt.format(d);

  /// Returns true only if [bytes] looks like a real PNG or JPEG image.
  /// pw.MemoryImage throws "Unexpected null value" deep inside the renderer
  /// when fed garbage bytes (e.g. empty buffer, SVG, downloaded HTML error
  /// page) — so we sniff the magic numbers before embedding.
  static bool _isValidImage(Uint8List? bytes) {
    if (bytes == null || bytes.length < 8) return false;
    // PNG: 89 50 4E 47 0D 0A 1A 0A
    final isPng = bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
    if (isPng) return true;
    // JPEG: FF D8 FF
    final isJpeg = bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
    return isJpeg;
  }

  static pw.Widget? _safeImage(Uint8List? bytes,
      {required double width, required double height, pw.EdgeInsets? margin}) {
    if (!_isValidImage(bytes)) return null;
    try {
      return pw.Container(
        width: width,
        height: height,
        margin: margin,
        child: pw.Image(pw.MemoryImage(bytes!)),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List> build({
    required LoanModel loan,
    required List<EMIScheduleModel> schedule,
    required List<LoanStatementPayment> payments,
    required LoanStatementOrgInfo org,
    required DateTime periodStart,
    required DateTime periodEnd,
    required StatementVariant variant,
    String? statementRef,
    String? generatedByName,
    Uint8List? qrPngBytes,
  }) async {
    final pdf = pw.Document(
      title: 'Loan Statement ${loan.loanNumber}',
      author: org.name,
      creator: org.name,
      subject: 'Loan Statement',
    );

    final ledger = _buildLedger(
      loan: loan,
      schedule: schedule,
      payments: payments,
      periodStart: periodStart,
      periodEnd: periodEnd,
      variant: variant,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft: 28,
          marginRight: 28,
          marginTop: 28,
          marginBottom: 36,
        ),
        header: (ctx) => ctx.pageNumber == 1
            ? _buildHeader(org, loan, variant, statementRef, periodStart,
                periodEnd, qrPngBytes)
            : _buildRunningHeader(org, loan),
        footer: (ctx) => _buildFooter(ctx, org, statementRef, generatedByName),
        build: (ctx) => [
          if (ctx.pageNumber == 1) ...[
            pw.SizedBox(height: 12),
            _buildCustomerAndLoanBlocks(loan),
            pw.SizedBox(height: 14),
          ] else
            pw.SizedBox(height: 6),
          _buildLedgerTable(ledger),
          pw.SizedBox(height: 12),
          _buildSummaryFooter(loan, ledger),
          if (variant == StatementVariant.taxStatement) ...[
            pw.SizedBox(height: 16),
            _buildTaxBlock(ledger),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  // ───── Header (page 1) ─────
  static pw.Widget _buildHeader(
    LoanStatementOrgInfo org,
    LoanModel loan,
    StatementVariant variant,
    String? statementRef,
    DateTime periodStart,
    DateTime periodEnd,
    Uint8List? qrPngBytes,
  ) {
    final logoWidget = _safeImage(org.logoBytes,
        width: 56,
        height: 56,
        margin: const pw.EdgeInsets.only(right: 12));
    final qrWidget =
        _safeImage(qrPngBytes, width: 56, height: 56);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logoWidget != null) logoWidget,
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    org.name.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (org.fullAddress.isNotEmpty)
                    pw.Text(org.fullAddress,
                        style: const pw.TextStyle(fontSize: 9)),
                  if ((org.phone ?? '').isNotEmpty ||
                      (org.email ?? '').isNotEmpty)
                    pw.Text(
                      [
                        if ((org.phone ?? '').isNotEmpty) 'Tel: ${org.phone}',
                        if ((org.email ?? '').isNotEmpty) 'Email: ${org.email}',
                      ].join('  '),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  if ((org.gstNumber ?? '').isNotEmpty)
                    pw.Text('GSTIN: ${org.gstNumber}',
                        style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ),
            if (qrWidget != null) qrWidget,
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(_variantTitle(variant),
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                'Period: ${_date(periodStart)}  –  ${_date(periodEnd)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
        if (statementRef != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text('Statement Ref: $statementRef',
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey700)),
          ),
      ],
    );
  }

  static pw.Widget _buildRunningHeader(
      LoanStatementOrgInfo org, LoanModel loan) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(org.name,
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text('Loan No: ${loan.loanNumber}',
              style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  // ───── Customer + Loan summary ─────
  static pw.Widget _buildCustomerAndLoanBlocks(LoanModel loan) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _labeledBlock('Customer', [
            _kv('Name', loan.customerName ?? '—'),
            _kv('Phone', loan.customerPhone ?? '—'),
            _kv('Customer ID', loan.customerId),
          ]),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _labeledBlock('Loan', [
            _kv('Loan No.', loan.loanNumber),
            _kv('Principal', _money(loan.amount)),
            _kv('Interest Rate', '${loan.interestRate}% (${loan.interestType.name})'),
            _kv('Tenure', loan.formattedTenure),
            _kv('EMI', _money(loan.emiAmount)),
            _kv('Total Repayable', _money(loan.totalRepayable)),
            _kv('Disbursed', loan.disbursementDate != null
                ? _date(loan.disbursementDate!)
                : '—'),
            _kv('Status', loan.status.name.toUpperCase()),
          ]),
        ),
      ],
    );
  }

  static pw.Widget _labeledBlock(String title, List<pw.Widget> rows) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title.toUpperCase(),
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.5,
                  color: PdfColors.grey700)),
          pw.SizedBox(height: 6),
          ...rows,
        ],
      ),
    );
  }

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

  // ───── Ledger build + table ─────
  static _LedgerResult _buildLedger({
    required LoanModel loan,
    required List<EMIScheduleModel> schedule,
    required List<LoanStatementPayment> payments,
    required DateTime periodStart,
    required DateTime periodEnd,
    required StatementVariant variant,
  }) {
    final rows = <_LedgerRow>[];
    double balance = loan.amount;
    double totalDebit = 0;
    double totalCredit = 0;
    double totalInterestPaid = 0;
    double totalPrincipalPaid = 0;

    // Disbursement row
    if (loan.disbursementDate != null &&
        !loan.disbursementDate!.isBefore(periodStart) &&
        !loan.disbursementDate!.isAfter(periodEnd)) {
      rows.add(_LedgerRow(
        date: loan.disbursementDate!,
        emiNumber: null,
        description: 'Loan disbursement',
        debit: loan.amount,
        credit: 0,
        balance: balance,
      ));
      totalDebit += loan.amount;
    }

    // Merge schedule + payments chronologically
    final activityOnly = variant != StatementVariant.fullSchedule;

    for (final emi in schedule) {
      // EMI scheduled (debit interest+principal as a single row)
      final inPeriod = !emi.dueDate.isBefore(periodStart) &&
          !emi.dueDate.isAfter(periodEnd);

      if (!activityOnly && inPeriod) {
        rows.add(_LedgerRow(
          date: emi.dueDate,
          emiNumber: emi.emiNumber,
          description: 'EMI #${emi.emiNumber} due (P: ${_money(emi.principal)}, I: ${_money(emi.interest)})',
          debit: 0,
          credit: 0,
          balance: balance,
          isSchedule: true,
          status: emi.status,
        ));
      }

      if (emi.paidOn != null) {
        final paidInPeriod = !emi.paidOn!.isBefore(periodStart) &&
            !emi.paidOn!.isAfter(periodEnd);
        if (paidInPeriod) {
          balance -= emi.principal;
          totalCredit += emi.emiAmount;
          totalInterestPaid += emi.interest;
          totalPrincipalPaid += emi.principal;
          rows.add(_LedgerRow(
            date: emi.paidOn!,
            emiNumber: emi.emiNumber,
            description:
                'EMI #${emi.emiNumber} paid via ${emi.paymentMode?.name ?? 'cash'} '
                '(P: ${_money(emi.principal)}, I: ${_money(emi.interest)})',
            debit: 0,
            credit: emi.emiAmount,
            balance: balance,
            isPayment: true,
          ));
        }
      }
    }

    // Free-form payments not tied to a schedule row
    for (final p in payments) {
      final inPeriod = !p.date.isBefore(periodStart) &&
          !p.date.isAfter(periodEnd);
      if (!inPeriod) continue;
      final alreadyCounted = schedule.any((e) {
        final paidOn = e.paidOn;
        if (paidOn == null) return false;
        return paidOn.difference(p.date).inMinutes.abs() < 1 &&
            (e.emiAmount - p.amount).abs() < 0.01;
      });
      if (alreadyCounted) continue;
      balance -= p.amount;
      totalCredit += p.amount;
      rows.add(_LedgerRow(
        date: p.date,
        emiNumber: null,
        description:
            'Payment via ${p.mode}${p.referenceNumber != null ? ' (Ref: ${p.referenceNumber})' : ''}'
            '${p.collectedByName != null ? ' - by ${p.collectedByName}${p.collectedByRole != null ? ' (${p.collectedByRole})' : ''}' : ''}',
        debit: 0,
        credit: p.amount,
        balance: balance,
        isPayment: true,
      ));
    }

    rows.sort((a, b) => a.date.compareTo(b.date));

    return _LedgerResult(
      rows: rows,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      totalInterestPaid: totalInterestPaid,
      totalPrincipalPaid: totalPrincipalPaid,
      closingBalance: balance,
    );
  }

  static pw.Widget _buildLedgerTable(_LedgerResult ledger) {
    final headers = ['Date', 'EMI#', 'Description', 'Debit', 'Credit', 'Balance'];
    final data = ledger.rows.map((r) {
      return [
        _date(r.date),
        r.emiNumber?.toString() ?? '—',
        r.description,
        r.debit > 0 ? _money(r.debit) : '',
        r.credit > 0 ? _money(r.credit) : '',
        _money(r.balance),
      ];
    }).toList();

    if (data.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(20),
        alignment: pw.Alignment.center,
        child: pw.Text('No activity in the selected period.',
            style: const pw.TextStyle(
                fontSize: 11, color: PdfColors.grey600)),
      );
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
      columnWidths: {
        0: const pw.FlexColumnWidth(2.0),
        1: const pw.FlexColumnWidth(0.8),
        2: const pw.FlexColumnWidth(5.0),
        3: const pw.FlexColumnWidth(1.8),
        4: const pw.FlexColumnWidth(1.8),
        5: const pw.FlexColumnWidth(2.0),
      },
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.3),
        ),
      ),
    );
  }

  static pw.Widget _buildSummaryFooter(LoanModel loan, _LedgerResult ledger) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _kv('Total Debit', _money(ledger.totalDebit)),
                _kv('Total Credit', _money(ledger.totalCredit)),
                _kv('Principal Paid', _money(ledger.totalPrincipalPaid)),
                _kv('Interest Paid', _money(ledger.totalInterestPaid)),
              ],
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.blueGrey800,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('CURRENT OUTSTANDING',
                    style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.5)),
                pw.SizedBox(height: 4),
                pw.Text(_money(loan.outstandingBalance),
                    style: pw.TextStyle(
                        fontSize: 16,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTaxBlock(_LedgerResult ledger) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('TAX STATEMENT SUMMARY',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.5)),
          pw.SizedBox(height: 6),
          _kv('Interest Paid (deductible under applicable sections)',
              _money(ledger.totalInterestPaid)),
          _kv('Principal Repaid', _money(ledger.totalPrincipalPaid)),
          pw.SizedBox(height: 6),
          pw.Text(
            'This is a computer-generated summary of interest and principal '
            'paid during the selected period. Please consult a tax advisor '
            'for filing eligibility.',
            style: const pw.TextStyle(
                fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(
    pw.Context ctx,
    LoanStatementOrgInfo org,
    String? statementRef,
    String? generatedByName,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                  'This is a computer-generated statement and does not require a signature.',
                  style: const pw.TextStyle(
                      fontSize: 7.5, color: PdfColors.grey600)),
              if (generatedByName != null)
                pw.Text('Generated by: $generatedByName',
                    style: const pw.TextStyle(
                        fontSize: 7.5, color: PdfColors.grey600)),
              if (statementRef != null)
                pw.Text('Ref: $statementRef',
                    style: const pw.TextStyle(
                        fontSize: 7.5, color: PdfColors.grey600)),
            ],
          ),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(
                  fontSize: 8, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  static String _variantTitle(StatementVariant v) {
    switch (v) {
      case StatementVariant.fullSchedule:
        return 'LOAN STATEMENT — FULL SCHEDULE';
      case StatementVariant.activityOnly:
        return 'LOAN STATEMENT — ACTIVITY ONLY';
      case StatementVariant.taxStatement:
        return 'LOAN STATEMENT — TAX SUMMARY';
    }
  }
}

class _LedgerRow {
  final DateTime date;
  final int? emiNumber;
  final String description;
  final double debit;
  final double credit;
  final double balance;
  final bool isSchedule;
  final bool isPayment;
  final EMIStatus? status;

  _LedgerRow({
    required this.date,
    required this.emiNumber,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
    this.isSchedule = false,
    this.isPayment = false,
    this.status,
  });
}

class _LedgerResult {
  final List<_LedgerRow> rows;
  final double totalDebit;
  final double totalCredit;
  final double totalInterestPaid;
  final double totalPrincipalPaid;
  final double closingBalance;

  _LedgerResult({
    required this.rows,
    required this.totalDebit,
    required this.totalCredit,
    required this.totalInterestPaid,
    required this.totalPrincipalPaid,
    required this.closingBalance,
  });
}
