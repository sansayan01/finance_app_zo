// ignore_for_file: depend_on_referenced_packages
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// Frosted-glass card with backdrop blur. Used by the executive admin
/// portal for hero/info surfaces.
///
/// Centralised here so every page renders the same look and the
/// implementation can evolve (e.g. add accessibility tweaks, animation
/// presets) in a single place.
class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blurSigma;
  final Color? tint;
  final VoidCallback? onTap;
  final bool elevated;

  const GlassmorphicCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 24,
    this.blurSigma = 18,
    this.tint,
    this.onTap,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor =
        tint ?? (isDark ? const Color(0xFF1A1F2E) : Colors.white);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.3);
    final shadow = isDark
        ? Colors.black.withValues(alpha: 0.2)
        : Colors.black.withValues(alpha: 0.04);

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Material(
            color: baseColor.withValues(alpha: isDark ? 0.7 : 0.8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              side: BorderSide(color: borderColor),
            ),
            elevation: elevated ? 6 : 0,
            shadowColor: shadow,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(borderRadius),
              child: Padding(
                padding: padding ?? const EdgeInsets.all(20),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
