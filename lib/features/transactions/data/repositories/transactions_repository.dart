import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/enums.dart';
import '../models/transaction_model.dart';

class TransactionsRepository {
  final SupabaseClient _client;
  final String _orgId;

  TransactionsRepository(this._client, this._orgId);

  Future<List<TransactionModel>> getRecentTransactions({int limit = 10}) async {
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('org_id', _orgId)
          .order('created_at', ascending: false)
          .limit(limit);

      final filtered = await _filterOrphanedTransactions(response as List);

      return filtered.map((json) => TransactionModel.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<TransactionModel>> getTransactionsByDate(
    DateTime date, {
    int limit = 100,
  }) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final response = await _client
        .from('transactions')
        .select()
        .eq('org_id', _orgId)
        .filter('created_at', 'gte', startOfDay.toIso8601String())
        .filter('created_at', 'lt', endOfDay.toIso8601String())
        .order('created_at', ascending: false)
        .limit(limit);

    final filtered = await _filterOrphanedTransactions(response as List);

    return filtered.map((json) => TransactionModel.fromJson(json)).toList();
  }

  Future<List<TransactionModel>> getTransactionsBySavingsId(
    String savingsId, {
    int limit = 50,
  }) async {
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('org_id', _orgId)
          .eq('savings_id', savingsId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => TransactionModel.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> createTransaction({
    required String memberId,
    required String memberName,
    required TransactionType type,
    required double amount,
    String? loanId,
    String? savingsId,
    PaymentMode? paymentMode,
    String? description,
  }) async {
    await _client.from('transactions').insert({
      'member_id': memberId,
      'member_name': memberName,
      'type': type.name,
      'amount': amount,
      'loan_id': loanId,
      'savings_id': savingsId,
      'payment_mode': paymentMode?.name,
      'description': description,
      'org_id': _orgId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> getTodayStats() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await _client
          .from('transactions')
          .select()
          .eq('org_id', _orgId)
          .filter('created_at', 'gte', startOfDay.toIso8601String())
          .filter('created_at', 'lt', endOfDay.toIso8601String());

      final filtered = await _filterOrphanedTransactions(response as List);

      double collected = 0;
      double disbursed = 0;
      int collectionCount = 0;
      int totalDue = 0;

      for (final t in filtered) {
        final type = t['type'] as String;
        final amount = (t['amount'] as num).toDouble();
        if (type == 'emiPayment' || type == 'savingsDeposit') {
          collected += amount;
          collectionCount++;
        } else if (type == 'loanDisbursement') {
          disbursed += amount;
        }
      }

      return {
        'collected': collected,
        'disbursed': disbursed,
        'collectionCount': collectionCount,
        'totalDue': totalDue,
      };
    } catch (e) {
      return {
        'collected': 0.0,
        'disbursed': 0.0,
        'collectionCount': 0,
        'totalDue': 0,
      };
    }
  }

  Future<List<dynamic>> _filterOrphanedTransactions(
      List<dynamic> transactions) async {
    if (transactions.isEmpty) return [];

    final loanIds = transactions
        .map((t) => t['loan_id'] as String?)
        .where((id) => id != null)
        .cast<String>()
        .toSet()
        .toList();

    final savingsIds = transactions
        .map((t) => t['savings_id'] as String?)
        .where((id) => id != null)
        .cast<String>()
        .toSet()
        .toList();

    final Map<String, bool> existingLoans = {};
    if (loanIds.isNotEmpty) {
      try {
        final loansResponse =
            await _client.from('loans').select('id').inFilter('id', loanIds);
        for (final l in loansResponse as List) {
          existingLoans[l['id'] as String] = true;
        }
      } catch (_) {}
    }

    final Map<String, bool> existingSavings = {};
    if (savingsIds.isNotEmpty) {
      try {
        final savingsResponse = await _client
            .from('savings_plans')
            .select('id')
            .inFilter('id', savingsIds);
        for (final s in savingsResponse as List) {
          existingSavings[s['id'].toString()] = true;
        }
      } catch (_) {
        try {
          final savingsResponse = await _client
              .from('savings')
              .select('id')
              .inFilter('id', savingsIds);
          for (final s in savingsResponse as List) {
            existingSavings[s['id'].toString()] = true;
          }
        } catch (_) {}
      }
    }

    return transactions.where((t) {
      final loanId = t['loan_id'] as String?;
      final savingsId = t['savings_id'] as String?;

      if (loanId != null && !existingLoans.containsKey(loanId)) {
        return false;
      }
      if (savingsId != null && !existingSavings.containsKey(savingsId)) {
        return false;
      }
      return true;
    }).toList();
  }
}
