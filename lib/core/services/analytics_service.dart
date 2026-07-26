import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around the PostHog Flutter SDK.
///
/// Centralizes event capture so feature code calls `analytics.track(...)`
/// instead of touching the SDK directly. Mirrors the project's existing
/// service-layer pattern (see `core/services/*.dart`).
///
/// Events are no-ops when PostHog is not initialized (e.g. missing key,
/// demo mode) so callers never need to guard their calls.
class AnalyticsService {
  AnalyticsService._();

  static bool _initialized = false;

  /// Whether PostHog has been set up. When false, all capture calls are no-ops.
  static bool get isInitialized => _initialized;

  /// Call once during app startup (in `main.dart`, mirroring Sentry).
  static Future<void> init({
    required String apiKey,
    required String host,
    bool debug = false,
  }) async {
    if (apiKey.isEmpty || !apiKey.startsWith('phc_')) {
      debugPrint('⚠️ PostHog key missing or invalid — analytics disabled');
      return;
    }
    try {
      await Posthog().setup(
        PostHogConfig(apiKey)
          ..host = host
          ..debug = debug && kDebugMode,
      );
      _initialized = true;
      debugPrint('✅ PostHog initialized');
    } catch (e) {
      debugPrint('⚠️ PostHog init failed: $e');
    }
  }

  /// Capture a custom event with optional properties.
  void track(String event, [Map<String, Object>? properties]) {
    if (!_initialized) return;
    try {
      Posthog().capture(
        eventName: event,
        properties: properties,
      );
    } catch (e) {
      debugPrint('⚠️ PostHog track failed: $e');
    }
  }

  /// Track a screen/page view.
  void screen(String screenName, [Map<String, Object>? properties]) {
    if (!_initialized) return;
    try {
      Posthog().screen(
        screenName: screenName,
        properties: properties,
      );
    } catch (e) {
      debugPrint('⚠️ PostHog screen failed: $e');
    }
  }

  /// Associate the current anonymous user with a real identity.
  /// Call on successful login/signup.
  void identify(String distinctId, [Map<String, Object>? userProperties]) {
    if (!_initialized) return;
    try {
      Posthog().identify(
        userId: distinctId,
        userProperties: userProperties,
      );
    } catch (e) {
      debugPrint('⚠️ PostHog identify failed: $e');
    }
  }

  /// Clear the current identity (e.g. on logout).
  void reset() {
    if (!_initialized) return;
    try {
      Posthog().reset();
    } catch (e) {
      debugPrint('⚠️ PostHog reset failed: $e');
    }
  }

  /// Flush queued events to the server immediately.
  void flush() {
    if (!_initialized) return;
    try {
      Posthog().flush();
    } catch (e) {
      debugPrint('⚠️ PostHog flush failed: $e');
    }
  }
}

/// Singleton accessor used by feature code and the Riverpod provider.
final AnalyticsService analytics = AnalyticsService._();
