import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../repositories/customer_loans_repository.dart';
import '../models/customer_loan_model.dart';
import '../models/customer_emi_model.dart';
import 'customer_member_provider.dart';

final customerLoansRepositoryProvider =
    Provider<CustomerLoansRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return CustomerLoansRepository(client, orgId);
});

final customerLoansProvider =
    FutureProvider<List<CustomerLoanModel>>((ref) async {
  final memberId = ref.watch(currentCustomerIdSyncProvider);
  if (memberId == null) return [];
  final repository = ref.watch(customerLoansRepositoryProvider);
  return repository.getCustomerLoans(memberId);
});

final customerLoanDetailProvider =
    FutureProvider.family<CustomerLoanModel?, String>((ref, loanId) async {
  final repository = ref.watch(customerLoansRepositoryProvider);
  return repository.getLoanById(loanId);
});

final customerEmiScheduleProvider =
    FutureProvider.family<List<CustomerEmiModel>, String>((ref, loanId) async {
  final repository = ref.watch(customerLoansRepositoryProvider);
  return repository.getEmiSchedule(loanId);
});
