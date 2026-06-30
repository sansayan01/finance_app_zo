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

class _SplashPageState extends ConsumerState<SplashPage>
    with TickerProviderStateMixin {
  String _iconPreset = 'default';
  String? _logoUrl;
  bool _navigated = false;

  late AnimationController _slideController;
  late AnimationController _zoomController;
  late AnimationController _fadeController;

  // Slide: 0.0 = off-screen top, 1.0 = centered
  late Animation<double> _slideAnimation;
  // Zoom: 1.0 = normal, large enough to cover screen
  late Animation<double> _zoomAnimation;
  // Fade out
  late Animation<double> _fadeAnimation;

  @override
  void dispose() {
    _navigated = true;
    _slideController.dispose();
    _zoomController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // Phase 1: Slide in from top (600ms)
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    // Phase 2: Zoom + Fade together (700ms)
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _zoomAnimation = Tween<double>(begin: 1.0, end: 20.0).animate(
      CurvedAnimation(parent: _zoomController, curve: Curves.easeInOut),
    );

    // Fade — faster than zoom so logo dissolves quickly
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _runAnimation();
  }

  Future<void> _runAnimation() async {
    await _loadCachedBranding();
    if (!mounted) return;
    setState(() {});

    // Load fresh branding + start auth resolution in parallel
    await Future.wait([
      _loadBrandingFromSession(),
      _waitForAuthResolution(),
    ]);
    if (!mounted) return;
    setState(() {});

    // Short pause so logo is visible before animation starts
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    // Phase 1: Slide logo in from top
    await _slideController.forward();
    if (!mounted) return;

    // Hold at center — logo is the star, give users time to see it
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    // Phase 2: Zoom + Fade together
    _zoomController.forward();
    await _fadeController.forward();
    if (!mounted) return;

    // Navigate immediately — auth is already resolved
    await _navigate();
  }

  Future<void> _navigate() async {
    if (!mounted || _navigated) return;

    final authStatus = ref.read(authProvider).status;
    _navigated = true;

    if (authStatus == AuthStatus.authenticated) {
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
    final startTime = DateTime.now();
    while (DateTime.now().difference(startTime) < timeout) {
      if (!mounted) return;
      final status = ref.read(authProvider).status;
      if (status != AuthStatus.initial && status != AuthStatus.loading) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
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
    final bgColor = isDark ? const Color(0xFF0F1219) : Colors.white;

    final logo = Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B4CDB).withValues(alpha: 0.25),
            blurRadius: 32,
            spreadRadius: 4,
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
                errorWidget: (_, __, ___) => _buildPresetIcon(assetPath),
              )
            : _buildPresetIcon(assetPath),
      ),
    );

    return Scaffold(
      backgroundColor: bgColor,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _slideController,
          _zoomController,
          _fadeController,
        ]),
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.translate(
              offset: Offset(
                0,
                MediaQuery.of(context).size.height * _slideAnimation.value,
              ),
              child: Transform.scale(
                scale: _zoomAnimation.value,
                child: Center(child: child),
              ),
            ),
          );
        },
        child: logo,
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
