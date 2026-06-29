import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/constants/statement_colors.dart';
import '../../../../core/models/statement_org_info.dart';
import '../../../../core/utils/statement_formatters.dart';
import '../models/transaction_model.dart';
import 'transaction_export_options.dart';

pw.Font _fontRegular = pw.Font.helvetica();
pw.Font _fontSemiBold = pw.Font.helveticaBold();
pw.Font _fontBold = pw.Font.helveticaBold();
bool _fontsLoaded = false;

Future<void> _loadFonts() async {
  if (_fontsLoaded) return;
  try {
    final regular = await rootBundle.load('assets/fonts/Inter-Regular.ttf');
    final semiBold = await rootBundle.load('assets/fonts/Inter-SemiBold.ttf');
    final bold = await rootBundle.load('assets/fonts/Inter-Bold.ttf');
    _fontRegular = pw.Font.ttf(regular);
    _fontSemiBold = pw.Font.ttf(semiBold);
    _fontBold = pw.Font.ttf(bold);
    _fontsLoaded = true;
  } catch (e) {
    debugPrint('[TransactionPdfService] Font loading failed: $e');
  }
}

class TransactionPdfService {
  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _generatedFmt = DateFormat('dd MMM yyyy, hh:mm a');

  static String _s(String? s) => StatementFormatters.sanitizeForEncoding(s);
  static String _money(num v) => StatementFormatters.money(v);

  static Future<Uint8List> generate({
    required List<TransactionModel> transactions,
    required TransactionExportOptions options,
    StatementOrgInfo? orgInfo,
  }) async {
    await _loadFonts();

    final org = orgInfo ?? StatementOrgInfo.fallback();
    final theme = pw.ThemeData.withFont(
      base: _fontRegular,
      bold: _fontBold,
    );

    final pdf = pw.Document();
    final pageFormat = PdfPageFormat.a4;

    // Compute summary stats
    double inflow = 0;
    double outflow = 0;
    for (final t in transactions) {
      if (_isInflow(t.type)) {
        inflow += t.amount;
      } else {
        outflow += t.amount;
      }
    }
    final net = inflow - outflow;

    // Group by date
    final grouped = <String, List<TransactionModel>>{};
    for (final t in transactions) {
      final key = _dateFmt.format(t.createdAt);
      grouped.putIfAbsent(key, () => []).add(t);
    }

    // Build pages
    final header = _buildHeader(org, options, transactions.length);
    final summary = _buildSummary(inflow, outflow, transactions.length, net);
    final tableHeader = _buildTableHeader();

    final tableRows = <pw.Widget>[];
    for (final entry in grouped.entries) {
      tableRows.add(_buildDateHeader(entry.key));
      for (final t in entry.value) {
        tableRows.add(_buildTransactionRow(t));
      }
    }

    final footer = _buildFooter();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(40),
        theme: theme,
        header: (context) => header,
        footer: (context) => footer,
        build: (context) => [
          summary,
          pw.SizedBox(height: 20),
          tableHeader,
          pw.SizedBox(height: 8),
          ...tableRows,
        ],
      ),
    );

    return pdf.save();
  }

  static Future<void> share({
    required List<TransactionModel> transactions,
    required TransactionExportOptions options,
    StatementOrgInfo? orgInfo,
  }) async {
    final bytes = await generate(
      transactions: transactions,
      options: options,
      orgInfo: orgInfo,
    );
    final dir = await getTemporaryDirectory();
    final periodLabel = _periodLabel(options);
    final file = File('${dir.path}/transaction_report_$periodLabel.pdf');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Transaction Report - $periodLabel',
        text: 'Transaction report for $periodLabel',
      ),
    );
  }

  static pw.Widget _buildHeader(
    StatementOrgInfo org,
    TransactionExportOptions options,
    int count,
  ) {
    final start = options.resolvedStart;
    final end = options.resolvedEnd;
    final periodStr = (start != null && end != null)
        ? '${_dateFmt.format(start)} \u2192 ${_dateFmt.format(end)}'
        : 'All Transactions';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _s(org.name),
                  style: pw.TextStyle(
                    font: _fontBold,
                    fontSize: 18,
                    color: StatementColors.navy900,
                  ),
                ),
                if (org.fullAddress.isNotEmpty)
                  pw.Text(
                    _s(org.fullAddress),
                    style: pw.TextStyle(
                      font: _fontRegular,
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                if (org.phone != null)
                  pw.Text(
                    _s(org.phone!),
                    style: pw.TextStyle(
                      font: _fontRegular,
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: pw.BoxDecoration(
                color: StatementColors.navy900,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'TRANSACTION REPORT',
                style: pw.TextStyle(
                  font: _fontBold,
                  fontSize: 10,
                  color: PdfColors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          width: double.infinity,
          height: 1,
          color: StatementColors.navy100,
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Period: $periodStr',
              style: pw.TextStyle(
                font: _fontSemiBold,
                fontSize: 11,
                color: StatementColors.navy800,
              ),
            ),
            pw.Text(
              '$count transactions',
              style: pw.TextStyle(
                font: _fontRegular,
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  static pw.Widget _buildSummary(
    double inflow,
    double outflow,
    int count,
    double net,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: StatementColors.navy50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: StatementColors.navy100),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total Inflow', _money(inflow), StatementColors.green700),
          _buildStatItem('Total Outflow', _money(outflow), StatementColors.red700),
          _buildStatItem('Transactions', '$count', StatementColors.navy700),
          _buildStatItem('Net', _money(net), net >= 0 ? StatementColors.green700 : StatementColors.red700),
        ],
      ),
    );
  }

  static pw.Widget _buildStatItem(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            font: _fontBold,
            fontSize: 14,
            color: color,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: pw.TextStyle(
            font: _fontRegular,
            fontSize: 9,
            color: PdfColors.grey600,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTableHeader() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: pw.BoxDecoration(
        color: StatementColors.navy900,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        children: [
          _headerCell('Date', 2),
          _headerCell('Member', 2.5),
          _headerCell('Type', 1.8),
          _headerCell('Mode', 1.2),
          _headerCell('Amount', 1.5, right: true),
          _headerCell('Collected By', 1.5),
        ],
      ),
    );
  }

  static pw.Widget _headerCell(String text, double flex, {bool right = false}) {
    return pw.Expanded(
      flex: (flex * 10).toInt(),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: _fontBold,
          fontSize: 8,
          color: PdfColors.white,
          letterSpacing: 0.5,
        ),
        textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
      ),
    );
  }

  static pw.Widget _buildDateHeader(String date) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12, bottom: 6),
      child: pw.Row(
        children: [
          pw.Container(
            width: 6,
            height: 6,
            decoration: pw.BoxDecoration(
              color: StatementColors.teal600,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            date,
            style: pw.TextStyle(
              font: _fontBold,
              fontSize: 10,
              color: StatementColors.teal600,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Container(
              height: 0.5,
              color: StatementColors.teal200,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTransactionRow(TransactionModel t) {
    final isInflow = _isInflow(t.type);
    final amountColor = isInflow ? StatementColors.green700 : StatementColors.red700;
    final prefix = isInflow ? '+' : '-';

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.3),
        ),
      ),
      child: pw.Row(
        children: [
          _dataCell(DateFormat('dd MMM, hh:mm').format(t.createdAt), 2),
          _dataCell(_s(t.memberName.isNotEmpty ? t.memberName : 'Unknown'), 2.5),
          _dataCell(_typeLabel(t.type), 1.8),
          _dataCell(_paymentModeLabel(t.paymentMode), 1.2),
          pw.Expanded(
            flex: 15,
            child: pw.Text(
              '$prefix${_money(t.amount)}',
              style: pw.TextStyle(
                font: _fontBold,
                fontSize: 9,
                color: amountColor,
              ),
              textAlign: pw.TextAlign.right,
            ),
          ),
          _dataCell(_s(t.collectedByName ?? '—'), 1.5),
        ],
      ),
    );
  }

  static pw.Widget _dataCell(String text, double flex) {
    return pw.Expanded(
      flex: (flex * 10).toInt(),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: _fontRegular,
          fontSize: 8,
          color: PdfColors.grey800,
        ),
        maxLines: 1,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated ${_generatedFmt.format(DateTime.now())}',
            style: pw.TextStyle(
              font: _fontRegular,
              fontSize: 8,
              color: PdfColors.grey500,
            ),
          ),
          pw.Text(
            'MicroFlow Pro',
            style: pw.TextStyle(
              font: _fontSemiBold,
              fontSize: 8,
              color: StatementColors.navy600,
            ),
          ),
        ],
      ),
    );
  }

  static String _periodLabel(TransactionExportOptions options) {
    final start = options.resolvedStart;
    final end = options.resolvedEnd;
    if (start != null && end != null) {
      return '${DateFormat('yyyy-MM-dd').format(start)}_to_${DateFormat('yyyy-MM-dd').format(end)}';
    }
    return 'all';
  }

  static bool _isInflow(TransactionType type) {
    switch (type) {
      case TransactionType.loanDisbursement:
      case TransactionType.savingsWithdrawal:
        return false;
      default:
        return true;
    }
  }

  static String _typeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.emiPayment:
        return 'EMI';
      case TransactionType.savingsDeposit:
        return 'Savings';
      case TransactionType.loanDisbursement:
        return 'Disbursed';
      case TransactionType.savingsWithdrawal:
        return 'Withdrawal';
      case TransactionType.penalty:
        return 'Penalty';
      case TransactionType.staffCashDeposit:
        return 'Cash Deposit';
      case TransactionType.other:
        return 'Other';
    }
  }

  static String _paymentModeLabel(PaymentMode? mode) {
    switch (mode) {
      case PaymentMode.cash:
        return 'Cash';
      case PaymentMode.upi:
        return 'UPI';
      case PaymentMode.bankTransfer:
        return 'Bank';
      case PaymentMode.cheque:
        return 'Cheque';
      case PaymentMode.card:
        return 'Card';
      case null:
        return '—';
    }
  }
}
