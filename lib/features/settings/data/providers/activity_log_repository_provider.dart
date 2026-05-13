import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/activity_log_repository.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';

final Provider<ActivityLogRepository> activityLogRepositoryProvider =
    Provider<ActivityLogRepository>((ref) {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) {
    return ActivityLogRepository(ref.watch(supabaseClientProvider));
  }
  return ActivityLogRepository(ref.watch(supabaseClientProvider), orgId);
});
