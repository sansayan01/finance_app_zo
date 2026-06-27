import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment Configuration
///
/// Loads values from .env files at runtime. Falls back to hardcoded defaults
/// if no .env file is found (e.g. in CI builds using --dart-define).
///
/// Usage:
///   flutter run                         → reads from .env
///   flutter run --dart-define=...       → overrides .env values
///   flutter build apk --dart-define=... → uses dart-define only
class EnvConfig {
  // Supabase Configuration
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ??
      const String.fromEnvironment('SUPABASE_URL');

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ??
      const String.fromEnvironment('SUPABASE_ANON_KEY');

  // App Configuration
  static String get appName =>
      dotenv.env['APP_NAME'] ??
      const String.fromEnvironment('APP_NAME', defaultValue: 'MicroFlow Pro');

  static String get appVersion =>
      dotenv.env['APP_VERSION'] ??
      const String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  // Mapbox Configuration
  static String get mapboxAccessToken =>
      dotenv.env['MAPBOX_ACCESS_TOKEN'] ??
      const String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

  // Telemetry (Sentry & PostHog)
  static String get sentryDsn =>
      dotenv.env['SENTRY_DSN'] ??
      const String.fromEnvironment('SENTRY_DSN');

  static String get posthogApiKey =>
      dotenv.env['POSTHOG_API_KEY'] ??
      const String.fromEnvironment('POSTHOG_API_KEY');

  static String get posthogHost =>
      dotenv.env['POSTHOG_HOST'] ??
      const String.fromEnvironment('POSTHOG_HOST',
          defaultValue: 'https://app.posthog.com');

  // Environment Detection
  static bool get isLocalEnvironment =>
      supabaseUrl.startsWith('http://') ||
      supabaseUrl.contains('127.0.0.1') ||
      supabaseUrl.contains('localhost');

  // Validate configuration
  static bool get isValidConfig =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      (supabaseUrl.startsWith('https://') || isLocalEnvironment);

  // Debug info (don't expose secrets in production)
  static String get debugInfo => '''
App: $appName v$appVersion
Supabase URL: $supabaseUrl
Config Valid: $isValidConfig
''';
}
