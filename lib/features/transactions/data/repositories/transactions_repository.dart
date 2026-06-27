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
    DateTime? dateFrom,
    DateTime? dateTo,
    double? amountMin,
    double? amountMax,
    List<PaymentMode>? paymentModes,
    String sortBy = 'date_desc',
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

      if (dateFrom != null) {
        query = query.gte('created_at', dateFrom.toIso8601String());
      }

      if (dateTo != null) {
        final endOfDay = DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59);
        query = query.lte('created_at', endOfDay.toIso8601String());
      }

      if (amountMin != null) {
        query = query.gte('amount', amountMin);
      }

      if (amountMax != null) {
        query = query.lte('amount', amountMax);
      }

      if (paymentModes != null && paymentModes.isNotEmpty) {
        query = query.inFilter('payment_mode', paymentModes.map((m) => m.name).toList());
      }

      // Apply sorting and pagination as transforms (they return PostgrestTransformBuilder)
      final isAmountSort = sortBy == 'amount_asc' || sortBy == 'amount_desc';
      final transform = isAmountSort
          ? query
              .order('amount', ascending: sortBy == 'amount_asc')
              .order('created_at', ascending: false)
          : query.order('created_at', ascending: sortBy == 'date_asc');

      final response = await transform.range(offset, offset + limit - 1);

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
      // Each collection has a transaction_id linking to its transaction.
      // For single-EMI payments: 1 transaction → 1 collection.
      // For multi-EMI payments: 1 transaction (total) → N collections (per-EMI).
      // We ONLY delete collections that are directly linked to THIS transaction.

      List<Map<String, dynamic>> matchingCollections = [];

      // Strategy 1: match by transaction_id (precise — the collection was created with this link)
      try {
        final byTxId = await _client
            .from('collections')
            .select('id, amount_collected')
            .eq('loan_id', loanId)
            .eq('transaction_id', id);

        if ((byTxId as List).isNotEmpty) {
          matchingCollections = List<Map<String, dynamic>>.from(byTxId);
        }
      } catch (_) {}

      // Strategy 2: fallback — find collections for this loan that have
      // transaction_id set but no OTHER transaction (orphaned by a previous
      // partial delete), OR the most recently created collection matching amount.
      if (matchingCollections.isEmpty) {
        try {
          // Try: collections linked to this specific transaction via description match
          // or the most recent collection for this loan that matches amount
          final candidates = await _client
              .from('collections')
              .select('id, amount_collected, transaction_id, collection_date')
              .eq('loan_id', loanId)
              .eq('amount_collected', amount)
              .order('created_at', ascending: false)
              .limit(1);

          if ((candidates as List).isNotEmpty) {
            // Verify this collection isn't linked to a DIFFERENT transaction
            final col = candidates.first;
            final colTxId = col['transaction_id']?.toString();
            if (colTxId == null || colTxId == id) {
              matchingCollections = List<Map<String, dynamic>>.from(candidates);
            }
          }
        } catch (_) {}
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

      // Delete the transaction itself (RPC/client-side may have already deleted it)
      try {
        await _client.from('transactions').delete().eq('id', id);
      } catch (_) {}
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
  /// Unmarks the linked EMI and restores the loan outstanding.
  Future<void> _deleteLoanCollectionClientSide({
    required String collectionId,
    required String loanId,
    required double amount,
    String? orgId,
  }) async {
    // 1. Fetch collection details before deleting
    String? scheduleId;
    String? linkedTxId;
    try {
      final col = await _client
          .from('collections')
          .select('selected_schedule_id, transaction_id')
          .eq('id', collectionId)
          .maybeSingle();
      scheduleId = col?['selected_schedule_id']?.toString();
      linkedTxId = col?['transaction_id']?.toString();
    } catch (_) {}

    // 2. Unmark the linked EMI FIRST (before deleting collection)
    try {
      if (scheduleId != null) {
        await _client.from('emi_schedule').update({
          'is_paid': false,
          'status': 'pending',
          'paid_on': null,
          'paid_date': null,
          'payment_mode': null,
          'amount_paid': 0,
          'transaction_id': null,
        }).eq('id', scheduleId).eq('is_paid', true);
      } else {
        // Fallback: unmark the most recently paid EMI for this loan
        // that is NOT linked to a DIFFERENT collection via selected_schedule_id
        final paidEmis = await _client
            .from('emi_schedule')
            .select('id')
            .eq('loan_id', loanId)
            .eq('is_paid', true)
            .order('paid_on', ascending: false)
            .order('emi_number', ascending: false);

        if ((paidEmis as List).isNotEmpty) {
          // Check which EMIs are claimed by other collections
          final otherClaimed = await _client
              .from('collections')
              .select('selected_schedule_id')
              .eq('loan_id', loanId)
              .neq('id', collectionId)
              .not('selected_schedule_id', 'is', null);

          final claimedIds = (otherClaimed as List)
              .map((c) => c['selected_schedule_id']?.toString())
              .where((id) => id != null)
              .toSet();

          // Find the first paid EMI not claimed by another collection
          for (final emi in paidEmis) {
            if (!claimedIds.contains(emi['id']?.toString())) {
              await _client.from('emi_schedule').update({
                'is_paid': false,
                'status': 'pending',
                'paid_on': null,
                'paid_date': null,
                'payment_mode': null,
                'amount_paid': 0,
                'transaction_id': null,
              }).eq('id', emi['id']);
              break;
            }
          }
        }
      }
    } catch (_) {}

    // 3. Delete the collection record
    await _client.from('collections').delete().eq('id', collectionId);

    // 4. Delete the linked transaction ONLY if no other collections reference it
    if (linkedTxId != null) {
      try {
        final otherRefs = await _client
            .from('collections')
            .select('id')
            .eq('transaction_id', linkedTxId)
            .limit(1);
        if ((otherRefs as List).isEmpty) {
          await _client.from('transactions').delete().eq('id', linkedTxId);
        }
      } catch (_) {}
    }

    // 5. Recalculate outstanding from EMI schedule (source of truth)
    //    instead of blindly adding back amount — avoids drift when
    //    collections don't align 1:1 with EMIs (migrated accounts, etc.)
    try {
      await _client.rpc('recalculate_loan_outstanding', params: {
        'p_loan_id': loanId,
      });
    } catch (_) {
      // RPC not available — recalculate manually from EMI schedule
      try {
        final emis = await _client
            .from('emi_schedule')
            .select('emi_amount, is_paid')
            .eq('loan_id', loanId);

        double totalRepaid = 0;
        int paidCount = 0;
        double totalEmi = 0;
        for (final emi in (emis as List)) {
          final emiAmt = (emi['emi_amount'] as num?)?.toDouble() ?? 0;
          totalEmi += emiAmt;
          if (emi['is_paid'] == true) {
            totalRepaid += emiAmt;
            paidCount++;
          }
        }

        final newOutstanding = totalEmi - totalRepaid;
        await _client.from('loans').update({
          'outstanding_amount': newOutstanding > 0 ? newOutstanding : 0,
          'outstanding_balance': newOutstanding > 0 ? newOutstanding : 0,
          'paid_emis': paidCount,
          'status': newOutstanding <= 0 ? 'closed' : 'active',
        }).eq('id', loanId);
      } catch (_) {}
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

        // Also count remaining collections to update installments_paid
        final remainingCols = await _client
            .from('savings_collections')
            .select('id')
            .eq('savings_plan_id', savingsPlanId);
        final installmentsPaid = (remainingCols as List).length;

        await _client.from('savings_plans').update({
          'current_amount': balance,
          'installments_paid': installmentsPaid,
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
