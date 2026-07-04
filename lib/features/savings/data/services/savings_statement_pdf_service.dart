import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/constants/statement_colors.dart';
import '../../../../core/models/statement_org_info.dart';
import '../../../../core/utils/statement_formatters.dart';
import 'savings_statement_models.dart';

/// Backward-compatible alias — now backed by the shared [StatementOrgInfo].
typedef SavingsStatementOrgInfo = StatementOrgInfo;

// ──────────────────────────────────────────────────────────────
//  Font loading (Inter) — graceful fallback to Helvetica
// ──────────────────────────────────────────────────────────────

pw.Font _fontRegular = pw.Font.helvetica();
pw.Font _fontBold = pw.Font.helveticaBold();
bool _fontsLoaded = false;

Future<void> _loadFonts() async {
  if (_fontsLoaded) return;
  try {
    final regular = await rootBundle.load('assets/fonts/Inter-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/Inter-Bold.ttf');
    _fontRegular = pw.Font.ttf(regular);
    _fontBold = pw.Font.ttf(bold);
    _fontsLoaded = true;
  } catch (e) {
    debugPrint('[SavingsStatementPdf] Font loading failed: $e');
    // Fallback to Helvetica
    _fontRegular = pw.Font.helvetica();
    _fontBold = pw.Font.helveticaBold();
    _fontsLoaded = true;
  }
}

class SavingsStatementPdfService {
  static String _date(DateTime d) => StatementFormatters.date(d);
  static bool _isValidImage(Uint8List? bytes) =>
      StatementFormatters.isValidImage(bytes);
  static String _s(String? s) => StatementFormatters.sanitizeForEncoding(s);

  /// Money without decimals: "Rs. 1,500" instead of "Rs. 1,500.00"
  static String _moneyInt(num v) {
    final negative = v < 0;
    final n = v.abs();
    final whole = n.truncate();
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
    return '${negative ? '-' : ''}Rs. $grouped';
  }

  static Future<Uint8List> build({
    required SavingsStatementData data,
    required SavingsStatementOrgInfo org,
    String? statementRef,
    String? generatedByName,
    Uint8List? qrPngBytes,
    double overdueAmount = 0,
  }) async {
    await _loadFonts();

    try {
      return await _buildPdf(data, org, statementRef, generatedByName, qrPngBytes, overdueAmount);
    } on FormatException catch (e) {
      debugPrint('[SavingsStatementPdf] FormatException: $e, retrying with Helvetica');
      _fontRegular = pw.Font.helvetica();
      _fontBold = pw.Font.helveticaBold();
      return await _buildPdf(data, org, statementRef, generatedByName, qrPngBytes, overdueAmount);
    }
  }

  static Future<Uint8List> _buildPdf(
    SavingsStatementData data,
    SavingsStatementOrgInfo org,
    String? statementRef,
    String? generatedByName,
    Uint8List? qrPngBytes,
    double overdueAmount,
  ) async {
    final pdf = pw.Document(
      title: _s('Savings Statement - ${data.customer.fullName}'),
      author: _s(org.name),
      creator: _s(org.name),
      subject: 'Savings Statement',
    );

    final header1 = _buildHeader(org, data, statementRef, qrPngBytes);
    final headerN = _buildRunningHeader(org, data);

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
          pw.SizedBox(height: 10),
          _buildCustomerBlock(data),
          pw.SizedBox(height: 12),
          _buildPortfolioSummary(data, overdueAmount),
          pw.SizedBox(height: 16),
          ...data.plans.map((p) => _buildPlanSection(p, org)),
          // Footer note
          pw.Container(
            width: double.infinity,
            padding: pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: StatementColors.grey50,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: StatementColors.grey200, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Important:',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold,
                        color: StatementColors.grey700, font: _fontBold)),
                pw.SizedBox(height: 3),
                pw.Text(
                    '• This is a computer-generated statement and does not require a signature.',
                    style: pw.TextStyle(fontSize: 7.5, color: StatementColors.grey600, font: _fontRegular)),
                pw.Text(
                    '• Please contact us immediately if you notice any discrepancy.',
                    style: pw.TextStyle(fontSize: 7.5, color: StatementColors.grey600, font: _fontRegular)),
                if (org.phone != null && org.phone!.isNotEmpty)
                  pw.Text(
                      '• For queries, call: ${org.phone}',
                      style: pw.TextStyle(fontSize: 7.5, color: StatementColors.grey600, font: _fontRegular)),
                pw.SizedBox(height: 4),
                pw.Text(
                    'Keep saving! Your financial discipline today builds your security tomorrow.',
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: StatementColors.green700, font: _fontBold)),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────
  //  PREMIUM CENTERED HEADER
  // ─────────────────────────────────────────────────────────

  static pw.Widget _buildHeader(
    SavingsStatementOrgInfo org,
    SavingsStatementData data,
    String? statementRef,
    Uint8List? qrPngBytes,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Logo (larger, centered)
        if (org.logoBytes != null && _isValidImage(org.logoBytes))
          pw.Container(
            height: 50,
            child: pw.Image(pw.MemoryImage(org.logoBytes!)),
          ),
        if (org.logoBytes != null) pw.SizedBox(height: 10),

        // Org name (large, premium)
        pw.Center(
          child: pw.Text(
            _s(org.name),
            style: pw.TextStyle(
              font: _fontBold,
              fontSize: 22,
              letterSpacing: 1,
              color: StatementColors.navy900,
            ),
          ),
        ),
        pw.SizedBox(height: 4),

        // Address
        if (org.fullAddress.isNotEmpty)
          pw.Center(
            child: pw.Text(
              _s(org.fullAddress),
              style: pw.TextStyle(
                font: _fontRegular,
                fontSize: 10,
                color: StatementColors.grey600,
              ),
            ),
          ),

        // Phone | Email
        if (org.phone != null || org.email != null)
          pw.Center(
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(top: 3),
              child: pw.Text(
                [
                  if (org.phone != null) 'Ph: ${_s(org.phone)}',
                  if (org.email != null) _s(org.email),
                ].join('  |  '),
                style: pw.TextStyle(
                  font: _fontRegular,
                  fontSize: 9,
                  color: StatementColors.grey500,
                ),
              ),
            ),
          ),

        // QR code (centered)
        if (qrPngBytes != null && _isValidImage(qrPngBytes))
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Center(
              child: pw.Container(
                width: 60,
                height: 60,
                child: pw.Image(pw.MemoryImage(qrPngBytes)),
              ),
            ),
          ),

        pw.SizedBox(height: 16),
        pw.Container(height: 2, color: StatementColors.navy900),
        pw.SizedBox(height: 12),

        // Statement title and period
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('SAVINGS PASSBOOK STATEMENT',
                style: pw.TextStyle(
                    font: _fontBold,
                    fontSize: 14,
                    letterSpacing: 0.5,
                    color: StatementColors.navy900)),
            pw.Text(
              '${_date(data.periodStart)} - ${_date(data.periodEnd)}',
              style: pw.TextStyle(
                  font: _fontRegular,
                  fontSize: 9,
                  color: StatementColors.grey600),
            ),
          ],
        ),
        if (statementRef != null && statementRef.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text('Ref: $statementRef',
                style: pw.TextStyle(
                    font: _fontRegular,
                    fontSize: 7,
                    color: StatementColors.grey400)),
          ),
      ],
    );
  }

  static pw.Widget _buildRunningHeader(
    SavingsStatementOrgInfo org,
    SavingsStatementData data,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(_s(org.name),
            style: pw.TextStyle(
                font: _fontBold,
                fontSize: 8,
                color: StatementColors.grey700)),
        pw.Text('Savings - ${_s(data.customer.fullName)}',
            style: pw.TextStyle(font: _fontRegular, fontSize: 8, color: StatementColors.grey600)),
      ],
    );
  }

  static pw.Widget _buildFooter(
    pw.Context ctx,
    SavingsStatementOrgInfo org,
    String? statementRef,
    String? generatedByName,
  ) {
    return pw.Column(
      children: [
        pw.Divider(height: 1, thickness: 0.5, color: StatementColors.grey300),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              _s(org.name),
              style: pw.TextStyle(font: _fontRegular, fontSize: 6.5, color: StatementColors.grey400),
            ),
            pw.Text('Page ${ctx.pageNumber}',
                style: pw.TextStyle(
                    font: _fontRegular, fontSize: 7, color: StatementColors.grey500)),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  //  CUSTOMER BLOCK
  // ─────────────────────────────────────────────────────────

  static pw.Widget _buildCustomerBlock(SavingsStatementData data) {
    final c = data.customer;
    return pw.Container(
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: StatementColors.grey200, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
        color: StatementColors.grey50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('CUSTOMER DETAILS',
              style: pw.TextStyle(
                  font: _fontBold,
                  fontSize: 9,
                  color: StatementColors.navy900)),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoRow('Name', _s(c.fullName)),
                    _infoRow('Member ID', _s(c.memberId)),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoRow('Phone', _s(c.phone)),
                    if (c.address != null && c.address!.isNotEmpty)
                      _infoRow('Address', _s(c.address)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        children: [
          pw.Text('$label: ',
              style: pw.TextStyle(
                  font: _fontBold,
                  fontSize: 8,
                  color: StatementColors.grey600)),
          pw.Text(value,
              style: pw.TextStyle(font: _fontRegular, fontSize: 8, color: StatementColors.grey900)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  PORTFOLIO SUMMARY (with overdue)
  // ─────────────────────────────────────────────────────────

  static pw.Widget _buildPortfolioSummary(SavingsStatementData data, double overdueAmount) {
    final p = data.portfolio;
    return pw.Container(
      padding: pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: StatementColors.green100, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
        color: StatementColors.green50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('YOUR SAVINGS OVERVIEW',
              style: pw.TextStyle(
                  font: _fontBold,
                  fontSize: 10,
                  color: StatementColors.green700)),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              _metricBox('Opening Balance', _moneyInt(p.openingBalance)),
              _metricBox('Total Deposited', _moneyInt(p.totalDeposits),
                  color: StatementColors.green700),
              _metricBox('Total Withdrawn', _moneyInt(p.totalWithdrawals),
                  color: StatementColors.red700),
              if (overdueAmount > 0)
                _metricBox('Overdue', _moneyInt(overdueAmount),
                    color: StatementColors.red700),
              _metricBox('Current Balance', _moneyInt(p.closingBalance),
                  color: StatementColors.navy900),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text('Active Plans: ${p.activePlans} of ${p.totalPlans}',
              style: pw.TextStyle(font: _fontRegular, fontSize: 8, color: StatementColors.grey600)),
        ],
      ),
    );
  }

  static pw.Widget _metricBox(String label, String value,
      {PdfColor? color}) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label.toUpperCase(),
              style: pw.TextStyle(
                  font: _fontBold,
                  fontSize: 6,
                  letterSpacing: 0.5,
                  color: StatementColors.grey400)),
          pw.SizedBox(height: 2),
          pw.Text(value,
              style: pw.TextStyle(
                  font: _fontBold,
                  fontSize: 10,
                  color: color ?? StatementColors.grey900)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  PLAN SECTION
  // ─────────────────────────────────────────────────────────

  static pw.Widget _buildPlanSection(
      SavingsStatementPlanBlock plan, SavingsStatementOrgInfo org) {
    final allTxs = [
      ...plan.deposits.map((t) => _LedgerRow(
            date: t.date,
            description: t.description,
            deposit: t.amount,
            withdrawal: 0,
            mode: t.paymentMode,
          )),
      ...plan.withdrawals.map((t) => _LedgerRow(
            date: t.date,
            description: t.description,
            deposit: 0,
            withdrawal: t.amount,
            mode: t.paymentMode,
          )),
    ]..sort((a, b) => a.date.compareTo(b.date));

    double running = plan.openingBalance;
    for (var i = 0; i < allTxs.length; i++) {
      running += allTxs[i].deposit - allTxs[i].withdrawal;
      allTxs[i].balance = running;
    }

    final daysToMaturity = plan.maturityDate.difference(DateTime.now()).inDays;
    final collectionLabel = _collectionLabel(plan.collectionType);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Plan header
        pw.Container(
          padding: pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: pw.BoxDecoration(
            color: StatementColors.navy50,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: StatementColors.navy100, width: 0.5),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(_s(plan.planName),
                      style: pw.TextStyle(
                          font: _fontBold,
                          fontSize: 11,
                          color: StatementColors.navy900)),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Collection: $collectionLabel  |  Maturity: ${_date(plan.maturityDate)}',
                    style: pw.TextStyle(
                        font: _fontRegular,
                        fontSize: 8,
                        color: StatementColors.grey600),
                  ),
                ],
              ),
              pw.Container(
                padding:
                    pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: plan.status == 'active'
                      ? StatementColors.green100
                      : StatementColors.grey100,
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text(plan.status.toUpperCase(),
                    style: pw.TextStyle(
                        font: _fontBold,
                        fontSize: 8,
                        color: plan.status == 'active'
                            ? StatementColors.green700
                            : StatementColors.grey600)),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),

        // Key info
        pw.Container(
          padding: pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: StatementColors.grey200, width: 0.5),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            children: [
              pw.Row(
                children: [
                  _planMetric('Target Amount', _moneyInt(plan.targetAmount)),
                  _planMetric('Installment', '${_moneyInt(plan.monthlyDeposit)} / $collectionLabel'),
                  _planMetric('Current Balance', _moneyInt(plan.closingBalance),
                      color: StatementColors.green700),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  _planMetric(
                      'Progress',
                      '${plan.progressPercent.toStringAsFixed(1)}% of target'),
                  if (plan.totalInstallments != null && plan.paidInstallments != null)
                    _planMetric(
                        'Installments',
                        '${plan.paidInstallments} of ${plan.totalInstallments}'),
                  if (plan.nextDueDate != null)
                    _planMetric('Next Due', _date(plan.nextDueDate!),
                        color: StatementColors.orange700)
                  else
                    _planMetric('Next Due', '—'),
                  _planMetric(
                      'Days to Maturity',
                      daysToMaturity > 0
                          ? '$daysToMaturity days'
                          : 'Matured'),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),

        // Transaction history
        pw.Text('DEPOSIT HISTORY',
            style: pw.TextStyle(
                font: _fontBold,
                fontSize: 9,
                color: StatementColors.navy900)),
        pw.SizedBox(height: 6),
        if (allTxs.isNotEmpty)
          _buildLedgerTable(allTxs, plan)
        else
          pw.Padding(
            padding: pw.EdgeInsets.all(10),
            child: pw.Text('No transactions in this period.',
                style: pw.TextStyle(
                    font: _fontRegular,
                    fontSize: 8,
                    color: StatementColors.grey400)),
          ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  static String _collectionLabel(String type) {
    switch (type.toLowerCase()) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      case 'yearly':
        return 'Yearly';
      default:
        return type;
    }
  }

  static pw.Widget _planMetric(String label, String value,
      {PdfColor? color}) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: pw.BoxDecoration(
          color: StatementColors.grey50,
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(label.toUpperCase(),
                style: pw.TextStyle(
                    font: _fontBold,
                    fontSize: 5.5,
                    letterSpacing: 0.8,
                    color: StatementColors.grey400)),
            pw.SizedBox(height: 3),
            pw.Text(value,
                style: pw.TextStyle(
                    font: _fontBold,
                    fontSize: 9,
                    color: color ?? StatementColors.grey900)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  LEDGER TABLE
  // ─────────────────────────────────────────────────────────

  static pw.Widget _buildLedgerTable(
      List<_LedgerRow> rows, SavingsStatementPlanBlock plan) {
    final headers = ['Date', 'Description', 'Deposited', 'Withdrawn', 'Balance'];
    final colWidths = [.15, .35, .17, .17, .16];

    return pw.Table(
      border: pw.TableBorder.all(
          color: StatementColors.grey200, width: 0.3),
      columnWidths: colWidths
          .asMap()
          .map((i, w) => MapEntry(i, pw.FlexColumnWidth(w))),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: StatementColors.navy900),
          children: headers
              .map((h) => _cell(h,
                  bold: true, align: pw.TextAlign.center, size: 7,
                  headerColor: true))
              .toList(),
        ),
        ...rows.asMap().entries.map((entry) {
          final r = entry.value;
          final isEven = entry.key % 2 == 0;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEven ? StatementColors.grey50 : PdfColors.white,
            ),
            children: [
              _cell(_date(r.date), size: 7),
              _cell(_s(r.description), size: 7),
              _cell(r.deposit > 0 ? _moneyInt(r.deposit) : '',
                  size: 7, align: pw.TextAlign.right,
                  color: r.deposit > 0 ? StatementColors.green700 : null),
              _cell(r.withdrawal > 0 ? _moneyInt(r.withdrawal) : '',
                  size: 7, align: pw.TextAlign.right,
                  color: r.withdrawal > 0 ? StatementColors.red700 : null),
              _cell(_moneyInt(r.balance),
                  size: 7,
                  align: pw.TextAlign.right,
                  bold: true),
            ],
          );
        }),
        pw.TableRow(
          decoration: pw.BoxDecoration(color: StatementColors.green50),
          children: [
            _cell('', size: 7),
            _cell('Plan Total',
                bold: true, size: 7, align: pw.TextAlign.right),
            _cell(_moneyInt(plan.totalDeposited),
                bold: true, size: 7, align: pw.TextAlign.right,
                color: StatementColors.green700),
            _cell(_moneyInt(plan.totalWithdrawn),
                bold: true, size: 7, align: pw.TextAlign.right,
                color: StatementColors.red700),
            _cell(_moneyInt(plan.closingBalance),
                bold: true, size: 7, align: pw.TextAlign.right),
          ],
        ),
      ],
    );
  }

  static pw.Widget _cell(String text,
      {bool bold = false,
      pw.TextAlign align = pw.TextAlign.left,
      double size = 8,
      PdfColor? color,
      bool headerColor = false}) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(4),
      child: pw.Text(text,
          style: pw.TextStyle(
            font: bold ? _fontBold : _fontRegular,
            fontSize: size,
            color: headerColor
                ? StatementColors.white
                : (color ?? StatementColors.grey900),
          ),
          textAlign: align),
    );
  }
}

class _LedgerRow {
  final DateTime date;
  final String description;
  final double deposit;
  final double withdrawal;
  double balance = 0;
  final String? mode;

  _LedgerRow({
    required this.date,
    required this.description,
    required this.deposit,
    required this.withdrawal,
    this.mode,
  });
}
