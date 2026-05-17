import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';

final allNotificationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final client = ref.watch(supabaseClientProvider);
    final response = await client
        .from('staff_notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(response);
  } catch (_) {
    return [];
  }
});
