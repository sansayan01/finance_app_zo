import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/emi_schedule_model.dart';

class EMIRepository {
  final SupabaseClient _client;

  EMIRepository(this._client);

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
      // 1. Update EMI Schedule
      await _client.from('emi_schedule').update({
        'status': 'paid',
        'paid_on': DateTime.now().toIso8601String(),
        'payment_mode': paymentMode,
      }).eq('id', emiId);

      // 2. Create Transaction Record
      await _client.from('transactions').insert({
        'loan_id': loanId,
        'type': 'emi_payment',
        'amount': amount,
        'payment_mode': paymentMode,
        'notes': notes,
        'agent_id': agentId,
        'entered_at': DateTime.now().toIso8601String(),
      });

      // Note: Supabase functions/triggers would normally handle
      // updating the loan's outstanding balance and total collected.
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
            'emi_number': i,
            'due_date': DateTime(
                    startDate.year, startDate.month + (i - 1), startDate.day)
                .toIso8601String(),
            'emi_amount': emiAmount,
            'principal': principalPaid,
            'interest': interest,
            'balance_after': balance,
            'status': 'upcoming',
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
           .inFilter('status', ['upcoming', 'overdue', 'pendingPayment']);

      return (response as List)
          .map((json) => EMIScheduleModel.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }
}
