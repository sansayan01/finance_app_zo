import 'package:flutter/material.dart';

/// A subtle "Powered by MicroFlow Pro" badge to maintain platform identity
/// when organizations use custom branding.
///
/// Place this in footers, about screens, or settings page bottoms.
class PoweredByBadge extends StatelessWidget {
  final bool compact;
  final Color? textColor;

  const PoweredByBadge({
    super.key,
    this.compact = false,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = textColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.3)
            : Colors.black.withValues(alpha: 0.3));

    if (compact) {
      return Text(
        'Powered by MicroFlow Pro',
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(
          color: color.withValues(alpha: 0.15),
          indent: 60,
          endIndent: 60,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bolt_rounded,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              'Powered by MicroFlow Pro',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Enterprise Micro-Finance Platform',
          style: TextStyle(
            fontSize: 9,
            color: color.withValues(alpha: 0.6),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
