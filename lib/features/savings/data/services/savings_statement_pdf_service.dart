import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/models/statement_org_info.dart';
import '../../../../core/utils/statement_formatters.dart';
import 'savings_statement_models.dart';

/// Backward-compatible alias — now backed by the shared [StatementOrgInfo].
typedef SavingsStatementOrgInfo = StatementOrgInfo;

class SavingsStatementPdfService {
  /// Delegates to shared [StatementFormatters.money].
  static String _money(num v) => StatementFormatters.money(v);

  /// Delegates to shared [StatementFormatters.date].
  static String _date(DateTime d) => StatementFormatters.date(d);

  /// Delegates to shared [StatementFormatters.isValidImage].
  static bool _isValidImage(Uint8List? bytes) =>
      StatementFormatters.isValidImage(bytes);

  static pw.Widget? _safeImage(Uint8List? bytes,
      {double width = 80, double height = 80, pw.EdgeInsets? margin}) {
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
    required SavingsStatementData data,
    required SavingsStatementOrgInfo org,
    String? statementRef,
    String? generatedByName,
    Uint8List? qrPngBytes,
  }) async {
    final pdf = pw.Document(
      title: 'Savings Statement - ${data.customer.fullName}',
      author: org.name,
      creator: org.name,
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
          pw.SizedBox(height: 12),
          _buildCustomerBlock(data),
          pw.SizedBox(height: 16),
          _buildPortfolioSummary(data),
          pw.SizedBox(height: 20),
          ...data.plans.map((p) => _buildPlanSection(p, org)),
          // Customer-friendly footer note
          pw.Container(
            width: double.infinity,
            padding: pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.blueGrey50,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Important:',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey700)),
                pw.SizedBox(height: 3),
                pw.Text(
                    '• This is a computer-generated statement and does not require a signature.',
                    style: pw.TextStyle(fontSize: 7.5, color: PdfColors.blueGrey600)),
                pw.Text(
                    '• Please contact us immediately if you notice any discrepancy.',
                    style: pw.TextStyle(fontSize: 7.5, color: PdfColors.blueGrey600)),
                if (org.phone != null && org.phone!.isNotEmpty)
                  pw.Text(
                      '• For queries, call: ${org.phone}',
                      style: pw.TextStyle(fontSize: 7.5, color: PdfColors.blueGrey600)),
                pw.SizedBox(height: 4),
                pw.Text(
                    'Keep saving! Your financial discipline today builds your security tomorrow.',
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800)),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(
    SavingsStatementOrgInfo org,
    SavingsStatementData data,
    String? statementRef,
    Uint8List? qrPngBytes,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(org.name,
                      style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey900)),
                  if (org.fullAddress.isNotEmpty)
                    pw.Text(org.fullAddress,
                        style: pw.TextStyle(
                            fontSize: 8, color: PdfColors.blueGrey600)),
                  if (org.phone != null && org.phone!.isNotEmpty)
                    pw.Text('Ph: ${org.phone}',
                        style: pw.TextStyle(
                           fontSize: 8, color: PdfColors.blueGrey600)),
                  if (org.email != null && org.email!.isNotEmpty)
                    pw.Text(org.email!,
                        style: pw.TextStyle(
                            fontSize: 8, color: PdfColors.blueGrey600)),
                ],
              ),
            ),
            if (qrPngBytes != null)
              _safeImage(qrPngBytes, width: 56, height: 56) ??
                  pw.SizedBox(),
            if (org.logoBytes != null)
              _safeImage(org.logoBytes, width: 60, height: 60,
                  margin: pw.EdgeInsets.only(left: 8)) ?? pw.SizedBox(),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Container(
          padding: pw.EdgeInsets.symmetric(vertical: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border(
                top: pw.BorderSide(color: PdfColors.blueGrey300, width: 1.5),
                bottom:
                    pw.BorderSide(color: PdfColors.blueGrey300, width: 1.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('SAVINGS PASSBOOK STATEMENT',
                  style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey900)),
              pw.Text(
                '${_date(data.periodStart)} - ${_date(data.periodEnd)}',
                style: pw.TextStyle(
                    fontSize: 9, color: PdfColors.blueGrey600),
              ),
            ],
          ),
        ),
        if (statementRef != null && statementRef.isNotEmpty)
          pw.Padding(
            padding: pw.EdgeInsets.only(top: 4),
            child: pw.Text('Ref: $statementRef',
                style: pw.TextStyle(
                    fontSize: 7, color: PdfColors.blueGrey400)),
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
        pw.Text(org.name,
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey700)),
        pw.Text('Savings - ${data.customer.fullName}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey600)),
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
        pw.Divider(height: 1, thickness: 0.5, color: PdfColors.blueGrey300),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'This is a computer-generated statement. ${statementRef != null ? "Ref: $statementRef" : ""}',
              style: pw.TextStyle(fontSize: 6.5, color: PdfColors.blueGrey400),
            ),
            pw.Text('Page ${ctx.pageNumber}',
                style: pw.TextStyle(
                    fontSize: 7, color: PdfColors.blueGrey500)),
          ],
        ),
        if (generatedByName != null && generatedByName.isNotEmpty)
          pw.Text('Generated by: $generatedByName',
              style: pw.TextStyle(fontSize: 6.5, color: PdfColors.blueGrey400)),
      ],
    );
  }

  static pw.Widget _buildCustomerBlock(SavingsStatementData data) {
    final c = data.customer;
    return pw.Container(
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
        color: PdfColors.blueGrey50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('CUSTOMER DETAILS',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey700)),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoRow('Name', c.fullName),
                    _infoRow('Member ID', c.memberId),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoRow('Phone', c.phone),
                    if (c.address != null && c.address!.isNotEmpty)
                      _infoRow('Address', c.address!),
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
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey600)),
          pw.Text(value,
              style: pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey900)),
        ],
      ),
    );
  }

  static pw.Widget _buildPortfolioSummary(SavingsStatementData data) {
    final p = data.portfolio;
    return pw.Container(
      padding: pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.green300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
        color: PdfColors.green50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('YOUR SAVINGS OVERVIEW',
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800)),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              _metricBox('Opening Balance', _money(p.openingBalance)),
              _metricBox('Total Deposited', _money(p.totalDeposits),
                  color: PdfColors.green700),
              _metricBox('Total Withdrawn', _money(p.totalWithdrawals),
                  color: PdfColors.red700),
              _metricBox('Interest Earned', _money(p.interestEarned),
                  color: PdfColors.green700),
              _metricBox('Current Balance', _money(p.closingBalance),
                  color: PdfColors.blueGrey900),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text('Active Plans: ${p.activePlans} of ${p.totalPlans}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey600)),
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
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey500)),
          pw.SizedBox(height: 2),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: color ?? PdfColors.blueGrey800)),
        ],
      ),
    );
  }

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
            color: PdfColors.indigo50,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: PdfColors.indigo200, width: 0.5),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(plan.planName,
                      style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.indigo900)),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Collection: $collectionLabel  |  Maturity: ${_date(plan.maturityDate)}',
                    style: pw.TextStyle(
                        fontSize: 8, color: PdfColors.blueGrey600),
                  ),
                ],
              ),
              pw.Container(
                padding:
                    pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: plan.status == 'active'
                      ? PdfColors.green100
                      : PdfColors.blueGrey100,
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text(plan.status.toUpperCase(),
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: plan.status == 'active'
                            ? PdfColors.green800
                            : PdfColors.blueGrey600)),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),

        // Key info for customer (2 rows)
        pw.Container(
          padding: pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.5),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            children: [
              pw.Row(
                children: [
                  _planMetric('Target Amount', _money(plan.targetAmount)),
                  _planMetric('Installment', '${_money(plan.monthlyDeposit)} / $collectionLabel'),
                  _planMetric('Current Balance', _money(plan.closingBalance),
                      color: PdfColors.green800),
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
                        color: PdfColors.orange800)
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
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey700)),
        pw.SizedBox(height: 6),
        if (allTxs.isNotEmpty)
          _buildLedgerTable(allTxs, plan)
        else
          pw.Padding(
            padding: pw.EdgeInsets.all(10),
            child: pw.Text('No transactions in this period.',
                style: pw.TextStyle(
                    fontSize: 8, color: PdfColors.blueGrey400)),
          ),
        pw.SizedBox(height: 20),
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
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey500)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: color ?? PdfColors.blueGrey800)),
        ],
      ),
    );
  }

  static pw.Widget _buildLedgerTable(
      List<_LedgerRow> rows, SavingsStatementPlanBlock plan) {
    final headers = ['Date', 'Description', 'Deposited', 'Withdrawn', 'Balance'];
    final colWidths = [.15, .35, .17, .17, .16];

    return pw.Table(
      border: pw.TableBorder.all(
          color: PdfColors.blueGrey200, width: 0.3),
      columnWidths: colWidths
          .asMap()
          .map((i, w) => MapEntry(i, pw.FlexColumnWidth(w))),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.blueGrey100),
          children: headers
              .map((h) => _cell(h,
                  bold: true, align: pw.TextAlign.center, size: 7))
              .toList(),
        ),
        ...rows.map((r) => pw.TableRow(
              children: [
                _cell(_date(r.date), size: 7),
                _cell(r.description, size: 7),
                _cell(r.deposit > 0 ? _money(r.deposit) : '',
                    size: 7, align: pw.TextAlign.right),
                _cell(r.withdrawal > 0 ? _money(r.withdrawal) : '',
                    size: 7, align: pw.TextAlign.right),
                _cell(_money(r.balance),
                    size: 7,
                    align: pw.TextAlign.right,
                    bold: true),
              ],
            )),
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.green50),
          children: [
            _cell('', size: 7),
            _cell('Plan Total',
                bold: true, size: 7, align: pw.TextAlign.right),
            _cell(_money(plan.totalDeposited),
                bold: true, size: 7, align: pw.TextAlign.right),
            _cell(_money(plan.totalWithdrawn),
                bold: true, size: 7, align: pw.TextAlign.right),
            _cell(_money(plan.closingBalance),
                bold: true, size: 7, align: pw.TextAlign.right),
          ],
        ),
      ],
    );
  }

  static pw.Widget _cell(String text,
      {bool bold = false,
      pw.TextAlign align = pw.TextAlign.left,
      double size = 8}) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(4),
      child: pw.Text(text,
          style: pw.TextStyle(
            fontSize: size,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: PdfColors.blueGrey900,
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
