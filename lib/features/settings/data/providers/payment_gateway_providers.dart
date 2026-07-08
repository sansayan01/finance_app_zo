import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../services/payment_gateway_service.dart';

final paymentGatewayServiceProvider = Provider<PaymentGatewayService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return PaymentGatewayService(client, orgId);
});

final paymentGatewayConfigProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final svc = ref.watch(paymentGatewayServiceProvider);
  return svc.getGatewayConfig();
});
