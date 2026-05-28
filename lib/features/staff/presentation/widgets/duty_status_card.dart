import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/providers/duty_providers.dart';
import '../../data/providers/live_tracking_providers.dart';

/// A premium duty status card for the staff dashboard.
/// Shows on-duty/off-duty state, elapsed time, and toggle action.
class DutyStatusCard extends ConsumerStatefulWidget {
  const DutyStatusCard({super.key});

  @override
  ConsumerState<DutyStatusCard> createState() => _DutyStatusCardState();
}

class _DutyStatusCardState extends ConsumerState<DutyStatusCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _timerInitialized = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer(int initialSeconds) {
    _timer?.cancel();
    _elapsedSeconds = initialSeconds;
    _timerInitialized = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _elapsedSeconds = 0;
    _timerInitialized = false;
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dutyState = ref.watch(onDutyProvider);
    final isOnDuty = dutyState.valueOrNull ?? false;
    final isLoading = dutyState.isLoading;
    final isTracking = ref.watch(isTrackingProvider);
    final dutyMinutesAsync = ref.watch(todayDutyMinutesProvider);

    // Manage timer based on duty state
    if (isOnDuty && !_timerInitialized) {
      final sessionAsync = ref.watch(activeDutySessionProvider);
      sessionAsync.whenData((session) {
        if (session != null && !_timerInitialized) {
          final startTime = DateTime.parse(session['start_time'] as String);
          final elapsed = DateTime.now().difference(startTime).inSeconds;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _startTimer(elapsed);
          });
        }
      });
    } else if (!isOnDuty && _timerInitialized) {
      _stopTimer();
    }

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        return GlassCard(
          borderRadius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header row
              Row(
                children: [
                  // Status icon with pulse
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isOnDuty
                          ? AppColors.success.withValues(
                              alpha: 0.12 + _pulseCtrl.value * 0.06)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isOnDuty
                            ? AppColors.success.withValues(alpha: 0.3)
                            : Colors.transparent,
                      ),
                    ),
                    child: Icon(
                      isOnDuty
                          ? Icons.directions_walk_rounded
                          : Icons.pause_circle_outline_rounded,
                      color: isOnDuty
                          ? AppColors.success
                          : (isDark ? Colors.white38 : Colors.black38),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Status text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOnDuty ? 'On Duty' : 'Off Duty',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isOnDuty
                                ? AppColors.success
                                : (isDark ? Colors.white60 : Colors.black54),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isOnDuty
                              ? 'Location tracking active'
                              : 'Tap to start your shift',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Toggle button
                  GestureDetector(
                    onTap: isLoading
                        ? null
                        : () async {
                            HapticFeedback.heavyImpact();
                            await ref
                                .read(onDutyProvider.notifier)
                                .toggleDuty();
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isOnDuty
                            ? LinearGradient(
                                colors: [
                                  Colors.red.shade400,
                                  Colors.red.shade600,
                                ],
                              )
                            : LinearGradient(
                                colors: [
                                  AppColors.success,
                                  AppColors.success.withValues(alpha: 0.8),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: (isOnDuty
                                    ? Colors.red
                                    : AppColors.success)
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isOnDuty
                                      ? Icons.stop_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isOnDuty ? 'End' : 'Start',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),

              // Stats row (only when on duty or has today's data)
              if (isOnDuty || (dutyMinutesAsync.valueOrNull ?? 0) > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Current session timer
                      if (isOnDuty)
                        _statItem(
                          icon: Icons.timer_outlined,
                          label: 'Session',
                          value: _formatDuration(_elapsedSeconds),
                          color: AppColors.success,
                          isDark: isDark,
                        ),
                      // Today's total
                      _statItem(
                        icon: Icons.schedule_rounded,
                        label: 'Today',
                        value: _formatTotalDuty(
                            dutyMinutesAsync.valueOrNull ?? 0),
                        color: AppColors.primary,
                        isDark: isDark,
                      ),
                      // GPS status
                      _statItem(
                        icon: isTracking
                            ? Icons.gps_fixed_rounded
                            : Icons.gps_off_rounded,
                        label: 'GPS',
                        value: isTracking ? 'Active' : 'Off',
                        color: isTracking ? AppColors.success : Colors.grey,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _statItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      ],
    );
  }

  String _formatTotalDuty(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m';
  }
}
