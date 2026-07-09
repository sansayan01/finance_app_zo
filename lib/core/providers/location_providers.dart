import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/location_service.dart';
import '../services/background_location_service.dart';
import '../services/location_cleanup_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final backgroundLocationServiceProvider = Provider<BackgroundLocationService>((ref) {
  final service = BackgroundLocationService();
  ref.onDispose(() => service.dispose());
  return service;
});

final locationCleanupServiceProvider = Provider<LocationCleanupService>((ref) {
  final client = Supabase.instance.client;
  return LocationCleanupService(client);
});
