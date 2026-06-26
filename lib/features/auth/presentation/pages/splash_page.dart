import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_provider.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  String _iconPreset = 'default';
  String? _logoUrl;
  bool _ready = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _loadAndNavigate();
  }

  @override
  void dispose() {
    _navigated = true;
    super.dispose();
  }

  Future<void> _loadAndNavigate() async {
    // 1. Load cached branding from SharedPreferences (instant)
    await _loadCachedBranding();
    setState(() => _ready = true);

    // 2. Try to load branding from existing auth session (user may already be logged in)
    await _loadBrandingFromSession();

    // 3. Wait a moment to show the splash
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted || _navigated) return;

    // 4. Wait for auth state to resolve — prevents flashing the login screen
    await _waitForAuthResolution();
    if (!mounted || _navigated) return;

    // 5. Navigate based on resolved auth state
    final authStatus = ref.read(authProvider).status;
    _navigated = true;

    if (authStatus == AuthStatus.authenticated) {
      // Already logged in — router will redirect to the correct portal by role
      context.go('/');
    } else {
      context.go('/auth');
    }
  }

  /// Waits for auth state to move past [AuthStatus.initial] / loading.
  /// Times out after [timeout] to avoid blocking the splash forever.
  Future<void> _waitForAuthResolution({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final status = ref.read(authProvider).status;
    if (status != AuthStatus.initial && status != AuthStatus.loading) return;

    final completer = Completer<void>();

    ref.listen(authProvider, (prev, next) {
      if (next.status != AuthStatus.initial &&
          next.status != AuthStatus.loading &&
          !completer.isCompleted) {
        completer.complete();
      }
    });

    // Timeout fallback — don't block the splash screen forever
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete();
    });

    await completer.future;
    timer.cancel();
  }

  /// If user has an existing Supabase session, fetch org branding directly
  Future<void> _loadBrandingFromSession() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      // Get user's org from profiles
      final profile = await client
          .from('profiles')
          .select('org_id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (profile == null || profile['org_id'] == null) return;
      final orgId = profile['org_id'] as String;

      // Fetch org branding
      final org = await client
          .from('organizations')
          .select('name, display_name, icon_preset, logo_url')
          .eq('id', orgId)
          .maybeSingle();

      if (org == null || !mounted) return;

      final preset = (org['icon_preset'] as String?) ?? 'default';
      final logo = org['logo_url'] as String?;

      setState(() {
        _iconPreset = preset;
        _logoUrl = logo;
      });

      // Cache for next launch
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('splash_icon_preset', preset);
      await prefs.setString('splash_logo_url', logo ?? '');
    } catch (e) {
      // Silently fail — will show cached or default
      debugPrint('[Splash] Session branding load failed: $e');
    }
  }

  Future<void> _loadCachedBranding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final preset = prefs.getString('splash_icon_preset');
      final logo = prefs.getString('splash_logo_url');
      if (preset != null) _iconPreset = preset;
      if (logo != null && logo.isNotEmpty) _logoUrl = logo;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final assetPath = 'assets/icons/preset_$_iconPreset.png';
    final hasLogo = _logoUrl != null && _logoUrl!.isNotEmpty;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1219) : Colors.white,
      body: Center(
        child: AnimatedOpacity(
          opacity: _ready ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Icon - Logo only
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: hasLogo
                      ? CachedNetworkImage(
                          imageUrl: _logoUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 200,
                          memCacheHeight: 200,
                          errorWidget: (_, __, ___) =>
                              _buildPresetIcon(assetPath),
                        )
                      : _buildPresetIcon(assetPath),
                ),
              ),
              const SizedBox(height: 40),

              // Loading indicator
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark
                        ? Colors.white.withValues(alpha: 0.8)
                        : const Color(0xFF1A5CFF),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetIcon(String assetPath) {
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      width: 100,
      height: 100,
      errorBuilder: (_, __, ___) => const Icon(
        Icons.account_balance_rounded,
        size: 50,
        color: Color(0xFF1A5CFF),
      ),
    );
  }
}
