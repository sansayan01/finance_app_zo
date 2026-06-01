import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Derives the member_id for the current auth user by querying the members
/// table where profile_id = profiles.id (not auth.uid()).
///
/// Chain: auth.uid() -> profiles.user_id -> profiles.id -> members.profile_id
final currentCustomerIdProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  // If the user already has a memberId, use it directly
  if (user.memberId != null && user.memberId!.isNotEmpty) {
    return user.memberId;
  }

  final client = ref.watch(supabaseClientProvider);
  try {
    // Step 1: Get the profiles.id for this auth user
    // user.id is auth.users.id, but members.profile_id stores profiles.id
    final profile = await client
        .from('profiles')
        .select('id')
        .eq('user_id', user.id)
        .limit(1)
        .maybeSingle();

    if (profile == null) return null;

    final profileId = profile['id'] as String;

    // Step 2: Get the member record using profiles.id
    final data = await client
        .from('members')
        .select('id')
        .eq('profile_id', profileId)
        .limit(1)
        .maybeSingle();
    if (data != null) {
      return data['id'] as String;
    }
  } catch (_) {}

  // No member found for this user
  return null;
});

/// Returns the profiles.id for the current auth user.
///
/// Chain: auth.uid() -> profiles.user_id -> profiles.id
/// Needed for tables with FK to profiles.id (e.g. customer_ticket_messages.sender_id).
final currentProfileIdProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final client = ref.watch(supabaseClientProvider);
  try {
    final profile = await client
        .from('profiles')
        .select('id')
        .eq('user_id', user.id)
        .limit(1)
        .maybeSingle();

    if (profile != null) {
      return profile['id'] as String;
    }
  } catch (_) {}

  return null;
});

/// Synchronous version that returns null while loading.
final currentProfileIdSyncProvider = Provider<String?>((ref) {
  final asyncValue = ref.watch(currentProfileIdProvider);
  return asyncValue.valueOrNull;
});

/// Synchronous version that returns null while loading.
/// Use this in providers that need to chain.
final currentCustomerIdSyncProvider = Provider<String?>((ref) {
  final asyncValue = ref.watch(currentCustomerIdProvider);
  return asyncValue.valueOrNull;
});
