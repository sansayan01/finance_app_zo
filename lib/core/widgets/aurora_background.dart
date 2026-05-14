// ignore_for_file: deprecated_member_use
import 'dart:math';
import 'package:flutter/material.dart';

class AuroraBackground extends StatefulWidget {
  final Widget child;
  const AuroraBackground({super.key, required this.child});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;

    return Stack(
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _AuroraPainter(
                progress: _controller.value,
                primaryColor: primary.withValues(alpha: isDark ? 0.08 : 0.05),
                secondaryColor:
                    secondary.withValues(alpha: isDark ? 0.06 : 0.03),
                isDark: isDark,
              ),
              size: Size.infinite,
            );
          },
        ),
        widget.child,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isDark;

  _AuroraPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);

    // Dynamic blobs
    _drawBlob(canvas, size, 0.2 + 0.1 * sin(progress * 2 * pi),
        0.3 + 0.1 * cos(progress * 2 * pi), 150, primaryColor, paint);
    _drawBlob(canvas, size, 0.8 - 0.1 * cos(progress * 2 * pi),
        0.2 + 0.1 * sin(progress * 2 * pi), 180, secondaryColor, paint);
    _drawBlob(
        canvas,
        size,
        0.5 + 0.1 * sin(progress * pi),
        0.7 - 0.1 * cos(progress * 2 * pi),
        200,
        primaryColor.withValues(alpha: 0.03),
        paint);
  }

  void _drawBlob(Canvas canvas, Size size, double xFactor, double yFactor,
      double radius, Color color, Paint paint) {
    paint.color = color;
    canvas.drawCircle(
      Offset(size.width * xFactor, size.height * yFactor),
      radius,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) =>
      oldDelegate.progress != progress;
}


