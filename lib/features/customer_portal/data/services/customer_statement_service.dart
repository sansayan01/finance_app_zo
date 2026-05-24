import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

/// Premium PDF statement generator for the Customer Portal.
///
/// Generates loan repayment statements and savings passbook statements
/// with Indian-style number formatting (1,00,000), indigo-themed headers,
/// alternating row colours, and multi-page support with running headers
/// and page-number footers.
class CustomerStatementService {
  CustomerStatementService._();

  // ---------------------------------------------------------------------------
  // Formatters
  // ---------------------------------------------------------------------------

  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');

  /// Indian-style currency formatting without relying on locale data.
  /// Produces strings like "Rs. 1,23,456.00".
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

  // ---------------------------------------------------------------------------
  // Colour palette
  // ---------------------------------------------------------------------------

  // Indigo-based palette for a premium fintech look.
  static final _indigo900 = PdfColor.fromHex('#1a237e');
  static final _indigo800 = PdfColor.fromHex('#283593');
  static final _indigo100 = PdfColor.fromHex('#c5cae9');
  static final _indigo50 = PdfColor.fromHex('#e8eaf6');

  static final _grey800 = PdfColor.fromHex('#424242');
  static final _grey600 = PdfColor.fromHex('#757575');
  static final _grey400 = PdfColor.fromHex('#bdbdbd');
  static final _grey200 = PdfColor.fromHex('#eeeeee');
  static final _grey100 = PdfColor.fromHex('#f5f5f5');

  static final _green800 = PdfColor.fromHex('#2e7d32');
  static final _green100 = PdfColor.fromHex('#c8e6c9');
  static final _green50 = PdfColor.fromHex('#e8f5e9');

  static final _red800 = PdfColor.fromHex('#c62828');

  // =========================================================================
  // PUBLIC API
  // =========================================================================

  /// Generate a loan repayment statement PDF.
  static Future<pw.Document> generateLoanStatement({
    required String memberName,
    required String loanNumber,
    required double loanAmount,
    required double interestRate,
    required int tenure,
    required DateTime? disbursementDate,
    required List<Map<String, dynamic>> emiSchedule,
    required List<Map<String, dynamic>> transactions,
  }) async {
    final pdf = pw.Document(
      title: 'Loan Statement - $loanNumber',
      author: 'MicroFlow Pro',
      creator: 'MicroFlow Pro',
      subject: 'Loan Repayment Statement',
    );

    // Pre-compute summary values.
    final totalPaid = transactions.fold<double>(
      0,
      (sum, t) => sum + ((t['amount'] as num?)?.toDouble() ?? 0),
    );
    final totalRepayable = _computeTotalRepayable(emiSchedule);
    final outstanding =
        (totalRepayable - totalPaid).clamp(0.0, double.infinity);
    final totalInterest = emiSchedule.fold<double>(
      0,
      (sum, e) => sum + ((e['interest'] as num?)?.toDouble() ?? 0),
    );

    // Sort transactions chronologically.
    final sortedTxns = List<Map<String, dynamic>>.from(transactions)
      ..sort((a, b) {
        final da = a['date'] as DateTime? ?? DateTime(2000);
        final db = b['date'] as DateTime? ?? DateTime(2000);
        return da.compareTo(db);
      });

    final now = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft: 28,
          marginRight: 28,
          marginTop: 28,
          marginBottom: 36,
        ),
        header: (ctx) => ctx.pageNumber == 1
            ? _buildLoanHeader(memberName, loanNumber, now)
            : _buildRunningHeader('LOAN STATEMENT', loanNumber),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 10),
          _buildLoanSummaryBox(
            loanNumber: loanNumber,
            loanAmount: loanAmount,
            interestRate: interestRate,
            tenure: tenure,
            disbursementDate: disbursementDate,
            memberName: memberName,
          ),
          pw.SizedBox(height: 16),
          _buildRepaymentScheduleTable(emiSchedule),
          pw.SizedBox(height: 16),
          _buildTransactionHistoryTable(sortedTxns),
          pw.SizedBox(height: 16),
          _buildLoanSummaryFooter(
            totalPaid: totalPaid,
            outstanding: outstanding,
            totalInterest: totalInterest,
          ),
        ],
      ),
    );

    return pdf;
  }

  /// Generate a savings passbook statement PDF.
  static Future<pw.Document> generateSavingsStatement({
    required String memberName,
    required String planName,
    required double targetAmount,
    required double currentAmount,
    required double monthlyDeposit,
    required double interestRate,
    required DateTime? maturityDate,
    required List<Map<String, dynamic>> transactions,
  }) async {
    final pdf = pw.Document(
      title: 'Savings Statement - $planName',
      author: 'MicroFlow Pro',
      creator: 'MicroFlow Pro',
      subject: 'Savings Statement',
    );

    // Pre-compute summary values.
    double totalDeposited = 0;
    double totalWithdrawn = 0;
    for (final t in transactions) {
      final amount = (t['amount'] as num?)?.toDouble() ?? 0;
      final type = (t['type'] as String? ?? '').toLowerCase();
      if (type == 'withdrawal') {
        totalWithdrawn += amount;
      } else {
        totalDeposited += amount;
      }
    }

    // Sort transactions chronologically.
    final sortedTxns = List<Map<String, dynamic>>.from(transactions)
      ..sort((a, b) {
        final da = a['date'] as DateTime? ?? DateTime(2000);
        final db = b['date'] as DateTime? ?? DateTime(2000);
        return da.compareTo(db);
      });

    final now = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft: 28,
          marginRight: 28,
          marginTop: 28,
          marginBottom: 36,
        ),
        header: (ctx) => ctx.pageNumber == 1
            ? _buildSavingsHeader(memberName, planName, now)
            : _buildRunningHeader('SAVINGS STATEMENT', planName),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 10),
          _buildSavingsSummaryBox(
            planName: planName,
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            monthlyDeposit: monthlyDeposit,
            interestRate: interestRate,
            maturityDate: maturityDate,
          ),
          pw.SizedBox(height: 16),
          _buildSavingsTransactionTable(sortedTxns, currentAmount),
          pw.SizedBox(height: 16),
          _buildSavingsSummaryFooter(
            totalDeposited: totalDeposited,
            totalWithdrawn: totalWithdrawn,
            currentBalance: currentAmount,
          ),
        ],
      ),
    );

    return pdf;
  }

  /// Share a generated PDF document via the system share sheet.
  static Future<void> shareStatement(pw.Document doc, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(await doc.save());
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)]),
    );
  }

  /// Download / save a generated PDF document to the app's documents directory.
  static Future<void> downloadStatement(
      pw.Document doc, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(await doc.save());
  }

  // =========================================================================
  // LOAN STATEMENT — PRIVATE HELPERS
  // =========================================================================

  /// First-page header for loan statement.
  static pw.Widget _buildLoanHeader(
    String memberName,
    String loanNumber,
    DateTime generatedAt,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Brand row
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 40,
              height: 40,
              decoration: pw.BoxDecoration(
                color: _indigo900,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              alignment: pw.Alignment.center,
              child: pw.Text('MF',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  )),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('MICROFLOW PRO',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: _indigo900,
                        letterSpacing: 0.5,
                      )),
                  pw.SizedBox(height: 2),
                  pw.Text('Micro-Finance Management Platform',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: _grey600,
                      )),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 14),

        // Title bar
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: pw.BoxDecoration(color: _indigo900),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('LOAN STATEMENT',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    letterSpacing: 0.5,
                  )),
              pw.Text('Generated: ${_dateTimeFmt.format(generatedAt)}',
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: _indigo100,
                  )),
            ],
          ),
        ),
      ],
    );
  }

  /// Loan summary box with key details.
  static pw.Widget _buildLoanSummaryBox({
    required String loanNumber,
    required double loanAmount,
    required double interestRate,
    required int tenure,
    required DateTime? disbursementDate,
    required String memberName,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _indigo100, width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
        color: _indigo50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: _infoBlock('MEMBER', [
                  _kv('Name', memberName),
                ]),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _infoBlock('LOAN DETAILS', [
                  _kv('Loan Number', loanNumber),
                  _kv('Loan Amount', _money(loanAmount)),
                  _kv('Interest Rate', '$interestRate% p.a.'),
                  _kv('Tenure', '$tenure months'),
                  _kv('Disbursed On',
                      disbursementDate != null ? _date(disbursementDate) : '--'),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Repayment schedule table.
  static pw.Widget _buildRepaymentScheduleTable(
      List<Map<String, dynamic>> emiSchedule) {
    if (emiSchedule.isEmpty) {
      return _emptyBox('No repayment schedule available.');
    }

    final headers = [
      'Period',
      'Due Date',
      'EMI',
      'Principal',
      'Interest',
      'Balance',
      'Status',
    ];

    final data = <List<String>>[];
    for (final emi in emiSchedule) {
      data.add([
        '${emi['period'] ?? emi['emi_number'] ?? '--'}',
        emi['due_date'] != null ? _date(emi['due_date'] as DateTime) : '--',
        _money((emi['emi_amount'] as num?)?.toDouble() ?? 0),
        _money((emi['principal'] as num?)?.toDouble() ?? 0),
        _money((emi['interest'] as num?)?.toDouble() ?? 0),
        _money((emi['balance'] as num?)?.toDouble() ?? 0),
        (emi['status'] as String? ?? 'pending').toUpperCase(),
      ]);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('REPAYMENT SCHEDULE'),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: data,
          headerStyle: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(color: _indigo800),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignments: {
            0: pw.Alignment.center,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
            6: pw.Alignment.center,
          },
          cellPadding:
              const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          headerAlignments: {
            0: pw.Alignment.center,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
            6: pw.Alignment.center,
          },
          oddRowDecoration: pw.BoxDecoration(color: _indigo50),
          rowDecoration: pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: _grey200, width: 0.3),
            ),
          ),
        ),
      ],
    );
  }

  /// Transaction history table.
  static pw.Widget _buildTransactionHistoryTable(
      List<Map<String, dynamic>> transactions) {
    if (transactions.isEmpty) {
      return _emptyBox('No transactions recorded yet.');
    }

    final headers = ['Date', 'Type', 'Amount', 'Mode', 'Description'];

    final data = <List<String>>[];
    for (final t in transactions) {
      data.add([
        t['date'] != null ? _date(t['date'] as DateTime) : '--',
        (t['type'] as String? ?? '--').toUpperCase(),
        _money((t['amount'] as num?)?.toDouble() ?? 0),
        t['mode'] as String? ?? '--',
        t['description'] as String? ?? '--',
      ]);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('TRANSACTION HISTORY'),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: data,
          headerStyle: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(color: _indigo800),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.center,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.center,
            4: pw.Alignment.centerLeft,
          },
          cellPadding:
              const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          oddRowDecoration: pw.BoxDecoration(color: _indigo50),
          rowDecoration: pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: _grey200, width: 0.3),
            ),
          ),
        ),
      ],
    );
  }

  /// Loan summary footer with totals.
  static pw.Widget _buildLoanSummaryFooter({
    required double totalPaid,
    required double outstanding,
    required double totalInterest,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _grey100,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _kv('Total Paid', _money(totalPaid)),
                _kv('Total Interest Component', _money(totalInterest)),
              ],
            ),
          ),
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: pw.BoxDecoration(
              color: outstanding > 0 ? _red800 : _green800,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('OUTSTANDING',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.5,
                    )),
                pw.SizedBox(height: 2),
                pw.Text(_money(outstanding),
                    style: pw.TextStyle(
                      fontSize: 16,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SAVINGS STATEMENT — PRIVATE HELPERS
  // =========================================================================

  /// First-page header for savings statement.
  static pw.Widget _buildSavingsHeader(
    String memberName,
    String planName,
    DateTime generatedAt,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Brand row
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 40,
              height: 40,
              decoration: pw.BoxDecoration(
                color: _indigo900,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              alignment: pw.Alignment.center,
              child: pw.Text('MF',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  )),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('MICROFLOW PRO',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: _indigo900,
                        letterSpacing: 0.5,
                      )),
                  pw.SizedBox(height: 2),
                  pw.Text('Micro-Finance Management Platform',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: _grey600,
                      )),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 14),

        // Title bar
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: pw.BoxDecoration(color: _indigo900),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('SAVINGS STATEMENT',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    letterSpacing: 0.5,
                  )),
              pw.Text('Generated: ${_dateTimeFmt.format(generatedAt)}',
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: _indigo100,
                  )),
            ],
          ),
        ),
      ],
    );
  }

  /// Savings account summary box.
  static pw.Widget _buildSavingsSummaryBox({
    required String planName,
    required double targetAmount,
    required double currentAmount,
    required double monthlyDeposit,
    required double interestRate,
    required DateTime? maturityDate,
  }) {
    final progressPct =
        targetAmount > 0 ? (currentAmount / targetAmount * 100).clamp(0, 100) : 0.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _green100, width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
        color: _green50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: _infoBlock('PLAN DETAILS', [
                  _kv('Plan Name', planName),
                  _kv('Target Amount', _money(targetAmount)),
                  _kv('Monthly Deposit', _money(monthlyDeposit)),
                  _kv('Interest Rate', '$interestRate% p.a.'),
                  _kv('Maturity Date',
                      maturityDate != null ? _date(maturityDate) : '--'),
                ]),
              ),
              pw.SizedBox(width: 12),
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: _green800,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('CURRENT BALANCE',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.5,
                        )),
                    pw.SizedBox(height: 4),
                    pw.Text(_money(currentAmount),
                        style: pw.TextStyle(
                          fontSize: 18,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                        )),
                    pw.SizedBox(height: 4),
                    pw.Text('${progressPct.toStringAsFixed(1)}% of target',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: _green100,
                        )),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Savings transaction table with running balance.
  static pw.Widget _buildSavingsTransactionTable(
    List<Map<String, dynamic>> transactions,
    double currentBalance,
  ) {
    if (transactions.isEmpty) {
      return _emptyBox('No transactions recorded yet.');
    }

    final headers = ['Date', 'Type', 'Amount', 'Description'];

    // Compute running balances backwards from current balance.
    final balances = <double>[];
    double running = currentBalance;
    for (var i = transactions.length - 1; i >= 0; i--) {
      balances.insert(0, running);
      final amount = (transactions[i]['amount'] as num?)?.toDouble() ?? 0;
      final type = (transactions[i]['type'] as String? ?? '').toLowerCase();
      if (type == 'withdrawal') {
        running += amount;
      } else {
        running -= amount;
      }
    }

    final data = <List<String>>[];
    for (var i = 0; i < transactions.length; i++) {
      final t = transactions[i];
      final type = (t['type'] as String? ?? '--').toUpperCase();
      data.add([
        t['date'] != null ? _date(t['date'] as DateTime) : '--',
        type,
        _money((t['amount'] as num?)?.toDouble() ?? 0),
        t['description'] as String? ?? '--',
      ]);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('TRANSACTION HISTORY'),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: data,
          headerStyle: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(color: _indigo800),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.center,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerLeft,
          },
          cellPadding:
              const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          oddRowDecoration: pw.BoxDecoration(color: _indigo50),
          rowDecoration: pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: _grey200, width: 0.3),
            ),
          ),
        ),
      ],
    );
  }

  /// Savings summary footer.
  static pw.Widget _buildSavingsSummaryFooter({
    required double totalDeposited,
    required double totalWithdrawn,
    required double currentBalance,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _grey100,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _kv('Total Deposited', _money(totalDeposited)),
                _kv('Total Withdrawn', _money(totalWithdrawn)),
              ],
            ),
          ),
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: pw.BoxDecoration(
              color: _green800,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('CURRENT BALANCE',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.5,
                    )),
                pw.SizedBox(height: 2),
                pw.Text(_money(currentBalance),
                    style: pw.TextStyle(
                      fontSize: 16,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SHARED WIDGET HELPERS
  // =========================================================================

  /// Running header for pages after the first.
  static pw.Widget _buildRunningHeader(String title, String ref) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _grey400)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('MICROFLOW PRO',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _indigo900,
              )),
          pw.Text('$title | $ref',
              style: pw.TextStyle(
                fontSize: 9,
                color: _grey600,
              )),
        ],
      ),
    );
  }

  /// Page footer with page numbers.
  static pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _grey400)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'This is a computer-generated statement and does not require a signature.',
            style: pw.TextStyle(fontSize: 7, color: _grey600),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: _grey600),
          ),
        ],
      ),
    );
  }

  /// Section title with indigo accent.
  static pw.Widget _sectionTitle(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _indigo800, width: 1.5),
        ),
      ),
      child: pw.Text(text,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: _indigo900,
            letterSpacing: 0.5,
          )),
    );
  }

  /// Info block with a label and key-value rows.
  static pw.Widget _infoBlock(String label, List<pw.Widget> rows) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _grey600,
              letterSpacing: 0.5,
            )),
        pw.SizedBox(height: 6),
        ...rows,
      ],
    );
  }

  /// Key-value row.
  static pw.Widget _kv(String k, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(k,
                style: pw.TextStyle(
                  fontSize: 8,
                  color: _grey600,
                )),
          ),
          pw.Expanded(
            child: pw.Text(v,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: _grey800,
                )),
          ),
        ],
      ),
    );
  }

  /// Empty state box.
  static pw.Widget _emptyBox(String message) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      alignment: pw.Alignment.center,
      child: pw.Text(message,
          style: pw.TextStyle(
            fontSize: 10,
            color: _grey600,
          )),
    );
  }

  /// Compute total repayable from the EMI schedule.
  static double _computeTotalRepayable(List<Map<String, dynamic>> schedule) {
    if (schedule.isEmpty) return 0;
    return schedule.fold<double>(
      0,
      (sum, e) => sum + ((e['emi_amount'] as num?)?.toDouble() ?? 0),
    );
  }
}
