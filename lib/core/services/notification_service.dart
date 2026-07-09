import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Lightweight local notification service for app update prompts.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Static getter for the plugin instance (used by PushNotificationService).
  static FlutterLocalNotificationsPlugin get plugin => _plugin;

  /// Initialize the notification plugin with an Android channel.
  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create high-importance Android notification channel for app updates
    const updateChannel = AndroidNotificationChannel(
      'app_updates',
      'App Updates',
      description: 'Notifications for app update downloads and installations',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(updateChannel);

    // Create channel for push notifications
    const pushChannel = AndroidNotificationChannel(
      'push_notifications',
      'Push Notifications',
      description: 'Notifications from MicroFlow Pro',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(pushChannel);

    _initialized = true;
    debugPrint('🔔 NotificationService initialized');
  }

  /// Show a notification that a new app version is ready to install.
  static Future<void> showUpdateReadyNotification(String version) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'app_updates',
      'App Updates',
      channelDescription: 'Notifications for app updates',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      ongoing: true, // Cannot be swiped away
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      9999, // Fixed ID so it replaces previous update notifications
      'Update Ready: v$version',
      'Tap to install the latest version',
      details,
    );
    debugPrint('🔔 Update notification shown for v$version');
  }

  /// Cancel any pending update notification.
  static Future<void> cancelUpdateNotification() async {
    await _plugin.cancel(9999);
  }

  /// Handle notification tap — open the downloaded APK.
  static void _onNotificationTapped(NotificationResponse response) async {
    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/microflow_update.apk';
      final file = File(filePath);
      if (await file.exists()) {
        await OpenFilex.open(
          filePath,
          type: 'application/vnd.android.package-archive',
        );
      }
    } catch (e) {
      debugPrint('❌ Notification tap error: $e');
    }
  }
}
