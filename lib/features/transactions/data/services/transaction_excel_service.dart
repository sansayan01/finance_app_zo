import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/enums.dart';
import '../models/transaction_model.dart';
import 'transaction_export_options.dart';

class TransactionExcelService {
  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');

  static Future<void> share({
    required List<TransactionModel> transactions,
    required TransactionExportOptions options,
  }) async {
    final bytes = build(transactions: transactions, options: options);
    final dir = await getTemporaryDirectory();
    final periodLabel = _periodLabel(options);
    final file = File('${dir.path}/transaction_report_$periodLabel.xlsx');
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
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Transactions');
    final sheet = excel['Transactions'];

    // Summary stats
    double inflow = 0;
    double outflow = 0;
    for (final t in transactions) {
      if (_isInflow(t.type)) {
        inflow += t.amount;
      } else {
        outflow += t.amount;
      }
    }

    // Header
    sheet.appendRow([TextCellValue('TRANSACTION REPORT')]);
    final start = options.resolvedStart;
    final end = options.resolvedEnd;
    if (start != null && end != null) {
      sheet.appendRow([
        TextCellValue('Period:'),
        TextCellValue('${_dateFmt.format(start)} – ${_dateFmt.format(end)}'),
      ]);
    } else {
      sheet.appendRow([TextCellValue('Period: All Transactions')]);
    }
    sheet.appendRow([
      TextCellValue('Generated:'),
      TextCellValue(_dateTimeFmt.format(DateTime.now())),
    ]);
    sheet.appendRow([]);

    // Summary
    if (options.includeSummary) {
      sheet.appendRow([TextCellValue('SUMMARY')]);
      sheet.appendRow([TextCellValue('Total Inflow'), DoubleCellValue(inflow)]);
      sheet.appendRow([TextCellValue('Total Outflow'), DoubleCellValue(outflow)]);
      sheet.appendRow([TextCellValue('Transaction Count'), IntCellValue(transactions.length)]);
      sheet.appendRow([TextCellValue('Net'), DoubleCellValue(inflow - outflow)]);
      sheet.appendRow([]);
    }

    // Data header
    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Member'),
      TextCellValue('Type'),
      TextCellValue('Payment Mode'),
      TextCellValue('Amount'),
      TextCellValue('Direction'),
      TextCellValue('Collected By'),
      TextCellValue('Role'),
      TextCellValue('Description'),
    ]);

    // Data rows
    for (final t in transactions) {
      sheet.appendRow([
        TextCellValue(_dateTimeFmt.format(t.createdAt)),
        TextCellValue(t.memberName.isNotEmpty ? t.memberName : 'Unknown'),
        TextCellValue(_typeLabel(t.type)),
        TextCellValue(_paymentModeLabel(t.paymentMode)),
        DoubleCellValue(t.amount),
        TextCellValue(_isInflow(t.type) ? 'Inflow' : 'Outflow'),
        TextCellValue(t.collectedByName ?? ''),
        TextCellValue(t.collectedByRole ?? ''),
        TextCellValue(t.description ?? ''),
      ]);
    }

    final fileBytes = excel.save();
    if (fileBytes == null) {
      throw Exception('Failed to generate Excel file');
    }
    return Uint8List.fromList(fileBytes);
  }

  static String _periodLabel(TransactionExportOptions options) {
    final start = options.resolvedStart;
    final end = options.resolvedEnd;
    if (start != null && end != null) {
      return '${DateFormat('yyyy-MM-dd').format(start)}_to_${DateFormat('yyyy-MM-dd').format(end)}';
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
}
