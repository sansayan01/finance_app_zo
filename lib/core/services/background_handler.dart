import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Background message handler for Firebase Cloud Messaging.
///
/// This must be a top-level function (not a method in a class).
/// It runs when a notification is received while the app is in the background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Background message received: ${message.messageId}');
  debugPrint('🔔 Title: ${message.notification?.title}');
  debugPrint('🔔 Body: ${message.notification?.body}');
  debugPrint('🔔 Data: ${message.data}');

  // Note: You cannot show UI or access providers here.
  // The notification is already displayed by the OS.
  // Use this for any background data processing if needed.
}
