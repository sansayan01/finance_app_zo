/// Environment Configuration
///
/// These values can be overridden via --dart-define flags:
/// flutter run --dart-define=SUPABASE_URL=https://... --dart-define=SUPABASE_ANON_KEY=...
/// The defaults below are safe - anon keys are public-facing.
class EnvConfig {
  // Supabase Configuration
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://tccwdpsnuudzfyxfoohk.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRjY3dkcHNudXVkemZ5eGZvb2hrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzNDQ1MTgsImV4cCI6MjA5MzkyMDUxOH0.I3B-A6YIrC2XlFlbf1eyTVqmcVJUOOcOUBYstpYE9_Y',
  );

  // App Configuration
  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'MicroFlow Pro',
  );

  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  // Telemetry (Sentry & PostHog)
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');
  static const String posthogApiKey = String.fromEnvironment('POSTHOG_API_KEY');
  static const String posthogHost = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://app.posthog.com',
  );

  // Validate configuration
  static bool get isValidConfig =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      supabaseUrl.startsWith('https://');

  // Debug info (don't expose secrets in production)
  static String get debugInfo => '''
App: $appName v$appVersion
Supabase URL: $supabaseUrl
Config Valid: $isValidConfig
''';
}
