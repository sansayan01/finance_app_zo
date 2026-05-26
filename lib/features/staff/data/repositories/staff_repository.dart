import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/staff_profile_model.dart';
import '../models/wallet_model.dart';
import '../models/streak_model.dart';
import '../models/target_model.dart';

class StaffRepository {
  final SupabaseClient _client;
  final String _orgId;

  StaffRepository(this._client, this._orgId);

  /// Get current staff profile from user ID.
  /// Tries staff_profiles first, falls back to profiles table since
  /// user creation (UserRepository.createUser) only creates a profiles row,
  /// not a staff_profiles row.
  Future<StaffProfileModel?> getStaffProfile(String userId,
      [String? fullName, String? email]) async {
    try {
      // Try staff_profiles first
      final spResponse = await _client
          .from('staff_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (spResponse != null) {
        // Fetch supervisor name separately
        final supervisorId = spResponse['supervisor_id'] as String?;
        if (supervisorId != null) {
          try {
            final sup = await _client
                .from('staff_profiles')
                .select('full_name')
                .eq('id', supervisorId)
                .maybeSingle();
            spResponse['supervisor'] = {'full_name': sup?['full_name']};
          } catch (_) {
            spResponse['supervisor'] = null;
          }
        }
        // Fetch branch name separately
        final branchId = spResponse['branch_id'] as String?;
        if (branchId != null) {
          try {
            final branch = await _client
                .from('branches')
                .select('name')
                .eq('id', branchId)
                .maybeSingle();
            spResponse['branches'] = branch;
          } catch (_) {
            spResponse['branches'] = null;
          }
        }
        return StaffProfileModel.fromJson(spResponse);
      }

      // Fallback: profiles table (created by UserRepository.createUser)
      final pResponse = await _client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (pResponse != null) {
        pResponse['supervisor'] = null;
        // Fetch branch name separately (FK join on profiles may fail)
        final branchId = pResponse['branch_id'] as String?;
        if (branchId != null) {
          try {
            final branch = await _client
                .from('branches')
                .select('name')
                .eq('id', branchId)
                .maybeSingle();
            pResponse['branches'] = branch;
          } catch (_) {
            pResponse['branches'] = null;
          }
        }
        return StaffProfileModel.fromJson(pResponse);
      }

      return null;
    } catch (e) {
      debugPrint('[StaffRepository] getStaffProfile error: $e');
      return null;
    }
  }

  /// Get staff profile by staff ID
  Future<StaffProfileModel?> getStaffById(String staffId) async {
    try {
      final response = await _client.from('staff_profiles').select()
          .eq('id', staffId).single();

      // Fetch supervisor name separately
      final supervisorId = response['supervisor_id'] as String?;
      String? supervisorName;
      if (supervisorId != null) {
        try {
          final sup = await _client
              .from('staff_profiles')
              .select('full_name')
              .eq('id', supervisorId)
              .maybeSingle();
          supervisorName = sup?['full_name'] as String?;
        } catch (_) {}
      }
      response['supervisor'] = {'full_name': supervisorName};

      // Fetch branch name separately
      final branchId = response['branch_id'] as String?;
      if (branchId != null) {
        try {
          final branch = await _client
              .from('branches')
              .select('name')
              .eq('id', branchId)
              .maybeSingle();
          response['branches'] = branch;
        } catch (_) {
          response['branches'] = null;
        }
      }

      return StaffProfileModel.fromJson(response);
    } catch (e) {
      debugPrint('[StaffRepository] getStaffById error: $e');
      return null;
    }
  }

  /// Get staff wallet
  Future<WalletModel?> getWallet(String staffId) async {
    try {
      final response = await _client
          .from('staff_wallet')
          .select()
          .eq('staff_id', staffId)
          .single();

      return WalletModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Get staff streak
  Future<StreakModel?> getStreak(String staffId) async {
    try {
      final response = await _client
          .from('staff_streaks')
          .select()
          .eq('staff_id', staffId)
          .single();

      return StreakModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Get today's target
  Future<TargetModel?> getTodayTarget(String staffId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;

      final response = await _client
          .from('collection_targets')
          .select()
          .eq('staff_id', staffId)
          .eq('period_type', 'daily')
          .eq('target_date', today)
          .single();

      return TargetModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Create or update today's target
  Future<TargetModel> ensureTodayTarget(
    String staffId,
    double dailyTarget,
  ) async {
    final today = DateTime.now();
    final todayStr = today.toIso8601String().split('T').first;

    // Try to get existing
    final existing = await getTodayTarget(staffId);
    if (existing != null) return existing;

    // Create new target
    final payload = {
      'staff_id': staffId,
      'period_type': 'daily',
      'target_date': todayStr,
      'period_start': todayStr,
      'period_end': todayStr,
      'target_amount': dailyTarget,
      'status': 'active',
      'org_id': _orgId,
    };

    final response = await _client
        .from('collection_targets')
        .insert(payload)
        .select()
        .single();

    return TargetModel.fromJson(response);
  }

  /// Get today's summary from view
  Future<Map<String, dynamic>?> getTodaySummary(String staffId) async {
    try {
      final response = await _client
          .from('staff_today_summary')
          .select()
          .eq('staff_id', staffId)
          .single();

      return response;
    } catch (e) {
      return null;
    }
  }

  /// Record wallet deposit
  Future<void> recordDeposit({
    required String staffId,
    required double amount,
    required String depositMode,
    double? gpsLat,
    double? gpsLng,
  }) async {
    final now = DateTime.now();

    // Get current wallet
    final wallet = await getWallet(staffId);
    if (wallet == null) throw Exception('Wallet not found');

    // Update wallet
    await _client.from('staff_wallet').update({
      'cash_in_hand': wallet.cashInHand - amount,
      'total_deposited_today': wallet.totalDepositedToday + amount,
      'is_over_limit': (wallet.cashInHand - amount) > wallet.safeLimit,
      'last_updated': now.toIso8601String(),
    }).eq('staff_id', staffId);

    // Create wallet transaction
    await _client.from('wallet_transactions').insert({
      'staff_id': staffId,
      'type': 'deposit',
      'amount': amount,
      'direction': 'out',
      'payment_mode': depositMode,
      'balance_after': wallet.cashInHand - amount,
      'org_id': _orgId,
    });
  }

  /// Log activity
  Future<void> logActivity({
    required String staffId,
    required String action,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? metadata,
    double? gpsLat,
    double? gpsLng,
    String? gpsAddress,
  }) async {
    await _client.from('activity_logs').insert({
      'staff_id': staffId,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'metadata': metadata ?? {},
      'gps_lat': gpsLat,
      'gps_lng': gpsLng,
      'gps_address': gpsAddress,
      'sync_status': 'synced',
      'org_id': _orgId,
    });
  }

  /// Record staff location
  Future<void> recordLocation({
    required String staffId,
    required double latitude,
    required double longitude,
    double? accuracy,
    double? altitude,
    double? speed,
    double? heading,
    String activityType = 'idle',
    int? batteryLevel,
    bool isCharging = false,
  }) async {
    try {
      await _client.from('staff_locations').insert({
        'staff_id': staffId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'altitude': altitude,
        'speed': speed,
        'heading': heading,
        'activity_type': activityType,
        'battery_level': batteryLevel,
        'is_charging': isCharging,
        'recorded_at': DateTime.now().toIso8601String(),
        'org_id': _orgId,
      });
    } catch (e) {
      // Location tracking is non-critical
    }
  }

  /// Log a visit (check-in).
  /// [orgId] should be the staff profile's org_id (verified by RLS SELECT).
  Future<void> logVisit({
    required String staffId,
    required String orgId,
    String? customerId,
    required String purpose,
    required double checkInLat,
    required double checkInLng,
    String? notes,
  }) async {
    await _client.from('visit_logs').insert({
      'staff_id': staffId,
      'customer_id': customerId,
      'member_id': customerId,
      'purpose': purpose,
      'check_in_time': DateTime.now().toIso8601String(),
      'check_in_lat': checkInLat,
      'check_in_lng': checkInLng,
      'notes': notes,
      'status': 'in_progress',
      'org_id': orgId,
    });

    // Log activity (best-effort, don't fail the check-in if this fails)
    try {
      await logActivity(
        staffId: staffId,
        action: 'visit_check_in',
        entityType: 'customer',
        entityId: customerId,
        metadata: {'purpose': purpose},
        gpsLat: checkInLat,
        gpsLng: checkInLng,
      );
    } catch (e) {
      debugPrint('[StaffRepository] logActivity failed: $e');
    }
  }

  /// Complete a visit (check-out)
  Future<void> completeVisit({
    required String staffId,
    required double checkOutLat,
    required double checkOutLng,
    String? outcome,
    String? notes,
  }) async {
    final now = DateTime.now();

    // Find active visit
    final activeVisit = await _client
        .from('visit_logs')
        .select()
        .eq('staff_id', staffId)
        .eq('status', 'in_progress')
        .order('check_in_time', ascending: false)
        .limit(1)
        .maybeSingle();

    if (activeVisit == null) throw Exception('No active visit found');

    await _client.from('visit_logs').update({
      'check_out_time': now.toIso8601String(),
      'check_out_lat': checkOutLat,
      'check_out_lng': checkOutLng,
      'status': 'completed',
      'outcome': outcome ?? 'collected',
      'notes': notes,
    }).eq('id', activeVisit['id']);

    // Log activity (best-effort)
    try {
      await logActivity(
        staffId: staffId,
        action: 'visit_check_out',
        entityType: 'visit',
        entityId: activeVisit['id'],
        gpsLat: checkOutLat,
        gpsLng: checkOutLng,
      );
    } catch (e) {
      debugPrint('[StaffRepository] logActivity failed: $e');
    }
  }

  /// Record cash deposit
  Future<void> recordCashDeposit({
    required String staffId,
    required double amount,
    required String method,
    String? reference,
    String? notes,
  }) async {
    try {
      final now = DateTime.now();

      // Create cash deposit record
      await _client.from('cash_deposits').insert({
        'staff_id': staffId,
        'amount': amount,
        'bank_name': method,
        'reference_number': reference,
        'notes': notes,
        'deposit_date': now.toIso8601String().split('T').first,
        'deposit_time': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
        'status': 'pending_verification',
        'org_id': _orgId,
      });

      // Update wallet
      final wallet = await getWallet(staffId);
      if (wallet != null) {
        await _client.from('staff_wallet').update({
          'cash_in_hand': wallet.cashInHand - amount,
          'total_deposited_today': wallet.totalDepositedToday + amount,
          'last_updated': now.toIso8601String(),
        }).eq('staff_id', staffId);
      }

      // Log activity
      await logActivity(
        staffId: staffId,
        action: 'cash_deposit',
        entityType: 'deposit',
        metadata: {'amount': amount, 'method': method},
      );
    } catch (e) {
      // Log failure silently
    }
  }

  /// Start a break
  Future<void> startBreak({
    required String staffId,
    required String breakType,
    String? notes,
  }) async {
    try {
      await _client.from('staff_breaks').insert({
        'staff_id': staffId,
        'break_type': breakType,
        'break_start': DateTime.now().toIso8601String(),
        'notes': notes,
      });

      // Log activity
      await logActivity(
        staffId: staffId,
        action: 'break_start',
        metadata: {'break_type': breakType},
      );
    } catch (e) {
      // Log failure silently
    }
  }

  /// End a break
  Future<void> endBreak(String staffId) async {
    try {
      final now = DateTime.now();

      // Find active break
      final activeBreak = await _client
          .from('staff_breaks')
          .select()
          .eq('staff_id', staffId)
          .isFilter('break_end', null)
          .order('break_start', ascending: false)
          .limit(1)
          .maybeSingle();

      if (activeBreak == null) return;

      final breakStart = DateTime.parse(activeBreak['break_start']);
      final duration = now.difference(breakStart).inMinutes;

      await _client.from('staff_breaks').update({
        'break_end': now.toIso8601String(),
        'duration_minutes': duration,
      }).eq('id', activeBreak['id']);

      // Log activity
      await logActivity(
        staffId: staffId,
        action: 'break_end',
        entityType: 'break',
        entityId: activeBreak['id'],
      );
    } catch (e) {
      // Log failure silently
    }
  }

  /// Get current break (break_end is null means break is active)
  Future<Map<String, dynamic>?> getCurrentBreak(String staffId) async {
    return await _client
        .from('staff_breaks')
        .select()
        .eq('staff_id', staffId)
        .isFilter('break_end', null)
        .order('break_start', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  /// Get today's breaks
  Future<List<Map<String, dynamic>>> getTodayBreaks(String staffId) async {
    final today = DateTime.now().toIso8601String().split('T').first;

    return await _client
        .from('staff_breaks')
        .select()
        .eq('staff_id', staffId)
        .gte('break_start', '${today}T00:00:00')
        .order('break_start', ascending: false);
  }

  /// Get daily summary for a specific date
  Future<Map<String, dynamic>> getDailySummary(
      String staffId, DateTime date) async {
    final dateStr = date.toIso8601String().split('T').first;

    // Get collections for the date
    final collections = await _client
        .from('collections')
        .select()
        .eq('staff_id', staffId)
        .eq('collection_date', dateStr);

    // Get visits for the date
    final visits = await _client
        .from('visit_logs')
        .select()
        .eq('staff_id', staffId)
        .gte('check_in_time', '${dateStr}T00:00:00')
        .lt('check_in_time', '${dateStr}T23:59:59');

    // Calculate summary
    double totalCollected = 0;
    double cashCollected = 0;
    double digitalCollected = 0;
    int successfulVisits = 0;

    for (var c in collections) {
      final amount = (c['amount_collected'] as num?)?.toDouble() ?? 0;
      totalCollected += amount;
      if (c['payment_mode'] == 'cash') {
        cashCollected += amount;
      } else {
        digitalCollected += amount;
      }
    }

    for (var v in visits) {
      if (v['status'] == 'completed') {
        successfulVisits++;
      }
    }

    // Get target for the date
    final target = await _client
        .from('collection_targets')
        .select()
        .eq('staff_id', staffId)
        .eq('period_type', 'daily')
        .eq('target_date', dateStr)
        .maybeSingle();

    // Get streak
    final streak = await getStreak(staffId);

    return {
      'total_collected': totalCollected,
      'cash_collected': cashCollected,
      'digital_collected': digitalCollected,
      'collection_count': collections.length,
      'total_visits': visits.length,
      'successful_visits': successfulVisits,
      'target_amount': target?['target_amount'] ?? 0,
      'streak_days': streak?.currentStreak ?? 0,
      'recent_collections': collections.take(5).toList(),
    };
  }

  /// Get current activity status
  Future<String?> getCurrentActivity(String staffId) async {
    // Check if on break
    final activeBreak = await getCurrentBreak(staffId);
    if (activeBreak != null) return 'break';

    // Check if on visit
    final activeVisit = await _client
        .from('visit_logs')
        .select()
        .eq('staff_id', staffId)
        .eq('status', 'in_progress')
        .maybeSingle();

    if (activeVisit != null) return 'collecting';

    return 'idle';
  }

  /// Get unread notifications count
  Future<int> getUnreadNotificationCount(String staffId) async {
    try {
      final response = await _client
          .from('staff_notifications')
          .select('id')
          .eq('staff_id', staffId)
          .eq('is_read', false);
      return response.length;
    } catch (_) {
      return 0;
    }
  }

  /// Get recent notifications
  Future<List<Map<String, dynamic>>> getRecentNotifications(
    String staffId, {
    int limit = 5,
  }) async {
    try {
      final response = await _client
          .from('staff_notifications')
          .select()
          .eq('staff_id', staffId)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  /// Get active visit
  Future<Map<String, dynamic>?> getActiveVisit(String staffId) async {
    try {
      return await _client
          .from('visit_logs')
          .select('*, members(full_name, phone)')
          .eq('staff_id', staffId)
          .eq('status', 'in_progress')
          .order('check_in_time', ascending: false)
          .limit(1)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  /// Get recent activities for staff
  Future<List<Map<String, dynamic>>> getRecentActivities(
    String staffId, {
    int limit = 10,
  }) async {
    try {
      final response = await _client
          .from('activity_logs')
          .select()
          .eq('staff_id', staffId)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  /// Get today's savings collection stats
  Future<Map<String, dynamic>> getTodaySavingsStats(String staffId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final response = await _client
          .from('savings_collections')
          .select('amount, payment_mode')
          .eq('staff_id', staffId)
          .filter('collection_date', 'gte', today);

      double totalSavings = 0;
      double cashSavings = 0;
      double digitalSavings = 0;

      for (final item in response) {
        final amount = (item['amount'] as num?)?.toDouble() ?? 0;
        totalSavings += amount;
        if (item['payment_mode'] == 'cash') {
          cashSavings += amount;
        } else {
          digitalSavings += amount;
        }
      }

      return {
        'total_savings': totalSavings,
        'cash_savings': cashSavings,
        'digital_savings': digitalSavings,
        'savings_count': response.length,
      };
    } catch (_) {
      return {
        'total_savings': 0.0,
        'cash_savings': 0.0,
        'digital_savings': 0.0,
        'savings_count': 0,
      };
    }
  }

  /// Get weekly trend data for performance pulse
  Future<List<Map<String, dynamic>>> getWeeklyTrend(String staffId) async {
    try {
      final today = DateTime.now();
      final weekAgo = today.subtract(const Duration(days: 6));
      final response = await _client
          .from('collections')
          .select('amount_collected, collection_date')
          .eq('staff_id', staffId)
          .filter('collection_date', 'gte',
              weekAgo.toIso8601String().split('T').first)
          .order('collection_date', ascending: true);

      // Group by date and sum amounts
      final Map<String, double> dailyTotals = {};
      for (final item in response) {
        final date = item['collection_date'] as String? ?? '';
        final amount = (item['amount_collected'] as num?)?.toDouble() ?? 0;
        dailyTotals[date] = (dailyTotals[date] ?? 0) + amount;
      }

      final result = <Map<String, dynamic>>[];
      for (int i = 0; i < 7; i++) {
        final date = today.subtract(Duration(days: 6 - i));
        final dateStr = date.toIso8601String().split('T').first;
        result.add({
          'date': dateStr,
          'amount': dailyTotals[dateStr] ?? 0,
          'dayLabel': ['S', 'M', 'T', 'W', 'T', 'F', 'S'][date.weekday - 1],
        });
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  /// Get overdue collection count nearby (within staff's area)
  Future<int> getNearbyOverdueCount(String staffId) async {
    try {
      final response = await _client
          .from('overdue_loans_view')
          .select('id')
          .eq('staff_id', staffId);
      return response.length;
    } catch (_) {
      return 0;
    }
  }
}
