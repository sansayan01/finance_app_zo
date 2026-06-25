import 'dart:math' as math;
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
import '../models/emi_schedule_model.dart';
import 'qr_png.dart';

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
    // Fonts not loadable — stay with Helvetica but warn.
    // Helvetica cannot render non-Latin chars (₹, etc.), so we
    // do NOT set _fontsLoaded = true, allowing a retry next time.
    debugPrint('[LoanStatementPdf] Font loading failed: $e');
  }
}

// ──────────────────────────────────────────────────────────────
//  Premium Loan Statement Builder
// ──────────────────────────────────────────────────────────────

class LoanStatementPdfService {
  static final _dateFmt = DateFormat('dd MMM yyyy');

  // ── Shared formatters ──
  // Each formatter sanitises non-finite numbers (NaN / ±Infinity) before
  // touching `truncate()`/`toStringAsFixed()`, which would otherwise throw
  // `UnsupportedError: NaN or infinity is not allowed` mid-build.
  static double _safe(num? v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    final d = v.toDouble();
    return (d.isNaN || d.isInfinite) ? fallback : (d < 0 ? -d : d).toDouble();
  }

  static String _money(num? v) => StatementFormatters.money(_safe(v));
  static String _date(DateTime d) => _dateFmt.format(d);
  static String _num(num? v) => StatementFormatters.number(_safe(v));
  static String _pct(num? v) => StatementFormatters.percentage(_safe(v));
  static String _dateTime(DateTime d) => DateFormat('dd MMM yyyy, hh:mm a').format(d);
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

  static Future<Uint8List> buildCustomerStatement({
    required LoanModel loan,
    required List<EMIScheduleModel> schedule,
    required List<LoanStatementPayment> payments,
    required LoanStatementOrgInfo org,
    String? generatedByName,
    Uint8List? qrPngBytes,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? statementRef,
  }) async {
    await _loadFonts();

    try {
      return await _buildCustomerStatementImpl(
        loan: loan,
        schedule: schedule,
        payments: payments,
        org: org,
        generatedByName: generatedByName,
        qrPngBytes: qrPngBytes,
        periodStart: periodStart,
        periodEnd: periodEnd,
        statementRef: statementRef,
      );
    } on FormatException catch (e, st) {
      // TTF font subsetting can throw FormatException for corrupt font data.
      // Reset to built-in Helvetica and retry once.
      debugPrint(
        "[LoanStatementPdf] FormatException with TTF fonts: $e\n"
        "Retrying with Helvetica fallback...\n$st",
      );
      _fontRegular = pw.Font.helvetica();
      _fontSemiBold = pw.Font.helveticaBold();
      _fontBold = pw.Font.helveticaBold();
      _fontsLoaded = true;
      try {
        return await _buildCustomerStatementImpl(
          loan: loan,
          schedule: schedule,
          payments: payments,
          org: org,
          generatedByName: generatedByName,
          qrPngBytes: qrPngBytes,
          periodStart: periodStart,
          periodEnd: periodEnd,
          statementRef: statementRef,
        );
      } catch (e2, st2) {
        debugPrint(
          "[LoanStatementPdf] Retry also failed: $e2\n$st2",
        );
        Error.throwWithStackTrace(StateError('PDF build failed: $e2'), st2);
      }
    } catch (e, st) {
      debugPrint(
        "[LoanStatementPdf] Failed to build statement for "
        "loan=${loan.loanNumber}, id=${loan.id}, "
        "customer=${loan.customerName ?? '(no name)'}: $e\n$st",
      );
      Error.throwWithStackTrace(StateError('PDF build failed: $e'), st);
    }
  }

  // ─────────────────────────────────────────────────────────
  //  Internal builder — separated so try/catch in the public entry
  //  can wrap it cleanly without scoping the entire body.
  // ─────────────────────────────────────────────────────────
  static Future<Uint8List> _buildCustomerStatementImpl({
    required LoanModel loan,
    required List<EMIScheduleModel> schedule,
    required List<LoanStatementPayment> payments,
    required LoanStatementOrgInfo org,
    String? generatedByName,
    Uint8List? qrPngBytes,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? statementRef,
  }) async {
    final s = StatementFormatters.sanitizeForEncoding;

    return _buildBody(
      loan: loan.copyWith(
        customerName: s(loan.customerName),
        loanNumber: s(loan.loanNumber),
        customerId: s(loan.customerId),
        customerPhone: s(loan.customerPhone),
        frequency: s(loan.frequency),
        tenureUnit: s(loan.tenureUnit),
        purpose: s(loan.purpose),
        remarks: s(loan.remarks),
        staffName: s(loan.staffName),
        staffPhone: s(loan.staffPhone),
      ),
      schedule: schedule,
      payments: payments
          .map((p) => LoanStatementPayment(
                date: p.date,
                amount: p.amount,
                mode: s(p.mode),
                referenceNumber: s(p.referenceNumber),
                notes: s(p.notes),
                collectedByName: s(p.collectedByName),
                collectedByRole: s(p.collectedByRole),
              ))
          .toList(),
      org: StatementOrgInfo(
        name: s(org.name),
        tagline: s(org.tagline),
        address: s(org.address),
        city: s(org.city),
        state: s(org.state),
        pincode: s(org.pincode),
        phone: s(org.phone),
        email: s(org.email),
        website: s(org.website),
        gstNumber: s(org.gstNumber),
        registrationNumber: s(org.registrationNumber),
        grievanceOfficer: s(org.grievanceOfficer),
        grievancePhone: s(org.grievancePhone),
        logoBytes: org.logoBytes,
      ),
      generatedByName: s(generatedByName),
      qrPngBytes: qrPngBytes,
      periodStart: periodStart,
      periodEnd: periodEnd,
      statementRef: s(statementRef),
    );
  }

  static Future<Uint8List> _buildBody({
    required LoanModel loan,
    required List<EMIScheduleModel> schedule,
    required List<LoanStatementPayment> payments,
    required LoanStatementOrgInfo org,
    String? generatedByName,
    Uint8List? qrPngBytes,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? statementRef,
  }) async {
    final generatedAt = DateTime.now();

    // ── Resolve period ──
    final effectiveStart =
        periodStart ?? loan.disbursementDate ?? DateTime(2000);
    final effectiveEnd = periodEnd ?? generatedAt;

    // ── Sort & filter payments ──
    final sortedPayments = List<LoanStatementPayment>.from(payments)
      ..sort((a, b) => a.date.compareTo(b.date));



    // ── Summary metrics (derive from schedule, not stale DB columns) ──
    final totalPaid =
        sortedPayments.fold<double>(0, (s, p) => s + p.amount);
    final totalScheduleEmis = schedule.length;
    final paidEmis = schedule.where((e) => e.status == EMIStatus.paid).length;
    final nextEmi =
        schedule.where((e) => e.status != EMIStatus.paid && e.status != EMIStatus.frozen).toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final nextDue = nextEmi.isNotEmpty ? nextEmi.first.dueDate : null;
    final nextEmiAmount = nextEmi.isNotEmpty ? nextEmi.first.emiAmount : 0.0;
    final progress = totalScheduleEmis > 0
        ? (paidEmis / totalScheduleEmis * 100)
        : 0.0;

    // ── Penalty check ──
    final hasPenalties = schedule.any((e) => e.penaltyAmount > 0);
    final totalPenalties =
        schedule.fold<double>(0, (s, e) => s + e.penaltyAmount);
    final totalPenaltyPaid = schedule.fold<double>(
        0, (s, e) => s + (e.penaltyPaid ? e.penaltyAmount : 0));

    // ── Security hash ──
    final docHash = StatementFormatters.securityHash(
      loanNumber: loan.loanNumber,
      amount: loan.amount,
      outstandingBalance: loan.outstandingBalance,
      totalEmis: totalScheduleEmis,
      paidEmis: paidEmis,
      generatedAt: generatedAt,
    );
    final hashShort = docHash.substring(0, 16);

    // ── Statement ref ──
    final effectiveRef = statementRef ??
        'STM-${loan.loanNumber}-${DateFormat('yyyyMMdd').format(generatedAt)}';

    // ── QR code (with verification data) ──
    final qrBytes = qrPngBytes ??
        await QrPng.generateVerification(
          loanNumber: loan.loanNumber,
          statementRef: effectiveRef,
          securityHash: docHash,
        );
    final qrData = 'VERIFY|$effectiveRef|$hashShort|${loan.loanNumber}';

    // ── Health score ──
    final now = DateTime.now();
    // Normalize to UTC date-only for safe comparison with DB dates
    final todayUtc = DateTime.utc(now.year, now.month, now.day);
    final dueSchedule = schedule.where((e) {
      final d = DateTime.utc(e.dueDate.year, e.dueDate.month, e.dueDate.day);
      return !d.isAfter(todayUtc);
    }).toList();
    // Count truly on-time payments: paid ON or BEFORE the due date.
    final onTimeCount = dueSchedule.where((e) {
      if (e.status != EMIStatus.paid) return false;
      if (e.paidOn == null) return true; // paid but no date recorded — assume on-time
      final paidDay = DateTime.utc(e.paidOn!.year, e.paidOn!.month, e.paidOn!.day);
      final dueDay = DateTime.utc(e.dueDate.year, e.dueDate.month, e.dueDate.day);
      return !paidDay.isAfter(dueDay);
    }).length;
    final overdueEmis = schedule
        .where((e) =>
            e.status != EMIStatus.paid &&
            e.status != EMIStatus.waived &&
            e.status != EMIStatus.frozen &&
            DateTime.utc(e.dueDate.year, e.dueDate.month, e.dueDate.day).isBefore(todayUtc))
        .toList();
    final maxDaysOverdue = overdueEmis.isEmpty
        ? 0
        : overdueEmis
            .map((e) => todayUtc.difference(DateTime.utc(e.dueDate.year, e.dueDate.month, e.dueDate.day)).inDays)
            .reduce(math.max);
    final healthGrade = StatementFormatters.healthGrade(
      onTimeCount: onTimeCount,
      totalDue: dueSchedule.length,
      currentOverdueCount: overdueEmis.length,
      maxDaysOverdue: maxDaysOverdue,
    );

    // ── Build PDF ──
    final theme = pw.ThemeData.withFont(
      base: _fontRegular,
      bold: _fontBold,
      boldItalic: _fontSemiBold,
      italic: _fontRegular,
    );

    final pdf = pw.Document(
      title: 'Loan Statement - ${loan.loanNumber}',
      author: org.name,
      creator: org.name,
      subject: 'Loan Repayment Statement',
      keywords: 'loan, statement, ${loan.loanNumber}, ${org.name}',
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft: 20,
          marginRight: 20,
          marginTop: 20,
          marginBottom: 28,
        ),
        theme: theme,
        header: (ctx) => ctx.pageNumber == 1
            ? _buildPremiumHeader(
                org: org,
                loan: loan,
                qrBytes: qrBytes,
                statementRef: effectiveRef,
                periodStart: effectiveStart,
                periodEnd: effectiveEnd,
                qrData: qrData,
              )
            : _buildRunningHeader(org, loan, hashShort),
        footer: (ctx) => _buildPremiumFooter(
          ctx,
          org: org,
          generatedByName: generatedByName,
          statementRef: effectiveRef,
          hashShort: hashShort,
          generatedAt: generatedAt,
        ),
        build: (ctx) => [
          // ── Status badge (if closed/settled) ──
          if (loan.status == LoanStatus.closed) ...[
            pw.SizedBox(height: 2),
            _buildStatusBadge(loan),
          ],

          pw.SizedBox(height: 8),

          // ── Account Health Score + Info Panels ──
          _buildHealthAndInfoRow(
            loan: loan,
            healthGrade: healthGrade,
            onTimeCount: onTimeCount,
            totalDue: dueSchedule.length,
          ),
          pw.SizedBox(height: 8),

          // ── Visual Dashboard ──
          _buildVisualDashboard(
            loan: loan,
            totalPaid: totalPaid,
            paidEmis: paidEmis,
            totalScheduleEmis: totalScheduleEmis,
            nextDue: nextDue,
            nextEmiAmount: nextEmiAmount,
            progress: progress,
            overdueCount: overdueEmis.length,
          ),
          pw.SizedBox(height: 10),

          // ── Unified Account Activity Ledger ──
          _buildSectionLabel('ACCOUNT ACTIVITY LEDGER'),
          pw.SizedBox(height: 4),
          _buildLedgerTable(
            loan: loan,
            payments: payments,
            effectiveStart: effectiveStart,
            effectiveEnd: effectiveEnd,
          ),
          pw.SizedBox(height: 10),

          // ── Overdue Aging Analysis (conditional) ──
          if (overdueEmis.isNotEmpty) ...[
            _buildSectionLabel('OVERDUE AGING ANALYSIS'),
            pw.SizedBox(height: 4),
            _buildOverdueAging(overdueEmis, todayUtc),
            pw.SizedBox(height: 10),
          ],

          // ── Penalty summary (conditional) ──
          if (hasPenalties) ...[
            _buildPenaltySection(
              schedule: schedule,
              totalPenalties: totalPenalties,
              totalPenaltyPaid: totalPenaltyPaid,
            ),
            pw.SizedBox(height: 10),
          ],

          // ── Regulatory Compliance Block ──
          if (_hasRegulatoryInfo(org)) ...[
            _buildRegulatoryBlock(org),
            pw.SizedBox(height: 8),
          ],

          // ── Disclaimer ──
          _buildPremiumDisclaimer(org: org, effectiveRef: effectiveRef),
        ],
      ),
    );

    return pdf.save();
  }

  // ════════════════════════════════════════════════════════════
  //  SECTION BUILDERS
  // ════════════════════════════════════════════════════════════

  // ── 1. Premium Org Header (page 1) ──
  static pw.Widget _buildPremiumHeader({
    required LoanStatementOrgInfo org,
    required LoanModel loan,
    required Uint8List? qrBytes,
    required String statementRef,
    required DateTime periodStart,
    required DateTime periodEnd,
    String? qrData,
  }) {
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
                  if (org.logoBytes != null &&
                      org.logoBytes!.isNotEmpty &&
                      StatementFormatters.isValidImage(org.logoBytes))
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
                          org.name.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: StatementColors.navy900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        if ((org.tagline ?? '').isNotEmpty)
                          pw.Text(
                            org.tagline!,
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              color: StatementColors.teal600,
                              fontStyle: pw.FontStyle.italic,
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
                    'LOAN STATEMENT',
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: StatementColors.navy900,
                      letterSpacing: 1.2,
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
                        _metaRow('Loan Account', loan.loanNumber),
                        _metaRow('Statement Ref', statementRef),
                        _metaRow('Period', '${_date(periodStart)} - ${_date(periodEnd)}'),
                        _metaRow('Generated At', DateFormat('dd MMM yyyy').format(DateTime.now())),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  
                  // Inline QR code
                  if (qrBytes != null && StatementFormatters.isValidImage(qrBytes))
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'Scan to verify  ',
                          style: pw.TextStyle(
                            fontSize: 5.5,
                            color: StatementColors.grey400,
                          ),
                        ),
                        pw.Container(
                          width: 32,
                          height: 32,
                          padding: const pw.EdgeInsets.all(1.5),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(
                                color: StatementColors.grey200, width: 0.5),
                            borderRadius: pw.BorderRadius.circular(3),
                          ),
                          child: pw.Image(pw.MemoryImage(qrBytes)),
                        ),
                      ],
                    )
                  else if (qrData != null && qrData.isNotEmpty)
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'Scan to verify  ',
                          style: pw.TextStyle(
                            fontSize: 5.5,
                            color: StatementColors.grey400,
                          ),
                        ),
                        pw.Container(
                          width: 32,
                          height: 32,
                          padding: const pw.EdgeInsets.all(1.5),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(
                                color: StatementColors.grey200, width: 0.5),
                            borderRadius: pw.BorderRadius.circular(3),
                          ),
                          child: pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: qrData,
                            drawText: false,
                            color: StatementColors.navy900,
                          ),
                        ),
                      ],
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
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 6.5,
              fontWeight: pw.FontWeight.bold,
              color: StatementColors.grey800,
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
            ),
          ),
          pw.TextSpan(
            text: value,
            style: pw.TextStyle(
              fontSize: 7,
              color: StatementColors.grey700,
            ),
          ),
        ],
      ),
    );
  }


  // ── 3. Status Badge ──
  static pw.Widget _buildStatusBadge(LoanModel loan) {
    final isSettled =
        loan.outstandingBalance <= 0.01 || loan.status == LoanStatus.closed;
    final label = isSettled ? 'FULLY SETTLED' : 'ACCOUNT CLOSED';
    final bgColor = StatementColors.green100;
    final borderColor = StatementColors.green700;
    final textColor = StatementColors.green700;

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: pw.BoxDecoration(
            color: bgColor,
            borderRadius: pw.BorderRadius.circular(12),
            border: pw.Border.all(color: borderColor, width: 1),
          ),
          child: pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Container(
                width: 6,
                height: 6,
                decoration: pw.BoxDecoration(
                  color: textColor,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: textColor,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 4. Health Score + Info Panels Row ──
  static pw.Widget _buildHealthAndInfoRow({
    required LoanModel loan,
    required String healthGrade,
    required int onTimeCount,
    required int totalDue,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: StatementColors.grey200, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
        color: StatementColors.grey50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ACCOUNT OVERVIEW',
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: StatementColors.navy900,
              letterSpacing: 1.2,
            ),
          ),
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 4, bottom: 8),
            height: 0.5,
            color: StatementColors.grey200,
          ),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Column 1: Borrower Details
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _overviewRow('Borrower Name', loan.customerName ?? '\u2014'),
                    _overviewRow('Borrower ID', loan.customerId),
                    _overviewRow('Contact Number', loan.customerPhone ?? '\u2014'),
                    _overviewRow('Loan Account No.', loan.loanNumber),
                  ],
                ),
              ),
              pw.SizedBox(width: 24),
              // Column 2: Loan Parameters
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _overviewRow('Interest Rate', '${_num(loan.interestRate)}% (${loan.interestType.name})'),
                    _overviewRow('Installment Period', loan.formattedTenure),
                    _overviewRow('Repayment Frequency', loan.frequency?.toUpperCase() ?? 'WEEKLY'),
                    _overviewRow('Account Status', loan.status.name.toUpperCase()),
                  ],
                ),
              ),
              pw.SizedBox(width: 24),
              // Column 3: Dates & Health
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _overviewRow('Disbursement Date', loan.disbursementDate != null ? _date(loan.disbursementDate!) : '\u2014'),
                    _overviewRow('Last Payment Date', loan.lastPaymentDate != null ? _date(loan.lastPaymentDate!) : '\u2014'),
                    _overviewRow('Payment Consistency', '$onTimeCount / $totalDue On-Time'),
                    _overviewRow('Repayment Grade', '$healthGrade (${StatementFormatters.healthGradeLabel(healthGrade)})'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _overviewRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
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
            ),
          ),
          pw.SizedBox(height: 1.5),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: StatementColors.grey900,
            ),
          ),
        ],
      ),
    );
  }

  // ── 5. Visual Dashboard ──
  static pw.Widget _buildVisualDashboard({
    required LoanModel loan,
    required double totalPaid,
    required int paidEmis,
    required int totalScheduleEmis,
    required DateTime? nextDue,
    required double nextEmiAmount,
    required double progress,
    required int overdueCount,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: StatementColors.grey200, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
        color: StatementColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'FINANCIAL STATUS SUMMARY',
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: StatementColors.navy900,
                  letterSpacing: 1.2,
                ),
              ),
              pw.Text(
                '${_pct(progress)} Paid',
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: StatementColors.teal600,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),

          // Thin progress bar
          pw.Container(
            height: 4,
            decoration: pw.BoxDecoration(
              color: StatementColors.grey100,
              borderRadius: pw.BorderRadius.circular(2),
            ),
            child: pw.Row(
              children: [
                if (progress > 0)
                  pw.Expanded(
                    flex: progress.round().clamp(1, 100),
                    child: pw.Container(
                      height: 4,
                      decoration: pw.BoxDecoration(
                        color: StatementColors.teal600,
                        borderRadius: pw.BorderRadius.circular(2),
                      ),
                    ),
                  ),
                if (progress < 100)
                  pw.Expanded(
                    flex: (100 - progress).round().clamp(1, 100),
                    child: pw.Container(
                      height: 4,
                      color: StatementColors.grey100,
                    ),
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Core balances grid
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _metricItem('Total Disbursed', _moneyInt(loan.amount), StatementColors.navy900),
              _metricItem('Total Repaid', _moneyInt(totalPaid), StatementColors.green700),
              _metricItem('Outstanding', _moneyInt(loan.totalRepayable - totalPaid), (loan.totalRepayable - totalPaid) > 0 ? StatementColors.red700 : StatementColors.green700),
              _metricItem('Next Due Installment', nextDue != null ? '${_moneyInt(nextEmiAmount)} on ${_date(nextDue)}' : 'Completed', StatementColors.orange700),
            ],
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
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }



  // ── 7. Unified Account Activity Ledger Table ──
  static pw.Widget _buildLedgerTable({
    required LoanModel loan,
    required List<LoanStatementPayment> payments,
    required DateTime effectiveStart,
    required DateTime effectiveEnd,
  }) {
    // 1. Gather all events from inception
    final allEvents = <_LedgerEvent>[];

    // Disbursement — record the actual principal disbursed
    if (loan.disbursementDate != null) {
      allEvents.add(_LedgerEvent(
        date: loan.disbursementDate!,
        description: 'Loan Disbursed',
        type: _LedgerEventType.disbursement,
        amount: loan.amount,
      )..outstanding = loan.totalRepayable);
    }

    // Payments — merge same-second payments (identical second = same
    // collection-sheet batch), then compute outstanding by walking
    // FORWARD from loan.amount and subtracting each payment.
    final sortedAllPayments = List<LoanStatementPayment>.from(payments)
      ..sort((a, b) => a.date.compareTo(b.date));

    final mergedPayments = _mergePaymentsByDateTime(sortedAllPayments);

    // Forward walk: start from total repayable (principal + interest),
    // subtract each payment to show customer's perspective.
    double outstanding = loan.totalRepayable;
    for (int i = 0; i < mergedPayments.length; i++) {
      final p = mergedPayments[i];
      final event = _LedgerEvent(
        date: p.date,
        description: p.description,
        type: _LedgerEventType.payment,
        amount: p.amount,
        collectedByName: p.collectedByName,
      );
      outstanding -= p.amount;
      event.outstanding = outstanding < 0 ? 0.0 : outstanding;
      allEvents.add(event);
    }

    // Sort chronologically (disbursement before payment at same time)
    allEvents.sort((a, b) {
      final cmp = a.date.compareTo(b.date);
      if (cmp != 0) return cmp;
      return a.type.index.compareTo(b.type.index);
    });

    // Ensure last row is exactly 0 if loan is closed/settled
    if (loan.status == LoanStatus.closed && allEvents.isNotEmpty) {
      final lastPaymentIndex = allEvents.lastIndexWhere((e) => e.type == _LedgerEventType.payment);
      if (lastPaymentIndex != -1) {
        allEvents[lastPaymentIndex].outstanding = 0.0;
        for (int i = lastPaymentIndex + 1; i < allEvents.length; i++) {
          allEvents[i].outstanding = 0.0;
        }
      }
    }

    // 3. Filter events within statement period
    final periodEvents = allEvents.where((e) {
      return !e.date.isBefore(effectiveStart) && !e.date.isAfter(effectiveEnd);
    }).toList();

    // 4. If periodStart is after disbursement, add an Opening Balance event
    final firstDisbursement = allEvents.firstWhere(
      (e) => e.type == _LedgerEventType.disbursement,
      orElse: () => _LedgerEvent(date: DateTime(2000), description: '', type: _LedgerEventType.disbursement, amount: 0.0),
    );

    final showOpeningBalance = periodEvents.isEmpty ||
        (periodEvents.first.type != _LedgerEventType.disbursement &&
         periodEvents.first.date.isAfter(firstDisbursement.date));

    if (showOpeningBalance) {
      final firstPaymentInPeriod = periodEvents.firstWhere(
        (e) => e.type == _LedgerEventType.payment,
        orElse: () => _LedgerEvent(date: DateTime(2000), description: '', type: _LedgerEventType.openingBalance, amount: 0.0),
      );

      double openingBalanceAmt;
      if (firstPaymentInPeriod.description.isNotEmpty) {
        openingBalanceAmt = firstPaymentInPeriod.outstanding + firstPaymentInPeriod.amount;
      } else {
        openingBalanceAmt = loan.outstandingBalance;
      }

      periodEvents.insert(0, _LedgerEvent(
        date: effectiveStart,
        description: 'Opening Balance Brought Forward',
        type: _LedgerEventType.openingBalance,
        amount: 0.0,
      )..outstanding = openingBalanceAmt);
    }

    // Add Closing Balance row at end
    if (periodEvents.isNotEmpty) {
      final lastEvent = periodEvents.last;
      periodEvents.add(_LedgerEvent(
        date: effectiveEnd,
        description: 'Closing Balance',
        type: _LedgerEventType.closingBalance,
        amount: 0.0,
      )..outstanding = lastEvent.outstanding);
    }

    if (periodEvents.isEmpty) {
      return _emptyBox('No payments recorded for this period.');
    }

    // 5. Build Table Rows
    int idx = 1;
    // Safe upper bound for outstanding column — handle invalid/missing totalRepayable.
    final outUpper = (loan.totalRepayable.isFinite && loan.totalRepayable > 0)
        ? loan.totalRepayable
        : double.infinity;
    final rows = periodEvents.map((e) {
      String dateStr = e.type == _LedgerEventType.openingBalance ||
              e.type == _LedgerEventType.disbursement ||
              e.type == _LedgerEventType.closingBalance
          ? _date(e.date)
          : _dateTime(e.date);

      String amtStr;
      if (e.type == _LedgerEventType.openingBalance ||
          e.type == _LedgerEventType.closingBalance) {
        amtStr = '—';
      } else {
        amtStr = _money(e.amount);
      }

      return [
        (e.type == _LedgerEventType.openingBalance || e.type == _LedgerEventType.closingBalance) ? '' : '${idx++}',
        dateStr,
        e.description,
        e.collectedByName ?? '',
        amtStr,
        _money(e.outstanding.isNaN ? 0.0 : e.outstanding.clamp(0.0, outUpper)),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: [
        '#',
        'Date & Time',
        'Description',
        'Collected By',
        'Amount',
        'Outstanding',
      ],
      data: rows,
      headerStyle: pw.TextStyle(
        fontSize: 7,
        fontWeight: pw.FontWeight.bold,
        color: StatementColors.white,
      ),
      headerDecoration: pw.BoxDecoration(
        color: StatementColors.navy800,
        borderRadius: const pw.BorderRadius.only(
          topLeft: pw.Radius.circular(4),
          topRight: pw.Radius.circular(4),
        ),
      ),
      cellStyle: pw.TextStyle(
        fontSize: 7,
        color: StatementColors.grey800,
      ),
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
      cellPadding:
          const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
      cellDecoration: (rowIndex, cellIndex, row) {
        if (rowIndex < 0) return const pw.BoxDecoration();

        final event = periodEvents[rowIndex.clamp(0, periodEvents.length - 1)];

        if (event.type == _LedgerEventType.openingBalance || event.type == _LedgerEventType.disbursement) {
          return pw.BoxDecoration(
            color: StatementColors.navy100,
            border: pw.Border(
              bottom: pw.BorderSide(
                  color: StatementColors.grey200, width: 0.5),
            ),
          );
        }

        if (event.type == _LedgerEventType.closingBalance) {
          return pw.BoxDecoration(
            color: StatementColors.navy100,
            border: pw.Border(
              top: pw.BorderSide(
                  color: StatementColors.grey400, width: 0.5),
              bottom: pw.BorderSide(
                  color: StatementColors.grey200, width: 0.5),
            ),
          );
        }

        if (event.type == _LedgerEventType.payment) {
          return pw.BoxDecoration(
            color: StatementColors.green100.withAlpha(0.12),
            border: pw.Border(
              bottom: pw.BorderSide(
                  color: StatementColors.grey200, width: 0.3),
            ),
          );
        }

        return pw.BoxDecoration(
          color: rowIndex.isOdd ? StatementColors.grey50 : StatementColors.white,
          border: pw.Border(
            bottom: pw.BorderSide(
                color: StatementColors.grey200, width: 0.3),
          ),
        );
      },
    );
  }

  // ── 8. Overdue Aging Analysis ──
  static pw.Widget _buildOverdueAging(
      List<EMIScheduleModel> overdueEmis, DateTime today) {
    int count030 = 0, count3160 = 0, count6190 = 0, count90 = 0;
    double amt030 = 0, amt3160 = 0, amt6190 = 0, amt90 = 0;

    for (final e in overdueEmis) {
      final dueUtc = DateTime.utc(e.dueDate.year, e.dueDate.month, e.dueDate.day);
      final days = today.difference(dueUtc).inDays;
      if (days <= 30) {
        count030++;
        amt030 += e.emiAmount;
      } else if (days <= 60) {
        count3160++;
        amt3160 += e.emiAmount;
      } else if (days <= 90) {
        count6190++;
        amt6190 += e.emiAmount;
      } else {
        count90++;
        amt90 += e.emiAmount;
      }
    }

    final totalOverdueAmt = amt030 + amt3160 + amt6190 + amt90;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: StatementColors.red50,
        border: pw.Border.all(
            color: StatementColors.red700.withAlpha(0.20), width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Total Overdue: ${_money(totalOverdueAmt)}',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: StatementColors.red700,
                ),
              ),
              pw.Text(
                '${overdueEmis.length} EMI(s) overdue',
                style: pw.TextStyle(
                  fontSize: 7.5,
                  color: StatementColors.grey600,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),

          // Severity bar
          if (totalOverdueAmt > 0)
            pw.Row(
              children: [
                if (amt030 > 0)
                  pw.Expanded(
                    flex: (amt030 / totalOverdueAmt * 100).round().clamp(1, 100),
                    child: pw.Container(
                      height: 6,
                      color: StatementColors.orange700,
                    ),
                  ),
                if (amt3160 > 0)
                  pw.Expanded(
                    flex: (amt3160 / totalOverdueAmt * 100).round().clamp(1, 100),
                    child: pw.Container(
                      height: 6,
                      color: StatementColors.orange600,
                    ),
                  ),
                if (amt6190 > 0)
                  pw.Expanded(
                    flex: (amt6190 / totalOverdueAmt * 100).round().clamp(1, 100),
                    child: pw.Container(
                      height: 6,
                      color: StatementColors.red600,
                    ),
                  ),
                if (amt90 > 0)
                  pw.Expanded(
                    flex: (amt90 / totalOverdueAmt * 100).round().clamp(1, 100),
                    child: pw.Container(
                      height: 6,
                      color: StatementColors.red700,
                    ),
                  ),
              ],
            ),
          pw.SizedBox(height: 6),

          // Aging table
          pw.TableHelper.fromTextArray(
            headers: ['Aging Bucket', 'EMIs', 'Amount', '% of Overdue'],
            data: [
              [
                '0 \u2013 30 days',
                '$count030',
                _money(amt030),
                totalOverdueAmt > 0
                    ? _pct(amt030 / totalOverdueAmt * 100)
                    : '0%'
              ],
              [
                '31 \u2013 60 days',
                '$count3160',
                _money(amt3160),
                totalOverdueAmt > 0
                    ? _pct(amt3160 / totalOverdueAmt * 100)
                    : '0%'
              ],
              [
                '61 \u2013 90 days',
                '$count6190',
                _money(amt6190),
                totalOverdueAmt > 0
                    ? _pct(amt6190 / totalOverdueAmt * 100)
                    : '0%'
              ],
              [
                '90+ days',
                '$count90',
                _money(amt90),
                totalOverdueAmt > 0
                    ? _pct(amt90 / totalOverdueAmt * 100)
                    : '0%'
              ],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: StatementColors.white,
            ),
            headerDecoration: pw.BoxDecoration(
              color: StatementColors.red700,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(3),
                topRight: pw.Radius.circular(3),
              ),
            ),
            cellStyle:
                pw.TextStyle(fontSize: 7, color: StatementColors.grey800),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          ),
        ],
      ),
    );
  }

  // ── 9. Enhanced Penalty Section ──
  static pw.Widget _buildPenaltySection({
    required List<EMIScheduleModel> schedule,
    required double totalPenalties,
    required double totalPenaltyPaid,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final penaltyRows = schedule
        .where((e) => e.penaltyAmount > 0)
        .map((e) {
      final daysLate = e.status == EMIStatus.paid
          ? (e.paidOn != null
              ? e.paidOn!.difference(e.dueDate).inDays
              : 0)
          : today.difference(e.dueDate).inDays;
      return [
        'EMI #${e.emiNumber}',
        _date(e.dueDate),
        '${daysLate > 0 ? daysLate : 0} days',
        _money(e.penaltyAmount),
        e.penaltyPaid ? '\u2713 Paid' : '\u2717 Pending',
        e.penaltyPaid ? '\u2014' : _money(e.penaltyAmount),
      ];
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('PENALTY SUMMARY'),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: StatementColors.red50,
            border: pw.Border.all(
                color: StatementColors.red700.withAlpha(0.16), width: 0.5),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total Penalties: ${_money(totalPenalties)}',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: StatementColors.red700,
                    ),
                  ),
                  pw.Text(
                    'Paid: ${_money(totalPenaltyPaid)}  |  Outstanding: ${_money(totalPenalties - totalPenaltyPaid)}',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      color: StatementColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: [
                  'EMI',
                  'Due Date',
                  'Days Late',
                  'Penalty',
                  'Status',
                  'Outstanding'
                ],
                data: penaltyRows,
                headerStyle: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: StatementColors.white,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: StatementColors.red700,
                  borderRadius: const pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(3),
                    topRight: pw.Radius.circular(3),
                  ),
                ),
                cellStyle: pw.TextStyle(
                    fontSize: 7, color: StatementColors.grey800),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.center,
                  5: pw.Alignment.centerRight,
                },
                cellPadding:
                    const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              ),
            ],
          ),
        ),
      ],
    );
  }



  // ── 11. Regulatory Compliance Block ──
  static bool _hasRegulatoryInfo(LoanStatementOrgInfo org) {
    return (org.registrationNumber ?? '').isNotEmpty ||
        (org.grievanceOfficer ?? '').isNotEmpty;
  }

  static pw.Widget _buildRegulatoryBlock(LoanStatementOrgInfo org) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: StatementColors.gold50,
        border: pw.Border.all(color: StatementColors.gold300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 3,
                height: 10,
                decoration: pw.BoxDecoration(
                  color: StatementColors.gold500,
                  borderRadius: pw.BorderRadius.circular(2),
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Text(
                'REGULATORY INFORMATION',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: StatementColors.gold700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          if ((org.registrationNumber ?? '').isNotEmpty)
            pw.Text(
              'Registration / License No: ${org.registrationNumber}',
              style: pw.TextStyle(
                  fontSize: 7.5, color: StatementColors.grey700),
            ),
          if ((org.grievanceOfficer ?? '').isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              'Grievance Officer: ${org.grievanceOfficer}'
              '${(org.grievancePhone ?? '').isNotEmpty ? '  |  Ph: ${org.grievancePhone}' : ''}',
              style: pw.TextStyle(
                  fontSize: 7.5, color: StatementColors.grey700),
            ),
          ],
          pw.SizedBox(height: 3),
          pw.Text(
            'This institution operates under applicable microfinance / NBFC regulations. '
            'For grievances, contact the designated officer above or escalate to the regulatory authority.',
            style: pw.TextStyle(
              fontSize: 6.5,
              color: StatementColors.grey500,
              fontStyle: pw.FontStyle.italic,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── 12. Premium Disclaimer ──
  static pw.Widget _buildPremiumDisclaimer({
    required LoanStatementOrgInfo org,
    required String effectiveRef,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: StatementColors.navy100,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: StatementColors.navy100, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'IMPORTANT INFORMATION & TERMS',
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: StatementColors.navy900,
              letterSpacing: 0.8,
            ),
          ),
          pw.SizedBox(height: 6),

          _disclaimerClause('1',
              'This is a computer-generated statement and does not require a physical signature. '
              'It is issued as a service to the borrower for informational purposes.'),
          _disclaimerClause('2',
              'Please review this statement carefully. Report any discrepancy within 15 days '
              'of receipt to the issuing branch or designated grievance officer.'),
          _disclaimerClause('3',
              'The outstanding shown is as of the statement generation date. '
              'Subsequent payments or charges may not be reflected.'),
          _disclaimerClause('4',
              'Late payment may attract penalties as per the loan agreement terms. '
              'Persistent default may affect your credit score and eligibility for future credit.'),

          if ((org.phone ?? '').isNotEmpty || (org.email ?? '').isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Row(
              children: [
                if ((org.phone ?? '').isNotEmpty)
                  pw.Text(
                    'Helpline: ${org.phone}',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                      color: StatementColors.navy700,
                    ),
                  ),
                if ((org.phone ?? '').isNotEmpty &&
                    (org.email ?? '').isNotEmpty)
                  pw.Text('    |    ',
                      style: pw.TextStyle(
                          fontSize: 7, color: StatementColors.grey300)),
                if ((org.email ?? '').isNotEmpty)
                  pw.Text(
                    'Email: ${org.email}',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                      color: StatementColors.navy700,
                    ),
                  ),
              ],
            ),
          ],

          pw.SizedBox(height: 8),

          // Verification notice
          pw.Container(
            width: double.infinity,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: StatementColors.teal50,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(
                  color: StatementColors.teal200, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'DIGITAL VERIFICATION',
                  style: pw.TextStyle(
                    fontSize: 6.5,
                    fontWeight: pw.FontWeight.bold,
                    color: StatementColors.teal600,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Scan the QR code on this statement to verify its authenticity. '
                  'The document hash and reference number ($effectiveRef) can be '
                  'cross-verified with the issuing institution.',
                  style: pw.TextStyle(
                    fontSize: 6.5,
                    color: StatementColors.teal600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 6),

          // Motivational box
          pw.Container(
            width: double.infinity,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: StatementColors.gold50,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              'Repay on time, build your financial trust. Your timely payments open doors to greater opportunities.',
              style: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: StatementColors.gold700,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _disclaimerClause(String number, String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 14,
            child: pw.Text(
              '$number.',
              style: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: StatementColors.navy700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              text,
              style: pw.TextStyle(
                fontSize: 7,
                color: StatementColors.grey700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Running Header (page 2+) ──
  static pw.Widget _buildRunningHeader(
      LoanStatementOrgInfo org, LoanModel loan, String hashShort) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Thin brand strip
        pw.Container(
          height: 1.5,
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [
                StatementColors.navy900,
                StatementColors.teal600,
                StatementColors.navy900,
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              org.name.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: StatementColors.navy900,
                letterSpacing: 0.5,
              ),
            ),
            pw.Text(
              'Loan Statement \u2014 ${loan.customerName ?? "Customer"}',
              style: pw.TextStyle(
                fontSize: 7.5,
                color: StatementColors.grey600,
              ),
            ),
            pw.Row(
              children: [
                pw.Text(
                  loan.loanNumber,
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: StatementColors.navy700,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 4, vertical: 1),
                  decoration: pw.BoxDecoration(
                    color: StatementColors.grey100,
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Text(
                    hashShort,
                    style: pw.TextStyle(
                      fontSize: 5.5,
                      color: StatementColors.grey500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(
            height: 1, thickness: 0.5, color: StatementColors.grey300),
        pw.SizedBox(height: 8),
      ],
    );
  }

  // ── Premium Footer (every page) ──
  static pw.Widget _buildPremiumFooter(
    pw.Context ctx, {
    required LoanStatementOrgInfo org,
    String? generatedByName,
    required String statementRef,
    required String hashShort,
    required DateTime generatedAt,
  }) {
    return pw.Column(
      children: [
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 4),
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: StatementColors.grey300, width: 0.5),
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
                    'Generated: ${StatementFormatters.timestamp(generatedAt)}'
                    '${generatedByName != null ? ' by $generatedByName' : ''}',
                    style: pw.TextStyle(
                        fontSize: 6, color: StatementColors.grey500),
                  ),
                  pw.Text(
                    'Ref: $statementRef',
                    style: pw.TextStyle(
                        fontSize: 5.5, color: StatementColors.grey400),
                  ),
                ],
              ),

              // Center: anti-tamper
              pw.Column(
                children: [
                  pw.Text(
                    'Digitally Generated Document',
                    style: pw.TextStyle(
                      fontSize: 5.5,
                      color: StatementColors.grey400,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                  pw.Text(
                    'Hash: $hashShort',
                    style: pw.TextStyle(
                        fontSize: 5, color: StatementColors.grey400),
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
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 3),
        // Bottom brand strip
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

  // ════════════════════════════════════════════════════════════
  //  SHARED HELPERS
  // ════════════════════════════════════════════════════════════


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
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Expanded(
          child: pw.Container(
            height: 0.5,
            color: StatementColors.grey300,
          ),
        ),
      ],
    );
  }

  static pw.Widget _emptyBox(String message) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: StatementColors.grey50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: StatementColors.grey200, width: 0.5),
      ),
      child: pw.Text(
        message,
        style: pw.TextStyle(
          fontSize: 9,
          color: StatementColors.grey400,
          fontStyle: pw.FontStyle.italic,
        ),
      ),
    );
  }

  static String _paymentModeLabel(String mode) {
    switch (mode.toLowerCase()) {
      case 'upi':
        return 'UPI';
      case 'cash':
        return 'Cash';
      case 'bank_transfer':
      case 'banktransfer':
        return 'Bank Transfer';
      case 'cheque':
      case 'check':
        return 'Cheque';
      case 'mobile_money':
      case 'mobilemoney':
        return 'Mobile Money';
      case 'online':
        return 'Online';
      default:
        // Capitalize first letter of each word
        return mode
            .split(RegExp(r'[_\s]+'))
            .map((w) =>
                w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
            .join(' ');
    }
  }

  // ── Payment Merging ──

  /// Returns `true` when two DateTimes fall within the same minute AND
  /// their dates are identical.  This is used to group payments that the
  /// collection sheet recorded in rapid succession (e.g. 3 EMI inserts
  /// inside a for-loop within the same minute).
  static bool _sameMinute(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day &&
      a.hour == b.hour &&
      a.minute == b.minute;

  /// Merges payments that fall within the same minute into a single
  /// [_MergedPayment].
  ///
  /// When a customer pays 3 EMIs at once, the collection sheet records
  /// 3 separate rows (one per EMI), each with a slightly different
  /// Supabase `created_at`.  This merge groups them so the ledger shows:
  ///   "3 installments paid (Cash)   –Rs. 300.00   Rs. 5,200.00"
  /// instead of three identical-time separate rows.
  static List<_MergedPayment> _mergePaymentsByDateTime(
      List<LoanStatementPayment> sorted) {
    if (sorted.isEmpty) return const [];

    final merged = <_MergedPayment>[];
    int i = 0;

    while (i < sorted.length) {
      final anchor = sorted[i];
      double sum = anchor.amount;
      int count = 1;
      final modes = <String>{anchor.mode};

      // Collect all consecutive payments within the same minute
      while (i + 1 < sorted.length &&
          _sameMinute(anchor.date, sorted[i + 1].date)) {
        i++;
        sum += sorted[i].amount;
        modes.add(sorted[i].mode);
        count++;
      }

      if (count > 1) {
        final modeStr = modes.map(_paymentModeLabel).join(' / ');
        merged.add(_MergedPayment(
          date: anchor.date,
          amount: sum,
          description: '$count installments paid ($modeStr)',
          collectedByName: anchor.collectedByName,
          count: count,
        ));
      } else {
        String desc = 'Payment via ${_paymentModeLabel(anchor.mode)}';
        merged.add(_MergedPayment(
          date: anchor.date,
          amount: sum,
          description: desc,
          collectedByName: anchor.collectedByName,
          count: 1,
        ));
      }

      i++;
    }

    return merged;
  }
}

// ──────────────────────────────────────────────────────────────
//  Account Ledger Events Helper Models
// ──────────────────────────────────────────────────────────────

enum _LedgerEventType { openingBalance, disbursement, payment, closingBalance }

class _LedgerEvent {
  final DateTime date;
  final String description;
  final _LedgerEventType type;
  final double amount;
  final String? collectedByName;
  double outstanding = 0.0;

  _LedgerEvent({
    required this.date,
    required this.description,
    required this.type,
    required this.amount,
    this.collectedByName,
  });
}

/// Represents one or more payments merged into a single ledger row
/// when they share the exact same date+time.
class _MergedPayment {
  final DateTime date;
  final double amount;
  final String description;
  final String? collectedByName;
  final int count;

  const _MergedPayment({
    required this.date,
    required this.amount,
    required this.description,
    this.collectedByName,
    required this.count,
  });
}
