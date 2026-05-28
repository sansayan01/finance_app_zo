import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/enums.dart';
import '../models/emi_schedule_model.dart';

class EMIRepository {
  final SupabaseClient _client;
  final String _orgId;

  EMIRepository(this._client, this._orgId);

  Future<List<EMIScheduleModel>> getByLoanId(String loanId) async {
    try {
      var response = await _client
          .from('emi_schedule')
          .select()
          .eq('loan_id', loanId)
          .order('emi_number', ascending: true);

      if ((response as List).isEmpty) {
        try {
          final loanResponse = await _client
              .from('loans')
              .select()
              .eq('id', loanId)
              .maybeSingle();
          if (loanResponse != null) {
            final double amount = ((loanResponse['amount'] ?? loanResponse['principal']) as num?)?.toDouble() ?? 0.0;
            final double interestRate = ((loanResponse['interest_rate']) as num?)?.toDouble() ?? 0.0;
            final int tenureMonths = loanResponse['tenure_months'] as int? ?? 12;
            final String interestType = loanResponse['interest_type'] as String? ?? 'flat';
            final double emiAmount = (loanResponse['emi_amount'] as num?)?.toDouble() ?? 0.0;
            final String? memberId = loanResponse['customer_id']?.toString() ?? loanResponse['member_id']?.toString();
            final String? frequency = loanResponse['frequency'] as String?;
            final DateTime startDate = (loanResponse['first_emi_date'] ?? loanResponse['first_installment_date']) != null
                ? DateTime.parse((loanResponse['first_emi_date'] ?? loanResponse['first_installment_date']) as String)
                : (loanResponse['disbursement_date'] != null
                    ? DateTime.parse(loanResponse['disbursement_date'] as String)
                    : DateTime.now());

            await generateSchedule(
              loanId,
              principal: amount,
              interestRate: interestRate,
              tenureMonths: tenureMonths,
              interestType: interestType,
              startDate: startDate,
              emiAmount: emiAmount,
              memberId: memberId,
              frequency: frequency,
            );

            response = await _client
                .from('emi_schedule')
                .select()
                .eq('loan_id', loanId)
                .order('emi_number', ascending: true);
          }
        } catch (_) {}
      }

      return (response as List)
          .map((json) => EMIScheduleModel.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> recordPayment({
    required String emiId,
    required String loanId,
    required double amount,
    required String paymentMode,
    String? notes,
    String? agentId,
  }) async {
    try {
      final now = DateTime.now();

      // 1. Update EMI Schedule
      await _client.from('emi_schedule').update({
        'is_paid': true,
        'paid_date': now.toUtc().toIso8601String(),
      }).eq('id', emiId);

      // 2. Look up borrower info from the loan
      String? memberId;
      String? memberName;
      try {
        final loan = await _client
            .from('loans')
            .select('customer_id, member_id, member_name')
            .eq('id', loanId)
            .maybeSingle();
        if (loan == null) return;
        memberId = loan['customer_id']?.toString() ?? loan['member_id']?.toString();
        memberName = loan['member_name']?.toString();
        // If member_name is null on loan, look up from members table
        if (memberName == null && memberId != null) {
          final member = await _client
              .from('members')
              .select('full_name')
              .eq('id', memberId)
              .maybeSingle();
          memberName = member?['full_name']?.toString();
        }
      } catch (_) {}

      // 3. Create Transaction Record
      await _client.from('transactions').insert({
        'loan_id': loanId,
        'member_id': memberId,
        'member_name': memberName ?? 'Unknown',
        'type': TransactionType.emiPayment.name,
        'amount': amount,
        'payment_mode': paymentMode,
        'description':
            'EMI payment via $paymentMode${notes != null ? ': $notes' : ''}',
        'org_id': _orgId,
        'entered_at': now.toUtc().toIso8601String(),
        'created_at': now.toUtc().toIso8601String(),
      });

      // 3. Update loan's outstanding balance
      final loanResponse = await _client
          .from('loans')
          .select('outstanding_amount, outstanding_balance')
          .eq('id', loanId)
          .maybeSingle();

      if (loanResponse == null) return;

      final currentBalance = ((loanResponse['outstanding_amount'] ??
                  loanResponse['outstanding_balance']) as num?)
              ?.toDouble() ??
          0;

      final newBalance = (currentBalance - amount).clamp(0.0, currentBalance);

      await _client.from('loans').update({
        'outstanding_amount': newBalance,
        'outstanding_balance': newBalance,
      }).eq('id', loanId);

      // 4. Check if loan is fully paid - auto close
      if (newBalance <= 0) {
        await _client.from('loans').update({
          'status': 'closed',
          'closed_date': now.toIso8601String().split('T').first,
          'outstanding_amount': 0.0,
          'outstanding_balance': 0.0,
        }).eq('id', loanId);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> recordManualPayment({
    required String loanId,
    required double amount,
    required String paymentMode,
    String? notes,
    String? agentId,
  }) async {
    try {
      final now = DateTime.now();

      // 1. Look up borrower info from the loan
      String? memberId;
      String? memberName;
      try {
        final loan = await _client
            .from('loans')
            .select('customer_id, member_id, member_name')
            .eq('id', loanId)
            .maybeSingle();
        if (loan == null) return;
        memberId = loan['customer_id']?.toString() ?? loan['member_id']?.toString();
        memberName = loan['member_name']?.toString();
        if (memberName == null && memberId != null) {
          final member = await _client
              .from('members')
              .select('full_name')
              .eq('id', memberId)
              .maybeSingle();
          memberName = member?['full_name']?.toString();
        }
      } catch (_) {}

      // 2. Create Transaction Record
      await _client.from('transactions').insert({
        'loan_id': loanId,
        'member_id': memberId,
        'member_name': memberName ?? 'Unknown',
        'type': TransactionType.emiPayment.name,
        'amount': amount,
        'payment_mode': paymentMode,
        'description':
            'Manual payment via $paymentMode${notes != null ? ': $notes' : ''}',
        'org_id': _orgId,
        'entered_at': now.toUtc().toIso8601String(),
        'created_at': now.toUtc().toIso8601String(),
      });

      // 2. Update loan's outstanding balance
      final loanResponse = await _client
          .from('loans')
          .select('outstanding_amount, outstanding_balance')
          .eq('id', loanId)
          .maybeSingle();

      if (loanResponse == null) return;

      final currentBalance = ((loanResponse['outstanding_amount'] ??
                  loanResponse['outstanding_balance']) as num?)
              ?.toDouble() ??
          0;

      final newBalance = (currentBalance - amount).clamp(0.0, currentBalance);

      await _client.from('loans').update({
        'outstanding_amount': newBalance,
        'outstanding_balance': newBalance,
      }).eq('id', loanId);

      // 3. Check if loan is fully paid - auto close
      if (newBalance <= 0) {
        await _client.from('loans').update({
          'status': 'closed',
          'closed_date': now.toIso8601String().split('T').first,
          'outstanding_amount': 0.0,
          'outstanding_balance': 0.0,
        }).eq('id', loanId);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> generateSchedule(
    String loanId, {
    required double principal,
    required double interestRate,
    required int tenureMonths,
    required String interestType,
    required DateTime startDate,
    required double emiAmount,
    String? memberId,
    String? frequency,
  }) async {
    try {
      // Try RPC first, verify it actually created rows
      bool rpcWorked = false;
      try {
        await _client
            .rpc('generate_emi_schedule', params: {'p_loan_id': loanId});
        // Verify rows were created
        final check = await _client
            .from('emi_schedule')
            .select('id')
            .eq('loan_id', loanId)
            .limit(1);
        if ((check as List).isNotEmpty) {
          rpcWorked = true;
        }
      } catch (e) {
        // RPC failed, will use manual generation
      }

      if (!rpcWorked) {
        // Manual generation fallback
        final List<Map<String, dynamic>> schedule = [];
        double balance = principal;
        final annualRate = interestRate / 100;
        final monthlyRate = annualRate / 12;

        // Determine number of installments based on frequency
        final freq = frequency ?? 'monthly';
        int numberOfInstallments;
        switch (freq) {
          case 'daily':
            numberOfInstallments = tenureMonths * 30;
            break;
          case 'weekly':
            numberOfInstallments = (tenureMonths * 30 / 7).round();
            break;
          case 'yearly':
            numberOfInstallments = (tenureMonths / 12).round().clamp(1, 100);
            break;
          default: // monthly
            numberOfInstallments = tenureMonths;
        }

        // Recalculate EMI for the actual number of installments
        final actualEmi = (principal + (principal * annualRate * (tenureMonths / 12))) / numberOfInstallments;
        final emiToUse = emiAmount > 0 ? emiAmount : actualEmi;

        for (int i = 1; i <= numberOfInstallments; i++) {
          double interest;
          double principalPaid;

          if (interestType == 'reducing' || interestType == 'reducingBalance') {
            // Adjust rate per period
            double ratePerPeriod;
            switch (freq) {
              case 'daily':
                ratePerPeriod = annualRate / 365;
                break;
              case 'weekly':
                ratePerPeriod = annualRate / 52;
                break;
              case 'yearly':
                ratePerPeriod = annualRate;
                break;
              default:
                ratePerPeriod = monthlyRate;
            }
            interest = balance * ratePerPeriod;
            principalPaid = emiToUse - interest;
          } else {
            // Flat rate
            interest =
                (principal * annualRate * (tenureMonths / 12)) / numberOfInstallments;
            principalPaid = emiToUse - interest;
          }

          balance -= principalPaid;
          if (balance < 0) balance = 0;

          // Calculate due date based on frequency
          DateTime dueDate;
          switch (freq) {
            case 'daily':
              dueDate = startDate.add(Duration(days: i - 1));
              break;
            case 'weekly':
              dueDate = startDate.add(Duration(days: (i - 1) * 7));
              break;
            case 'yearly':
              dueDate = DateTime(startDate.year + (i - 1), startDate.month, startDate.day);
              break;
            default: // monthly
              dueDate = DateTime(startDate.year, startDate.month + (i - 1), startDate.day);
          }

          schedule.add({
            'loan_id': loanId,
            'org_id': _orgId,
            'member_id': memberId,
            'emi_number': i,
            'installment_number': i,
            'period': i,
            'due_date': dueDate.toIso8601String().split('T').first,
            'emi_amount': emiToUse,
            'emi': emiToUse,
            'principal': principalPaid,
            'interest': interest,
            'balance_after': balance,
            'status': 'pending',
            'is_paid': false,
            'is_overdue': false,
          });
        }

        await _client.from('emi_schedule').insert(schedule);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateEMIStatus(String emiId, String status) async {
    await _client
        .from('emi_schedule')
        .update({'status': status}).eq('id', emiId);
  }

  Future<List<Map<String, dynamic>>> getPaymentHistory(String loanId) async {
    try {
      // 1. Fetch collections for this loan
      final collectionsResponse = await _client
          .from('collections')
          .select('''
            id,
            loan_id,
            amount_collected,
            amount_expected,
            payment_mode,
            collection_date,
            collection_time,
            remarks,
            reference_number,
            profiles!fk_collections_staff(full_name, role)
          ''')
          .eq('loan_id', loanId);

      final List<Map<String, dynamic>> collections = [];
      for (final json in collectionsResponse) {
        final item = Map<String, dynamic>.from(json);
        final staff = item['profiles'] as Map<String, dynamic>?;
        collections.add({
          'id': item['id']?.toString() ?? '',
          'transaction_id': item['id']?.toString() ?? '',
          'loan_id': item['loan_id']?.toString() ?? '',
          'amount': ((item['amount_collected'] ?? item['amount_expected']) as num?)?.toDouble() ?? 0.0,
          'payment_mode': item['payment_mode']?.toString() ?? 'cash',
          'reference_number': item['reference_number']?.toString(),
          'notes': item['remarks']?.toString(),
          'created_at': item['collection_time']?.toString() ?? item['collection_date']?.toString() ?? '',
          'collected_by_name': staff?['full_name']?.toString(),
          'collected_by_role': staff?['role']?.toString(),
          'source': 'collection',
        });
      }

      // 2. Fetch transactions for this loan
      final transactionsResponse = await _client
          .from('transactions')
          .select()
          .eq('loan_id', loanId)
          .eq('type', TransactionType.emiPayment.name);

      final List<Map<String, dynamic>> transactions = [];
      for (final json in transactionsResponse) {
        final item = Map<String, dynamic>.from(json);
        transactions.add({
          'id': item['id']?.toString() ?? '',
          'transaction_id': item['id']?.toString() ?? '',
          'loan_id': item['loan_id']?.toString() ?? '',
          'amount': (item['amount'] as num?)?.toDouble() ?? 0.0,
          'payment_mode': item['payment_mode']?.toString() ?? 'cash',
          'reference_number': item['reference_number']?.toString(),
          'notes': item['description']?.toString(),
          'created_at': item['created_at']?.toString() ?? '',
          'source': 'transaction',
        });
      }

      // 3. Merge and deduplicate
      final List<Map<String, dynamic>> merged = [];
      merged.addAll(collections);

      for (final tx in transactions) {
        final txTimeStr = tx['created_at']?.toString() ?? '';
        final txTime = DateTime.tryParse(txTimeStr);
        final txAmount = tx['amount'] as double;
        final txMode = tx['payment_mode']?.toString();

        bool isDuplicate = false;
        if (txTime != null) {
          for (final col in collections) {
            final colTimeStr = col['created_at']?.toString() ?? '';
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
        final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });

      return merged;
    } catch (e) {
      return [];
    }
  }

  Future<List<EMIScheduleModel>> getTodaysDues() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await _client
          .from('emi_schedule')
          .select()
          .filter('due_date', 'gte', startOfDay.toIso8601String())
          .filter('due_date', 'lt', endOfDay.toIso8601String())
          .inFilter('status', ['pending', 'overdue']);

      return (response as List)
          .map((json) => EMIScheduleModel.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }
}
