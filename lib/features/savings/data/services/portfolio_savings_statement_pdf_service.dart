import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/constants/statement_colors.dart';
import '../../../../core/models/statement_org_info.dart';
import '../../../../core/utils/statement_formatters.dart';
import '../models/savings_model.dart';

/// Portfolio-level savings statement data model.
class PortfolioSavingsStatementData {
  final SavingsSummary summary;
  final List<SavingsModel> plans;
  final StatementOrgInfo org;
  final DateTime generatedAt;
  final String? generatedByName;
  final String? statementRef;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  /// Map of plan ID → overdue amount (pre-computed from schedule).
  final Map<String, double> overdueAmounts;

  const PortfolioSavingsStatementData({
    required this.summary,
    required this.plans,
    required this.org,
    required this.generatedAt,
    this.generatedByName,
    this.statementRef,
    this.periodStart,
    this.periodEnd,
    this.overdueAmounts = const {},
  });
}

// ──────────────────────────────────────────────────────────────
//  Font loading (Inter) — graceful fallback to Helvetica
// ──────────────────────────────────────────────────────────────

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
    debugPrint('[PortfolioSavingsStatementPdf] Font loading failed: $e');
  }
}

// ──────────────────────────────────────────────────────────────
//  Portfolio Savings Statement Builder
// ──────────────────────────────────────────────────────────────

class PortfolioSavingsStatementPdfService {
  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');

  static double _safe(num? v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    final d = v.toDouble();
    return (d.isNaN || d.isInfinite) ? fallback : (d < 0 ? -d : d).toDouble();
  }

  static String _date(DateTime d) => _dateFmt.format(d);
  static String _dateTime(DateTime d) => _dateTimeFmt.format(d);

  /// Money without decimals: "Rs. 1,500" instead of "Rs. 1,500.00"
  static String _moneyInt(num? v) {
    final raw = _safe(v);
    final negative = (v ?? 0) < 0;
    final n = raw;
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

  // ════════════════════════════════════════════════════════════
  //  PUBLIC ENTRY POINT
  // ════════════════════════════════════════════════════════════

  static Future<Uint8List> buildPortfolioStatement({
    required SavingsSummary summary,
    required List<SavingsModel> plans,
    required StatementOrgInfo org,
    String? generatedByName,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? statementRef,
    Uint8List? qrPngBytes,
    Map<String, double> overdueAmounts = const {},
  }) async {
    await _loadFonts();

    final data = PortfolioSavingsStatementData(
      summary: summary,
      plans: plans,
      org: org,
      generatedAt: DateTime.now(),
      generatedByName: generatedByName,
      statementRef: statementRef,
      periodStart: periodStart,
      periodEnd: periodEnd,
      overdueAmounts: overdueAmounts,
    );

    try {
      return await _buildImpl(data, qrPngBytes: qrPngBytes);
    } on FormatException catch (e, st) {
      debugPrint(
        "[PortfolioSavingsStatementPdf] FormatException with TTF fonts: $e\n"
        "Retrying with Helvetica fallback...\n$st",
      );
      _fontRegular = pw.Font.helvetica();
      _fontSemiBold = pw.Font.helveticaBold();
      _fontBold = pw.Font.helveticaBold();
      _fontsLoaded = true;
      try {
        return await _buildImpl(data, qrPngBytes: qrPngBytes);
      } catch (e2, st2) {
        debugPrint("[PortfolioSavingsStatementPdf] Retry also failed: $e2\n$st2");
        Error.throwWithStackTrace(StateError('PDF build failed: $e2'), st2);
      }
    } catch (e, st) {
      debugPrint("[PortfolioSavingsStatementPdf] Failed: $e\n$st");
      Error.throwWithStackTrace(StateError('PDF build failed: $e'), st);
    }
  }

  // ─────────────────────────────────────────────────────────
  //  Internal builder
  // ─────────────────────────────────────────────────────────

  static Future<Uint8List> _buildImpl(
    PortfolioSavingsStatementData data, {
    Uint8List? qrPngBytes,
  }) async {
    final s = StatementFormatters.sanitizeForEncoding;
    final generatedAt = data.generatedAt;
    final effectiveStart = data.periodStart ?? DateTime(2000);
    final effectiveEnd = data.periodEnd ?? generatedAt;

    final theme = pw.ThemeData.withFont(
      base: _fontRegular,
      bold: _fontBold,
      boldItalic: _fontSemiBold,
      italic: _fontRegular,
    );

    final doc = pw.Document();

    // ── Sort plans by status then name ──
    final sortedPlans = List<SavingsModel>.from(data.plans)
      ..sort((a, b) {
        final statusCmp = a.status.compareTo(b.status);
        if (statusCmp != 0) return statusCmp;
        return a.memberName.compareTo(b.memberName);
      });

    // ── Compute metrics ──
    final summary = data.summary;
    final maturedPlans = sortedPlans.where((p) => p.status == 'matured').length;
    final totalDeposited = sortedPlans.fold<double>(0, (sum, p) => sum + p.currentAmount);

    // ── Build PDF ──
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        header: (context) => _buildHeader(data, s, effectiveStart, effectiveEnd, qrPngBytes),
        footer: (context) => _buildFooter(data, context, s),
        build: (context) => [
          // ── Portfolio Summary ──
          _buildSectionTitle('SAVINGS PORTFOLIO SUMMARY', theme),
          pw.SizedBox(height: 12),
          _buildSummaryGrid(summary, maturedPlans, totalDeposited, theme),
          pw.SizedBox(height: 20),

          // ── Savings Plans Breakdown ──
          _buildSectionTitle('SAVINGS PLANS', theme),
          pw.SizedBox(height: 10),
          _buildPlansTable(sortedPlans, data.overdueAmounts, theme),
          pw.SizedBox(height: 20),

          // ── Disclaimer ──
          _buildDisclaimer(data, s, theme),
        ],
      ),
    );

    return doc.save();
  }

  // ─────────────────────────────────────────────────────────
  //  HEADER
  // ─────────────────────────────────────────────────────────

  static pw.Widget _buildHeader(
    PortfolioSavingsStatementData data,
    String Function(String?) s,
    DateTime effectiveStart,
    DateTime effectiveEnd,
    Uint8List? qrPngBytes,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Logo (larger, centered)
          if (data.org.logoBytes != null &&
              StatementFormatters.isValidImage(data.org.logoBytes))
            pw.Container(
              height: 50,
              child: pw.Image(
                pw.MemoryImage(data.org.logoBytes!),
                fit: pw.BoxFit.contain,
              ),
            ),
          if (data.org.logoBytes != null) pw.SizedBox(height: 10),
          // Org name (large, premium)
          pw.Center(
            child: pw.Text(
              s(data.org.name),
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
          if (data.org.fullAddress.isNotEmpty)
            pw.Center(
              child: pw.Text(
                s(data.org.fullAddress),
                style: pw.TextStyle(
                  font: _fontRegular,
                  fontSize: 10,
                  color: StatementColors.grey600,
                ),
              ),
            ),
          // Phone | Email
          if (data.org.phone != null || data.org.email != null)
            pw.Center(
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(top: 3),
                child: pw.Text(
                  [
                    if (data.org.phone != null) 'Ph: ${s(data.org.phone)}',
                    if (data.org.email != null) 'Email: ${s(data.org.email)}',
                  ].join('  |  '),
                  style: pw.TextStyle(
                    font: _fontRegular,
                    fontSize: 9,
                    color: StatementColors.grey500,
                  ),
                ),
              ),
            ),
          if (qrPngBytes != null && StatementFormatters.isValidImage(qrPngBytes))
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
          pw.SizedBox(height: 16),

          // Title
          pw.Center(
            child: pw.Text(
              'SAVINGS PORTFOLIO STATEMENT',
              style: pw.TextStyle(
                font: _fontBold,
                fontSize: 18,
                letterSpacing: 2,
                color: StatementColors.navy900,
              ),
            ),
          ),
          pw.SizedBox(height: 12),

          // Meta row
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Period: ${_date(effectiveStart)}  →  ${_date(effectiveEnd)}',
                    style: pw.TextStyle(
                      font: _fontSemiBold,
                      fontSize: 9,
                      color: StatementColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Generated: ${_dateTime(data.generatedAt)}',
                    style: pw.TextStyle(
                      font: _fontRegular,
                      fontSize: 8,
                      color: StatementColors.grey500,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if (data.statementRef != null)
                    pw.Text(
                      'Ref: ${s(data.statementRef)}',
                      style: pw.TextStyle(
                        font: _fontRegular,
                        fontSize: 8,
                        color: StatementColors.grey500,
                      ),
                    ),
                  if (data.generatedByName != null)
                    pw.Text(
                      'By: ${s(data.generatedByName)}',
                      style: pw.TextStyle(
                        font: _fontRegular,
                        fontSize: 8,
                        color: StatementColors.grey500,
                      ),
                    ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 12),
          pw.Container(height: 0.5, color: StatementColors.grey200),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  SECTION TITLE
  // ─────────────────────────────────────────────────────────

  static pw.Widget _buildSectionTitle(String title, pw.ThemeData theme) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: StatementColors.navy900, width: 1.5),
        ),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          font: _fontBold,
          fontSize: 11,
          letterSpacing: 1.2,
          color: StatementColors.navy900,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  SUMMARY GRID — compact 2-row table
  // ─────────────────────────────────────────────────────────

  static pw.Widget _buildSummaryGrid(
    SavingsSummary summary,
    int maturedPlans,
    double totalDeposited,
    pw.ThemeData theme,
  ) {
    final labelStyle = pw.TextStyle(
      font: _fontBold,
      fontSize: 7,
      letterSpacing: 0.8,
      color: StatementColors.grey500,
    );

    final valueStyle = pw.TextStyle(
      font: _fontBold,
      fontSize: 11,
      color: StatementColors.grey800,
    );

    pw.Widget cell(String label, String value, PdfColor accent) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: pw.BoxDecoration(
          border: pw.Border(
            right: pw.BorderSide(color: StatementColors.grey200, width: 0.5),
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: labelStyle),
            pw.SizedBox(height: 2),
            pw.Text(value, style: valueStyle.copyWith(color: accent)),
          ],
        ),
      );
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: StatementColors.grey200, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(child: cell('TOTAL PLANS', summary.activeAccounts.toString(), StatementColors.navy700)),
          pw.Expanded(child: cell('ACTIVE', summary.activeAccounts.toString(), StatementColors.green700)),
          pw.Expanded(child: cell('MATURED', maturedPlans.toString(), StatementColors.teal600)),
          pw.Expanded(child: cell('COLLECTED', _moneyInt(totalDeposited), StatementColors.green600)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  PLANS TABLE — compact, info-dense
  // ─────────────────────────────────────────────────────────

  static pw.Widget _buildPlansTable(List<SavingsModel> plans, Map<String, double> overdueAmounts, pw.ThemeData theme) {
    if (plans.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(20),
        child: pw.Center(
          child: pw.Text(
            'No savings plans found.',
            style: pw.TextStyle(
              font: _fontRegular,
              fontSize: 10,
              color: StatementColors.grey400,
            ),
          ),
        ),
      );
    }

    final headerStyle = pw.TextStyle(
      font: _fontBold,
      fontSize: 7,
      color: StatementColors.white,
    );

    final cellStyle = pw.TextStyle(
      font: _fontRegular,
      fontSize: 7.5,
      color: StatementColors.grey800,
    );

    return pw.TableHelper.fromTextArray(
      headerStyle: headerStyle,
      cellStyle: cellStyle,
      headerDecoration: pw.BoxDecoration(
        color: StatementColors.navy900,
      ),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.center,
        7: pw.Alignment.center,
        8: pw.Alignment.center,
      },
      headerAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.center,
        7: pw.Alignment.center,
        8: pw.Alignment.center,
      },
      columnWidths: {
        0: const pw.FlexColumnWidth(0.3),
        1: const pw.FlexColumnWidth(1.2),
        2: const pw.FlexColumnWidth(0.85),
        3: const pw.FlexColumnWidth(0.85),
        4: const pw.FlexColumnWidth(0.85),
        5: const pw.FlexColumnWidth(0.7),
        6: const pw.FlexColumnWidth(0.55),
        7: const pw.FlexColumnWidth(0.5),
        8: const pw.FlexColumnWidth(0.55),
      },
      headers: ['#', 'MEMBER', 'COLLECTED', 'TARGET', 'MATURITY', 'TENURE', 'STATUS', 'RATIO', 'OVERDUE'],
      data: plans.asMap().entries.map((entry) {
        final i = entry.key + 1;
        final plan = entry.value;
        final statusLabel = plan.status.toUpperCase();
        final tenureLabel = '${plan.tenure}${plan.tenureUnit?.substring(0, 1) ?? 'M'}';
        final ratio = plan.totalInstallments > 0
            ? '${plan.installmentsPaid}/${plan.totalInstallments}'
            : '-';
        final overdueAmt = overdueAmounts[plan.id] ?? 0.0;

        return [
          i.toString(),
          StatementFormatters.sanitizeForEncoding(plan.memberName),
          _moneyInt(plan.currentAmount),
          _moneyInt(plan.targetAmount),
          _date(plan.maturityDate),
          tenureLabel,
          statusLabel,
          ratio,
          overdueAmt > 0 ? _moneyInt(overdueAmt) : '-',
        ];
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  DISCLAIMER
  // ─────────────────────────────────────────────────────────

  static pw.Widget _buildDisclaimer(
    PortfolioSavingsStatementData data,
    String Function(String?) s,
    pw.ThemeData theme,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: StatementColors.grey50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: StatementColors.grey200, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'DISCLAIMER',
            style: pw.TextStyle(
              font: _fontBold,
              fontSize: 8,
              letterSpacing: 1,
              color: StatementColors.grey500,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'This statement is generated from the system records of ${s(data.org.name)} '
            'and is intended for internal use only. The figures are as of ${_dateTime(data.generatedAt)} '
            'and may change upon reconciliation. For any discrepancies, please contact the administration.',
            style: pw.TextStyle(
              font: _fontRegular,
              fontSize: 8,
              color: StatementColors.grey500,
              lineSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  FOOTER
  // ─────────────────────────────────────────────────────────

  static pw.Widget _buildFooter(
    PortfolioSavingsStatementData data,
    pw.Context context,
    String Function(String?) s,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 16),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: StatementColors.grey200, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            s(data.org.name),
            style: pw.TextStyle(
              font: _fontRegular,
              fontSize: 7,
              color: StatementColors.grey400,
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(
              font: _fontRegular,
              fontSize: 7,
              color: StatementColors.grey400,
            ),
          ),
          if (data.statementRef != null)
            pw.Text(
              s(data.statementRef),
              style: pw.TextStyle(
                font: _fontRegular,
                fontSize: 7,
                color: StatementColors.grey400,
              ),
            ),
        ],
      ),
    );
  }
}
