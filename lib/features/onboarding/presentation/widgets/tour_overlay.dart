import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';

/// A single step in the quick tour.
class TourStep {
  final String title;
  final String description;
  final IconData icon;
  final Color? accentColor;

  const TourStep({
    required this.title,
    required this.description,
    required this.icon,
    this.accentColor,
  });
}

/// Full-screen overlay that shows tour steps as beautiful cards.
/// No spotlight/target needed — this is a modal walkthrough style.
class TourOverlay extends StatelessWidget {
  final TourStep step;
  final int currentIndex;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onBack;
  final VoidCallback onFinish;

  const TourOverlay({
    super.key,
    required this.step,
    required this.currentIndex,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
    required this.onBack,
    required this.onFinish,
  });

  bool get isFirst => currentIndex == 0;
  bool get isLast => currentIndex == totalSteps - 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = step.accentColor ?? theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Dimmed backdrop with blur
          Positioned.fill(
            child: GestureDetector(
              onTap: () {}, // absorb taps
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(
                  color: (isDark ? Colors.black : Colors.black87)
                      .withValues(alpha: 0.7),
                ),
              ),
            ),
          ),

          // Tour card centered
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: _buildCard(context, theme, isDark, accent),
            ),
          ),

          // Skip button top-right
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 20,
            child: TextButton(
              onPressed: onSkip,
              child: Text(
                'Skip Tour',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
      BuildContext context, ThemeData theme, bool isDark, Color accent) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 380),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.shade900.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: accent.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.15),
            blurRadius: 40,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Step indicator
            _buildStepIndicator(accent),
            const SizedBox(height: 24),

            // Icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: accent.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(step.icon, color: accent, size: 34),
            )
                .animate()
                .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1, 1),
                    duration: 400.ms,
                    curve: Curves.elasticOut)
                .fadeIn(duration: 300.ms),
            const SizedBox(height: 20),

            // Title
            Text(
              step.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: -0.3,
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
            const SizedBox(height: 12),

            // Description
            Text(
              step.description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
                fontSize: 14,
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
            const SizedBox(height: 28),

            // Navigation buttons
            _buildButtons(theme, accent),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildStepIndicator(Color accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (i) {
        final isActive = i == currentIndex;
        final isPast = i < currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? accent
                : isPast
                    ? accent.withValues(alpha: 0.4)
                    : accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildButtons(ThemeData theme, Color accent) {
    return Row(
      children: [
        // Back button
        if (!isFirst)
          Expanded(
            child: OutlinedButton(
              onPressed: onBack,
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        if (!isFirst) const SizedBox(width: 12),

        // Next / Finish button
        Expanded(
          flex: isFirst ? 1 : 1,
          child: ElevatedButton(
            onPressed: isLast ? onFinish : onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              isLast ? 'Get Started' : 'Next',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}
