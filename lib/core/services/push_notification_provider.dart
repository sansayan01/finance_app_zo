import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'fcm_token_service.dart';
import 'push_notification_service.dart';
import 'notification_navigation_handler.dart';

/// Provider for the FCM token service.
final fcmTokenServiceProvider = Provider<FcmTokenService>((ref) {
  final client = Supabase.instance.client;
  return FcmTokenService(client);
});

/// Provider for the notification navigation handler.
final notificationNavigationHandlerProvider =
    Provider<NotificationNavigationHandler>((ref) {
  return NotificationNavigationHandler();
});

/// Provider for the push notification service.
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final navigationHandler = ref.watch(notificationNavigationHandlerProvider);
  return PushNotificationService(
    navigationHandler: navigationHandler,
  );
});
