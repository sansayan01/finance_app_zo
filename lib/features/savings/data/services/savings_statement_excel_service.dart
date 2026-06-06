import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/statement_formatters.dart';
import 'savings_statement_models.dart';

class SavingsStatementExcelService {
  static final _dateFmt = DateFormat('dd MMM yyyy');

  static Uint8List build({
    required SavingsStatementData data,
    required String orgName,
    String? statementRef,
  }) {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Savings Statement');
    final sheet = excel['Savings Statement'];

    sheet.appendRow([TextCellValue(orgName)]);
    sheet.appendRow([TextCellValue('Savings Account Statement')]);
    sheet.appendRow([
      TextCellValue(
          '${_dateFmt.format(data.periodStart)} - ${_dateFmt.format(data.periodEnd)}'),
    ]);
    sheet.appendRow([]);

    final c = data.customer;
    sheet.appendRow([TextCellValue('Customer: ${c.fullName}')]);
    sheet.appendRow([TextCellValue('Member ID: ${c.memberId}')]);
    sheet.appendRow([TextCellValue('Phone: ${c.phone}')]);
    if (statementRef != null) {
      sheet.appendRow([TextCellValue('Ref: $statementRef')]);
    }
    sheet.appendRow([]);

    final p = data.portfolio;
    sheet.appendRow([TextCellValue('PORTFOLIO SUMMARY')]);
    sheet.appendRow([TextCellValue('Opening Balance'), TextCellValue(_money(p.openingBalance))]);
    sheet.appendRow([TextCellValue('Total Deposits'), TextCellValue(_money(p.totalDeposits))]);
    sheet.appendRow([TextCellValue('Total Withdrawals'), TextCellValue(_money(p.totalWithdrawals))]);
    sheet.appendRow([TextCellValue('Interest Earned'), TextCellValue(_money(p.interestEarned))]);
    sheet.appendRow([TextCellValue('Closing Balance'), TextCellValue(_money(p.closingBalance))]);
    sheet.appendRow([TextCellValue('Active Plans'), TextCellValue('${p.activePlans} of ${p.totalPlans}')]);
    sheet.appendRow([]);

    for (final plan in data.plans) {
      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([TextCellValue(plan.planName)]);
      sheet.appendRow([
        TextCellValue('Target: ${_money(plan.targetAmount)}'),
        TextCellValue('Opening Balance: ${_money(plan.openingBalance)}'),
        TextCellValue('Deposits: ${_money(plan.totalDeposited)}'),
        TextCellValue('Withdrawals: ${_money(plan.totalWithdrawn)}'),
        TextCellValue('Interest: ${_money(plan.interestAccrued)}'),
        TextCellValue('Closing Balance: ${_money(plan.closingBalance)}'),
      ]);
      sheet.appendRow([
        TextCellValue('Maturity: ${_dateFmt.format(plan.maturityDate)}'),
        TextCellValue('Status: ${plan.status}'),
      ]);
      sheet.appendRow([]);

      final allTxs = <_TxRow>[
        ...plan.deposits.map((t) => _TxRow(
              date: t.date,
              description: t.description,
              deposit: t.amount,
              withdrawal: 0.0,
            )),
        ...plan.withdrawals.map((t) => _TxRow(
              date: t.date,
              description: t.description,
              deposit: 0.0,
              withdrawal: t.amount,
            )),
      ];
      allTxs.sort((a, b) => a.date.compareTo(b.date));

      sheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Description'),
        TextCellValue('Deposit'),
        TextCellValue('Withdrawal'),
        TextCellValue('Balance'),
      ]);

      double running = plan.openingBalance;
      for (final t in allTxs) {
        running += t.deposit - t.withdrawal;
        sheet.appendRow([
          TextCellValue(_dateFmt.format(t.date)),
          TextCellValue(t.description),
          TextCellValue(t.deposit > 0 ? _money(t.deposit) : ''),
          TextCellValue(t.withdrawal > 0 ? _money(t.withdrawal) : ''),
          TextCellValue(_money(running)),
        ]);
      }

      sheet.appendRow([
        TextCellValue(''),
        TextCellValue('Plan Total'),
        TextCellValue(_money(plan.totalDeposited)),
        TextCellValue(_money(plan.totalWithdrawn)),
        TextCellValue(_money(plan.closingBalance)),
      ]);
      sheet.appendRow([]);
    }

    return Uint8List.fromList(excel.save()!);
  }

  /// Delegates to shared [StatementFormatters.money].
  static String _money(num v) => StatementFormatters.money(v);
}

class _TxRow {
  final DateTime date;
  final String description;
  final double deposit;
  final double withdrawal;
  _TxRow({
    required this.date,
    required this.description,
    required this.deposit,
    required this.withdrawal,
  });
}
