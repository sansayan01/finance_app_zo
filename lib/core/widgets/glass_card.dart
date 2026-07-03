// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

/// Ultra-premium card widget with iOS-style surface depth and multi-layer shadows.
/// Set [glassmorphic] to true for frosted-glass effect (no blur, GPU-friendly).
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

  /// When true, uses semi-transparent fill for frosted-glass effect (GPU-friendly, no blur).
  final bool glassmorphic;

  /// Optional gradient border (e.g. primary→accent). Only used in glassmorphic mode.
  final Gradient? gradientBorder;

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
    this.glassmorphic = false,
    this.gradientBorder,
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

    if (widget.glassmorphic) {
      return _buildGlassmorphic(context, isDark, theme);
    }
    return _buildLegacy(context, isDark, theme);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Glassmorphic mode — real frosted glass
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildGlassmorphic(BuildContext context, bool isDark, ThemeData theme) {
    final glassBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.55);

    final glassBorder = widget.gradientBorder == null
        ? (isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.32))
        : null; // gradient border handles its own color

    final shadowColor = isDark ? Colors.black : const Color(0xFF0F172A);
    final shadows = [
      BoxShadow(
        color: shadowColor.withValues(alpha: isDark ? 0.25 : 0.06),
        blurRadius: widget.elevated ? 32 : 20,
        offset: Offset(0, widget.elevated ? 8 : 4),
        spreadRadius: widget.elevated ? -6 : -4,
      ),
      if (widget.elevated)
        BoxShadow(
          color: shadowColor.withValues(alpha: isDark ? 0.15 : 0.03),
          blurRadius: 12,
          offset: const Offset(0, 2),
          spreadRadius: -2,
        ),
      // Top-edge highlight
      BoxShadow(
        color: Colors.white.withValues(alpha: isDark ? 0.03 : 0.5),
        blurRadius: 0,
        offset: const Offset(0, -0.5),
        spreadRadius: 0,
      ),
    ];

    final content = Padding(
      padding: widget.margin ?? EdgeInsets.zero,
      child: Container(
        padding: widget.padding,
        decoration: BoxDecoration(
          color: _isPressed
              ? glassBg.withValues(alpha: isDark ? 0.02 : 0.5)
              : glassBg,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: glassBorder != null
              ? Border.all(color: glassBorder, width: 0.8)
              : null,
          gradient: widget.gradientBorder,
          boxShadow: shadows,
        ),
        child: widget.child,
      ),
    );

    if (widget.onTap == null) return content;

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
        child: content,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Legacy mode — solid fill, backward compatible
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLegacy(BuildContext context, bool isDark, ThemeData theme) {
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

    if (widget.onTap == null) return child;

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
