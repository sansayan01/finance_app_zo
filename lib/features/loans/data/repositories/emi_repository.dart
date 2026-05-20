import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/enums.dart';
import '../models/emi_schedule_model.dart';

class EMIRepository {
  final SupabaseClient _client;
  final String _orgId;

  EMIRepository(this._client, this._orgId);

  Future<List<EMIScheduleModel>> getByLoanId(String loanId) async {
    try {
      final response = await _client
          .from('emi_schedule')
          .select()
          .eq('loan_id', loanId)
          .order('emi_number', ascending: true);

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
            .single();
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
          .single();

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
            .single();
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
          .single();

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
  }) async {
    try {
      // Try RPC first
      try {
        await _client
            .rpc('generate_emi_schedule', params: {'p_loan_id': loanId});
        return;
      } catch (e) {
        // Fallback to manual generation if RPC fails
        final List<Map<String, dynamic>> schedule = [];
        double balance = principal;
        final annualRate = interestRate / 100;
        final monthlyRate = annualRate / 12;

        for (int i = 1; i <= tenureMonths; i++) {
          double interest;
          double principalPaid;

          if (interestType == 'reducing') {
            interest = balance * monthlyRate;
            principalPaid = emiAmount - interest;
          } else {
            // Flat rate
            interest =
                (principal * annualRate * (tenureMonths / 12)) / tenureMonths;
            principalPaid = emiAmount - interest;
          }

          balance -= principalPaid;
          if (balance < 0) balance = 0;

          schedule.add({
            'loan_id': loanId,
            'org_id': _orgId,
            'emi_number': i,
            'due_date': startDate.add(Duration(days: i - 1)).toIso8601String(),
            'emi_amount': emiAmount,
            'principal': principalPaid,
            'interest': interest,
            'balance_after': balance,
            'status': 'pending',
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
      final response = await _client
          .from('transactions')
          .select()
          .eq('loan_id', loanId)
          .eq('type', TransactionType.emiPayment.name)
          .order('entered_at', ascending: false);

      return (response as List)
          .map((json) => json as Map<String, dynamic>)
          .toList();
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
