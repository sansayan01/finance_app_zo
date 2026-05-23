import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/enums.dart';
import '../models/transaction_model.dart';

class TransactionsRepository {
  final SupabaseClient _client;
  final String _orgId;

  TransactionsRepository(this._client, this._orgId);

  Future<List<TransactionModel>> getRecentTransactions({int limit = 10}) async {
    try {
      // RLS enforces org isolation — no need for client-side org_id filter
      final response = await _client
          .from('transactions')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      final list = response as List;
      if (list.isEmpty) return [];

      return list
          .map((json) =>
              TransactionModel.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
    } catch (e) {
      debugPrint('getRecentTransactions error: $e');
      return [];
    }
  }

  /// Paginated fetch for the transaction history page.
  /// Uses offset-based pagination.
  Future<List<TransactionModel>> getTransactionsPaginated({
    int offset = 0,
    int limit = 20,
    TransactionType? typeFilter,
    String? searchQuery,
  }) async {
    try {
      var query = _client
          .from('transactions')
          .select();

      if (typeFilter != null) {
        query = query.eq('type', typeFilter.name);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        query = query.ilike('member_name', '%${searchQuery.trim()}%');
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final list = response as List;
      if (list.isEmpty) return [];

      return list
          .map((json) =>
              TransactionModel.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
    } catch (e) {
      debugPrint('getTransactionsPaginated error: $e');
      return [];
    }
  }

  Future<List<TransactionModel>> getTransactionsByDate(
    DateTime date, {
    int limit = 100,
  }) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    try {
      final response = await _client
          .from('transactions')
          .select()
          .filter('created_at', 'gte', startOfDay.toIso8601String())
          .filter('created_at', 'lt', endOfDay.toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) =>
              TransactionModel.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
    } catch (e) {
      debugPrint('getTransactionsByDate error: $e');
      return [];
    }
  }

  Future<List<TransactionModel>> getMemberSavingsTransactions({
    required String memberId,
    required DateTime periodEnd,
  }) async {
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('member_id', memberId)
          .inFilter('type', [
        TransactionType.savingsDeposit.name,
        TransactionType.savingsWithdrawal.name,
      ])
          .filter('created_at', 'lt', periodEnd.toIso8601String())
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => TransactionModel.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<TransactionModel>> getTransactionsBySavingsId(
    String savingsId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('savings_id', savingsId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => TransactionModel.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> updateTransaction({
    required String id,
    double? amount,
    String? description,
    DateTime? createdAt,
    TransactionType? type,
  }) async {
    final patch = <String, dynamic>{};
    if (amount != null) patch['amount'] = amount;
    if (description != null) patch['description'] = description;
    if (createdAt != null) patch['created_at'] = createdAt.toIso8601String();
    if (type != null) patch['type'] = type.name;
    if (patch.isEmpty) return;

    await _client.from('transactions').update(patch).eq('id', id);
  }

  Future<void> deleteTransaction(String id) async {
    await _client.from('transactions').delete().eq('id', id);
  }

  Future<int> deleteTransactions(List<String> ids) async {
    if (ids.isEmpty) return 0;
    await _client.from('transactions').delete().inFilter('id', ids);
    return ids.length;
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
          .filter('created_at', 'gte', startOfDay.toIso8601String())
          .filter('created_at', 'lt', endOfDay.toIso8601String());

      final list = response as List;

      double collected = 0;
      double disbursed = 0;
      int collectionCount = 0;
      int totalDue = 0;

      for (final t in list) {
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
}
