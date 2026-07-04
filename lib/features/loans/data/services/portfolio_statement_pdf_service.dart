import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/constants/enums.dart';
import '../../../../core/constants/statement_colors.dart';
import '../../../../core/models/statement_org_info.dart';
import '../../../../core/utils/statement_formatters.dart';
import '../models/loan_model.dart';

/// Portfolio-level statement data model.
class PortfolioStatementData {
  final LoanSummary summary;
  final List<LoanModel> loans;
  final StatementOrgInfo org;
  final DateTime generatedAt;
  final String? generatedByName;
  final String? statementRef;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  /// Map of loan ID → overdue amount (pre-computed from EMI schedule).
  final Map<String, double> overdueAmounts;

  const PortfolioStatementData({
    required this.summary,
    required this.loans,
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
    debugPrint('[PortfolioStatementPdf] Font loading failed: $e');
  }
}

// ──────────────────────────────────────────────────────────────
//  Portfolio Statement Builder
// ──────────────────────────────────────────────────────────────

class PortfolioStatementPdfService {
  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');

  static double _safe(num? v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    final d = v.toDouble();
    return (d.isNaN || d.isInfinite) ? fallback : (d < 0 ? -d : d).toDouble();
  }

  static String _money(num? v) => StatementFormatters.money(_safe(v));
  static String _date(DateTime d) => _dateFmt.format(d);
  static String _dateTime(DateTime d) => _dateTimeFmt.format(d);
  static String _pct(num? v) => StatementFormatters.percentage(_safe(v));

  // ════════════════════════════════════════════════════════════
  //  PUBLIC ENTRY POINT
  // ════════════════════════════════════════════════════════════

  static Future<Uint8List> buildPortfolioStatement({
    required LoanSummary summary,
    required List<LoanModel> loans,
    required StatementOrgInfo org,
    String? generatedByName,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? statementRef,
    Uint8List? qrPngBytes,
    Map<String, double> overdueAmounts = const {},
  }) async {
    await _loadFonts();

    final data = PortfolioStatementData(
      summary: summary,
      loans: loans,
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
        "[PortfolioStatementPdf] FormatException with TTF fonts: $e\n"
        "Retrying with Helvetica fallback...\n$st",
      );
      _fontRegular = pw.Font.helvetica();
      _fontSemiBold = pw.Font.helveticaBold();
      _fontBold = pw.Font.helveticaBold();
      _fontsLoaded = true;
      try {
        return await _buildImpl(data, qrPngBytes: qrPngBytes);
      } catch (e2, st2) {
        debugPrint("[PortfolioStatementPdf] Retry also failed: $e2\n$st2");
        Error.throwWithStackTrace(StateError('PDF build failed: $e2'), st2);
      }
    } catch (e, st) {
      debugPrint("[PortfolioStatementPdf] Failed: $e\n$st");
      Error.throwWithStackTrace(StateError('PDF build failed: $e'), st);
    }
  }

  // ─────────────────────────────────────────────────────────
  //  Internal builder
  // ─────────────────────────────────────────────────────────

  static Future<Uint8List> _buildImpl(
    PortfolioStatementData data, {
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

    // ── Sort loans by status then name ──
    final sortedLoans = List<LoanModel>.from(data.loans)
      ..sort((a, b) {
        final statusCmp = a.status.index.compareTo(b.status.index);
        if (statusCmp != 0) return statusCmp;
        return (a.customerName ?? '').compareTo(b.customerName ?? '');
      });

    // ── Compute metrics ──
    final summary = data.summary;
    final closedLoans = summary.totalLoans - summary.activeLoans - summary.defaultLoans;

    // ── Build PDF ──
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        header: (context) => _buildHeader(data, s, effectiveStart, effectiveEnd, qrPngBytes),
        footer: (context) => _buildFooter(data, context, s),
        build: (context) => [
          // ── Portfolio Summary ──
          _buildSectionTitle('PORTFOLIO SUMMARY', theme),
          pw.SizedBox(height: 12),
          _buildSummaryGrid(summary, closedLoans, theme),
          pw.SizedBox(height: 20),

          // ── Status Distribution ──
          _buildSectionTitle('STATUS DISTRIBUTION', theme),
          pw.SizedBox(height: 10),
          _buildStatusDistribution(summary, closedLoans, theme),
          pw.SizedBox(height: 24),

          // ── Loan Breakdown ──
          _buildSectionTitle('LOAN BREAKDOWN', theme),
          pw.SizedBox(height: 10),
          _buildLoanTable(sortedLoans, data.overdueAmounts, theme),
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
    PortfolioStatementData data,
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
              'LOAN PORTFOLIO STATEMENT',
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
    LoanSummary summary,
    int closedLoans,
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
      child: pw.Column(
        children: [
          // Row 1: Counts
          pw.Row(
            children: [
              pw.Expanded(child: cell('TOTAL LOANS', summary.totalLoans.toString(), StatementColors.navy700)),
              pw.Expanded(child: cell('ACTIVE', summary.activeLoans.toString(), StatementColors.green700)),
              pw.Expanded(child: cell('DEFAULTED', summary.defaultLoans.toString(), StatementColors.red700)),
              pw.Expanded(child: cell('CLOSED', closedLoans.toString(), StatementColors.grey500)),
            ],
          ),
          pw.Container(height: 0.5, color: StatementColors.grey200),
          // Row 2: Amounts
          pw.Row(
            children: [
              pw.Expanded(child: cell('DISBURSED', _money(summary.totalDisbursed), StatementColors.teal600)),
              pw.Expanded(child: cell('OUTSTANDING', _money(summary.totalOutstanding), StatementColors.orange700)),
              pw.Expanded(child: cell('COLLECTED', _money(summary.totalCollected), StatementColors.green600)),
              pw.Expanded(child: cell('PAR %', _pct(summary.parPercentage), summary.parPercentage > 10 ? StatementColors.red700 : StatementColors.green700)),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  STATUS DISTRIBUTION
  // ─────────────────────────────────────────────────────────

  static pw.Widget _buildStatusDistribution(
    LoanSummary summary,
    int closedLoans,
    pw.ThemeData theme,
  ) {
    final total = summary.totalLoans;
    final activePct = total > 0 ? summary.activeLoans / total : 0.0;
    final defaultedPct = total > 0 ? summary.defaultLoans / total : 0.0;
    final closedPct = total > 0 ? closedLoans / total : 0.0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Stacked bar
        pw.Container(
          height: 16,
          decoration: pw.BoxDecoration(
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.ClipRRect(
            child: pw.Row(
              children: [
                if (activePct > 0)
                  pw.Expanded(
                    flex: (activePct * 1000).round().clamp(1, 999),
                    child: pw.Container(color: StatementColors.green600),
                  ),
                if (defaultedPct > 0)
                  pw.Expanded(
                    flex: (defaultedPct * 1000).round().clamp(1, 999),
                    child: pw.Container(color: StatementColors.red600),
                  ),
                if (closedPct > 0)
                  pw.Expanded(
                    flex: (closedPct * 1000).round().clamp(1, 999),
                    child: pw.Container(color: StatementColors.grey400),
                  ),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        // Legend
        pw.Row(
          children: [
            _legendDot(StatementColors.green600),
            pw.SizedBox(width: 4),
            pw.Text(
              'Active: ${summary.activeLoans} (${(activePct * 100).toStringAsFixed(0)}%)',
              style: pw.TextStyle(font: _fontRegular, fontSize: 9, color: StatementColors.grey700),
            ),
            pw.SizedBox(width: 16),
            _legendDot(StatementColors.red600),
            pw.SizedBox(width: 4),
            pw.Text(
              'Defaulted: ${summary.defaultLoans} (${(defaultedPct * 100).toStringAsFixed(0)}%)',
              style: pw.TextStyle(font: _fontRegular, fontSize: 9, color: StatementColors.grey700),
            ),
            pw.SizedBox(width: 16),
            _legendDot(StatementColors.grey400),
            pw.SizedBox(width: 4),
            pw.Text(
              'Closed: $closedLoans (${(closedPct * 100).toStringAsFixed(0)}%)',
              style: pw.TextStyle(font: _fontRegular, fontSize: 9, color: StatementColors.grey700),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _legendDot(PdfColor color) {
    return pw.Container(
      width: 8,
      height: 8,
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  LOAN TABLE — compact, info-dense
  // ─────────────────────────────────────────────────────────

  static pw.Widget _buildLoanTable(List<LoanModel> loans, Map<String, double> overdueAmounts, pw.ThemeData theme) {
    if (loans.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(20),
        child: pw.Center(
          child: pw.Text(
            'No loans found.',
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
      },
      columnWidths: {
        0: const pw.FlexColumnWidth(0.3),
        1: const pw.FlexColumnWidth(1.3),
        2: const pw.FlexColumnWidth(0.9),
        3: const pw.FlexColumnWidth(0.9),
        4: const pw.FlexColumnWidth(0.9),
        5: const pw.FlexColumnWidth(0.75),
        6: const pw.FlexColumnWidth(0.65),
        7: const pw.FlexColumnWidth(0.6),
      },
      headers: ['#', 'BORROWER', 'PRINCIPAL', 'OUTSTANDING', 'COLLECTED', 'OVERDUE', 'RATIO', 'STATUS'],
      data: loans.asMap().entries.map((entry) {
        final i = entry.key + 1;
        final loan = entry.value;
        final statusLabel = loan.status == LoanStatus.defaultStatus
            ? 'DEFAULT'
            : loan.status.name.toUpperCase();
        final collected = loan.totalRepayable - loan.outstandingBalance;
        final overdueAmt = overdueAmounts[loan.id] ?? 0.0;
        final totalDays = loan.tenureMonths * 30;
        final collectedRatio = totalDays > 0
            ? '${loan.paidEmis}/$totalDays'
            : '-';

        return [
          i.toString(),
          StatementFormatters.sanitizeForEncoding(loan.customerName ?? 'Unknown'),
          _money(loan.amount),
          _money(loan.outstandingBalance),
          _money(collected),
          overdueAmt > 0 ? _money(overdueAmt) : '-',
          collectedRatio,
          statusLabel,
        ];
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  DISCLAIMER
  // ─────────────────────────────────────────────────────────

  static pw.Widget _buildDisclaimer(
    PortfolioStatementData data,
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
    PortfolioStatementData data,
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
