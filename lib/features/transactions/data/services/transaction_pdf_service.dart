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

// ──────────────────────────────────────────────────────────────
//  Font loading (Inter) — graceful fallback to Helvetica
// ──────────────────────────────────────────────────────────────

pw.Font _fontRegular = pw.Font.helvetica();
pw.Font _fontSemiBold = pw.Font.helveticaBold();
pw.Font _fontBold = pw.Font.helveticaBold();
bool _fontsLoaded = false;

bool _isValidFontData(Uint8List data) {
  if (data.length < 4) return false;
  // TrueType signature: 00 01 00 00
  // OpenType (CFF) signature: 4F 54 54 4F ("OTTO")
  return (data[0] == 0x00 && data[1] == 0x01 && data[2] == 0x00 && data[3] == 0x00) ||
      (data[0] == 0x4F && data[1] == 0x54 && data[2] == 0x54 && data[3] == 0x4F);
}

Future<void> _loadFonts() async {
  if (_fontsLoaded) return;
  try {
    final regular = await rootBundle.load('assets/fonts/Inter-Regular.ttf');
    final semiBold = await rootBundle.load('assets/fonts/Inter-SemiBold.ttf');
    final bold = await rootBundle.load('assets/fonts/Inter-Bold.ttf');
    if (_isValidFontData(regular.buffer.asUint8List()) &&
        _isValidFontData(semiBold.buffer.asUint8List()) &&
        _isValidFontData(bold.buffer.asUint8List())) {
      _fontRegular = pw.Font.ttf(regular);
      _fontSemiBold = pw.Font.ttf(semiBold);
      _fontBold = pw.Font.ttf(bold);
      _fontsLoaded = true;
    } else {
      debugPrint('[TransactionPdf] Font files are invalid/not TTF, using Helvetica');
    }
  } catch (e) {
    debugPrint('[TransactionPdf] Font loading failed, using Helvetica: $e');
  }
}

// ──────────────────────────────────────────────────────────────
//  Config helper (computed once, passed everywhere)
// ──────────────────────────────────────────────────────────────

class _TypeBreakdown {
  final TransactionType type;
  final int count;
  final double total;
  final bool isInflow;
  _TypeBreakdown(this.type, this.count, this.total, this.isInflow);
}

class _PdfConfig {
  final StatementOrgInfo org;
  final TransactionExportOptions options;
  final double totalInflow;
  final double totalOutflow;
  final double net;
  final int transactionCount;
  final List<_TypeBreakdown> typeBreakdown;
  final Map<String, List<TransactionModel>> grouped;
  final String periodStr;
  final bool compact;
  final DateTime generatedAt;

  _PdfConfig({
    required this.org,
    required this.options,
    required this.totalInflow,
    required this.totalOutflow,
    required this.net,
    required this.transactionCount,
    required this.typeBreakdown,
    required this.grouped,
    required this.periodStr,
    required this.compact,
    required this.generatedAt,
  });
}

// ──────────────────────────────────────────────────────────────
//  Public service class
// ──────────────────────────────────────────────────────────────

class TransactionPdfService {
  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');
  static final _shortDateFmt = DateFormat('dd/MM HH:mm');

  static String _s(String? s) => StatementFormatters.sanitizeForEncoding(s);
  static String _money(num v) => StatementFormatters.money(v);

  // ── Public API ──

  static Future<Uint8List> generate({
    required List<TransactionModel> transactions,
    required TransactionExportOptions options,
    StatementOrgInfo? orgInfo,
  }) async {
    await _loadFonts();
    return _buildPdf(
      transactions: transactions,
      options: options,
      orgInfo: orgInfo,
    );
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

  // ─────────────────────────────────────────────────────────
  //  PDF Builder
  // ─────────────────────────────────────────────────────────

  static Future<Uint8List> _buildPdf({
    required List<TransactionModel> transactions,
    required TransactionExportOptions options,
    StatementOrgInfo? orgInfo,
  }) async {
    final org = orgInfo ?? StatementOrgInfo.fallback();
    final generatedAt = DateTime.now();
    final compact = transactions.length > 100;

    // ── Compute stats ──
    double inflow = 0, outflow = 0;
    for (final t in transactions) {
      if (_isInflow(t.type)) {
        inflow += t.amount;
      } else {
        outflow += t.amount;
      }
    }

    // ── Type breakdown ──
    final typeMap = <TransactionType, _TypeBreakdown>{};
    for (final t in transactions) {
      final existing = typeMap[t.type];
      if (existing != null) {
        typeMap[t.type] = _TypeBreakdown(
          t.type,
          existing.count + 1,
          existing.total + t.amount,
          existing.isInflow,
        );
      } else {
        typeMap[t.type] = _TypeBreakdown(
          t.type,
          1,
          t.amount,
          _isInflow(t.type),
        );
      }
    }
    final typeBreakdown = typeMap.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    // ── Group by date ──
    final grouped = <String, List<TransactionModel>>{};
    for (final t in transactions) {
      final key = _dateFmt.format(t.createdAt);
      grouped.putIfAbsent(key, () => []).add(t);
    }

    // ── Period string ──
    final periodStr = _periodDisplay(options);

    // ── Config ──
    final cfg = _PdfConfig(
      org: org,
      options: options,
      totalInflow: inflow,
      totalOutflow: outflow,
      net: inflow - outflow,
      transactionCount: transactions.length,
      typeBreakdown: typeBreakdown,
      grouped: grouped,
      periodStr: periodStr,
      compact: compact,
      generatedAt: generatedAt,
    );

    // ── Build theme ──
    final theme = pw.ThemeData.withFont(
      base: _fontRegular,
      bold: _fontBold,
    );

    // ── Build PDF ──
    final pdf = pw.Document(
      theme: theme,
      author: _s(org.name),
      creator: 'MicroFlow Pro',
      subject: 'Transaction Report',
      keywords: 'transactions, report, ${_s(org.name)}',
    );

    // Content pages (no cover page — matches loan statement style)
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.copyWith(
        marginLeft: 20,
        marginRight: 20,
        marginTop: 20,
        marginBottom: 28,
      ),
      theme: theme,
      header: (ctx) => _buildPremiumHeader(cfg),
      footer: (ctx) => _buildPremiumFooter(ctx, cfg),
      build: (ctx) => _buildContent(cfg),
    ));

    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────
  //  Content sections (auto-paginated)
  // ─────────────────────────────────────────────────────────

  static List<pw.Widget> _buildContent(_PdfConfig cfg) {
    final widgets = <pw.Widget>[];

    // ── Summary section ──
    if (cfg.options.includeSummary) {
      widgets.add(_buildSectionLabel('FINANCIAL SUMMARY'));
      widgets.add(pw.SizedBox(height: 8));
      widgets.add(_buildEnhancedSummary(cfg));

      // ── Type breakdown ──
      if (cfg.typeBreakdown.length > 1) {
        widgets.add(pw.SizedBox(height: 16));
        widgets.add(_buildSectionLabel('BREAKDOWN BY TYPE'));
        widgets.add(pw.SizedBox(height: 6));
        widgets.add(_buildTypeBreakdown(cfg));
      }

      // ── Filter summary ──
      if (cfg.options.hasActiveFilters) {
        widgets.add(pw.SizedBox(height: 16));
        widgets.add(_buildFilterSummary(cfg));
      }

      widgets.add(pw.SizedBox(height: 20));
      widgets.add(_buildDecorativeDivider());
      widgets.add(pw.SizedBox(height: 16));
    }

    // ── Transaction table ──
    widgets.add(_buildSectionLabel('TRANSACTION DETAILS'));
    widgets.add(pw.SizedBox(height: 8));

    // ── Single ledger table ──
    widgets.add(_buildTransactionLedger(cfg));

    // Empty state
    if (cfg.grouped.isEmpty) {
      widgets.add(pw.SizedBox(height: 40));
      widgets.add(pw.Center(
        child: pw.Column(
          children: [
            pw.Text(
              'No transactions found',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: StatementColors.grey500,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Try adjusting your filters or date range.',
              style: pw.TextStyle(
                fontSize: 9,
                color: StatementColors.grey400,
              ),
            ),
          ],
        ),
      ));
    }

    return widgets;
  }

  // ─────────────────────────────────────────────────────────
  //  Premium Header (matches loan statement style)
  // ─────────────────────────────────────────────────────────

  static pw.Widget _buildPremiumHeader(_PdfConfig cfg) {
    final org = cfg.org;
    final hasLogo = org.logoBytes != null &&
        org.logoBytes!.isNotEmpty &&
        StatementFormatters.isValidImage(org.logoBytes);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Top gradient brand strip
        pw.Container(
          height: 3,
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [
                StatementColors.navy900,
                StatementColors.teal600,
                StatementColors.gold500,
                StatementColors.teal600,
                StatementColors.navy900,
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 14),

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left column: Organization Details
            pw.Expanded(
              flex: 3,
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (hasLogo)
                    pw.Container(
                      width: 52,
                      height: 52,
                      margin: const pw.EdgeInsets.only(right: 12),
                      child: pw.Image(pw.MemoryImage(org.logoBytes!)),
                    )
                  else
                    pw.Container(
                      width: 52,
                      height: 52,
                      margin: const pw.EdgeInsets.only(right: 12),
                      decoration: pw.BoxDecoration(
                        color: StatementColors.navy900,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        org.name.isNotEmpty ? org.name[0].toUpperCase() : 'M',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: StatementColors.gold500,
                        ),
                      ),
                    ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          _s(org.name).toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: StatementColors.navy900,
                            letterSpacing: 1.0,
                            font: _fontBold,
                          ),
                        ),
                        if ((org.tagline ?? '').isNotEmpty)
                          pw.Text(
                            org.tagline!,
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              color: StatementColors.teal600,
                              fontStyle: pw.FontStyle.italic,
                              font: _fontRegular,
                            ),
                          ),
                        pw.SizedBox(height: 4),
                        if (org.fullAddress.isNotEmpty)
                          pw.Text(
                            org.fullAddress,
                            style: pw.TextStyle(
                              fontSize: 7,
                              color: StatementColors.grey600,
                              height: 1.3,
                              font: _fontRegular,
                            ),
                          ),
                        pw.SizedBox(height: 3),
                        pw.Row(
                          children: [
                            if ((org.phone ?? '').isNotEmpty)
                              _headerDetail('Tel', org.phone!),
                            if ((org.phone ?? '').isNotEmpty &&
                                (org.email ?? '').isNotEmpty)
                              pw.Text('  |  ',
                                  style: pw.TextStyle(
                                      fontSize: 7,
                                      color: StatementColors.grey300)),
                            if ((org.email ?? '').isNotEmpty)
                              _headerDetail('Email', org.email!),
                          ],
                        ),
                        if ((org.website ?? '').isNotEmpty)
                          pw.Text(
                            org.website!,
                            style: pw.TextStyle(
                              fontSize: 7,
                              color: StatementColors.teal600,
                              font: _fontRegular,
                            ),
                          ),
                        if ((org.registrationNumber ?? '').isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 2),
                            child: pw.Text(
                              'Reg: ${org.registrationNumber}',
                              style: pw.TextStyle(
                                fontSize: 6.5,
                                color: StatementColors.grey500,
                                letterSpacing: 0.3,
                                font: _fontRegular,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(width: 20),

            // Right column: Statement Title & Details Table
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'TRANSACTION REPORT',
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: StatementColors.navy900,
                      letterSpacing: 1.2,
                      font: _fontBold,
                    ),
                  ),
                  pw.SizedBox(height: 6),

                  // Metadata box
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      color: StatementColors.grey50,
                      border: pw.Border.all(color: StatementColors.grey200, width: 0.5),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _metaRow('Period', cfg.periodStr),
                        _metaRow('Transactions', '${cfg.transactionCount}'),
                        _metaRow('Generated', _dateFmt.format(cfg.generatedAt)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),

        // Bottom separator
        pw.Container(
          height: 1,
          color: StatementColors.grey300,
        ),
      ],
    );
  }

  static pw.Widget _metaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 6,
              fontWeight: pw.FontWeight.bold,
              color: StatementColors.grey500,
              font: _fontSemiBold,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 6.5,
              fontWeight: pw.FontWeight.bold,
              color: StatementColors.grey800,
              font: _fontBold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _headerDetail(String label, String value) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label: ',
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: StatementColors.grey500,
              font: _fontSemiBold,
            ),
          ),
          pw.TextSpan(
            text: value,
            style: pw.TextStyle(
              fontSize: 7,
              color: StatementColors.grey700,
              font: _fontRegular,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Premium Footer with page numbers
  // ─────────────────────────────────────────────────────────

  static pw.Widget _buildPremiumFooter(pw.Context ctx, _PdfConfig cfg) {
    return pw.Column(
      children: [
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 4),
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(
                color: StatementColors.grey300,
                width: 0.5,
              ),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              // Left: generation info
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Generated: ${_dateTimeFmt.format(cfg.generatedAt)}',
                    style: pw.TextStyle(
                      fontSize: 6,
                      color: StatementColors.grey500,
                      font: _fontRegular,
                    ),
                  ),
                  pw.Text(
                    'transaction_report_${_periodLabel(cfg.options)}.pdf',
                    style: pw.TextStyle(
                      fontSize: 5.5,
                      color: StatementColors.grey400,
                      font: _fontRegular,
                    ),
                  ),
                ],
              ),

              // Center: branding
              pw.Column(
                children: [
                  pw.Text(
                    'Generated by MicroFlow Pro',
                    style: pw.TextStyle(
                      fontSize: 6.5,
                      fontWeight: pw.FontWeight.bold,
                      color: StatementColors.teal600,
                      font: _fontSemiBold,
                    ),
                  ),
                  if (cfg.org.website != null &&
                      cfg.org.website!.isNotEmpty)
                    pw.Text(
                      _s(cfg.org.website),
                      style: pw.TextStyle(
                        fontSize: 5.5,
                        color: StatementColors.grey400,
                        font: _fontRegular,
                      ),
                    ),
                ],
              ),

              // Right: page number
              pw.Text(
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: StatementColors.navy700,
                  font: _fontBold,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 3),
        // Bottom gradient bar
        pw.Container(
          height: 2,
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [
                StatementColors.navy900,
                StatementColors.teal600,
                StatementColors.gold500,
                StatementColors.teal600,
                StatementColors.navy900,
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Section Label (reusable divider)
  // ─────────────────────────────────────────────────────────

  static pw.Widget _buildSectionLabel(String label) {
    return pw.Row(
      children: [
        pw.Container(
          width: 3,
          height: 10,
          decoration: pw.BoxDecoration(
            color: StatementColors.teal600,
            borderRadius: pw.BorderRadius.circular(2),
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: StatementColors.navy900,
            letterSpacing: 0.8,
            font: _fontBold,
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Divider(
            height: 1,
            thickness: 0.5,
            color: StatementColors.grey300,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildDecorativeDivider() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Container(
          width: 60,
          height: 3,
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [
                StatementColors.teal600,
                StatementColors.gold500,
                StatementColors.teal600,
              ],
            ),
            borderRadius: pw.BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Enhanced Summary (4 stat cards)
  // ─────────────────────────────────────────────────────────

  static pw.Widget _buildEnhancedSummary(_PdfConfig cfg) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: StatementColors.grey200, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
        color: StatementColors.grey50,
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _metricItem('Total Inflow', _money(cfg.totalInflow), StatementColors.green700),
          _metricItem('Total Outflow', _money(cfg.totalOutflow), StatementColors.red700),
          _metricItem('Transactions', '${cfg.transactionCount}', StatementColors.navy700),
          _metricItem(
            'Net',
            '${cfg.net >= 0 ? '+' : ''}${_money(cfg.net)}',
            cfg.net >= 0 ? StatementColors.teal600 : StatementColors.red700,
          ),
        ],
      ),
    );
  }

  static pw.Widget _metricItem(String label, String value, PdfColor valueColor) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 5.5,
              fontWeight: pw.FontWeight.bold,
              color: StatementColors.grey500,
              letterSpacing: 0.5,
              font: _fontSemiBold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: valueColor,
              font: _fontBold,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Type Breakdown Table
  // ─────────────────────────────────────────────────────────

  static pw.Widget _buildTypeBreakdown(_PdfConfig cfg) {
    final headerStyle = pw.TextStyle(
      fontSize: 7,
      fontWeight: pw.FontWeight.bold,
      color: StatementColors.white,
      letterSpacing: 0.5,
      font: _fontBold,
    );

    final rows = <pw.Widget>[];

    // Header row
    rows.add(pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: pw.BoxDecoration(
        color: StatementColors.navy800,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Text('Type', style: headerStyle),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Text('Direction', style: headerStyle),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Text('Count', style: headerStyle),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Total Amount', style: headerStyle),
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('% Share', style: headerStyle),
            ),
          ),
        ],
      ),
    ));

    // Data rows
    for (var i = 0; i < cfg.typeBreakdown.length; i++) {
      final tb = cfg.typeBreakdown[i];
      final isEven = i % 2 == 0;
      final pct = cfg.totalInflow > 0 && tb.isInflow
          ? '${(tb.total / cfg.totalInflow * 100).toStringAsFixed(1)}%'
          : '--';

      rows.add(pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: pw.BoxDecoration(
          color: isEven ? StatementColors.grey50 : PdfColors.white,
          border: pw.Border(
            bottom: pw.BorderSide(
              color: StatementColors.grey200,
              width: 0.3,
            ),
          ),
        ),
        child: pw.Row(
          children: [
            pw.Expanded(
              flex: 3,
              child: pw.Text(
                _typeLabel(tb.type),
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                  color: tb.isInflow
                      ? StatementColors.green700
                      : StatementColors.red700,
                  font: _fontSemiBold,
                ),
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 4, vertical: 1),
                decoration: pw.BoxDecoration(
                  color: tb.isInflow
                      ? StatementColors.green50
                      : StatementColors.red50,
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text(
                  tb.isInflow ? 'Inflow' : 'Outflow',
                  style: pw.TextStyle(
                    fontSize: 6.5,
                    fontWeight: pw.FontWeight.bold,
                    color: tb.isInflow
                        ? StatementColors.green700
                        : StatementColors.red700,
                    font: _fontSemiBold,
                  ),
                ),
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                tb.count.toString(),
                style: pw.TextStyle(
                  fontSize: 7.5,
                  color: StatementColors.grey800,
                  font: _fontRegular,
                ),
              ),
            ),
            pw.Expanded(
              flex: 3,
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  _money(tb.total),
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: StatementColors.grey800,
                    font: _fontSemiBold,
                  ),
                ),
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  pct,
                  style: pw.TextStyle(
                    fontSize: 7,
                    color: StatementColors.grey600,
                    font: _fontRegular,
                  ),
                ),
              ),
            ),
          ],
        ),
      ));
    }

    return pw.Column(children: rows);
  }

  // ─────────────────────────────────────────────────────────
  //  Filter Summary
  // ─────────────────────────────────────────────────────────

  static pw.Widget _buildFilterSummary(_PdfConfig cfg) {
    final opts = cfg.options;
    final chips = <pw.Widget>[];

    if (opts.typeFilter.isNotEmpty) {
      final names = opts.typeFilter.map((t) => _typeLabel(t)).join(', ');
      chips.add(_filterChip('Type: $names'));
    }
    if (opts.paymentModes.isNotEmpty) {
      final names =
          opts.paymentModes.map((m) => _paymentModeLabel(m)).join(', ');
      chips.add(_filterChip('Mode: $names'));
    }
    if (opts.amountMin != null || opts.amountMax != null) {
      final min =
          opts.amountMin != null ? _money(opts.amountMin!) : 'No min';
      final max =
          opts.amountMax != null ? _money(opts.amountMax!) : 'No max';
      chips.add(_filterChip('Amount: $min - $max'));
    }
    if (opts.searchQuery.isNotEmpty) {
      chips.add(_filterChip('Search: "${opts.searchQuery}"'));
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: StatementColors.teal50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: StatementColors.teal200, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'APPLIED FILTERS',
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: StatementColors.teal600,
              letterSpacing: 0.8,
              font: _fontBold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Wrap(
            spacing: 6,
            runSpacing: 4,
            children: chips,
          ),
        ],
      ),
    );
  }

  static pw.Widget _filterChip(String label) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(3),
        border: pw.Border.all(color: StatementColors.teal200, width: 0.5),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 7,
          color: StatementColors.teal600,
          font: _fontSemiBold,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Transaction Rows
  // ─────────────────────────────────────────────────────────

  static pw.Widget _buildTransactionLedger(_PdfConfig cfg) {
    // Flatten all transactions in date-group order
    final allTxns = <TransactionModel>[];
    for (final entry in cfg.grouped.entries) {
      allTxns.addAll(entry.value);
    }

    if (allTxns.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 40),
        child: pw.Center(
          child: pw.Column(
            children: [
              pw.Text(
                'No transactions found',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: StatementColors.grey500,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Try adjusting your filters or date range.',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: StatementColors.grey400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Build table data rows
    int idx = 1;
    final rows = allTxns.map((t) {
      final isInflow = _isInflow(t.type);
      final dateStr = cfg.compact
          ? _shortDateFmt.format(t.createdAt)
          : DateFormat('dd MMM, hh:mm').format(t.createdAt);
      final modeStr = t.paymentMode != null ? _paymentModeLabel(t.paymentMode!) : '\u2014';
      final collectedBy = (t.collectedByName ?? '').isNotEmpty ? t.collectedByName! : '\u2014';
      final amountStr = '${isInflow ? '+' : '-'}${_money(t.amount)}';

      return [
        '${idx++}',
        dateStr,
        t.memberName.isNotEmpty ? t.memberName : 'Unknown',
        _typeLabel(t.type),
        modeStr,
        collectedBy,
        amountStr,
      ];
    }).toList();

    // Build styled table
    final headerStyle = pw.TextStyle(
      fontSize: 7,
      fontWeight: pw.FontWeight.bold,
      color: StatementColors.white,
      letterSpacing: 0.3,
      font: _fontBold,
    );

    final headerRow = [
      pw.Expanded(flex: 1, child: pw.Text('#', style: headerStyle)),
      pw.Expanded(flex: 3, child: pw.Text('Date & Time', style: headerStyle)),
      pw.Expanded(flex: 4, child: pw.Text('Member', style: headerStyle)),
      pw.Expanded(flex: 2, child: pw.Text('Type', style: headerStyle)),
      pw.Expanded(flex: 2, child: pw.Text('Mode', style: headerStyle)),
      pw.Expanded(flex: 3, child: pw.Text('Collected By', style: headerStyle)),
      pw.Expanded(flex: 2, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Amount', style: headerStyle))),
    ];

    final tableRows = <pw.Widget>[];

    // Header row
    tableRows.add(pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: pw.BoxDecoration(
        color: StatementColors.navy800,
        borderRadius: const pw.BorderRadius.only(
          topLeft: pw.Radius.circular(4),
          topRight: pw.Radius.circular(4),
        ),
      ),
      child: pw.Row(children: headerRow),
    ));

    // Data rows
    for (var i = 0; i < allTxns.length; i++) {
      final t = allTxns[i];
      final isInflow = _isInflow(t.type);
      final amountColor = isInflow ? StatementColors.green700 : StatementColors.red700;
      final isEven = i % 2 == 0;
      final bgColor = isEven ? StatementColors.grey50 : PdfColors.white;

      final data = rows[i];
      tableRows.add(pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: pw.BoxDecoration(
          color: bgColor,
          border: pw.Border(
            bottom: pw.BorderSide(color: StatementColors.grey200, width: 0.3),
          ),
        ),
        child: pw.Row(
          children: [
            pw.Expanded(flex: 1, child: pw.Text(data[0], style: pw.TextStyle(fontSize: 7, color: StatementColors.grey500, font: _fontRegular))),
            pw.Expanded(flex: 3, child: pw.Text(data[1], style: pw.TextStyle(fontSize: 7, color: StatementColors.grey700, font: _fontRegular))),
            pw.Expanded(flex: 4, child: pw.Text(data[2], style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: StatementColors.grey900, font: _fontSemiBold))),
            pw.Expanded(flex: 2, child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: pw.BoxDecoration(
                color: isInflow ? StatementColors.green100 : StatementColors.red100,
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Text(data[3], style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: isInflow ? StatementColors.green700 : StatementColors.red700, font: _fontSemiBold)),
            )),
            pw.Expanded(flex: 2, child: pw.Text(data[4], style: pw.TextStyle(fontSize: 7, color: StatementColors.grey600, font: _fontRegular))),
            pw.Expanded(flex: 3, child: pw.Text(data[5], style: pw.TextStyle(fontSize: 7, color: StatementColors.grey600, font: _fontRegular))),
            pw.Expanded(flex: 2, child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(data[6], style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: amountColor, font: _fontBold)),
            )),
          ],
        ),
      ));
    }

    // Bottom rounded corners on last row
    if (tableRows.length > 1) {
      final lastRow = tableRows.last as pw.Container;
      final lastChild = lastRow.child as pw.Row;
      final isLastEven = (allTxns.length - 1) % 2 == 0;
      tableRows[tableRows.length - 1] = pw.Container(
        padding: lastRow.padding,
        decoration: pw.BoxDecoration(
          color: isLastEven ? StatementColors.grey50 : PdfColors.white,
          borderRadius: const pw.BorderRadius.only(
            bottomLeft: pw.Radius.circular(4),
            bottomRight: pw.Radius.circular(4),
          ),
        ),
        child: lastChild,
      );
    }

    return pw.Column(children: tableRows);
  }

  // ─────────────────────────────────────────────────────────
  //  Helpers
  // ─────────────────────────────────────────────────────────

  static String _periodLabel(TransactionExportOptions options) {
    final start = options.resolvedStart;
    final end = options.resolvedEnd;
    if (start != null && end != null) {
      return '${_dateFmt.format(start)}_to_${_dateFmt.format(end)}'
          .replaceAll(' ', '_');
    }
    return 'all';
  }

  static String _periodDisplay(TransactionExportOptions options) {
    final start = options.resolvedStart;
    final end = options.resolvedEnd;
    if (start != null && end != null) {
      return '${_dateFmt.format(start)} \u2014 ${_dateFmt.format(end)}';
    }
    return 'All Transactions';
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
      default:
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
      default:
        return '\u2014';
    }
  }
}
