import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

import '../../../../core/providers/branding_provider.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/widgets/powered_by_badge.dart';

class LoginPage extends ConsumerStatefulWidget {
  final VoidCallback onSignUpTap;
  const LoginPage({super.key, required this.onSignUpTap});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isHovering = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      HapticService.error();
      return;
    }

    HapticService.medium();

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final emailLower = email.toLowerCase();
    var success = await ref.read(authProvider.notifier).signIn(
          email: emailLower,
          password: password,
        );

    if (success && mounted) {
      HapticService.success();
      context.go('/');
    } else if (mounted) {
      HapticService.error();
      final error = ref.read(authProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error ?? 'Authentication failed'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final brandingAsync = ref.watch(brandingProvider);
    final brandName = brandingAsync.maybeWhen(
          data: (config) => config.displayName,
          orElse: () => null,
        ) ??
        'MicroFlow Pro';

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0B) : const Color(0xFFFBFBFE),
      body: Stack(
        children: [
          // Refined Aurora Background
          const Positioned.fill(child: _AuroraBackground()),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Sophisticated Logo Entry
                      _buildLogo(primary, ref),

                      const SizedBox(height: 32),

                      // Modern Header
                      Text(
                        brandName,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 32,
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 800.ms)
                          .slideY(begin: 0.2, end: 0),

                      const SizedBox(height: 8),
                      Text(
                        'Authorized administrative access only.',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ).animate().fadeIn(delay: 200.ms, duration: 800.ms),

                      const SizedBox(height: 56),

                      // Neo-Glass Login Card
                      _buildNeoGlassCard(isDark, primary, isLoading),

                      const SizedBox(height: 40),

                      // Footer Note
                      Text(
                        'Protected by Enterprise Security',
                        style: TextStyle(
                          color: isDark ? Colors.white24 : Colors.black26,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ).animate().fadeIn(delay: 1.seconds),

                      const SizedBox(height: 16),

                      // Powered by badge
                      PoweredByBadge(
                        compact: true,
                        textColor: isDark ? Colors.white24 : Colors.black26,
                      ).animate().fadeIn(delay: 1200.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(Color primary, WidgetRef ref) {
    final brandingAsync = ref.watch(brandingProvider);
    final logoUrl = brandingAsync.maybeWhen(
      data: (config) => config.logoUrl,
      orElse: () => null,
    );

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: logoUrl != null ? Colors.transparent : primary,
        borderRadius: BorderRadius.circular(20),
        image: logoUrl != null
            ? DecorationImage(image: NetworkImage(logoUrl), fit: BoxFit.contain)
            : null,
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: logoUrl == null
          ? const Icon(Icons.account_balance_rounded,
              color: Colors.white, size: 32)
          : null,
    ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack);
  }

  Widget _buildNeoGlassCard(bool isDark, Color primary, bool isLoading) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildField(
                  controller: _emailController,
                  label: 'IDENTITY',
                  hint: 'Email Address',
                  icon: Icons.alternate_email_rounded,
                  isDark: isDark,
                  primary: primary,
                ),
                const SizedBox(height: 24),
                _buildField(
                  controller: _passwordController,
                  label: 'CREDENTIALS',
                  hint: 'Password',
                  icon: Icons.lock_outline_rounded,
                  isDark: isDark,
                  primary: primary,
                  obscureText: _obscurePassword,
                  suffix: IconButton(
                    icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 18),
                    onPressed: () {
                      HapticService.selection();
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const SizedBox(height: 32),
                _buildActionButton(isLoading, primary),
                const SizedBox(height: 20),
                _buildSignUpLink(primary),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    required Color primary,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.1)),
            prefixIcon: Icon(icon,
                size: 20,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.3)),
            suffixIcon: suffix,
            filled: true,
            fillColor: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.03),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  BorderSide(color: primary.withValues(alpha: 0.5), width: 1),
            ),
          ),
          validator: (v) => v!.isEmpty ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildActionButton(bool isLoading, Color primary) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedScale(
        scale: _isHovering ? 1.02 : 1.0,
        duration: 200.ms,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primary, primary.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () {
              HapticService.light();
              if (!isLoading) _handleLogin();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Access Dashboard',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5)),
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpLink(Color primary) {
    return GestureDetector(
      onTap: () {
        HapticService.selection();
        widget.onSignUpTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppColors.success.withValues(alpha: 0.06),
            AppColors.primary.withValues(alpha: 0.03),
          ]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.free_breakfast_rounded,
                  color: AppColors.success, size: 16),
            ),
            const SizedBox(width: 10),
            Text('New here? ',
                style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            Text('Start 14-Day Free Trial',
                style: TextStyle(
                    color: primary, fontSize: 13, fontWeight: FontWeight.w700)),
            const Icon(Icons.arrow_forward_rounded,
                size: 16, color: AppColors.success),
          ],
        ),
      ),
    );
  }
}

class _AuroraBackground extends StatefulWidget {
  const _AuroraBackground();

  @override
  State<_AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<_AuroraBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 20))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c1 = AppColors.primary.withValues(alpha: isDark ? 0.1 : 0.05);
    final c2 = AppColors.accent.withValues(alpha: isDark ? 0.08 : 0.04);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _AuroraPainter(_controller.value, [c1, c2]),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;

  _AuroraPainter(this.progress, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);
    final t = progress * 2 * math.pi;

    canvas.drawCircle(
      Offset(size.width * 0.3 + 50 * math.sin(t),
          size.height * 0.2 + 30 * math.cos(t)),
      size.width * 0.6,
      paint..color = colors[0],
    );

    canvas.drawCircle(
      Offset(size.width * 0.7 + 40 * math.cos(t * 1.2),
          size.height * 0.8 + 60 * math.sin(t * 0.8)),
      size.width * 0.5,
      paint..color = colors[1],
    );
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
