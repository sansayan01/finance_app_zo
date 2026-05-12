import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/settings/data/providers/brand_provider.dart';
import 'router/app_router.dart';

class MicroFlowApp extends ConsumerWidget {
  const MicroFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);

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

    final brand = ref.watch(brandProvider);

    return MaterialApp.router(
      title: brand.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
