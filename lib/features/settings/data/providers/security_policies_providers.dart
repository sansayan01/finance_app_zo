import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../services/security_policies_service.dart';

final securityPoliciesServiceProvider = Provider<SecurityPoliciesService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return SecurityPoliciesService(client, orgId);
});

final securityPoliciesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(securityPoliciesServiceProvider);
  return service.getSecurityPolicies();
});
