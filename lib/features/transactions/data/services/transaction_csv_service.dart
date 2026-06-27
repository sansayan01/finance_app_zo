import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/utils/statement_formatters.dart';
import '../models/transaction_model.dart';
import 'transaction_export_options.dart';

class TransactionCsvService {
  static final _dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');
  static final _dateFmt = DateFormat('yyyy-MM-dd');

  static Future<void> share({
    required List<TransactionModel> transactions,
    required TransactionExportOptions options,
  }) async {
    final bytes = build(transactions: transactions, options: options);
    final dir = await getTemporaryDirectory();
    final periodLabel = _periodLabel(options);
    final file = File('${dir.path}/transactions_$periodLabel.csv');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Transaction Report - $periodLabel',
        text: 'Transaction report for $periodLabel',
      ),
    );
  }

  static Uint8List build({
    required List<TransactionModel> transactions,
    required TransactionExportOptions options,
  }) {
    final buf = StringBuffer();

    _writeln(buf, '# Transaction Report');
    _writeln(buf, '# Period,${_periodLabel(options)}');
    _writeln(buf, '# Generated,${_dateTimeFmt.format(DateTime.now())}');
    _writeln(buf, '# Transactions,${transactions.length}');
    _writeln(buf, '');

    // Summary
    if (options.includeSummary && transactions.isNotEmpty) {
      double inflow = 0;
      double outflow = 0;
      for (final t in transactions) {
        if (_isInflow(t.type)) {
          inflow += t.amount;
        } else {
          outflow += t.amount;
        }
      }

      _writeln(buf, '# Summary');
      _writeln(buf, '# Total Inflow,${_money(inflow)}');
      _writeln(buf, '# Total Outflow,${_money(outflow)}');
      _writeln(buf, '# Transaction Count,${transactions.length}');
      _writeln(buf, '# Net,${_money(inflow - outflow)}');
      _writeln(buf, '');
    }

    // Data header
    _writeln(buf, 'Date,Member,Type,Payment Mode,Amount,Direction,Collected By,Role,Description');

    // Data rows
    for (final t in transactions) {
      _writeln(buf, [
        _dateTimeFmt.format(t.createdAt),
        _escape(t.memberName.isNotEmpty ? t.memberName : 'Unknown'),
        _escape(_typeLabel(t.type)),
        _escape(_paymentModeLabel(t.paymentMode)),
        t.amount.toStringAsFixed(2),
        _isInflow(t.type) ? 'Inflow' : 'Outflow',
        _escape(t.collectedByName ?? ''),
        _escape(t.collectedByRole ?? ''),
        _escape(t.description ?? ''),
      ].join(','));
    }

    // UTF-8 BOM for Windows Excel compatibility
    final bom = [0xEF, 0xBB, 0xBF];
    final content = utf8.encode(StatementFormatters.sanitizeForEncoding(buf.toString()));
    return Uint8List.fromList(bom + content);
  }

  static String _periodLabel(TransactionExportOptions options) {
    final start = options.resolvedStart;
    final end = options.resolvedEnd;
    if (start != null && end != null) {
      return '${_dateFmt.format(start)}_to_${_dateFmt.format(end)}';
    }
    return 'all';
  }

  static bool _isInflow(TransactionType type) {
    switch (type) {
      case TransactionType.loanDisbursement:
      case TransactionType.savingsWithdrawal:
        return false;
      default:
        return true;
    }
  }

  static String _typeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.emiPayment:
        return 'EMI Payment';
      case TransactionType.savingsDeposit:
        return 'Savings Deposit';
      case TransactionType.loanDisbursement:
        return 'Loan Disbursed';
      case TransactionType.savingsWithdrawal:
        return 'Withdrawal';
      case TransactionType.penalty:
        return 'Penalty';
      case TransactionType.staffCashDeposit:
        return 'Cash Deposit';
      case TransactionType.other:
        return 'Other';
    }
  }

  static String _paymentModeLabel(PaymentMode? mode) {
    switch (mode) {
      case PaymentMode.cash:
        return 'Cash';
      case PaymentMode.upi:
        return 'UPI';
      case PaymentMode.bankTransfer:
        return 'Bank Transfer';
      case PaymentMode.cheque:
        return 'Cheque';
      case PaymentMode.card:
        return 'Card';
      case null:
        return '';
    }
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

  static String _money(num v) => StatementFormatters.money(v);
}
