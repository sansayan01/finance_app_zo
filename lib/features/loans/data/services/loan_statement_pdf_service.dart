import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/constants/enums.dart';
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

enum StatementVariant { fullSchedule, activityOnly, taxStatement, customerStatement }

class LoanStatementPdfService {
  static final _dateFmt = DateFormat('dd MMM yyyy');

  /// Manual Indian-style grouping so we don't need any locale data loaded
  /// (NumberFormat.currency with locale 'en_IN' throws when intl locale data
  /// isn't initialized, surfacing as "Unexpected null value").
  /// Delegates to shared [StatementFormatters.money].
  static String _money(num v) => StatementFormatters.money(v);

  static String _date(DateTime d) => _dateFmt.format(d);

  /// Delegates to shared [StatementFormatters.isValidImage].
  static bool _isValidImage(Uint8List? bytes) =>
      StatementFormatters.isValidImage(bytes);

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

    final header1 = _buildHeader(
        org, loan, variant, statementRef, periodStart, periodEnd, qrPngBytes);
    final headerN = _buildRunningHeader(org, loan);
    final customerBlock = _buildCustomerAndLoanBlocks(loan);
    final ledgerTable = _buildLedgerTable(ledger);
    final summary = _buildSummaryFooter(loan, ledger);

    // IMPORTANT: ctx.pageNumber cannot be used inside the build callback.
    // MultiPage's first layout pass calls build with a context that has
    // no page assigned yet (_page is null), so accessing pageNumber
    // crashes with "Null check operator used on a null value".
    // Header/footer callbacks DO get a valid page context.

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft: 28,
          marginRight: 28,
          marginTop: 28,
          marginBottom: 36,
        ),
        header: (ctx) => ctx.pageNumber == 1 ? header1 : headerN,
        footer: (ctx) =>
            _buildFooter(ctx, org, statementRef, generatedByName),
        build: (ctx) => [
          pw.SizedBox(height: 12),
          customerBlock,
          pw.SizedBox(height: 14),
          ledgerTable,
          pw.SizedBox(height: 12),
          summary,
          if (variant == StatementVariant.taxStatement) ...[
            pw.SizedBox(height: 16),
            _buildTaxBlock(ledger, org, periodStart, periodEnd),
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
    double totalPenalties = 0;
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
          // Track penalties
          if (emi.penaltyAmount > 0) {
            totalPenalties += emi.penaltyAmount;
            totalCredit += emi.penaltyAmount;
          }
          rows.add(_LedgerRow(
            date: emi.paidOn!,
            emiNumber: emi.emiNumber,
            description:
                'EMI #${emi.emiNumber} paid via ${emi.paymentMode?.name ?? 'cash'} '
                '(P: ${_money(emi.principal)}, I: ${_money(emi.interest)})',
            debit: 0,
            credit: emi.emiAmount,
            penalty: emi.penaltyAmount,
            balance: balance,
            isPayment: true,
          ));
        }
      } else if (emi.penaltyAmount > 0 && !emi.penaltyPaid) {
        // Unpaid penalty on a pending/overdue EMI — add a penalty row.
        totalPenalties += emi.penaltyAmount;
        rows.add(_LedgerRow(
          date: emi.dueDate,
          emiNumber: emi.emiNumber,
          description: 'Late fee / penalty — EMI #${emi.emiNumber}',
          debit: 0,
          credit: 0,
          penalty: emi.penaltyAmount,
          balance: balance + emi.penaltyAmount,
          isPenalty: true,
          status: emi.status,
        ));
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
      totalPenalties: totalPenalties,
      closingBalance: balance,
    );
  }

  static pw.Widget _buildLedgerTable(_LedgerResult ledger) {
    final headers = ['Date', 'EMI#', 'Description', 'Debit', 'Credit', 'Penalty', 'Balance'];
    final data = ledger.rows.map((r) {
      return [
        _date(r.date),
        r.emiNumber?.toString() ?? '—',
        r.description,
        r.debit > 0 ? _money(r.debit) : '',
        r.credit > 0 ? _money(r.credit) : '',
        r.penalty > 0 ? _money(r.penalty) : '',
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
        6: pw.Alignment.centerRight,
      },
      columnWidths: {
        0: const pw.FlexColumnWidth(1.8),
        1: const pw.FlexColumnWidth(0.7),
        2: const pw.FlexColumnWidth(4.2),
        3: const pw.FlexColumnWidth(1.6),
        4: const pw.FlexColumnWidth(1.6),
        5: const pw.FlexColumnWidth(1.4),
        6: const pw.FlexColumnWidth(1.8),
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
                if (ledger.totalPenalties > 0)
                  _kv('Penalties', _money(ledger.totalPenalties)),
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

  static pw.Widget _buildTaxBlock(
      _LedgerResult ledger, LoanStatementOrgInfo org,
      DateTime periodStart, DateTime periodEnd) {
    // Derive Indian financial year from period end date.
    final fyEndYear = periodEnd.month >= 4 ? periodEnd.year : periodEnd.year - 1;
    final fy = 'FY $fyEndYear-${(fyEndYear + 1).toString().substring(2)}';

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
          _kv('Financial Year', fy),
          _kv('Period', '${StatementFormatters.date(periodStart)} – ${StatementFormatters.date(periodEnd)}'),
          if (org.gstNumber != null && org.gstNumber!.isNotEmpty)
            _kv('GSTIN / TAN', org.gstNumber!),
          pw.SizedBox(height: 6),
          pw.Text('INTEREST & PRINCIPAL SUMMARY',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          _kv('Interest Paid (deductible under applicable sections)',
              _money(ledger.totalInterestPaid)),
          _kv('Principal Repaid', _money(ledger.totalPrincipalPaid)),
          if (ledger.totalPenalties > 0)
            _kv('Late Fees / Penalties', _money(ledger.totalPenalties)),
          pw.SizedBox(height: 6),
          pw.Text('APPLICABLE SECTIONS',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          pw.Text(
            '• Section 80C — Principal repayment (up to ₹1,50,000 per FY)',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.Text(
            '• Section 80E — Interest on education loan (no limit, 8 years)',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.Text(
            '• Section 269SS/269T — Cash transaction limits (₹20,000)',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'This is a computer-generated summary for the selected period. '
            'Interest paid may be eligible for deduction under Sections 80C/80E '
            'of the Income Tax Act, 1961. Please consult a qualified tax advisor '
            'for filing eligibility and applicable limits.',
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
      case StatementVariant.customerStatement:
        return 'LOAN REPAYMENT STATEMENT';
    }
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

class _LedgerRow {
  final DateTime date;
  final int? emiNumber;
  final String description;
  final double debit;
  final double credit;
  final double penalty;
  final double balance;
  final bool isSchedule;
  final bool isPayment;
  final bool isPenalty;
  final EMIStatus? status;

  _LedgerRow({
    required this.date,
    required this.emiNumber,
    required this.description,
    required this.debit,
    required this.credit,
    this.penalty = 0,
    required this.balance,
    this.isSchedule = false,
    this.isPayment = false,
    this.isPenalty = false,
    this.status,
  });
}

class _LedgerResult {
  final List<_LedgerRow> rows;
  final double totalDebit;
  final double totalCredit;
  final double totalInterestPaid;
  final double totalPrincipalPaid;
  final double totalPenalties;
  final double closingBalance;

  _LedgerResult({
    required this.rows,
    required this.totalDebit,
    required this.totalCredit,
    required this.totalInterestPaid,
    required this.totalPrincipalPaid,
    required this.totalPenalties,
    required this.closingBalance,
  });
}
