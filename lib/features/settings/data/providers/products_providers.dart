import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../services/loan_products_service.dart';
import '../services/savings_products_service.dart';

// ─── Loan Products ─────────────────────────────────────────────

final loanProductsServiceProvider = Provider<LoanProductsService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return LoanProductsService(client, orgId);
});

final loanProductsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(loanProductsServiceProvider);
  return service.getProducts();
});

// ─── Savings Products ──────────────────────────────────────────

final savingsProductsServiceProvider = Provider<SavingsProductsService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return SavingsProductsService(client, orgId);
});

final savingsProductsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(savingsProductsServiceProvider);
  return service.getProducts();
});
