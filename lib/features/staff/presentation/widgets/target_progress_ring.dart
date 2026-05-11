import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/target_model.dart';
import '../../data/models/streak_model.dart';

class TargetProgressRing extends StatefulWidget {
  final TargetModel target;
  final StreakModel? streak;
  final double size;
  final VoidCallback? onTap;

  const TargetProgressRing({
    super.key,
    required this.target,
    this.streak,
    this.size = 180,
    this.onTap,
  });

  @override
  State<TargetProgressRing> createState() => _TargetProgressRingState();
}

class _TargetProgressRingState extends State<TargetProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Tween<double>(
      begin: 0,
      end: widget.target.progressPercentage,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = widget.target.progressPercentage;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1A1A2E).withOpacity(0.5)
              : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Progress ring
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(widget.size - 40, widget.size - 40),
                  painter: _ProgressRingPainter(
                    progress: _animation.value,
                    color: _getProgressColor(progress),
                    backgroundColor:
                        isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
                    strokeWidth: 12,
                  ),
                );
              },
            ),

            // Center content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Percentage
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Text(
                      '${_animation.value.toStringAsFixed(0)}%',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: _getProgressColor(progress),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 4),

                // Achieved / Target
                Text(
                  '₹${AppFormatters.formatCompactCurrency(widget.target.achievedAmount)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'of ₹${AppFormatters.formatCompactCurrency(widget.target.targetAmount)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),

                // Streak badge
                if (widget.streak?.hasActiveStreak == true) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orangeAccent.withOpacity(0.8),
                          Colors.deepOrange.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.streak!.streakEmoji,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.streak!.currentStreak} day streak',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress >= 100) return Colors.greenAccent;
    if (progress >= 75) return Colors.lightGreenAccent;
    if (progress >= 50) return AppColors.primary;
    if (progress >= 25) return Colors.orangeAccent;
    return Colors.redAccent;
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * (progress / 100);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
