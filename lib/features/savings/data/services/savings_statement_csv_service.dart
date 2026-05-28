import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';

import 'savings_statement_models.dart';

class SavingsStatementCsvService {
  static final _dateFmt = DateFormat('dd MMM yyyy');

  static Uint8List build({
    required SavingsStatementData data,
    required String orgName,
    String? statementRef,
  }) {
    final buf = StringBuffer();

    _writeln(buf, '# $orgName');
    _writeln(buf, '# Savings Account Statement');
    _writeln(
        buf, '# ${_dateFmt.format(data.periodStart)} - ${_dateFmt.format(data.periodEnd)}');
    _writeln(buf, '# Customer: ${data.customer.fullName}');
    _writeln(buf, '# Member ID: ${data.customer.memberId}');
    _writeln(buf, '# Phone: ${data.customer.phone}');
    if (statementRef != null) _writeln(buf, '# Ref: $statementRef');
    _writeln(buf, '');

    final p = data.portfolio;
    _writeln(buf, 'Portfolio Summary');
    _writeln(buf, 'Opening Balance,${_money(p.openingBalance)}');
    _writeln(buf, 'Total Deposits,${_money(p.totalDeposits)}');
    _writeln(buf, 'Total Withdrawals,${_money(p.totalWithdrawals)}');
    _writeln(buf, 'Interest Earned,${_money(p.interestEarned)}');
    _writeln(buf, 'Closing Balance,${_money(p.closingBalance)}');
    _writeln(buf, 'Active Plans,${p.activePlans} of ${p.totalPlans}');
    _writeln(buf, '');

    for (final plan in data.plans) {
      _writeln(buf, 'Plan: ${plan.planName} (${plan.status.toUpperCase()})');
      _writeln(buf,
          'Target,${_money(plan.targetAmount)},Opening Balance,${_money(plan.openingBalance)}');
      _writeln(buf,
          'Deposited,${_money(plan.totalDeposited)},Withdrawals,${_money(plan.totalWithdrawn)},Interest,${_money(plan.interestAccrued)},Closing Balance,${_money(plan.closingBalance)}');
      _writeln(buf, 'Maturity,${_dateFmt.format(plan.maturityDate)}');
      _writeln(buf, '');

      final allTxs = [
        ...plan.deposits.map((t) => (
              t.date,
              t.description,
              t.amount,
              0.0,
              t.paymentMode ?? ''
            )),
        ...plan.withdrawals.map((t) => (
              t.date,
              t.description,
              0.0,
              t.amount,
              t.paymentMode ?? ''
            )),
      ]..sort((a, b) => a.$1.compareTo(b.$1));

      _writeln(buf, 'Date,Description,Deposit,Withdrawal,Balance,Mode');

      double running = plan.openingBalance;
      for (final t in allTxs) {
        running += t.$3 - t.$4;
        _writeln(buf,
            '${_dateFmt.format(t.$1)},${_escape(t.$2)},${t.$3 > 0 ? _money(t.$3) : ""},${t.$4 > 0 ? _money(t.$4) : ""},${_money(running)},${t.$5}');
      }
      _writeln(buf, '');
    }

    return utf8.encode(buf.toString()).buffer.asUint8List();
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
    return '${negative ? '-' : ''}$grouped.$fracStr';
  }
}
