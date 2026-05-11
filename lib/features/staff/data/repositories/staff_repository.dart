import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/staff_profile_model.dart';
import '../models/wallet_model.dart';
import '../models/streak_model.dart';
import '../models/target_model.dart';

class StaffRepository {
  final SupabaseClient _client;

  StaffRepository(this._client);

  /// Get current staff profile from user ID
  Future<StaffProfileModel?> getStaffProfile(String userId) async {
    try {
      final response = await _client
          .from('staff_profiles')
          .select('''
            *,
            branches(name),
            supervisor:staff_profiles!supervisor_id(full_name)
          ''')
          .eq('user_id', userId)
          .single();

      return StaffProfileModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Get staff profile by staff ID
  Future<StaffProfileModel?> getStaffById(String staffId) async {
    try {
      final response = await _client
          .from('staff_profiles')
          .select('''
            *,
            branches(name),
            supervisor:staff_profiles!supervisor_id(full_name)
          ''')
          .eq('id', staffId)
          .single();

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
          .eq('id', staffId)
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
  }
}
