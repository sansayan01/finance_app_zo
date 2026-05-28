import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/duty_providers.dart';

/// A premium On Duty toggle widget for the staff dashboard header.
/// Shows duty status with a sliding toggle and live timer.
class OnDutyToggle extends ConsumerStatefulWidget {
  const OnDutyToggle({super.key});

  @override
  ConsumerState<OnDutyToggle> createState() => _OnDutyToggleState();
}

class _OnDutyToggleState extends ConsumerState<OnDutyToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _timer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _elapsedSeconds = 0;
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final dutyState = ref.watch(onDutyProvider);
    final isOnDuty = dutyState.valueOrNull ?? false;
    final isLoading = dutyState.isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Manage timer based on duty state
    if (isOnDuty && _timer == null) {
      // Load elapsed time from active session
      final sessionAsync = ref.watch(activeDutySessionProvider);
      sessionAsync.whenData((session) {
        if (session != null && _elapsedSeconds == 0) {
          final startTime = DateTime.parse(session['start_time'] as String);
          _elapsedSeconds = DateTime.now().difference(startTime).inSeconds;
        }
      });
      _startTimer();
    } else if (!isOnDuty && _timer != null) {
      _stopTimer();
    }

    return GestureDetector(
      onTap: isLoading
          ? null
          : () async {
              HapticFeedback.heavyImpact();
              await ref.read(onDutyProvider.notifier).toggleDuty();
            },
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: isOnDuty
                  ? LinearGradient(
                      colors: [
                        AppColors.success.withValues(alpha: 0.2),
                        AppColors.success.withValues(
                            alpha: 0.1 + _pulseController.value * 0.1),
                      ],
                    )
                  : null,
              color: isOnDuty
                  ? null
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOnDuty
                    ? AppColors.success.withValues(alpha: 0.5)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.1)),
                width: 1.5,
              ),
              boxShadow: isOnDuty
                  ? [
                      BoxShadow(
                        color: AppColors.success.withValues(
                            alpha: 0.15 + _pulseController.value * 0.1),
                        blurRadius: 12,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status indicator dot
                if (isLoading)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isOnDuty ? AppColors.success : Colors.white70,
                    ),
                  )
                else
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isOnDuty ? AppColors.success : Colors.grey,
                      shape: BoxShape.circle,
                      boxShadow: isOnDuty
                          ? [
                              BoxShadow(
                                color: AppColors.success.withValues(
                                    alpha:
                                        0.5 + _pulseController.value * 0.5),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                const SizedBox(width: 6),
                // Label
                Text(
                  isOnDuty ? 'ON DUTY' : 'OFF DUTY',
                  style: TextStyle(
                    color: isOnDuty ? AppColors.success : Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                // Timer (only when on duty)
                if (isOnDuty && _elapsedSeconds > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatDuration(_elapsedSeconds),
                      style: TextStyle(
                        color: AppColors.success.withValues(alpha: 0.9),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A compact version for the app bar / header area
class OnDutyChip extends ConsumerWidget {
  const OnDutyChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dutyState = ref.watch(onDutyProvider);
    final isOnDuty = dutyState.valueOrNull ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOnDuty
            ? AppColors.success.withValues(alpha: 0.15)
            : Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOnDuty
              ? AppColors.success.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isOnDuty ? AppColors.success : Colors.orange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isOnDuty ? 'On Duty' : 'Off Duty',
            style: TextStyle(
              color: isOnDuty ? AppColors.success : Colors.orange,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
