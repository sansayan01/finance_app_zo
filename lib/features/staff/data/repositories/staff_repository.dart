import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/staff_profile_model.dart';
import '../models/wallet_model.dart';
import '../models/streak_model.dart';
import '../models/target_model.dart';

class StaffRepository {
  final SupabaseClient _client;
  final String _orgId;

  StaffRepository(this._client, this._orgId);

  /// Get current staff profile from user ID
  Future<StaffProfileModel?> getStaffProfile(String userId,
      [String? fullName, String? email]) async {
    try {
      final response = await _client.from('staff_profiles').select('''
            *,
            branches(name),
            supervisor:staff_profiles!fk_sp_supervisor(full_name)
          ''').eq('user_id', userId).eq('org_id', _orgId).maybeSingle();

      if (response != null) {
        return StaffProfileModel.fromJson(response);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get staff profile by staff ID
  Future<StaffProfileModel?> getStaffById(String staffId) async {
    try {
      final response = await _client.from('staff_profiles').select('''
            *,
            branches(name),
            supervisor:staff_profiles!fk_sp_supervisor(full_name)
          ''').eq('id', staffId).single();

      return StaffProfileModel.fromJson(response);
    } catch (e) {
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
      'last_deposit_amount': amount,
      'last_deposit_at': now.toIso8601String(),
      'last_deposit_mode': depositMode,
      'is_over_limit': (wallet.cashInHand - amount) > wallet.safeLimit,
      'updated_at': now.toIso8601String(),
    }).eq('staff_id', staffId);

    // Create wallet transaction
    await _client.from('wallet_transactions').insert({
      'staff_id': staffId,
      'type': 'deposit',
      'amount': amount,
      'direction': 'out',
      'payment_mode': depositMode,
      'balance_after': wallet.cashInHand - amount,
      'gps_lat': gpsLat,
      'gps_lng': gpsLng,
      'transaction_time': now.toIso8601String(),
      'sync_status': 'synced',
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
        'sync_status': 'synced',
      });
    } catch (e) {
      // Location tracking is non-critical
    }
  }

  /// Log a visit (check-in)
  Future<void> logVisit({
    required String staffId,
    String? customerId,
    required String purpose,
    required double checkInLat,
    required double checkInLng,
    String? notes,
  }) async {
    try {
      await _client.from('visit_logs').insert({
        'staff_id': staffId,
        'customer_id': customerId,
        'member_id': customerId,
        'purpose': purpose,
        'check_in_time': DateTime.now().toIso8601String(),
        'check_in_at': DateTime.now().toIso8601String(),
        'check_in_lat': checkInLat,
        'check_in_lng': checkInLng,
        'notes': notes,
        'status': 'in_progress',
        'visit_type': 'collection',
        'sync_status': 'synced',
      });

      // Log activity
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
      // Log failure silently - visitor log is non-critical
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
    try {
      final now = DateTime.now();

      // Find active visit
      final activeVisit = await _client
          .from('visit_logs')
          .select()
          .eq('staff_id', staffId)
          .eq('status', 'in_progress')
          .order('check_in_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (activeVisit == null) throw Exception('No active visit found');

      await _client.from('visit_logs').update({
        'check_out_time': now.toIso8601String(),
        'check_out_at': now.toIso8601String(),
        'check_out_lat': checkOutLat,
        'check_out_lng': checkOutLng,
        'status': 'completed',
        'outcome': outcome ?? 'collected',
        'notes': notes,
        'sync_status': 'synced',
      }).eq('id', activeVisit['id']);

      // Log activity
      await logActivity(
        staffId: staffId,
        action: 'visit_check_out',
        entityType: 'visit',
        entityId: activeVisit['id'],
        gpsLat: checkOutLat,
        gpsLng: checkOutLng,
      );
    } catch (e) {
      // Log failure silently
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
        'deposit_method': method,
        'reference_number': reference,
        'notes': notes,
        'deposit_time': now.toIso8601String(),
        'status': 'pending_verification',
        'sync_status': 'synced',
      });

      // Update wallet
      final wallet = await getWallet(staffId);
      if (wallet != null) {
        await _client.from('staff_wallet').update({
          'cash_in_hand': wallet.cashInHand - amount,
          'total_deposited_today': wallet.totalDepositedToday + amount,
          'last_deposit_amount': amount,
          'last_deposit_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
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
        'start_time': DateTime.now().toIso8601String(),
        'notes': notes,
        'status': 'in_progress',
        'sync_status': 'synced',
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
          .eq('status', 'in_progress')
          .order('start_time', ascending: false)
          .limit(1)
          .maybeSingle();

      if (activeBreak == null) return;

      await _client.from('staff_breaks').update({
        'end_time': now.toIso8601String(),
        'status': 'completed',
        'sync_status': 'synced',
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

  /// Get current break
  Future<Map<String, dynamic>?> getCurrentBreak(String staffId) async {
    return await _client
        .from('staff_breaks')
        .select()
        .eq('staff_id', staffId)
        .eq('status', 'in_progress')
        .order('start_time', ascending: false)
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
        .filter('start_time', 'gte', today)
        .order('start_time', ascending: false);
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
        .filter('collection_time', 'gte', dateStr)
        .filter('collection_time', 'lt', '${dateStr}T23:59:59');

    // Get visits for the date
    final visits = await _client
        .from('visit_logs')
        .select()
        .eq('staff_id', staffId)
        .filter('check_in_at', 'gte', dateStr)
        .filter('check_in_at', 'lt', '${dateStr}T23:59:59');

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
          .select()
          .eq('staff_id', staffId)
          .eq('status', 'in_progress')
          .order('check_in_at', ascending: false)
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
