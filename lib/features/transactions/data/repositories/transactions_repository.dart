import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/utils/formatters.dart' show AppFormatters;
import '../models/transaction_model.dart';

class TransactionsRepository {
  final SupabaseClient _client;
  final String _orgId;

  TransactionsRepository(this._client, this._orgId);

  Future<List<TransactionModel>> getRecentTransactions({int limit = 10}) async {
    try {
      final response = await _client
          .from('transactions')
          .select('id, type, amount, description, created_at, member_id, member_name, loan_id, savings_id, payment_mode')
          .eq('org_id', _orgId)
          .order('created_at', ascending: false)
          .limit(limit);

      final list = response as List;
      if (list.isEmpty) return [];

      final txns = list
          .map((json) =>
              TransactionModel.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();

      return _resolveMemberNames(txns);
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
          .select()
          .eq('org_id', _orgId);

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

      final txns = list
          .map((json) =>
              TransactionModel.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();

      return _resolveMemberNames(txns);
    } catch (e) {
      debugPrint('getTransactionsPaginated error: $e');
      return [];
    }
  }

  /// Batch-resolve member names for transactions with missing names.
  Future<List<TransactionModel>> _resolveMemberNames(
      List<TransactionModel> txns) async {
    final missingIds = <String>{};
    for (final t in txns) {
      if (t.memberName.isEmpty && t.memberId.isNotEmpty) {
        missingIds.add(t.memberId);
      }
    }
    if (missingIds.isEmpty) return txns;

    try {
      final members = await _client
          .from('members')
          .select('id, full_name')
          .inFilter('id', missingIds.toList());

      final nameMap = <String, String>{};
      for (final m in members as List) {
        final id = m['id']?.toString() ?? '';
        final name = m['full_name']?.toString() ?? '';
        if (id.isNotEmpty && name.isNotEmpty) nameMap[id] = name;
      }

      return txns.map((t) {
        if (t.memberName.isEmpty && nameMap.containsKey(t.memberId)) {
          return TransactionModel(
            id: t.id,
            memberId: t.memberId,
            memberName: nameMap[t.memberId]!,
            type: t.type,
            amount: t.amount,
            loanId: t.loanId,
            savingsId: t.savingsId,
            createdAt: t.createdAt,
            description: t.description,
            paymentMode: t.paymentMode,
            agentId: t.agentId,
            collectedByUserId: t.collectedByUserId,
            collectedByName: t.collectedByName,
            collectedByRole: t.collectedByRole,
            collectedAt: t.collectedAt,
            collectionMethod: t.collectionMethod,
          );
        }
        return t;
      }).toList();
    } catch (e) {
      debugPrint('_resolveMemberNames error: $e');
      return txns;
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
          .select('id, type, amount, description, created_at, member_id, member_name, loan_id, savings_id, payment_mode')
          .eq('org_id', _orgId)
          .filter('created_at', 'gte', startOfDay.toIso8601String())
          .filter('created_at', 'lt', endOfDay.toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit);

      final txns = (response as List)
          .map((json) =>
              TransactionModel.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();

      return _resolveMemberNames(txns);
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
          .eq('org_id', _orgId)
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
          .select('id, type, amount, description, created_at, member_id, member_name, loan_id, savings_id, payment_mode')
          .eq('org_id', _orgId)
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

  /// Permanently deletes a transaction row.
  ///
  /// For EMI / savings-deposit transactions, this also reverts the linked
  /// collection (deletes savings_collections or unmarks EMIs + restores the
  /// loan outstanding) so the financial state stays consistent.
  ///
  /// Tries the server-side RPC first for atomicity; falls back to a
  /// client-side revert if the RPC is missing or fails (e.g. RLS).
  Future<void> deleteTransaction(String id) async {
    // 1. Fetch the transaction to determine its type
    final txData = await _client
        .from('transactions')
        .select('id, type, loan_id, savings_id, amount, member_id, org_id')
        .eq('id', id)
        .maybeSingle();

    if (txData == null) {
      throw Exception('Transaction not found');
    }

    final type = txData['type'] as String?;
    final loanId = txData['loan_id'] as String?;
    final savingsId = txData['savings_id'] as String?;
    final amount = (txData['amount'] as num?)?.toDouble() ?? 0.0;
    final memberId = txData['member_id'] as String?;
    final orgId = txData['org_id'] as String?;

    if (type == TransactionType.emiPayment.name && loanId != null) {
      // --- Full revert for loan EMI ---
      // The collection sheet inserts one row per EMI (each with
      // amount_collected == emiAmount) but the transaction stores the
      // total amount.  We find matching collections by loan_id
      // and delete them all, then delete the transaction.

      List<Map<String, dynamic>> matchingCollections = [];

      // Strategy 1: exact amount + member match (single EMI payment)
      final exactMatch = await _client
          .from('collections')
          .select('id')
          .eq('loan_id', loanId)
          .eq('amount_collected', amount)
          .eq('member_id', memberId ?? '')
          .order('collection_time', ascending: false)
          .limit(1)
          .maybeSingle();

      if (exactMatch != null) {
        matchingCollections.add(Map<String, dynamic>.from(exactMatch as Map));
      }

      // Strategy 2: find collections matching this payment event.
      // For multi-EMI payments, one transaction (total amount) maps to
      // multiple collection rows (per-EMI amounts) created at the same time.
      if (matchingCollections.isEmpty) {
        try {
          // Get the transaction's created_at to find the matching collections
          final txData = await _client
              .from('transactions')
              .select('created_at')
              .eq('id', id)
              .maybeSingle();

          final txDateStr = txData?['created_at']?.toString() ?? '';
          DateTime? txDate = DateTime.tryParse(txDateStr);
          txDate ??= DateTime.tryParse(txDateStr.replaceFirst(' ', 'T'));

          if (txDate != null) {
            // Find collections within 1 minute of the transaction (same batch)
            final txTimeStr = '${txDate.year}-${txDate.month.toString().padLeft(2, '0')}-${txDate.day.toString().padLeft(2, '0')}';

            final candidates = await _client
                .from('collections')
                .select('id, amount_collected, collection_time')
                .eq('loan_id', loanId)
                .eq('collection_date', txTimeStr)
                .order('collection_time', ascending: false);

            final list = candidates as List;
            if (list.isNotEmpty) {
              double runningSum = 0;
              for (final col in list) {
                final colAmount = (col['amount_collected'] as num?)?.toDouble() ?? 0;
                matchingCollections.add(Map<String, dynamic>.from(col as Map));
                runningSum += colAmount;
                if (runningSum >= amount - 0.01) break;
              }
            }
          }
        } catch (_) {
          // Fall through — will just delete the transaction
        }
      }

      if (matchingCollections.isNotEmpty) {
        // Delete each matching collection
        for (final col in matchingCollections) {
          final collectionId = col['id'] as String;
          try {
            await _client.rpc('delete_loan_collection', params: {
              'p_collection_id': collectionId,
            });
          } catch (_) {
            // RPC missing or blocked — fall through to client-side revert
            await _deleteLoanCollectionClientSide(
              collectionId: collectionId,
              loanId: loanId,
              amount: (col['amount_collected'] as num?)?.toDouble() ?? 0,
              orgId: orgId,
            );
          }
        }
      }

      // Always delete the transaction itself
      await _client.from('transactions').delete().eq('id', id);
      return;
    }

    if (type == TransactionType.savingsDeposit.name && savingsId != null) {
      // --- Full revert for savings deposit ---
      try {
        await _client.rpc('delete_savings_transaction', params: {
          'p_transaction_id': id,
        });
        return;
      } catch (_) {
        // RPC missing or blocked — fall through to client-side revert
      }
      await _deleteSavingsDepositClientSide(
        transactionId: id,
        savingsPlanId: savingsId,
        amount: amount,
        memberId: memberId,
        orgId: orgId,
      );
      return;
    }

    // --- Simple transaction deletion (no revert needed) ---
    await _client.from('transactions').delete().eq('id', id);
  }

  /// Client-side fallback: revert a loan collection without the RPC.
  /// Unmarks the most recently paid EMIs and restores the loan outstanding.
  Future<void> _deleteLoanCollectionClientSide({
    required String collectionId,
    required String loanId,
    required double amount,
    String? orgId,
  }) async {
    // 1. Delete the collection record
    await _client.from('collections').delete().eq('id', collectionId);

    // 2. Find and delete the matching transaction (best effort)
    try {
      final tx = await _client
          .from('transactions')
          .select('id')
          .eq('loan_id', loanId)
          .eq('amount', amount)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (tx != null) {
        await _client.from('transactions').delete().eq('id', tx['id']);
      }
    } catch (_) {
      // Non-fatal
    }

    // 3. Unmark the most recently paid EMIs (reverse order)
    try {
      double remaining = amount;
      final paidEmis = await _client
          .from('emi_schedule')
          .select('id, emi_amount')
          .eq('loan_id', loanId)
          .eq('is_paid', true)
          .order('paid_on', ascending: false)
          .order('emi_number', ascending: false);

      for (final emi in paidEmis) {
        if (remaining <= 0) break;
        final emiAmount = (emi['emi_amount'] as num?)?.toDouble() ?? 0;
        await _client.from('emi_schedule').update({
          'is_paid': false,
          'status': 'pending',
          'paid_on': null,
          'payment_mode': null,
          'amount_collected': 0,
          'collected_by': null,
          'transaction_id': null,
          'collection_date': null,
        }).eq('id', emi['id']);
        remaining -= emiAmount;
      }
    } catch (_) {
      // Non-fatal
    }

    // 4. Restore the loan outstanding balance
    try {
      final loan = await _client
          .from('loans')
          .select('outstanding_amount, outstanding_balance, status')
          .eq('id', loanId)
          .maybeSingle();
      if (loan != null) {
        final currentOutstanding =
            (loan['outstanding_amount'] as num?)?.toDouble() ??
                (loan['outstanding_balance'] as num?)?.toDouble() ??
                0.0;
        final restored = currentOutstanding + amount;
        final updateData = <String, dynamic>{
          'outstanding_amount': restored,
          'outstanding_balance': restored,
        };
        if (loan['status'] == 'closed') {
          updateData['status'] = 'active';
        }
        await _client.from('loans').update(updateData).eq('id', loanId);
      }
    } catch (_) {
      // Non-fatal — best-effort revert
    }
  }

  /// Client-side fallback: revert a savings deposit without the RPC.
  /// Deletes the savings_collections record, then triggers a balance recalc
  /// via the recalculate_savings_balance SECURITY DEFINER RPC.
  Future<void> _deleteSavingsDepositClientSide({
    required String transactionId,
    required String savingsPlanId,
    required double amount,
    String? memberId,
    String? orgId,
  }) async {
    // 1. Delete matching savings_collections record first (FK safety)
    try {
      // First try precise match by transaction_id
      final byTxId = await _client
          .from('savings_collections')
          .select('id')
          .eq('transaction_id', transactionId)
          .limit(1)
          .maybeSingle();

      if (byTxId != null) {
        await _client.from('savings_collections').delete().eq('id', byTxId['id']);
      } else {
        // Fallback: match by amount for legacy data without transaction_id
        var q = _client
            .from('savings_collections')
            .select('id')
            .eq('savings_plan_id', savingsPlanId)
            .or(
              'amount_collected.eq.$amount,amount_expected.eq.$amount',
            );
        if (memberId != null) q = q.eq('member_id', memberId);
        if (orgId != null) q = q.eq('org_id', orgId);
        final col = await q.limit(1).maybeSingle();
        if (col != null) {
          await _client.from('savings_collections').delete().eq('id', col['id']);
        }
      }
    } catch (_) {
      // Non-fatal
    }

    // 2. Delete the transaction (safe now — FK dependency removed)
    await _client.from('transactions').delete().eq('id', transactionId);

    // 3. Recalculate the plan balance via RPC (SECURITY DEFINER — bypasses RLS)
    try {
      await _client.rpc('recalculate_savings_balance', params: {
        'p_savings_id': savingsPlanId,
      });
    } catch (_) {
      // Fallback to direct update if the RPC isn't deployed yet
      try {
        final plan = await _client
            .from('savings_plans')
            .select('opening_balance, collection_type, start_date')
            .eq('id', savingsPlanId)
            .maybeSingle();
        final opening =
            (plan?['opening_balance'] as num?)?.toDouble() ?? 0.0;
        final rows = await _client
            .from('transactions')
            .select('type, amount')
            .eq('org_id', _orgId)
            .eq('savings_id', savingsPlanId);
        double balance = opening;
        for (final r in rows as List) {
          final t = r['type'] as String?;
          final amt = (r['amount'] as num?)?.toDouble() ?? 0.0;
          if (t == TransactionType.savingsWithdrawal.name) {
            balance -= amt;
          } else {
            balance += amt;
          }
        }
        if (balance < 0) balance = 0;
        await _client.from('savings_plans').update({
          'current_amount': balance,
        }).eq('id', savingsPlanId);
      } catch (_) {
        // Give up silently — the delete still removed the ledger entry
      }
    }
  }

  Future<int> deleteTransactions(List<String> ids) async {
    if (ids.isEmpty) return 0;
    for (final id in ids) {
      await deleteTransaction(id);
    }
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
      'created_at': AppFormatters.nowIST(),
    });
  }

  Future<Map<String, dynamic>> getTodayStats() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await _client
          .from('transactions')
          .select('type, amount')
          .eq('org_id', _orgId)
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
