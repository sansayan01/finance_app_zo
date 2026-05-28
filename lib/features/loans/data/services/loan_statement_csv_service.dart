import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import '../models/loan_model.dart';
import '../models/emi_schedule_model.dart';
import 'loan_statement_pdf_service.dart';

class LoanStatementCsvService {
  static final _dateFmt = DateFormat('yyyy-MM-dd');

  static Uint8List build({
    required LoanModel loan,
    required List<EMIScheduleModel> schedule,
    required List<LoanStatementPayment> payments,
    required DateTime periodStart,
    required DateTime periodEnd,
    required StatementVariant variant,
  }) {
    final rows = <List<dynamic>>[];

    // Metadata header (commented-out style so it doesn't confuse parsers)
    rows.add(['# Loan Statement']);
    rows.add(['# Loan No.', loan.loanNumber]);
    rows.add(['# Customer', loan.customerName ?? '—']);
    rows.add([
      '# Period',
      '${_dateFmt.format(periodStart)} to ${_dateFmt.format(periodEnd)}'
    ]);
    rows.add(['# Variant', variant.name]);
    rows.add([]);

    // Table header
    rows.add([
      'date',
      'emi_number',
      'description',
      'debit',
      'credit',
      'balance',
      'payment_mode',
      'reference',
      'collected_by',
      'collected_by_role',
    ]);

    double balance = loan.amount;

    if (loan.disbursementDate != null &&
        !loan.disbursementDate!.isBefore(periodStart) &&
        !loan.disbursementDate!.isAfter(periodEnd)) {
      rows.add([
        _dateFmt.format(loan.disbursementDate!),
        '',
        'Loan disbursement',
        loan.amount,
        '',
        balance,
        '',
        '',
        '',
        '',
      ]);
    }

    final activityOnly = variant != StatementVariant.fullSchedule;

    for (final emi in schedule) {
      final inPeriod = !emi.dueDate.isBefore(periodStart) &&
          !emi.dueDate.isAfter(periodEnd);
      if (!activityOnly && inPeriod) {
        rows.add([
          _dateFmt.format(emi.dueDate),
          emi.emiNumber,
          'EMI #${emi.emiNumber} due',
          '',
          '',
          balance,
          '',
          '',
          '',
          '',
        ]);
      }

      final paidOn = emi.paidOn;
      if (paidOn != null &&
          !paidOn.isBefore(periodStart) &&
          !paidOn.isAfter(periodEnd)) {
        balance -= emi.principal;
        rows.add([
          _dateFmt.format(paidOn),
          emi.emiNumber,
          'EMI #${emi.emiNumber} paid',
          '',
          emi.emiAmount,
          balance,
          emi.paymentMode?.name ?? 'cash',
          '',
          '',
          '',
        ]);
      }
    }

    for (final p in payments) {
      if (p.date.isBefore(periodStart) || p.date.isAfter(periodEnd)) continue;
      final alreadyCounted = schedule.any((e) {
        final paidOn = e.paidOn;
        if (paidOn == null) return false;
        return paidOn.difference(p.date).inMinutes.abs() < 1 &&
            (e.emiAmount - p.amount).abs() < 0.01;
      });
      if (alreadyCounted) continue;
      balance -= p.amount;
      rows.add([
        _dateFmt.format(p.date),
        '',
        'Payment',
        '',
        p.amount,
        balance,
        p.mode,
        p.referenceNumber ?? '',
        p.collectedByName ?? '',
        p.collectedByRole ?? '',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    return Uint8List.fromList(csv.codeUnits);
  }
}
