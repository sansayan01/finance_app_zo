import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/duty_providers.dart';
import '../providers/live_tracking_providers.dart';
import '../providers/staff_providers.dart';

/// Service that auto-resumes location tracking if the agent was on duty
/// when the app was last closed. Called once during app initialization.
class DutyAutoResumeService {
  final Ref _ref;

  DutyAutoResumeService(this._ref);

  /// Check if agent was on duty and resume tracking if so.
  /// Should be called after authentication is confirmed.
  Future<void> checkAndResume() async {
    try {
      final profile = await _ref.read(staffProfileProvider.future);
      if (profile == null) return;

      final repo = _ref.read(dutyRepositoryProvider);
      final isOnDuty = await repo.isOnDuty(profile.id);

      if (isOnDuty) {
        debugPrint('[DutyAutoResume] Agent was on duty, resuming tracking...');
        final startTracking = _ref.read(startTrackingProvider);
        await startTracking();
        debugPrint('[DutyAutoResume] Tracking resumed successfully.');
      } else {
        debugPrint('[DutyAutoResume] Agent is off duty, no action needed.');
      }
    } catch (e) {
      debugPrint('[DutyAutoResume] Error checking duty status: $e');
    }
  }
}

/// Provider for the auto-resume service
final dutyAutoResumeServiceProvider = Provider<DutyAutoResumeService>((ref) {
  return DutyAutoResumeService(ref);
});

/// Provider that triggers auto-resume on first read.
/// Watch this in the StaffShell or staff home to auto-resume.
final dutyAutoResumeProvider = FutureProvider<void>((ref) async {
  final service = ref.read(dutyAutoResumeServiceProvider);
  await service.checkAndResume();
});
