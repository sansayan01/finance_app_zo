import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  try {
    return Supabase.instance.client;
  } catch (e) {
    throw Exception(
        'Supabase not initialized. Please configure your Supabase credentials.');
  }
});

final authStateProvider = StreamProvider<User?>((ref) {
  try {
    return Supabase.instance.client.auth.onAuthStateChange
        .map((event) => event.session?.user);
  } catch (e) {
    return const Stream.empty();
  }
});

final supabaseUserProvider = Provider<User?>((ref) {
  try {
    // Watch the stream for real-time updates (sign-out, token refresh)
    final authState = ref.watch(authStateProvider);
    final streamUser = authState.whenOrNull(data: (user) => user);
    // Fallback: read currentUser synchronously (available immediately on app start)
    return streamUser ?? Supabase.instance.client.auth.currentUser;
  } catch (e) {
    return null;
  }
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  try {
    final user = ref.watch(supabaseUserProvider);
    return user != null;
  } catch (e) {
    return false;
  }
});
