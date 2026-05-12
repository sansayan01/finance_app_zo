import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/location_service.dart';
import '../../data/providers/staff_providers.dart';

class CheckInCard extends ConsumerStatefulWidget {
  const CheckInCard({super.key});

  @override
  ConsumerState<CheckInCard> createState() => _CheckInCardState();
}

class _CheckInCardState extends ConsumerState<CheckInCard> {
  bool _isLoading = false;

  Future<void> _handleCheckInOut() async {
    HapticFeedback.mediumImpact();
    final profile = await ref.read(staffProfileProvider.future);
    if (profile == null) return;

    final activeVisit = await ref.read(activeVisitProvider.future);
    final repo = ref.read(staffRepositoryProvider);

    setState(() => _isLoading = true);
    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentLocation();
      
      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not get location'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      if (activeVisit != null) {
        await repo.completeVisit(
          staffId: profile.id,
          checkOutLat: position.latitude,
          checkOutLng: position.longitude,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Checked out successfully'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
          );
        }
      } else {
        await repo.logVisit(
          staffId: profile.id,
          purpose: 'collection',
          checkInLat: position.latitude,
          checkInLng: position.longitude,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Checked in successfully'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
          );
        }
      }

      ref.invalidate(activeVisitProvider);
      ref.invalidate(currentActivityProvider(profile.id));
      ref.invalidate(recentActivitiesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 2)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeVisitAsync = ref.watch(activeVisitProvider);

    return activeVisitAsync.when(
      data: (activeVisit) {
        final isCheckedIn = activeVisit != null;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isCheckedIn
                  ? [Colors.green.shade600, Colors.teal.shade700]
                  : [AppColors.primary, AppColors.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (isCheckedIn ? Colors.green : AppColors.primary).withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isCheckedIn ? Icons.check_circle_outline_rounded : Icons.login_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCheckedIn ? 'Checked In' : 'Start Your Day',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        isCheckedIn ? 'Tap to check out' : 'Check in to begin',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleCheckInOut,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(
                              isCheckedIn ? 'Check Out' : 'Check In',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
