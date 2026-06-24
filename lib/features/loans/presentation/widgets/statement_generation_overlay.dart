import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A premium, non-dismissible loading overlay shown while a statement is
/// being generated.
///
/// Usage:
/// ```dart
/// StatementGenerationOverlay.show(context);
/// // ... do work ...
/// StatementGenerationOverlay.dismiss();
/// ```
class StatementGenerationOverlay {
  static OverlayEntry? _entry;

  /// Shows the loading overlay on top of everything.
  static void show(BuildContext context) {
    dismiss(); // clean up any prior instance

    _entry = OverlayEntry(
      builder: (_) => _StatementGenerationOverlayWidget(),
    );
    Overlay.of(context).insert(_entry!);
  }

  /// Removes the overlay if it's showing.
  static void dismiss() {
    _entry?.remove();
    _entry = null;
  }
}

class _StatementGenerationOverlayWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.black45,
      child: Center(
        child: Container(
          width: 200,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated pulse ring + icon
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pulsing ring
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                    ).animate(onPlay: (c) => c.repeat())
                        .scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.3, 1.3),
                          duration: 1200.ms,
                          curve: Curves.easeOut,
                        )
                        .fade(
                          begin: 0.6,
                          end: 0.0,
                          duration: 1200.ms,
                          curve: Curves.easeOut,
                        ),
                    // Center icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(
                        Icons.description_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Generating',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Preparing your statement…',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ).animate().scale(
            begin: const Offset(0.9, 0.9),
            end: const Offset(1, 1),
            duration: 250.ms,
            curve: Curves.easeOutBack,
          ),
    );
  }
}
