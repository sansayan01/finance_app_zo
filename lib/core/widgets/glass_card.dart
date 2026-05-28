// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

/// Ultra-premium card widget with iOS-style surface depth and multi-layer shadows.
class GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double borderRadius;
  final bool elevated;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool enableScale;
  final EdgeInsetsGeometry? margin;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.borderRadius = 24,
    this.elevated = false,
    this.backgroundColor,
    this.borderColor,
    this.enableScale = true,
    this.margin,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late final AnimationController _pressController;
  late final Animation<double> _pressAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _pressAnimation =
        CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = widget.backgroundColor ?? theme.colorScheme.surface;

    final shadowColor = isDark ? Colors.black : const Color(0xFF0F172A);
    final shadows = widget.elevated
        ? [
            BoxShadow(
              color: shadowColor.withValues(alpha: isDark ? 0.5 : 0.06),
              blurRadius: 32,
              offset: const Offset(0, 8),
              spreadRadius: -6,
            ),
            BoxShadow(
              color: shadowColor.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
              spreadRadius: -2,
            ),
          ]
        : [
            BoxShadow(
              color: shadowColor.withValues(alpha: isDark ? 0.4 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: shadowColor.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ];

    final child = Padding(
      padding: widget.margin ?? EdgeInsets.zero,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: _isPressed
              ? (isDark
                  ? bgColor.withValues(alpha: 0.9)
                  : bgColor.withValues(alpha: 0.95))
              : bgColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: widget.borderColor ??
                (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03)),
            width: widget.borderColor != null ? 1.5 : 0.5,
          ),
          boxShadow: shadows,
        ),
        child: widget.child,
      ),
    );

    if (widget.onTap == null) {
      return child;
    }

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) {
        if (widget.enableScale) _pressController.forward();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        if (widget.enableScale) _pressController.reverse();
        setState(() => _isPressed = false);
      },
      onTapCancel: () {
        if (widget.enableScale) _pressController.reverse();
        setState(() => _isPressed = false);
      },
      child: AnimatedBuilder(
        animation: _pressAnimation,
        builder: (context, child) {
          final scale =
              widget.enableScale ? 1.0 - (_pressAnimation.value * 0.02) : 1.0;
          return Transform.scale(scale: scale, child: child);
        },
        child: child,
      ),
    );
  }
}
