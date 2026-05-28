import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/live_tracking_providers.dart';

/// A widget shown in the Staff Home Dashboard to toggle live location sharing.
/// Displays current tracking status and start/stop button.
class LiveTrackingToggleWidget extends ConsumerStatefulWidget {
  const LiveTrackingToggleWidget({super.key});

  @override
  ConsumerState<LiveTrackingToggleWidget> createState() =>
      _LiveTrackingToggleWidgetState();
}

class _LiveTrackingToggleWidgetState
    extends ConsumerState<LiveTrackingToggleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pulse =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final isTracking = ref.read(isTrackingProvider);
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();
    try {
      if (isTracking) {
        await ref.read(stopTrackingProvider)();
      } else {
        await ref.read(startTrackingProvider)();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTracking = ref.watch(isTrackingProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: isTracking
              ? LinearGradient(
                  colors: [
                    AppColors.success.withValues(alpha: 0.12 + _pulse.value * 0.04),
                    AppColors.primary.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : LinearGradient(
                  colors: [
                    isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    isDark
                        ? Colors.white.withValues(alpha: 0.02)
                        : Colors.black.withValues(alpha: 0.01),
                  ],
                ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isTracking
                ? AppColors.success.withValues(alpha: 0.3)
                : theme.colorScheme.onSurface.withValues(alpha: 0.08),
            width: isTracking ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isTracking
                    ? AppColors.success.withValues(alpha: 0.15)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: isTracking
                  ? Icon(
                      Icons.location_on_rounded,
                      color: AppColors.success,
                      size: 26,
                    )
                  : Icon(
                      Icons.location_off_rounded,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                      size: 26,
                    ),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isTracking ? 'Live Tracking ON' : 'Live Tracking OFF',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isTracking
                          ? AppColors.success
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isTracking
                        ? 'Your manager can see your location'
                        : 'Tap to share your location with manager',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Toggle button
            GestureDetector(
              onTap: _isLoading ? null : _toggle,
              child: AnimatedContainer(
                duration: 300.ms,
                width: 56,
                height: 30,
                decoration: BoxDecoration(
                  color: isTracking ? AppColors.success : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: 300.ms,
                      left: isTracking ? 28 : 2,
                      top: 2,
                      child: _isLoading
                          ? const SizedBox(
                              width: 26,
                              height: 26,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(
                                  color: Colors.white, shape: BoxShape.circle),
                              child: isTracking
                                  ? const Icon(Icons.check_rounded,
                                      size: 14, color: AppColors.success)
                                  : null,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}
