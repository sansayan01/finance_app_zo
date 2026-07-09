import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing FCM device tokens.
///
/// Handles token acquisition, storage in Supabase, refresh, and cleanup.
class FcmTokenService {
  final SupabaseClient _client;
  String? _currentToken;
  bool _initialized = false;

  FcmTokenService(this._client);

  /// Get the current FCM token (cached after first fetch).
  String? get currentToken => _currentToken;

  /// Initialize FCM and register the device token.
  ///
  /// Call this after user authentication. Returns the FCM token or null
  /// if Firebase is unavailable (web, simulator, etc.).
  Future<String?> initialize() async {
    if (_initialized) return _currentToken;

    try {
      // Request permission (Android 13+ requires runtime permission)
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('🔔 FCM permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        debugPrint('⚠️ FCM permission not granted');
        return null;
      }

      // Get FCM token
      final token = await messaging.getToken();
      _currentToken = token;

      if (token != null) {
        debugPrint('🔔 FCM token obtained: ${token.substring(0, 20)}...');
        await _storeToken(token);
      }

      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔔 FCM token refreshed');
        _currentToken = newToken;
        _storeToken(newToken);
      });

      _initialized = true;
      return token;
    } catch (e) {
      debugPrint('❌ FCM initialization error: $e');
      return null;
    }
  }

  /// Store FCM token in Supabase database.
  Future<void> _storeToken(String token) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ No authenticated user, cannot store FCM token');
        return;
      }

      // Get user's org_id from profiles table
      final profile = await _client
          .from('profiles')
          .select('org_id')
          .eq('user_id', user.id)
          .maybeSingle();

      final orgId = profile?['org_id'];
      if (orgId == null) {
        debugPrint('⚠️ No org_id found for user, cannot store FCM token');
        return;
      }

      // Get device info
      final packageInfo = await PackageInfo.fromPlatform();
      final deviceInfo = {
        'model': Platform.isAndroid ? 'Android' : 'iOS',
        'os_version': Platform.operatingSystemVersion,
        'app_version': packageInfo.version,
        'app_build': packageInfo.buildNumber,
      };

      // Upsert token (insert or update if already exists)
      await _client.from('device_tokens').upsert(
        {
          'user_id': user.id,
          'org_id': orgId,
          'fcm_token': token,
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'device_info': deviceInfo,
          'is_active': true,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,fcm_token',
      );

      debugPrint('✅ FCM token stored in database');
    } catch (e) {
      debugPrint('❌ Error storing FCM token: $e');
    }
  }

  /// Delete all FCM tokens for the current user (call on logout).
  Future<void> deleteTokens() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      await _client
          .from('device_tokens')
          .delete()
          .eq('user_id', user.id);

      _currentToken = null;
      debugPrint('✅ FCM tokens deleted for user');
    } catch (e) {
      debugPrint('❌ Error deleting FCM tokens: $e');
    }
  }

  /// Delete a specific token (e.g., when FCM returns invalid token error).
  Future<void> deleteToken(String token) async {
    try {
      await _client
          .from('device_tokens')
          .delete()
          .eq('fcm_token', token);

      if (_currentToken == token) {
        _currentToken = null;
      }
      debugPrint('✅ FCM token deleted');
    } catch (e) {
      debugPrint('❌ Error deleting FCM token: $e');
    }
  }

  /// Mark a token as inactive (for FCM error handling).
  Future<void> deactivateToken(String token) async {
    try {
      await _client.rpc('deactivate_device_token', params: {
        'token_fcm': token,
      });
      debugPrint('✅ FCM token deactivated');
    } catch (e) {
      debugPrint('❌ Error deactivating FCM token: $e');
    }
  }
}
