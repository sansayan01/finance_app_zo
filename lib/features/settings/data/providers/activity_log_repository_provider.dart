import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/activity_log_repository.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';

final Provider<ActivityLogRepository> activityLogRepositoryProvider =
    Provider<ActivityLogRepository>((ref) {
  return ActivityLogRepository(ref.watch(supabaseClientProvider));
});

