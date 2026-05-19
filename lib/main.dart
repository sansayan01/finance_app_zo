import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/providers/storage_providers.dart';
import 'core/config/env_config.dart';
import 'features/onboarding/data/tour_service.dart';
import 'features/onboarding/data/tour_provider.dart';
import 'app.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('🚀 App starting...');

    // 1. Set orientations
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );

    // 2. Initialize Supabase
    try {
      debugPrint('🔗 Connecting to Supabase: ${EnvConfig.supabaseUrl}');
      await Supabase.initialize(
        url: EnvConfig.supabaseUrl,
        anonKey: EnvConfig.supabaseAnonKey,
        debug: true,
      );
      debugPrint('✅ Supabase initialized');
    } catch (e) {
      debugPrint('❌ Supabase initialization failed: $e');
    }

    // 3. Initialize SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    debugPrint('✅ SharedPreferences initialized');

    // 4. Setup Global Error Handler for Production
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light(),
        home: Scaffold(
          body: Container(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.red, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Something went wrong',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  details.exception.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => main(),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    };

    // 5. Initialize Sentry & Run App
    if (EnvConfig.sentryDsn.isNotEmpty) {
      debugPrint('🛰️ Initializing Sentry...');
      await SentryFlutter.init(
        (options) {
          options.dsn = EnvConfig.sentryDsn;
          options.tracesSampleRate = 1.0;
          options.attachScreenshot = true;
        },
        appRunner: () => _runMicroFlowApp(prefs),
      );
    } else {
      debugPrint('⚠️ Sentry DSN missing, running app without Sentry');
      _runMicroFlowApp(prefs);
    }
  } catch (e, stackTrace) {
    debugPrint('💥 FATAL ERROR: $e');
    debugPrint(stackTrace.toString());

    // Last resort fallback
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text('Fatal Initialization Error: $e'),
          ),
        ),
      ),
    ));
  }
}

void _runMicroFlowApp(SharedPreferences prefs) {
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        tourServiceProvider.overrideWithValue(TourService(prefs)),
      ],
      child: const MicroFlowApp(),
    ),
  );
}
