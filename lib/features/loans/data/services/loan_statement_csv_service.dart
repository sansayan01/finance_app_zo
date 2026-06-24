import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../../../../core/utils/statement_formatters.dart';
import '../models/emi_schedule_model.dart';
import '../models/loan_model.dart';
import 'loan_statement_pdf_service.dart';

/// CSV export for loan statements.
///
/// Produces a UTF-8 BOM–prefixed CSV file that Excel on Windows
/// interprets correctly. Dates use ISO 8601 (yyyy-MM-dd) for consistency.
class LoanStatementCsvService {
  static final _dateFmt = DateFormat('yyyy-MM-dd');

  static Uint8List build({
    required LoanModel loan,
    required List<EMIScheduleModel> schedule,
    required List<LoanStatementPayment> payments,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    final buf = StringBuffer();

    // Header
    _writeln(buf, '# Loan Statement');
    _writeln(buf, '# Loan Number,${loan.loanNumber}');
    _writeln(buf, '# Customer,${loan.customerName ?? '—'}');
    _writeln(buf, '# Loan Amount,${_money(loan.amount)}');
    _writeln(buf, '# Interest Rate,${loan.interestRate}%');
    _writeln(buf, '# Tenure,${loan.formattedTenure}');
    _writeln(buf,
        '# Period,${_dateFmt.format(periodStart)} - ${_dateFmt.format(periodEnd)}');
    _writeln(buf, '');

    // EMI Schedule
    _writeln(buf, 'EMI Schedule');
    _writeln(buf,
        'EMI#,Due Date,Principal,Interest,Total,Balance,Status,Penalty,Penalty Paid');
    for (final emi in schedule) {
      _writeln(buf,
          '${emi.emiNumber},${_dateFmt.format(emi.dueDate)},${_money(emi.principal)},${_money(emi.interest)},${_money(emi.emiAmount)},${_money(emi.balanceAfter)},${emi.status.name},${_money(emi.penaltyAmount)},${emi.penaltyPaid}');
    }
    _writeln(buf, '');

    // Payment history (activity)
    if (payments.isNotEmpty) {
      final sorted = List<LoanStatementPayment>.from(payments)
        ..sort((a, b) => a.date.compareTo(b.date));

      _writeln(buf, 'Payment History');
      _writeln(buf, 'Date,Amount,Mode,Reference,Notes');

      for (final p in sorted) {
        _writeln(buf,
            '${_dateFmt.format(p.date)},${_money(p.amount)},${_escape(p.mode)},${_escape(p.referenceNumber ?? '')},${_escape(p.notes ?? '')}');
      }
      _writeln(buf, '');
    }

    // Summary
    final totalPaid = payments.fold<double>(0, (s, p) => s + p.amount);
    final totalPenalties =
        schedule.fold<double>(0, (s, e) => s + e.penaltyAmount);
    final totalInterest = schedule.fold<double>(0, (s, e) => s + e.interest);
    final totalPrincipal = schedule.fold<double>(0, (s, e) => s + e.principal);

    _writeln(buf, 'Summary');
    _writeln(buf, 'Total Paid,${_money(totalPaid)}');
    _writeln(buf, 'Total Interest,${_money(totalInterest)}');
    _writeln(buf, 'Total Principal,${_money(totalPrincipal)}');
    if (totalPenalties > 0) {
      _writeln(buf, 'Total Penalties,${_money(totalPenalties)}');
    }
    _writeln(buf, 'Outstanding,${_money(loan.outstandingBalance)}');

    // Prepend UTF-8 BOM so Excel on Windows interprets encoding correctly.
    final bom = [0xEF, 0xBB, 0xBF];
    final content = utf8.encode(buf.toString());
    return Uint8List.fromList(bom + content);
  }

  static void _writeln(StringBuffer buf, String line) {
    buf.writeln(line);
  }

  static String _escape(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  /// Delegates to shared [StatementFormatters.money].
  static String _money(num v) => StatementFormatters.money(v);
}
