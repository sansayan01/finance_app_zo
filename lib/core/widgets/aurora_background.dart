import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Premium aurora background with radial gradient blobs, animated floating circles,
/// and slow-drift animation — all driven by a single AnimationController.
class AuroraBackground extends StatefulWidget {
  final Widget child;
  const AuroraBackground({super.key, required this.child});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;
    final accent = isDark
        ? const Color(0xFF9B87F5)
        : const Color(0xFFA855F7);
    final success = isDark
        ? const Color(0xFF52D1A4)
        : const Color(0xFF10B981);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;

        // Drift offsets for gradient blobs
        final s1 = math.sin(t * 2 * math.pi) * 0.04;
        final c1 = math.cos(t * 2 * math.pi) * 0.03;
        final s2 = math.sin((t + 0.25) * 2 * math.pi) * 0.03;
        final c2 = math.cos((t + 0.25) * 2 * math.pi) * 0.04;

        // Floating circle offsets (sin/cos based, no extra controllers)
        final c1x = math.sin(t * 2 * math.pi * 0.25) * 20; // 4s period
        final c1y = math.cos(t * 2 * math.pi * 0.2) * 30;  // 5s period
        final c2y = math.sin(t * 2 * math.pi * 0.167) * -40; // 6s period
        final c3x = math.sin(t * 2 * math.pi * 0.2) * 15;  // 5s period
        final c3y = math.cos(t * 2 * math.pi * 0.143) * 25; // 7s period

        return Stack(
          children: [
            // ── Radial gradient blobs ──

            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.6 + c1, -0.4 + s1),
                    radius: 1.3,
                    colors: [
                      primary.withValues(alpha: isDark ? 0.14 : 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.6 + s2, -0.75 + c2),
                    radius: 1.1,
                    colors: [
                      secondary.withValues(alpha: isDark ? 0.12 : 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.1 - c2, 0.6 + s1),
                    radius: 1.4,
                    colors: [
                      primary.withValues(alpha: isDark ? 0.08 : 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.5 + s1, 0.3 + c1),
                    radius: 1.2,
                    colors: [
                      accent.withValues(alpha: isDark ? 0.08 : 0.03),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── Floating circles (single controller, sin/cos math) ──

            Positioned(
              top: -60 + c1y,
              right: -40 + c1x,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: isDark ? 0.06 : 0.04),
                ),
              ),
            ),

            Positioned(
              bottom: 150 + c2y,
              left: -120,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: success.withValues(alpha: isDark ? 0.04 : 0.03),
                ),
              ),
            ),

            Positioned(
              top: 200 + c3y,
              left: -80 + c3x,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: isDark ? 0.03 : 0.02),
                ),
              ),
            ),

            // ── Child content ──
            widget.child,
          ],
        );
      },
    );
  }
}
