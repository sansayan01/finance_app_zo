import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/utils/formatters.dart' show AppFormatters;
import '../models/emi_schedule_model.dart';

class EMIRepository {
  final SupabaseClient _client;
  final String _orgId;

  EMIRepository(this._client, this._orgId);

  Future<List<EMIScheduleModel>> getByLoanId(String loanId) async {
    try {
      var response = await _client
          .from('emi_schedule')
          .select('id, loan_id, emi_number, due_date, emi_amount, principal, interest, balance_after, status, paid_on, payment_mode, transaction_id, penalty_amount, penalty_paid, created_at')
          .eq('loan_id', loanId)
          .order('emi_number', ascending: true);

      if ((response as List).isEmpty) {
        try {
          final loanResponse = await _client
              .from('loans')
              .select('amount, principal, interest_rate, tenure_months, tenure_value, tenure_unit, interest_type, emi_amount, customer_id, member_id, frequency, first_emi_date, first_installment_date, disbursement_date')
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
            final int? tenureValue = loanResponse['tenure_value'] as int?;
            final String? tenureUnit = loanResponse['tenure_unit'] as String?;
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
              tenureValue: tenureValue,
              tenureUnit: tenureUnit,
            );

            response = await _client
                .from('emi_schedule')
                .select('id, loan_id, emi_number, due_date, emi_amount, principal, interest, balance_after, status, paid_on, payment_mode, transaction_id, penalty_amount, penalty_paid, created_at')
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
        'status': 'paid',
        'paid_on': AppFormatters.nowIST(),
        'payment_mode': paymentMode,
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
        // If member_name is null/empty on loan, look up from members table
        if ((memberName == null || memberName.isEmpty) && memberId != null) {
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
        'entered_at': AppFormatters.nowIST(),
        'created_at': AppFormatters.nowIST(),
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
        // If member_name is null/empty on loan, look up from members table
        if ((memberName == null || memberName.isEmpty) && memberId != null) {
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
        'entered_at': AppFormatters.nowIST(),
        'created_at': AppFormatters.nowIST(),
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
    int? tenureValue,
    String? tenureUnit,
    int paidEmis = 0,
    DateTime? lastPaymentDate,
  }) async {
    try {
      // Try RPC first, but only for standard monthly tenure
      // RPC ignores tenureValue/tenureUnit so it's wrong for days/weeks/years
      final bool useRpc = (tenureUnit == null || tenureUnit == 'months') && paidEmis <= 0;
      bool rpcWorked = false;
      if (useRpc) {
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
      }

      if (!rpcWorked) {
        // Manual generation fallback
        final List<Map<String, dynamic>> schedule = [];
        double balance = principal;
        final annualRate = interestRate / 100;
        final monthlyRate = annualRate / 12;

        // Determine number of installments based on tenure unit and frequency
        final freq = frequency ?? 'monthly';
        int numberOfInstallments;

        // If tenureUnit/tenureValue are provided, use them directly
        final effectiveTenureUnit = tenureUnit ?? 'months';
        final effectiveTenureValue = tenureValue ?? tenureMonths;

        switch (effectiveTenureUnit) {
          case 'days':
            numberOfInstallments = freq == 'daily'
                ? effectiveTenureValue
                : (effectiveTenureValue / (freq == 'weekly' ? 7 : 30)).round();
            break;
          case 'weeks':
            numberOfInstallments = freq == 'daily'
                ? effectiveTenureValue * 7
                : effectiveTenureValue;
            break;
          case 'years':
            numberOfInstallments = freq == 'daily'
                ? effectiveTenureValue * 365
                : freq == 'weekly'
                    ? (effectiveTenureValue * 52)
                    : effectiveTenureValue * 12;
            break;
          default: // months
            switch (freq) {
              case 'daily':
                numberOfInstallments = effectiveTenureValue * 30;
                break;
              case 'weekly':
                numberOfInstallments = (effectiveTenureValue * 30 / 7).round();
                break;
              case 'yearly':
                numberOfInstallments = (effectiveTenureValue / 12).round().clamp(1, 100);
                break;
              default:
                numberOfInstallments = effectiveTenureValue;
            }
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

          final isPaid = i <= paidEmis;

          DateTime? paidOn;
          if (isPaid && lastPaymentDate != null) {
            // Compute synthetic paid date based on offset from last payment
            final offset = paidEmis - i;
            switch (freq) {
              case 'daily':
                paidOn = lastPaymentDate.subtract(Duration(days: offset));
                break;
              case 'weekly':
                paidOn = lastPaymentDate.subtract(Duration(days: offset * 7));
                break;
              case 'yearly':
                paidOn = DateTime(lastPaymentDate.year - offset, lastPaymentDate.month, lastPaymentDate.day);
                break;
              default:
                paidOn = DateTime(lastPaymentDate.year, lastPaymentDate.month - offset, lastPaymentDate.day);
            }
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
            'status': isPaid ? 'paid' : 'pending',
            'is_paid': isPaid,
            if (isPaid) 'paid_date': paidOn?.toIso8601String().split('T').first,
            if (isPaid) 'paid_on': DateTime.now().toUtc().toIso8601String(),
            if (isPaid) 'payment_mode': 'cash',
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
        .update({
          'status': status,
          if (status == 'paid') 'paid_on': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', emiId);
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
          'transaction_id': '',
          'collection_id': item['id']?.toString() ?? '',
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
          .select('id, loan_id, amount, payment_mode, reference_number, description, created_at')
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
      // Strategy: if a transaction has the same amount, payment mode, and same day
      // as a collection, it's a duplicate (the collection triggers create both records)
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
            final colAmount = col['amount'] as double;
            final colMode = col['payment_mode']?.toString();

            // Same amount and same payment mode = likely duplicate
            if ((txAmount - colAmount).abs() < 0.01 && txMode == colMode) {
              // Check if same day (parse collection date from created_at or use collection_date)
              final colTimeStr = col['created_at']?.toString() ?? '';
              final colTime = DateTime.tryParse(colTimeStr);

              if (colTime != null) {
                final diff = txTime.difference(colTime).inMinutes.abs();
                if (diff <= 1440) { // Same day (24 hours)
                  isDuplicate = true;
                  break;
                }
              } else {
                // If we can't parse the collection time, match by amount alone
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

  // ─── Date Freeze: detect skipped EMIs and freeze them ───

  /// Detects EMIs that were skipped between the first and last paid EMI,
  /// marks them as 'frozen', and extends the loan tenure by appending new EMIs.
  /// Returns the number of newly frozen EMIs.
  Future<int> detectAndFreezeSkippedEMIs(String loanId) async {
    try {
      final emis = await getByLoanId(loanId);
      if (emis.isEmpty) return 0;

      final paidNumbers = emis
          .where((e) => e.status == EMIStatus.paid)
          .map((e) => e.emiNumber)
          .toList();
      if (paidNumbers.isEmpty) return 0;

      final minPaid = paidNumbers.reduce((a, b) => a < b ? a : b);
      final maxPaid = paidNumbers.reduce((a, b) => a > b ? a : b);

      // Only freeze EMIs strictly between min and max paid
      final toFreeze = emis.where((e) =>
          e.emiNumber > minPaid &&
          e.emiNumber < maxPaid &&
          e.status != EMIStatus.paid &&
          e.status != EMIStatus.frozen &&
          e.status != EMIStatus.waived);

      int count = 0;
      for (final emi in toFreeze) {
        await _client
            .from('emi_schedule')
            .update({'status': 'frozen'}).eq('id', emi.id);
        count++;
      }

      if (count > 0) {
        // Fetch existing frozen_count to accumulate (not overwrite)
        final loanRecord = await _client
            .from('loans')
            .select('frozen_count')
            .eq('id', loanId)
            .maybeSingle();
        final existingFrozenCount =
            (loanRecord?['frozen_count'] as num?)?.toInt() ?? 0;

        await _client.from('loans').update({
          'frozen_count': existingFrozenCount + count,
        }).eq('id', loanId);

        // Extend tenure by appending new EMIs
        await _extendLoanTenure(loanId, count);
      }

      return count;
    } catch (e) {
      debugPrint('detectAndFreezeSkippedEMIs error: $e');
      return 0;
    }
  }

  /// Appends [extraCount] new EMIs at the end of the schedule and updates
  /// the loan's tenure_months and total_emis.
  Future<void> _extendLoanTenure(String loanId, int extraCount) async {
    try {
      final loanResponse = await _client
          .from('loans')
          .select(
              'amount, interest_rate, tenure_months, emi_amount, frequency, '
              'first_emi_date, first_installment_date, disbursement_date, '
              'tenure_value, tenure_unit, interest_type, customer_id, member_id')
          .eq('id', loanId)
          .maybeSingle();
      if (loanResponse == null) return;

      final emis = await getByLoanId(loanId);
      if (emis.isEmpty) return;

      final lastEmi = emis.last;
      final freq = loanResponse['frequency'] as String? ?? 'monthly';
      final emiAmount = (loanResponse['emi_amount'] as num?)?.toDouble() ?? 0.0;
      final interestType = loanResponse['interest_type'] as String? ?? 'flat';
      final principal = (loanResponse['amount'] as num?)?.toDouble() ?? 0.0;
      final annualRate =
          ((loanResponse['interest_rate'] as num?)?.toDouble() ?? 0) / 100;
      final tenureMonths =
          (loanResponse['tenure_months'] as num?)?.toInt() ?? 12;
      final memberId = loanResponse['customer_id']?.toString() ??
          loanResponse['member_id']?.toString();

      // Calculate new EMI number and starting date
      int nextEmiNumber = lastEmi.emiNumber + 1;
      DateTime nextDueDate;

      switch (freq) {
        case 'daily':
          nextDueDate = lastEmi.dueDate.add(const Duration(days: 1));
          break;
        case 'weekly':
          nextDueDate = lastEmi.dueDate.add(const Duration(days: 7));
          break;
        case 'yearly':
          nextDueDate = DateTime(lastEmi.dueDate.year + 1, lastEmi.dueDate.month,
              lastEmi.dueDate.day);
          break;
        default: // monthly
          int targetMonth = lastEmi.dueDate.month + 1;
          int targetYear =
              lastEmi.dueDate.year + ((targetMonth - 1) ~/ 12);
          targetMonth = ((targetMonth - 1) % 12) + 1;
          int targetDay = lastEmi.dueDate.day;
          int daysInTarget = DateTime(targetYear, targetMonth + 1, 0).day;
          if (targetDay > daysInTarget) targetDay = daysInTarget;
          nextDueDate = DateTime(targetYear, targetMonth, targetDay);
      }

      double balance = lastEmi.balanceAfter;
      final List<Map<String, dynamic>> newSchedule = [];

      for (int i = 0; i < extraCount; i++) {
        final installmentNum = nextEmiNumber + i;
        final interest = interestType == 'reducing' || interestType == 'reducingBalance'
            ? balance * (annualRate / 12)
            : (principal * annualRate * (tenureMonths / 12)) /
                (emis.length + extraCount);
        final principalPaid = emiAmount - interest;
        balance -= principalPaid;
        if (balance < 0) balance = 0;

        DateTime dueDate;
        switch (freq) {
          case 'daily':
            dueDate = nextDueDate.add(Duration(days: i));
            break;
          case 'weekly':
            dueDate = nextDueDate.add(Duration(days: i * 7));
            break;
          case 'yearly':
            dueDate = DateTime(
                nextDueDate.year + i, nextDueDate.month, nextDueDate.day);
            break;
          default:
            int m = nextDueDate.month + i;
            int y = nextDueDate.year + ((m - 1) ~/ 12);
            m = ((m - 1) % 12) + 1;
            int d = nextDueDate.day;
            int dim = DateTime(y, m + 1, 0).day;
            if (d > dim) d = dim;
            dueDate = DateTime(y, m, d);
        }

        newSchedule.add({
          'loan_id': loanId,
          'org_id': _orgId,
          'member_id': memberId,
          'emi_number': installmentNum,
          'installment_number': installmentNum,
          'period': installmentNum,
          'due_date': dueDate.toIso8601String().split('T').first,
          'emi_amount': emiAmount,
          'emi': emiAmount,
          'principal': principalPaid,
          'interest': interest,
          'balance_after': balance,
          'status': 'pending',
          'is_paid': false,
        });
      }

      if (newSchedule.isNotEmpty) {
        await _client.from('emi_schedule').insert(newSchedule);
      }

      // Update loan tenure
      final currentTenure =
          (loanResponse['tenure_months'] as num?)?.toInt() ?? 12;
      await _client.from('loans').update({
        'tenure_months': currentTenure + extraCount,
      }).eq('id', loanId);
    } catch (e) {
      debugPrint('_extendLoanTenure error: $e');
    }
  }

  /// Manually freeze all currently-skipped EMIs for a loan.
  /// Returns the number of newly frozen EMIs.
  Future<int> manualFreezeSkippedEMIs(String loanId) async {
    return detectAndFreezeSkippedEMIs(loanId);
  }

  /// Freeze a single specific EMI by its ID.
  /// Marks it as 'frozen' and updates frozen_count.
  Future<bool> freezeSingleEMI(String emiId, String loanId) async {
    try {
      debugPrint('freezeSingleEMI: emiId=$emiId, loanId=$loanId');

      // Freeze this EMI
      await _client
          .from('emi_schedule')
          .update({'status': 'frozen'}).eq('id', emiId);

      debugPrint('freezeSingleEMI: EMI status updated');

      // Accumulate frozen_count
      final loanRecord = await _client
          .from('loans')
          .select('frozen_count')
          .eq('id', loanId)
          .maybeSingle();
      final existingFrozenCount =
          (loanRecord?['frozen_count'] as num?)?.toInt() ?? 0;

      debugPrint('freezeSingleEMI: existingFrozenCount=$existingFrozenCount');

      await _client.from('loans').update({
        'frozen_count': existingFrozenCount + 1,
      }).eq('id', loanId);

      debugPrint('freezeSingleEMI: frozen_count updated');

      // Extend tenure (non-blocking — freeze already succeeded)
      try {
        await _extendLoanTenure(loanId, 1);
      } catch (e) {
        debugPrint('freezeSingleEMI: tenure extension failed (non-fatal): $e');
      }

      debugPrint('freezeSingleEMI: done');
      return true;
    } catch (e) {
      debugPrint('freezeSingleEMI error: $e');
      return false;
    }
  }

  /// Unfreeze a single specific EMI by its ID.
  /// Reverts status to 'pending' and decrements frozen_count.
  Future<bool> unfreezeSingleEMI(String emiId, String loanId) async {
    try {
      debugPrint('unfreezeSingleEMI: emiId=$emiId, loanId=$loanId');

      // Unfreeze this EMI
      await _client
          .from('emi_schedule')
          .update({'status': 'pending'}).eq('id', emiId);

      // Decrement frozen_count
      final loanRecord = await _client
          .from('loans')
          .select('frozen_count')
          .eq('id', loanId)
          .maybeSingle();
      final currentCount =
          (loanRecord?['frozen_count'] as num?)?.toInt() ?? 0;

      await _client.from('loans').update({
        'frozen_count': (currentCount - 1).clamp(0, 999999),
      }).eq('id', loanId);

      return true;
    } catch (e) {
      debugPrint('unfreezeSingleEMI error: $e');
      return false;
    }
  }
}
