import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for managing duty sessions (on-duty/off-duty state).
class DutyRepository {
  final SupabaseClient _client;
  final String orgId;

  DutyRepository(this._client, this.orgId);

  /// Start a new duty session
  Future<Map<String, dynamic>> startDuty({
    required String staffId,
    String? branchId,
    double? lat,
    double? lng,
  }) async {
    // End any existing active sessions first
    await _client
        .from('duty_sessions')
        .update({
          'status': 'abandoned',
          'end_time': DateTime.now().toIso8601String(),
        })
        .eq('staff_id', staffId)
        .eq('status', 'active');

    // Create new session
    final response = await _client.from('duty_sessions').insert({
      'staff_id': staffId,
      'org_id': orgId,
      'branch_id': branchId,
      'start_lat': lat,
      'start_lng': lng,
      'status': 'active',
    }).select().single();

    // Update profile duty status
    await _client
        .from('profiles')
        .update({'is_on_duty': true})
        .eq('id', staffId);

    return response;
  }

  /// End the current duty session
  Future<void> endDuty({
    required String staffId,
    double? lat,
    double? lng,
  }) async {
    final now = DateTime.now();

    // Find active session
    final activeSession = await _client
        .from('duty_sessions')
        .select()
        .eq('staff_id', staffId)
        .eq('status', 'active')
        .order('start_time', ascending: false)
        .limit(1)
        .maybeSingle();

    if (activeSession != null) {
      final startTime = DateTime.parse(activeSession['start_time'] as String);
      final durationMinutes = now.difference(startTime).inMinutes;

      await _client.from('duty_sessions').update({
        'end_time': now.toIso8601String(),
        'end_lat': lat,
        'end_lng': lng,
        'duration_minutes': durationMinutes,
        'status': 'completed',
      }).eq('id', activeSession['id']);
    }

    // Update profile duty status
    await _client
        .from('profiles')
        .update({'is_on_duty': false})
        .eq('id', staffId);
  }

  /// Get the current active duty session for a staff member
  Future<Map<String, dynamic>?> getActiveDutySession(String staffId) async {
    try {
      return await _client
          .from('duty_sessions')
          .select()
          .eq('staff_id', staffId)
          .eq('status', 'active')
          .order('start_time', ascending: false)
          .limit(1)
          .maybeSingle();
    } catch (e) {
      debugPrint('[DutyRepository] Error getting active session: $e');
      return null;
    }
  }

  /// Get today's duty sessions for a staff member
  Future<List<Map<String, dynamic>>> getTodayDutySessions(
      String staffId) async {
    try {
      final today = DateTime.now();
      final startOfDay =
          DateTime(today.year, today.month, today.day).toIso8601String();

      final response = await _client
          .from('duty_sessions')
          .select()
          .eq('staff_id', staffId)
          .gte('start_time', startOfDay)
          .order('start_time', ascending: false);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[DutyRepository] Error getting today sessions: $e');
      return [];
    }
  }

  /// Get total duty minutes today
  Future<int> getTodayDutyMinutes(String staffId) async {
    final sessions = await getTodayDutySessions(staffId);
    int totalMinutes = 0;

    for (final session in sessions) {
      if (session['duration_minutes'] != null) {
        totalMinutes += (session['duration_minutes'] as num).toInt();
      } else if (session['status'] == 'active') {
        // Currently active - calculate from start_time
        final startTime = DateTime.parse(session['start_time'] as String);
        totalMinutes += DateTime.now().difference(startTime).inMinutes;
      }
    }

    return totalMinutes;
  }

  /// Check if staff is currently on duty
  Future<bool> isOnDuty(String staffId) async {
    final session = await getActiveDutySession(staffId);
    return session != null;
  }
}
