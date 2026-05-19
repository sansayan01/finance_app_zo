import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/branding_provider.dart';
import '../../../settings/data/providers/brand_provider.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Curved Animations
  late Animation<double> _bgGlowOpacity;
  late Animation<double> _logoDrawProgress;
  late Animation<double> _logoScale;
  late Animation<double> _logoPulse;
  late Animation<double> _textOpacity;
  late Animation<double> _textTranslate;
  late Animation<double> _textLetterSpacing;
  late Animation<double> _loaderOpacity;

  @override
  void initState() {
    super.initState();

    // Set up 2.2s animation duration
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // 1. Ambient Background Glow
    _bgGlowOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // 2. Custom logo path drawing (0% to 100%)
    _logoDrawProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.6, curve: Curves.easeInOutCubic),
      ),
    );

    // 3. Logo initial reveal scale
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.6, curve: Curves.easeOutBack),
      ),
    );

    // 4. Logo pulse bounce near completion
    _logoPulse = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.05), weight: 50),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.05, end: 1.0), weight: 50),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 0.9, curve: Curves.easeInOut),
      ),
    );

    // 5. Typography Fade-In
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.75, curve: Curves.easeIn),
      ),
    );

    // 6. Typography slide up
    _textTranslate = Tween<double>(begin: 15.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.75, curve: Curves.easeOutQuad),
      ),
    );

    // 7. Typography kerning expand
    _textLetterSpacing = Tween<double>(begin: 2.0, end: 6.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    // 8. Progress loader fading-in
    _loaderOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 0.85, curve: Curves.easeIn),
      ),
    );

    // Run animations
    _controller.forward();

    // Trigger initialization check after the current frame builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeApp();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    final startTime = DateTime.now();

    try {
      // 1. Preload branding data
      await ref.read(brandingProvider.notifier).loadBranding();
    } catch (e) {
      debugPrint('⚠️ Splash error preloading branding: $e');
    }

    // 2. Ensure animation runs for at least 2.2 seconds for visual luxury
    final elapsed = DateTime.now().difference(startTime);
    const minDuration = Duration(milliseconds: 2200);
    if (elapsed < minDuration) {
      await Future.delayed(minDuration - elapsed);
    }

    // 3. Transition out of splash
    if (mounted) {
      _transitionOut();
    }
  }

  void _transitionOut() {
    // Smooth transition into the main application redirect logic
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Fallback/branding settings
    final brand = ref.watch(brandProvider);
    final brandingAsync = ref.watch(brandingProvider);
    final appName = brandingAsync.valueOrNull?.displayName ?? brand.name;
    final primaryColor = brandingAsync.valueOrNull?.primaryColor != null
        ? Color(BrandingConfig.parseHexColor(
                brandingAsync.valueOrNull!.primaryColor) ??
            AppColors.primary.toARGB32())
        : (isDarkMode ? AppColors.primaryDark : AppColors.primary);

    return Scaffold(
      backgroundColor:
          isDarkMode ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Stack(
        children: [
          // ─── BACKGROUND LAYER: Aurora Gradient Orbs ───
          AnimatedBuilder(
            animation: _bgGlowOpacity,
            builder: (context, child) {
              return Opacity(
                opacity: _bgGlowOpacity.value * (isDarkMode ? 0.25 : 0.08),
                child: child,
              );
            },
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.8, -0.7),
                  radius: 1.6,
                  colors: [
                    Color(0xFF818CF8), // Soft indigo
                    Color(0xFFA855F7), // Soft purple
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          // Secondary ambient glow in bottom right
          AnimatedBuilder(
            animation: _bgGlowOpacity,
            builder: (context, child) {
              return Opacity(
                opacity: _bgGlowOpacity.value * (isDarkMode ? 0.15 : 0.05),
                child: child,
              );
            },
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.8, 0.8),
                  radius: 1.2,
                  colors: [
                    Color(0xFF22D3EE), // Cyan
                    Colors.transparent,
                  ],
                  stops: [0.0, 1.0],
                ),
              ),
            ),
          ),

          // Glassmorphic overlay filter for smooth blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40.0, sigmaY: 40.0),
              child: Container(color: Colors.transparent),
            ),
          ),

          // ─── FOREGROUND CONTENT ───
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),

                // 🚀 Part 1: Animated Logo/Emblem
                Center(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final scale = _logoScale.value * _logoPulse.value;
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(
                                alpha: isDarkMode ? 0.12 : 0.05),
                            blurRadius: 40,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: AnimatedBuilder(
                        animation: _logoDrawProgress,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: SplashGrowthPainter(
                              progress: _logoDrawProgress.value,
                              color: primaryColor,
                              accentColor: isDarkMode
                                  ? AppColors.accentDark
                                  : AppColors.accent,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // 🚀 Part 2: Branding Typography
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _textOpacity.value,
                      child: Transform.translate(
                        offset: Offset(0.0, _textTranslate.value),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        appName.toUpperCase(),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDarkMode
                              ? Colors.white
                              : AppColors.textPrimaryLight,
                          letterSpacing: _textLetterSpacing.value,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "MICRO-FINANCE PLATFORM",
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          letterSpacing: 3.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // 🚀 Part 3: Shimmer Linear Progress Track
                AnimatedBuilder(
                  animation: _loaderOpacity,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _loaderOpacity.value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 100,
                    height: 3,
                    decoration: BoxDecoration(
                      color:
                          isDarkMode ? AppColors.fillDark : AppColors.fillLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: const LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.indigoAccent),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // MFI regulatory or credit label
                AnimatedBuilder(
                  animation: _loaderOpacity,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _loaderOpacity.value * 0.7,
                      child: child,
                    );
                  },
                  child: Text(
                    "SECURE • OFFLINE FIRST • MFI STANDARD",
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),

                const Spacer(flex: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 🎨 Splash Vector Growth Painter
/// Renders a premium glowing infinity loop that sweeps upwards representing positive growth.
class SplashGrowthPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color accentColor;

  SplashGrowthPainter({
    required this.progress,
    required this.color,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Glowing Neon Shadow Paint
    final shadowPaint1 = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);

    final shadowPaint2 = Paint()
      ..color = accentColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);

    // Primary Sharp Core Paint
    final paint1 = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    final paint2 = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    // ─── Loop 1: Left loop (Deep Purple-Blue) ───
    final leftPath = Path()
      ..moveTo(width * 0.5, height * 0.5)
      ..cubicTo(
        width * 0.35,
        height * 0.28,
        width * 0.15,
        height * 0.36,
        width * 0.15,
        height * 0.5,
      )
      ..cubicTo(
        width * 0.15,
        height * 0.64,
        width * 0.35,
        height * 0.72,
        width * 0.5,
        height * 0.5,
      );

    // ─── Loop 2: Right financial growth loop (Accent Cyan/Violet sweeping up) ───
    final rightPath = Path()
      ..moveTo(width * 0.5, height * 0.5)
      ..cubicTo(
        width * 0.65, height * 0.28,
        width * 0.85, height * 0.2, // Sweeps higher for upward growth trend
        width * 0.85, height * 0.45,
      )
      ..cubicTo(
        width * 0.85,
        height * 0.6,
        width * 0.65,
        height * 0.72,
        width * 0.5,
        height * 0.5,
      );

    // We draw parts of paths based on animation progress
    // Progress 0.0 -> 0.5 draws left loop
    // Progress 0.5 -> 1.0 draws right loop

    // Draw Left Loop
    if (progress > 0.0) {
      final leftProgress = math.min(1.0, progress * 2.0);
      final metrics = leftPath.computeMetrics();
      for (final metric in metrics) {
        final pathSegment =
            metric.extractPath(0.0, metric.length * leftProgress);
        // Draw glow first, then primary line on top
        canvas.drawPath(pathSegment, shadowPaint1);
        canvas.drawPath(pathSegment, paint1);
      }
    }

    // Draw Right Loop
    if (progress > 0.5) {
      final rightProgress = (progress - 0.5) * 2.0;
      final metrics = rightPath.computeMetrics();
      for (final metric in metrics) {
        final pathSegment =
            metric.extractPath(0.0, metric.length * rightProgress);
        // Draw glow first, then primary line on top
        canvas.drawPath(pathSegment, shadowPaint2);
        canvas.drawPath(pathSegment, paint2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SplashGrowthPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.accentColor != accentColor;
  }
}
