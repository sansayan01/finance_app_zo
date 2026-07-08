import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../repositories/payment_gateway_repository.dart';

final paymentGatewayRepositoryProvider = Provider<PaymentGatewayRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return PaymentGatewayRepository(client, orgId);
});

final pendingGatewayPaymentsProvider =
    FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.watch(paymentGatewayRepositoryProvider);
  return repo.getPendingOrders();
});
