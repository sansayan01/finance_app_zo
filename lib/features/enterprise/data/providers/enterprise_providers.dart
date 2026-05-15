import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../models/audit_log_model.dart';
import '../repositories/enterprise_repository.dart';

final enterpriseRepositoryProvider = Provider<EnterpriseRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return EnterpriseRepository(client);
});

final auditLogsProvider = FutureProvider.family<List<AuditLogModel>, (String orgId, int limit)>((ref, params) async {
  final repository = ref.watch(enterpriseRepositoryProvider);
  return repository.getAuditLogs(params.$1, limit: params.$2);
});

final auditStatsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, orgId) async {
  final repository = ref.watch(enterpriseRepositoryProvider);
  return repository.getAuditStats(orgId);
});

