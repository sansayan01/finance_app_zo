import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/models/statement_org_info.dart';
import '../../../loans/data/models/emi_schedule_model.dart';
import '../../../loans/data/models/loan_model.dart';
import '../../../loans/data/services/loan_statement_pdf_service.dart';
import '../../../savings/data/services/savings_statement_models.dart';
import '../../../savings/data/services/savings_statement_pdf_service.dart';

/// Customer-facing PDF statement generator.
///
/// Delegates to [LoanStatementPdfService] and [SavingsStatementPdfService]
/// for actual PDF rendering. This class handles:
///  1. Converting Map-based data (from Supabase) into typed models.
///  2. Providing share/download helpers for the Customer Portal.
class CustomerStatementService {
  CustomerStatementService._();

  // ---------------------------------------------------------------------------
  // Public API — LOAN
  // ---------------------------------------------------------------------------

  /// Generate a loan repayment statement PDF as raw bytes.
  ///
  /// Accepts raw Map data (typical from Supabase) and delegates to
  /// [LoanStatementPdfService.buildCustomerStatement].
  static Future<Uint8List> generateLoanStatement({
    required String memberName,
    required String loanNumber,
    required double loanAmount,
    required double interestRate,
    required int tenure,
    required DateTime? disbursementDate,
    required List<Map<String, dynamic>> emiSchedule,
    required List<Map<String, dynamic>> transactions,
    StatementOrgInfo? org,
  }) async {
    // Build a lightweight LoanModel from the flat parameters.
    final loan = LoanModel(
      id: loanNumber,
      customerId: '',
      loanNumber: loanNumber,
      amount: loanAmount,
      interestRate: interestRate,
      tenureMonths: tenure,
      emiAmount: emiSchedule.isNotEmpty
          ? (emiSchedule.first['emi_amount'] as num?)?.toDouble() ?? 0
          : 0,
      totalInterest: emiSchedule.fold<double>(
          0, (s, e) => s + ((e['interest'] as num?)?.toDouble() ?? 0)),
      totalRepayable: emiSchedule.fold<double>(
          0, (s, e) => s + ((e['emi_amount'] as num?)?.toDouble() ?? 0)),
      outstandingBalance: 0,
      interestType: InterestType.flat,
      disbursementDate: disbursementDate,
      status: LoanStatus.active,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      customerName: memberName,
    );

    // Convert EMI schedule Maps → EMIScheduleModel list.
    final schedule = emiSchedule.map((e) {
      return EMIScheduleModel(
        id: e['id']?.toString() ?? '',
        loanId: loanNumber,
        emiNumber: (e['period'] ?? e['emi_number'] ?? 0) as int,
        dueDate: e['due_date'] as DateTime? ?? DateTime.now(),
        emiAmount: (e['emi_amount'] as num?)?.toDouble() ?? 0,
        principal: (e['principal'] as num?)?.toDouble() ?? 0,
        interest: (e['interest'] as num?)?.toDouble() ?? 0,
        balanceAfter: (e['balance'] as num?)?.toDouble() ?? 0,
        status: EMIStatus.values.firstWhere(
          (s) => s.name == (e['status'] as String? ?? ''),
          orElse: () => EMIStatus.pending,
        ),
        penaltyAmount: (e['penalty_amount'] as num?)?.toDouble() ?? 0,
        penaltyPaid: e['penalty_paid'] as bool? ?? false,
        createdAt: DateTime.now(),
      );
    }).toList();

    // Convert transaction Maps → LoanStatementPayment list.
    final payments = transactions.map((t) {
      return LoanStatementPayment(
        date: t['date'] as DateTime? ?? DateTime.now(),
        amount: (t['amount'] as num?)?.toDouble() ?? 0,
        mode: t['mode'] as String? ?? 'Cash',
        referenceNumber: t['reference'] as String?,
        notes: t['description'] as String?,
        collectedByName: t['collected_by_name']?.toString(),
        collectedByRole: t['collected_by_role']?.toString(),
      );
    }).toList();

    final effectiveOrg = org ?? StatementOrgInfo.fallback();
    return LoanStatementPdfService.buildCustomerStatement(
      loan: loan,
      schedule: schedule,
      payments: payments,
      org: effectiveOrg,
    );
  }

  // ---------------------------------------------------------------------------
  // Public API — SAVINGS
  // ---------------------------------------------------------------------------

  /// Generate a savings passbook statement PDF as raw bytes.
  ///
  /// Accepts raw parameters and delegates to [SavingsStatementPdfService.build].
  static Future<Uint8List> generateSavingsStatement({
    required String memberName,
    required String planName,
    required double targetAmount,
    required double currentAmount,
    required double monthlyDeposit,
    required double interestRate,
    required DateTime? maturityDate,
    required List<Map<String, dynamic>> transactions,
    StatementOrgInfo? org,
  }) async {
    // Sort transactions chronologically.
    final sortedTxns = List<Map<String, dynamic>>.from(transactions)
      ..sort((a, b) {
        final da = a['date'] as DateTime? ?? DateTime(2000);
        final db = b['date'] as DateTime? ?? DateTime(2000);
        return da.compareTo(db);
      });

    // Split into deposits and withdrawals.
    final deposits = <SavingsStatementTx>[];
    final withdrawals = <SavingsStatementTx>[];
    for (final t in sortedTxns) {
      final tx = SavingsStatementTx(
        date: t['date'] as DateTime? ?? DateTime.now(),
        amount: (t['amount'] as num?)?.toDouble() ?? 0,
        description: t['description'] as String? ?? '',
        paymentMode: t['mode'] as String?,
      );
      final type = (t['type'] as String? ?? '').toLowerCase();
      if (type == 'withdrawal') {
        withdrawals.add(tx);
      } else {
        deposits.add(tx);
      }
    }

    final now = DateTime.now();
    final customer = SavingsStatementCustomer(
      id: '',
      memberId: '',
      fullName: memberName,
    );

    final plan = SavingsStatementPlanBlock(
      planId: planName,
      planName: planName,
      status: 'active',
      targetAmount: targetAmount,
      currentAmount: currentAmount,
      openingBalance: 0,
      closingBalance: currentAmount,
      interestRate: interestRate,
      maturityDate: maturityDate ?? now.add(const Duration(days: 365)),
      collectionType: 'monthly',
      monthlyDeposit: monthlyDeposit,
      maturityAmount: targetAmount,
      deposits: deposits,
      withdrawals: withdrawals,
    );

    final totalDeposited = deposits.fold<double>(0, (s, t) => s + t.amount);
    final totalWithdrawn = withdrawals.fold<double>(0, (s, t) => s + t.amount);

    final portfolio = SavingsStatementPortfolioSummary(
      openingBalance: 0,
      totalDeposits: totalDeposited,
      totalWithdrawals: totalWithdrawn,
      interestEarned: 0,
      closingBalance: currentAmount,
      activePlans: 1,
      totalPlans: 1,
    );

    final data = SavingsStatementData(
      customer: customer,
      periodStart: sortedTxns.isNotEmpty
          ? (sortedTxns.first['date'] as DateTime? ?? now)
          : now,
      periodEnd: now,
      plans: [plan],
      portfolio: portfolio,
    );

    final effectiveOrg = org ?? StatementOrgInfo.fallback();
    return SavingsStatementPdfService.build(
      data: data,
      org: effectiveOrg,
    );
  }

  // ---------------------------------------------------------------------------
  // Share / Download helpers
  // ---------------------------------------------------------------------------

  /// Share raw PDF bytes via the system share sheet.
  static Future<void> sharePdfBytes(Uint8List bytes, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)]),
      );
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  /// Save raw PDF bytes to the app's documents directory.
  /// Returns the saved file path.
  static Future<String> downloadPdfBytes(
      Uint8List bytes, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  // ---------------------------------------------------------------------------
  // Legacy helpers — kept for backward compatibility with callers that
  // already have a pw.Document and use the old API.
  // ---------------------------------------------------------------------------

  /// Share a generated PDF document via the system share sheet.
  static Future<void> shareStatement(pw.Document doc, String filename) async {
    final bytes = await doc.save();
    await sharePdfBytes(bytes, filename);
  }

  /// Download / save a generated PDF document to the app's documents directory.
  /// Returns the saved file path.
  static Future<String> downloadStatement(
      pw.Document doc, String filename) async {
    final bytes = await doc.save();
    return downloadPdfBytes(bytes, filename);
  }
}
