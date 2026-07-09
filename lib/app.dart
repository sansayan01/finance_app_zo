import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/providers/branding_provider.dart';
import 'core/services/auto_update_service.dart';
import 'core/services/push_notification_provider.dart';
import 'features/settings/data/providers/brand_provider.dart';
import 'router/app_router.dart';
import 'core/widgets/update_wrapper.dart';

class MicroFlowApp extends ConsumerStatefulWidget {
  const MicroFlowApp({super.key});

  @override
  ConsumerState<MicroFlowApp> createState() => _MicroFlowAppState();
}

class _MicroFlowAppState extends ConsumerState<MicroFlowApp> {
  @override
  void initState() {
    super.initState();
    // Load branding on startup
    Future.microtask(() {
      ref.read(brandingProvider.notifier).loadBranding();

      // Initialize push notification handlers after router is available
      _initializePushNotifications();
    });
  }

  void _initializePushNotifications() {
    // Only wire the router into the navigation handler early so taps/cold-starts
    // have a destination. Listeners + foreground display are set up once, after
    // login, in auth_provider._registerFcmToken() (pushService.initialize() is
    // guarded so it runs exactly once).
    try {
      final router = ref.read(routerProvider);
      final navigationHandler = ref.read(notificationNavigationHandlerProvider);
      navigationHandler.setRouter(router);
    } catch (e) {
      debugPrint('⚠️ Push notification router wiring error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);

    final brand = ref.watch(brandProvider);
    final brandingAsync = ref.watch(brandingProvider);
    final appName = brandingAsync.valueOrNull?.displayName ?? brand.name;

    // Apply system UI overlay style safely
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              themeMode == ThemeMode.dark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: themeMode == ThemeMode.dark
              ? const Color(0xFF1A1F2E)
              : Colors.white,
          systemNavigationBarIconBrightness:
              themeMode == ThemeMode.dark ? Brightness.light : Brightness.dark,
        ),
      );
    });

    return MaterialApp.router(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        if (child == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // Start auto-update service on first build (downloads APK in background)
        ref.read(autoUpdateServiceProvider);
        return UpdateWrapper(child: child);
      },
    );
  }
}
