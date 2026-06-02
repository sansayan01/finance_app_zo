import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer_loan_model.dart';
import '../models/customer_savings_model.dart';
import '../models/customer_transaction_model.dart';
import '../models/customer_emi_model.dart';

class CustomerHomeRepository {
  final SupabaseClient _client;
  final String _orgId;

  CustomerHomeRepository(this._client, this._orgId);

  Future<Map<String, dynamic>> getDashboardData(String memberId) async {
    try {
      final results = await Future.wait([
        _client
            .from('loans')
            .select()
            .eq('customer_id', memberId)
            .eq('org_id', _orgId),
        _client
            .from('savings_plans')
            .select()
            .eq('member_id', memberId)
            .eq('org_id', _orgId),
        _client
            .from('transactions')
            .select()
            .eq('member_id', memberId)
            .eq('org_id', _orgId)
            .order('transaction_date', ascending: false)
            .limit(5),
        _client
            .from('members')
            .select('full_name, phone, kyc_status, area, village')
            .eq('id', memberId)
            .maybeSingle(),
      ]);

      final loansData = results[0] as List;
      final savingsData = results[1] as List;
      final transactionsData = results[2] as List;
      final memberData = results[3] as Map<String, dynamic>?;

      final loans = loansData
          .map((e) => CustomerLoanModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final savings = savingsData
          .map((e) => CustomerSavingsModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final transactions = transactionsData
          .map((e) => CustomerTransactionModel.fromJson(e))
          .toList();

      final activeLoans = loans.where((l) => l.status == 'active').toList();
      final totalOutstanding =
          activeLoans.fold(0.0, (sum, l) => sum + l.outstandingBalance);
      final totalSavings =
          savings.fold(0.0, (sum, s) => sum + s.currentAmount);

      // Find next EMI due — single query for all active loans
      CustomerEmiModel? nextEmi;
      if (activeLoans.isNotEmpty) {
        try {
          final loanIds = activeLoans.map((l) => l.id).toList();
          final emiData = await _client
              .from('emi_schedule')
              .select()
              .inFilter('loan_id', loanIds)
              .eq('is_paid', false)
              .order('due_date', ascending: true);

          final emiList = (emiData as List)
              .map((e) => CustomerEmiModel.fromJson(
                    e is Map
                        ? Map<String, dynamic>.from(e)
                        : e as Map<String, dynamic>,
                  ))
              .toList();

          for (final emi in emiList) {
            if (nextEmi == null ||
                (emi.dueDate != null &&
                    nextEmi.dueDate != null &&
                    emi.dueDate!.isBefore(nextEmi.dueDate!))) {
              nextEmi = emi;
            }
          }
        } catch (_) {}
      }

      return {
        'memberName': memberData?['full_name'] as String? ?? 'Member',
        'memberPhone': memberData?['phone'] as String?,
        'kycStatus': memberData?['kyc_status'] as String?,
        'area': memberData?['area'] as String?,
        'village': memberData?['village'] as String?,
        'activeLoans': activeLoans.length,
        'totalOutstanding': totalOutstanding,
        'totalSavings': totalSavings,
        'nextEmi': nextEmi,
        'recentTransactions': transactions,
        'allLoans': loans,
        'allSavings': savings,
      };
    } catch (e) {
      rethrow;
    }
  }

  Future<List<CustomerTransactionModel>> getRecentTransactions(
      String memberId,
      {int limit = 5}) async {
    try {
      // 1. Fetch collections
      final collectionsResponse = await _client
          .from('collections')
          .select()
          .eq('member_id', memberId)
          .eq('org_id', _orgId)
          .order('collection_time', ascending: false)
          .limit(limit);

      final List<Map<String, dynamic>> collections = [];
      for (final json in collectionsResponse) {
        final item = Map<String, dynamic>.from(json);
        collections.add({
          'id': item['id']?.toString() ?? '',
          'amount': ((item['amount_collected'] ?? item['amount_expected']) as num?)?.toDouble() ?? 0.0,
          'type': 'collection',
          'description': item['remarks']?.toString() ?? 'EMI collection',
          'payment_mode': item['payment_mode']?.toString() ?? 'cash',
          'transaction_date': item['collection_time']?.toString() ?? item['collection_date']?.toString() ?? '',
          'sync_status': item['sync_status']?.toString() ?? 'synced',
          'member_name': item['member_name']?.toString(),
          'reference_number': item['reference_number']?.toString(),
        });
      }

      // 2. Fetch transactions
      final transactionsResponse = await _client
          .from('transactions')
          .select()
          .eq('member_id', memberId)
          .eq('org_id', _orgId)
          .order('transaction_date', ascending: false)
          .limit(limit);

      final List<Map<String, dynamic>> transactions = [];
      for (final json in transactionsResponse) {
        final item = Map<String, dynamic>.from(json);
        transactions.add({
          'id': item['id']?.toString() ?? '',
          'amount': (item['amount'] as num?)?.toDouble() ?? 0.0,
          'type': item['type']?.toString() ?? 'other',
          'description': item['description']?.toString(),
          'payment_mode': item['payment_mode']?.toString() ?? 'cash',
          'transaction_date': item['transaction_date']?.toString() ?? item['created_at']?.toString() ?? '',
          'sync_status': item['sync_status']?.toString() ?? 'synced',
          'member_name': item['member_name']?.toString(),
          'reference_number': item['reference_number']?.toString(),
        });
      }

      // 3. Merge and deduplicate
      final List<Map<String, dynamic>> merged = [];
      merged.addAll(collections);

      for (final tx in transactions) {
        final txTimeStr = tx['transaction_date']?.toString() ?? '';
        final txTime = DateTime.tryParse(txTimeStr);
        final txAmount = tx['amount'] as double;
        final txMode = tx['payment_mode']?.toString();

        bool isDuplicate = false;
        if (txTime != null) {
          for (final col in collections) {
            final colTimeStr = col['transaction_date']?.toString() ?? '';
            final colTime = DateTime.tryParse(colTimeStr);
            final colAmount = col['amount'] as double;
            final colMode = col['payment_mode']?.toString();

            if (colTime != null && 
                (txAmount - colAmount).abs() < 0.01 && 
                txMode == colMode) {
              final diff = txTime.difference(colTime).inMinutes.abs();
              if (diff <= 5) {
                isDuplicate = true;
                break;
              }
            }
          }
        }

        if (!isDuplicate) {
          merged.add(tx);
        }
      }

      // 4. Sort by date descending
      merged.sort((a, b) {
        final dateA = DateTime.tryParse(a['transaction_date']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = DateTime.tryParse(b['transaction_date']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });

      // 5. Limit and map
      return merged.take(limit).map((e) => CustomerTransactionModel.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }
}
