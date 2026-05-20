import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/today_payment_model.dart';
import '../providers/payment_providers.dart';

class PaymentExport {
  static Future<void> shareCsv(List<TodayPayment> payments, String dateLabel) async {
    try {
      final csv = _generateCsv(payments, dateLabel);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/payments_$dateLabel.csv');
      await file.writeAsString(csv);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Payments Report - $dateLabel',
          text: 'Payments report for $dateLabel',
        ),
      );
    } catch (e) {
      debugPrint('Error sharing CSV: $e');
      rethrow;
    }
  }

  static String _generateCsv(List<TodayPayment> payments, String dateLabel) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('hh:mm a');

    final buffer = StringBuffer();
    buffer.writeln('Payments Report - $dateLabel');
    buffer.writeln('');
    buffer.writeln('Customer Name,Phone,Type,Loan Number,EMI #,Branch,Agent,Amount Due,Penalty,Amount Collected,Status,Payment Mode,Due Date,Collected At,Remarks');

    for (final p in payments) {
      buffer.writeln(
        '"${p.memberName}",'
        '"${p.memberPhone ?? ''}",'
        '"${p.typeLabel}",'
        '"${p.loanNumber ?? ''}",'
        '"${p.emiNumber ?? ''}",'
        '"${p.branchName ?? ''}",'
        '"${p.agentName ?? ''}",'
        '"${currencyFormat.format(p.amountExpected)}",'
        '"${currencyFormat.format(p.penaltyAmount)}",'
        '"${p.amountCollected != null ? currencyFormat.format(p.amountCollected) : ''}",'
        '"${p.statusLabel}",'
        '"${p.paymentMode ?? ''}",'
        '"${dateFormat.format(p.dueDate)}",'
        '"${p.collectedAt != null ? timeFormat.format(p.collectedAt!) : ''}",'
        '"${p.remarks ?? ''}"',
      );
    }

    return buffer.toString();
  }

  static String generateSummaryText(TodayPaymentData data, String dateLabel) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final summary = data.summary;

    final buffer = StringBuffer();
    buffer.writeln('📊 Payments Summary - $dateLabel');
    buffer.writeln('');
    buffer.writeln('💰 Total Due: ${currencyFormat.format(summary.totalDue)}');
    buffer.writeln('✅ Collected: ${currencyFormat.format(summary.totalCollected)} (${summary.collectionRate.toStringAsFixed(0)}%)');
    buffer.writeln('⏳ Pending: ${currencyFormat.format(summary.totalPending)}');
    if (summary.totalPenalty > 0) {
      buffer.writeln('⚠️ Penalty: ${currencyFormat.format(summary.totalPenalty)}');
    }
    buffer.writeln('');
    buffer.writeln('📋 ${summary.countDue} total | ✅ ${summary.countCollected} collected | ⏳ ${summary.countPending} pending | 🔴 ${summary.countOverdue} overdue');

    if (data.branchSummaries.length > 1) {
      buffer.writeln('');
      buffer.writeln('🏢 Branch-wise:');
      for (final branch in data.branchSummaries) {
        buffer.writeln('  ${branch.branchName}: ${currencyFormat.format(branch.totalCollected)}/${currencyFormat.format(branch.totalDue)} (${branch.collectionRate.toStringAsFixed(0)}%)');
      }
    }

    return buffer.toString();
  }
}
