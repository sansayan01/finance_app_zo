import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/statement_colors.dart';
import '../../../../core/models/statement_org_info.dart';
import '../../../../core/utils/statement_formatters.dart';
import '../models/today_payment_model.dart';
import '../providers/payment_providers.dart';

// ──────────────────────────────────────────────────────────────
//  Font loading — graceful fallback to Helvetica
// ──────────────────────────────────────────────────────────────

pw.Font _fontRegular = pw.Font.helvetica();
pw.Font _fontSemiBold = pw.Font.helveticaBold();
pw.Font _fontBold = pw.Font.helveticaBold();
bool _fontsLoaded = false;

bool _isValidFontData(Uint8List data) {
  if (data.length < 4) return false;
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
    }
  } catch (_) {}
}

// ──────────────────────────────────────────────────────────────
//  PDF Service
// ──────────────────────────────────────────────────────────────

class PaymentPdfService {
  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');

  static String _s(String? s) => StatementFormatters.sanitizeForEncoding(s);
  static String _money(num v) => StatementFormatters.money(v);


  // ── Public API ──

  static Future<Uint8List> generate({
    required TodayPaymentData data,
    required String dateLabel,
    StatementOrgInfo? orgInfo,
  }) async {
    await _loadFonts();
    return _buildPdf(data: data, dateLabel: dateLabel, orgInfo: orgInfo);
  }

  static Future<void> share({
    required TodayPaymentData data,
    required String dateLabel,
    StatementOrgInfo? orgInfo,
  }) async {
    final bytes = await generate(data: data, dateLabel: dateLabel, orgInfo: orgInfo);
    final dir = await getTemporaryDirectory();
    final safeDate = dateLabel.replaceAll(RegExp(r'[^\w]'), '_');
    final file = File('${dir.path}/payments_report_$safeDate.pdf');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Payments Report - $dateLabel',
        text: 'Payments report for $dateLabel',
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  PDF Builder
  // ─────────────────────────────────────────────────────────

  static Future<Uint8List> _buildPdf({
    required TodayPaymentData data,
    required String dateLabel,
    StatementOrgInfo? orgInfo,
  }) async {
    final org = orgInfo ?? StatementOrgInfo.fallback();
    final generatedAt = DateTime.now();
    final summary = data.summary;
    final payments = data.payments;

    final theme = pw.ThemeData.withFont(
      base: _fontRegular,
      bold: _fontBold,
    );

    final pdf = pw.Document(
      theme: theme,
      author: _s(org.name),
      creator: 'MicroFlow Pro',
      subject: 'Payments Report',
    );

    // 1. Determine the report date (selected date)
    final now = DateTime.now();
    DateTime? reportDate;
    for (final p in payments) {
      if (p.isPending) {
        reportDate = DateTime(p.dueDate.year, p.dueDate.month, p.dueDate.day);
        break;
      }
    }
    if (reportDate == null) {
      for (final p in payments) {
        if (p.isCollected) {
          reportDate = DateTime(p.dueDate.year, p.dueDate.month, p.dueDate.day);
          break;
        }
      }
    }
    final finalReportDate = reportDate ?? DateTime(now.year, now.month, now.day);

    // 2. Separate payments into Overdue, Pending (Today's Due), and Collected Today
    final overduePayments = payments.where((p) => p.isOverdue || p.dueDate.isBefore(finalReportDate)).toList();
    final pendingPayments = payments.where((p) => p.isPending && !p.dueDate.isBefore(finalReportDate)).toList();
    final collectedPayments = payments.where((p) => p.isCollected && !p.dueDate.isBefore(finalReportDate)).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 48),
        header: (ctx) => _buildHeader(org, dateLabel, generatedAt),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) {
          final List<pw.Widget> content = [
            pw.SizedBox(height: 8),
            _buildSummaryPanel(summary),
            pw.SizedBox(height: 8),
          ];

          if (overduePayments.isNotEmpty) {
            content.add(_buildSectionHeader('Overdue Payments', StatementColors.red700));
            content.add(_buildPaymentTable(overduePayments, PdfColor.fromHex('#7F1D1D'), finalReportDate));
          }

          if (pendingPayments.isNotEmpty) {
            content.add(_buildSectionHeader('Today\'s Due (Pending)', StatementColors.orange700));
            content.add(_buildPaymentTable(pendingPayments, StatementColors.navy900, finalReportDate));
          }

          if (collectedPayments.isNotEmpty) {
            content.add(_buildSectionHeader('Collected Today', StatementColors.green700));
            content.add(_buildPaymentTable(collectedPayments, PdfColor.fromHex('#064E3B'), finalReportDate));
          }

          if (payments.isEmpty) {
            content.add(
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(40),
                  child: pw.Text(
                    'No payments found for this date',
                    style: pw.TextStyle(font: _fontRegular, fontSize: 14, color: StatementColors.grey500),
                  ),
                ),
              ),
            );
          }

          return content;
        },
      ),
    );

    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────
  //  Header
  // ─────────────────────────────────────────────────────────

  static pw.Widget _buildHeader(StatementOrgInfo org, String dateLabel, DateTime generatedAt) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: StatementColors.navy100, width: 1)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _s(org.name),
                  style: pw.TextStyle(font: _fontBold, fontSize: 18, color: StatementColors.navy900),
                ),
                if (org.tagline != null && org.tagline!.isNotEmpty)
                  pw.Text(
                    _s(org.tagline),
                    style: pw.TextStyle(font: _fontRegular, fontSize: 9, color: StatementColors.grey500),
                  ),
                if (org.fullAddress.isNotEmpty)
                  pw.Text(
                    _s(org.fullAddress),
                    style: pw.TextStyle(font: _fontRegular, fontSize: 8, color: StatementColors.grey500),
                  ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: StatementColors.navy900,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'PAYMENTS REPORT',
                  style: pw.TextStyle(font: _fontBold, fontSize: 9, color: StatementColors.white, letterSpacing: 1),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                dateLabel,
                style: pw.TextStyle(font: _fontSemiBold, fontSize: 11, color: StatementColors.navy800),
              ),
              pw.Text(
                'Generated: ${_dateTimeFmt.format(generatedAt)}',
                style: pw.TextStyle(font: _fontRegular, fontSize: 7, color: StatementColors.grey500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Summary Panel
  // ─────────────────────────────────────────────────────────

  static pw.Widget _buildSummaryPanel(TodayPaymentSummary summary) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: StatementColors.navy50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: StatementColors.navy100, width: 0.5),
      ),
      child: pw.Row(
        children: [
          _buildStatCard('Total Due', _money(summary.totalDue), '${summary.countDue} items', StatementColors.navy700),
          pw.SizedBox(width: 8),
          _buildStatCard('Collected', _money(summary.totalCollected), '${summary.countCollected} items (${summary.collectionRate.toStringAsFixed(0)}%)', StatementColors.green700),
          pw.SizedBox(width: 8),
          _buildStatCard('Pending', _money(summary.totalPending), '${summary.countPending} items', StatementColors.orange700),
          pw.SizedBox(width: 8),
          _buildStatCard('Overdue', _money(summary.totalOverdue), '${summary.countOverdue} items', StatementColors.red700),
          if (summary.totalPenalty > 0) ...[
            pw.SizedBox(width: 8),
            _buildStatCard('Penalty', _money(summary.totalPenalty), '', StatementColors.red600),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildStatCard(String label, String value, String subtitle, PdfColor color) {
    const cardHeight = 44.0;
    return pw.Expanded(
      child: pw.Container(
        height: cardHeight,
        decoration: pw.BoxDecoration(
          color: StatementColors.white,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: StatementColors.grey200, width: 0.5),
        ),
        child: pw.Row(
          children: [
            pw.Container(
              width: 3.5,
              height: cardHeight,
              decoration: pw.BoxDecoration(
                color: color,
                borderRadius: const pw.BorderRadius.only(
                  topLeft: pw.Radius.circular(3.5),
                  bottomLeft: pw.Radius.circular(3.5),
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(label.toUpperCase(), style: pw.TextStyle(font: _fontRegular, fontSize: 7, color: StatementColors.grey500, letterSpacing: 0.8)),
                    pw.SizedBox(height: 1),
                    pw.Text(value, style: pw.TextStyle(font: _fontBold, fontSize: 11, color: color)),
                    if (subtitle.isNotEmpty) ...[
                      pw.SizedBox(height: 1),
                      pw.Text(subtitle, style: pw.TextStyle(font: _fontRegular, fontSize: 7, color: StatementColors.grey500)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildHeaderCell(String text, pw.TextStyle style, pw.Alignment alignment) {
    return pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: pw.Text(text, style: style),
    );
  }

  static pw.Widget _buildTableCell(String text, pw.TextStyle style, pw.Alignment alignment, {bool softWrap = true}) {
    return pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(text, style: style, softWrap: softWrap),
    );
  }

  static pw.Widget _buildTypeBadge(String type) {
    final isSavings = type.toLowerCase().contains('savings') || type.toLowerCase().contains('deposit');
    final bgColor = isSavings ? PdfColor.fromHex('#F3E8FF') : PdfColor.fromHex('#E0F2FE');
    final textColor = isSavings ? PdfColor.fromHex('#7E22CE') : PdfColor.fromHex('#0369A1');

    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(
          type.toUpperCase(),
          style: pw.TextStyle(font: _fontBold, fontSize: 6.5, color: textColor),
        ),
      ),
    );
  }

  static pw.Widget _buildStatusBadge(String status) {
    final s = status.toLowerCase();
    PdfColor bgColor;
    PdfColor textColor;

    if (s.contains('collected') || s.contains('paid')) {
      bgColor = PdfColor.fromHex('#DCFCE7');
      textColor = PdfColor.fromHex('#15803D');
    } else if (s.contains('overdue')) {
      bgColor = PdfColor.fromHex('#FEE2E2');
      textColor = PdfColor.fromHex('#B91C1C');
    } else {
      // Pending
      bgColor = PdfColor.fromHex('#FFEDD5');
      textColor = PdfColor.fromHex('#C2410C');
    }

    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(
          status.toUpperCase(),
          style: pw.TextStyle(font: _fontBold, fontSize: 6.5, color: textColor),
        ),
      ),
    );
  }

  static pw.Widget _buildSectionHeader(String title, PdfColor color) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: pw.Row(
        children: [
          pw.Container(
            width: 3.5,
            height: 11,
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              font: _fontBold,
              fontSize: 8.5,
              color: StatementColors.navy900,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPaymentTable(List<TodayPayment> payments, PdfColor headerBgColor, DateTime reportDate) {
    final headerStyle = pw.TextStyle(font: _fontBold, fontSize: 7.5, color: StatementColors.white, letterSpacing: 0.5);
    final cellStyle = pw.TextStyle(font: _fontRegular, fontSize: 7.5, color: StatementColors.grey800);

    // Group payments by unique loan/plan
    final Map<String, List<TodayPayment>> groups = {};
    for (final p in payments) {
      final key = p.type == PaymentType.emi
          ? (p.loanId ?? p.loanNumber ?? p.id)
          : '${p.memberId ?? p.memberName}_${p.planName ?? p.id}';
      groups.putIfAbsent(key, () => []).add(p);
    }

    final List<pw.TableRow> rows = [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: headerBgColor),
        children: [
          _buildHeaderCell('#', headerStyle, pw.Alignment.center),
          _buildHeaderCell('Customer', headerStyle, pw.Alignment.centerLeft),
          _buildHeaderCell('Type', headerStyle, pw.Alignment.center),
          _buildHeaderCell('Loan / Plan', headerStyle, pw.Alignment.centerLeft),
          _buildHeaderCell('Amount Due', headerStyle, pw.Alignment.centerRight),
          _buildHeaderCell('Penalty', headerStyle, pw.Alignment.centerRight),
          _buildHeaderCell('Collected', headerStyle, pw.Alignment.centerRight),
          _buildHeaderCell('Status', headerStyle, pw.Alignment.center),
          _buildHeaderCell('Mode', headerStyle, pw.Alignment.center),
          _buildHeaderCell('Due Date', headerStyle, pw.Alignment.center),
        ],
      ),
    ];

    int rowIndex = 1;
    for (final group in groups.values) {
      final first = group.first;
      final isEven = rowIndex % 2 == 0;
      final rowBg = isEven ? StatementColors.grey50 : StatementColors.white;

      final totalExpected = group.fold<double>(0.0, (sum, p) => sum + p.amountExpected);
      final totalPenalty = group.fold<double>(0.0, (sum, p) => sum + p.penaltyAmount);
      final totalCollected = group.fold<double>(0.0, (sum, p) => sum + (p.amountCollected ?? 0.0));

      final collectedCount = group.where((p) => p.isCollected).length;
      final overdueCount = group.where((p) => p.isOverdue || p.dueDate.isBefore(reportDate)).length;

      // Status determination
      String statusLabel;
      if (collectedCount == group.length) {
        statusLabel = 'Collected';
      } else if (overdueCount > 0) {
        statusLabel = 'Overdue';
      } else {
        statusLabel = 'Pending';
      }

      // Mode: unique non-empty modes
      final modes = group
          .map((p) => p.paymentMode)
          .where((m) => m != null && m.isNotEmpty)
          .toSet()
          .map((m) => m!.toUpperCase())
          .join(', ');
      final modeText = modes.isNotEmpty ? modes : '-';

      // Due Date range
      final dates = group.map((p) => p.dueDate).toList()..sort();
      final String dueDateStr = dates.first.day == dates.last.day &&
              dates.first.month == dates.last.month &&
              dates.first.year == dates.last.year
          ? _dateFmt.format(dates.first)
          : '${_dateFmt.format(dates.first)} – ${_dateFmt.format(dates.last)}';

      // Loan / Plan text
      final loanOrPlanName = first.loanNumber ?? first.planName ?? '-';
      pw.Widget loanPlanWidget;
      if (group.length > 1) {
        final countText = overdueCount > 0
            ? '(${group.length} overdues)'
            : '(${group.length} installments)';
        loanPlanWidget = pw.Container(
          alignment: pw.Alignment.centerLeft,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(_s(loanOrPlanName), style: cellStyle),
              pw.SizedBox(height: 1),
              pw.Text(countText, style: pw.TextStyle(font: _fontRegular, fontSize: 6.5, color: StatementColors.grey500)),
            ],
          ),
        );
      } else {
        loanPlanWidget = _buildTableCell(_s(loanOrPlanName), cellStyle, pw.Alignment.centerLeft);
      }

      // Collected column widget
      pw.Widget collectedWidget;
      if (group.length > 1 && collectedCount > 0) {
        collectedWidget = pw.Container(
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(_money(totalCollected), style: cellStyle),
              pw.SizedBox(height: 1),
              pw.Text('($collectedCount paid)', style: pw.TextStyle(font: _fontRegular, fontSize: 6.5, color: StatementColors.grey500)),
            ],
          ),
        );
      } else {
        collectedWidget = _buildTableCell(totalCollected > 0 ? _money(totalCollected) : '-', cellStyle, pw.Alignment.centerRight);
      }

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: rowBg),
          children: [
            _buildTableCell('$rowIndex', cellStyle, pw.Alignment.center, softWrap: false),
            _buildTableCell(_s(first.memberName), cellStyle, pw.Alignment.centerLeft),
            _buildTypeBadge(first.typeLabel),
            loanPlanWidget,
            _buildTableCell(_money(totalExpected), cellStyle, pw.Alignment.centerRight),
            _buildTableCell(totalPenalty > 0 ? _money(totalPenalty) : '-', cellStyle, pw.Alignment.centerRight),
            collectedWidget,
            _buildStatusBadge(statusLabel),
            _buildTableCell(modeText, cellStyle, pw.Alignment.center),
            _buildTableCell(dueDateStr, cellStyle, pw.Alignment.center),
          ],
        ),
      );
      rowIndex++;
    }

    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: StatementColors.grey200, width: 0.5),
        bottom: pw.BorderSide(color: StatementColors.grey300, width: 0.5),
      ),
      columnWidths: {
        0: const pw.FixedColumnWidth(25), // #
        1: const pw.FlexColumnWidth(2.2), // Customer
        2: const pw.FixedColumnWidth(45), // Type
        3: const pw.FlexColumnWidth(2.2), // Loan / Plan
        4: const pw.FixedColumnWidth(65), // Amount Due
        5: const pw.FixedColumnWidth(45), // Penalty
        6: const pw.FixedColumnWidth(65), // Collected
        7: const pw.FixedColumnWidth(55), // Status
        8: const pw.FixedColumnWidth(50), // Mode
        9: const pw.FixedColumnWidth(95), // Due Date
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: rows,
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Footer
  // ─────────────────────────────────────────────────────────

  static pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: StatementColors.grey200, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated by MicroFlow Pro',
            style: pw.TextStyle(font: _fontRegular, fontSize: 7, color: StatementColors.grey400),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(font: _fontRegular, fontSize: 7, color: StatementColors.grey400),
          ),
        ],
      ),
    );
  }
}
