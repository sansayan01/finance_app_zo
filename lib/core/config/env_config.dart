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
  // Priority: --dart-define (CI/CD) > .env file (local dev) > hardcoded production
  // Hardcoded values ensure the app always connects to production as a safety net.
  static const _prodUrl = 'https://tccwdpsnuudzfyxfoohk.supabase.co';
  static const _prodAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
      'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRjY3dkcHNudXVkemZ5eGZvb2hrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzNDQ1MTgsImV4cCI6MjA5MzkyMDUxOH0.'
      'I3B-A6YIrC2XlFlbf1eyTVqmcVJUOOcOUBYstpYE9_Y';

  static String get supabaseUrl {
    const dartDefine = String.fromEnvironment('SUPABASE_URL');
    if (dartDefine.isNotEmpty) return dartDefine;
    final envFile = dotenv.env['SUPABASE_URL'];
    if (envFile != null && envFile.isNotEmpty) return envFile;
    return _prodUrl;
  }

  static String get supabaseAnonKey {
    const dartDefine = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (dartDefine.isNotEmpty) return dartDefine;
    final envFile = dotenv.env['SUPABASE_ANON_KEY'];
    if (envFile != null && envFile.isNotEmpty) return envFile;
    return _prodAnonKey;
  }

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

  // GitHub Configuration (for in-app update checks)
  static String get githubToken =>
      dotenv.env['GITHUB_TOKEN'] ??
      const String.fromEnvironment('GITHUB_TOKEN', defaultValue: '');

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
GitHub Token: ${githubToken.isNotEmpty ? 'configured' : 'not set'}
Config Valid: $isValidConfig
''';
}
