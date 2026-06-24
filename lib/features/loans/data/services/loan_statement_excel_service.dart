import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../models/loan_model.dart';
import '../models/emi_schedule_model.dart';
import 'loan_statement_pdf_service.dart';

class LoanStatementExcelService {
  static final _dateFmt = DateFormat('dd MMM yyyy');

  static Uint8List build({
    required LoanModel loan,
    required List<EMIScheduleModel> schedule,
    required List<LoanStatementPayment> payments,
    required LoanStatementOrgInfo org,
    required DateTime periodStart,
    required DateTime periodEnd,
    String? statementRef,
  }) {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Statement');
    final summary = excel['Statement'];

    // ---- Header section ----
    summary.appendRow([TextCellValue(org.name)]);
    if (org.fullAddress.isNotEmpty) {
      summary.appendRow([TextCellValue(org.fullAddress)]);
    }
    final contact = [
      if ((org.phone ?? '').isNotEmpty) 'Tel: ${org.phone}',
      if ((org.email ?? '').isNotEmpty) 'Email: ${org.email}',
      if ((org.gstNumber ?? '').isNotEmpty) 'GSTIN: ${org.gstNumber}',
    ].join('  ');
    if (contact.isNotEmpty) {
      summary.appendRow([TextCellValue(contact)]);
    }
    summary.appendRow([]);
    summary.appendRow([TextCellValue('LOAN REPAYMENT STATEMENT')]);
    summary.appendRow([
      TextCellValue('Period:'),
      TextCellValue(
          '${_dateFmt.format(periodStart)} – ${_dateFmt.format(periodEnd)}'),
    ]);
    if (statementRef != null) {
      summary
          .appendRow([TextCellValue('Ref:'), TextCellValue(statementRef)]);
    }
    summary.appendRow([]);

    // ---- Loan + customer ----
    summary.appendRow([TextCellValue('CUSTOMER')]);
    summary.appendRow([
      TextCellValue('Name'),
      TextCellValue(loan.customerName ?? '—'),
    ]);
    summary.appendRow([
      TextCellValue('Phone'),
      TextCellValue(loan.customerPhone ?? '—'),
    ]);
    summary.appendRow([
      TextCellValue('Customer ID'),
      TextCellValue(loan.customerId),
    ]);
    summary.appendRow([]);

    summary.appendRow([TextCellValue('LOAN')]);
    summary.appendRow(
        [TextCellValue('Loan No.'), TextCellValue(loan.loanNumber)]);
    summary
        .appendRow([TextCellValue('Principal'), DoubleCellValue(loan.amount)]);
    summary.appendRow([
      TextCellValue('Interest Rate'),
      TextCellValue('${loan.interestRate}% (${loan.interestType.name})'),
    ]);
    summary
        .appendRow([TextCellValue('Tenure'), TextCellValue(loan.formattedTenure)]);
    summary.appendRow(
        [TextCellValue('EMI Amount'), DoubleCellValue(loan.emiAmount)]);
    summary.appendRow([
      TextCellValue('Total Repayable'),
      DoubleCellValue(loan.totalRepayable),
    ]);
    summary.appendRow([
      TextCellValue('Disbursement'),
      TextCellValue(loan.disbursementDate != null
          ? _dateFmt.format(loan.disbursementDate!)
          : '—'),
    ]);
    summary.appendRow([
      TextCellValue('Status'),
      TextCellValue(loan.status.name.toUpperCase()),
    ]);
    summary.appendRow([]);

    // ---- Ledger sheet ----
    final ledger = excel['Ledger'];
    ledger.appendRow([
      TextCellValue('Date'),
      TextCellValue('EMI #'),
      TextCellValue('Description'),
      TextCellValue('Debit'),
      TextCellValue('Credit'),
      TextCellValue('Outstanding'),
    ]);

    double balance = loan.amount;
    double totalDebit = 0;
    double totalCredit = 0;
    double totalInterestPaid = 0;
    double totalPrincipalPaid = 0;

    if (loan.disbursementDate != null &&
        !loan.disbursementDate!.isBefore(periodStart) &&
        !loan.disbursementDate!.isAfter(periodEnd)) {
      ledger.appendRow([
        TextCellValue(_dateFmt.format(loan.disbursementDate!)),
        TextCellValue('—'),
        TextCellValue('Loan disbursement'),
        DoubleCellValue(loan.amount),
        TextCellValue(''),
        DoubleCellValue(balance),
      ]);
      totalDebit += loan.amount;
    }

    for (final emi in schedule) {
      final paidOn = emi.paidOn;
      if (paidOn != null &&
          !paidOn.isBefore(periodStart) &&
          !paidOn.isAfter(periodEnd)) {
        balance -= emi.principal;
        totalCredit += emi.emiAmount;
        totalInterestPaid += emi.interest;
        totalPrincipalPaid += emi.principal;
        ledger.appendRow([
          TextCellValue(_dateFmt.format(paidOn)),
          IntCellValue(emi.emiNumber),
          TextCellValue(
              'EMI #${emi.emiNumber} paid via ${emi.paymentMode?.name ?? 'cash'}'),
          TextCellValue(''),
          DoubleCellValue(emi.emiAmount),
          DoubleCellValue(balance),
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
      totalCredit += p.amount;
      ledger.appendRow([
        TextCellValue(_dateFmt.format(p.date)),
        TextCellValue('—'),
        TextCellValue(
            'Payment via ${p.mode}${p.referenceNumber != null ? ' (Ref: ${p.referenceNumber})' : ''}'
            '${p.collectedByName != null ? ' — by ${p.collectedByName}${p.collectedByRole != null ? ' (${p.collectedByRole})' : ''}' : ''}'),
        TextCellValue(''),
        DoubleCellValue(p.amount),
        DoubleCellValue(balance),
      ]);
    }

    // ---- Summary rows ----
    ledger.appendRow([]);
    ledger.appendRow([
      TextCellValue('TOTALS'),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(totalDebit),
      DoubleCellValue(totalCredit),
      DoubleCellValue(balance),
    ]);

    summary.appendRow([]);
    summary.appendRow([TextCellValue('SUMMARY')]);
    summary.appendRow(
        [TextCellValue('Total Debit'), DoubleCellValue(totalDebit)]);
    summary.appendRow(
        [TextCellValue('Total Credit'), DoubleCellValue(totalCredit)]);
    summary.appendRow([
      TextCellValue('Principal Paid'),
      DoubleCellValue(totalPrincipalPaid),
    ]);
    summary.appendRow([
      TextCellValue('Interest Paid'),
      DoubleCellValue(totalInterestPaid),
    ]);
    summary.appendRow([
      TextCellValue('Current Outstanding'),
      DoubleCellValue(loan.outstandingBalance),
    ]);

    final bytes = excel.save();
    return Uint8List.fromList(bytes ?? <int>[]);
  }
}
