import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_navigation_handler.dart';

/// Service for handling push notifications via Firebase Cloud Messaging.
///
/// Manages foreground message display, notification taps, and deep linking.
class PushNotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications;
  final NotificationNavigationHandler _navigationHandler;
  bool _initialized = false;

  PushNotificationService({
    FlutterLocalNotificationsPlugin? localNotifications,
    NotificationNavigationHandler? navigationHandler,
  })  : _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin(),
        _navigationHandler = navigationHandler ?? NotificationNavigationHandler();

  /// Initialize push notification handlers.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final messaging = FirebaseMessaging.instance;

      // Set foreground notification presentation options (iOS)
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Create notification channel for Android
      await _createNotificationChannel();

      // Initialize local notifications for foreground display
      await _initializeLocalNotifications();

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps (app opened via notification)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a notification (cold start)
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('🔔 App opened from notification (cold start)');
        _handleNotificationTap(initialMessage);
      }

      _initialized = true;
      debugPrint('✅ PushNotificationService initialized');
    } catch (e) {
      debugPrint('❌ PushNotificationService initialization error: $e');
    }
  }

  /// Create Android notification channel for push notifications.
  Future<void> _createNotificationChannel() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      const channel = AndroidNotificationChannel(
        'push_notifications',
        'Push Notifications',
        description: 'Notifications from MicroFlow Pro',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );

      await androidPlugin.createNotificationChannel(channel);

      // Also ensure the app_updates channel exists
      const updateChannel = AndroidNotificationChannel(
        'app_updates',
        'App Updates',
        description: 'Notifications for app updates',
        importance: Importance.high,
      );
      await androidPlugin.createNotificationChannel(updateChannel);
    }
  }

  /// Initialize local notifications plugin for foreground display.
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );
  }

  /// Handle messages received while app is in foreground.
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('🔔 Foreground message received: ${message.messageId}');

    final notification = message.notification;
    if (notification == null) return;

    // Show as local notification
    _showLocalNotification(
      id: message.hashCode,
      title: notification.title ?? 'MicroFlow Pro',
      body: notification.body ?? '',
      payload: jsonEncode(message.data),
    );
  }

  /// Show a local notification when app is in foreground.
  void _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) {
    const androidDetails = AndroidNotificationDetails(
      'push_notifications',
      'Push Notifications',
      channelDescription: 'Notifications from MicroFlow Pro',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);

    _localNotifications.show(id, title, body, details, payload: payload);
  }

  /// Handle notification tap.
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('🔔 Notification tapped: ${message.messageId}');
    debugPrint('🔔 Data: ${message.data}');

    _navigationHandler.handleNotificationData(message.data);
  }

  /// Handle local notification tap.
  void _onLocalNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Local notification tapped');

    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _navigationHandler.handleNotificationData(data);
      } catch (e) {
        debugPrint('❌ Error parsing notification payload: $e');
      }
    }
  }

  /// Get the current FCM token.
  Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Subscribe to a topic (for broadcast notifications).
  Future<void> subscribeToTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from a topic.
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from topic: $e');
    }
  }
}
