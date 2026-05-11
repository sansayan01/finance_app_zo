import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../../core/providers/storage_providers.dart';
import '../models/collection_model.dart';
import '../repositories/collection_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'staff_providers.dart';
import '../../presentation/providers/sync_status_provider.dart';

// Repository provider
final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return CollectionRepository(client);
});

// Connectivity provider
final isOnlineProvider = FutureProvider<bool>((ref) async {
  final checker = InternetConnectionChecker();
  return checker.hasConnection;
});

// Connectivity stream provider
final connectivityStreamProvider = StreamProvider<bool>((ref) {
  final checker = InternetConnectionChecker();
  return checker.onStatusChange.map((status) => status == InternetConnectionStatus.connected);
});

// =====================================================
// OFFLINE SYNC ENGINE PROVIDER
// =====================================================

class OfflineSyncNotifier extends StateNotifier<SyncStatus> {
  final SharedPreferences _prefs;
  final Ref _ref;
  static const String _queueKey = 'offline_queue';

  OfflineSyncNotifier(this._prefs, this._ref) : super(const SyncStatus()) {
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    final queue = _getQueue();
    state = state.copyWith(pending: queue.length);
  }

  List<Map<String, dynamic>> _getQueue() {
    final json = _prefs.getString(_queueKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> _saveQueue(List<Map<String, dynamic>> queue) async {
    await _prefs.setString(_queueKey, jsonEncode(queue));
  }

  Future<void> queueOperation({
    required String operation,
    required String table,
    required Map<String, dynamic> data,
  }) async {
    final queue = _getQueue();
    final operationId = 'op_${DateTime.now().millisecondsSinceEpoch}';
    
    queue.add({
      'id': operationId,
      'operation': operation,
      'table': table,
      'data': data,
      'created_at': DateTime.now().toIso8601String(),
      'attempts': 0,
    });

    await _saveQueue(queue);
    state = state.copyWith(pending: queue.length);
  }

  Future<void> syncPendingOperations() async {
    if (state.isSyncing) return;
    
    final isOnline = await InternetConnectionChecker().hasConnection;
    if (!isOnline) {
      _ref.read(syncStatusProvider.notifier).updateOnline(false);
      return;
    }

    _ref.read(syncStatusProvider.notifier).updateOnline(true);
    state = state.copyWith(isSyncing: true);
    _ref.read(syncStatusProvider.notifier).updateSyncing(true);

    final queue = _getQueue();
    final client = _ref.read(supabaseClientProvider);
    final List<String> successIds = [];
    final List<String> failedIds = [];

    for (final op in queue) {
      try {
        switch (op['operation']) {
          case 'insert':
            await client.from(op['table']).insert(op['data']);
            break;
          case 'update':
            await client
                .from(op['table'])
                .update(op['data']['values'])
                .eq('id', op['data']['id']);
            break;
        }
        successIds.add(op['id']);
        _ref.read(syncStatusProvider.notifier).recordSuccess();
      } catch (e) {
        failedIds.add(op['id']);
        _ref.read(syncStatusProvider.notifier).recordFailure();
        
        // Increment attempts
        final index = queue.indexWhere((q) => q['id'] == op['id']);
        if (index != -1) {
          queue[index]['attempts'] = (queue[index]['attempts'] ?? 0) + 1;
        }
        
        // Remove if too many attempts
        if ((queue[index]['attempts'] ?? 0) >= 5) {
          queue.removeAt(index);
        }
      }
    }

    // Remove successful operations
    final newQueue = queue.where((op) => !successIds.contains(op['id'])).toList();
    await _saveQueue(newQueue);
    
    state = state.copyWith(
      pending: newQueue.length,
      isSyncing: false,
      lastSync: DateTime.now(),
    );
    
    _ref.read(syncStatusProvider.notifier).updateSyncing(false);
    _ref.read(syncStatusProvider.notifier).updatePending(newQueue.length);

    // Refresh data after sync
    if (successIds.isNotEmpty) {
      _ref.invalidate(todayCollectionsProvider);
      _ref.invalidate(todayCollectionStatsProvider);
      _ref.invalidate(staffWalletProvider);
    }
  }

  Future<void> clearQueue() async {
    await _prefs.remove(_queueKey);
    state = state.copyWith(pending: 0);
    _ref.read(syncStatusProvider.notifier).updatePending(0);
  }

  List<Map<String, dynamic>> getPendingOperations() => _getQueue();
}

final offlineSyncProvider =
    StateNotifierProvider<OfflineSyncNotifier, SyncStatus>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return OfflineSyncNotifier(prefs, ref);
});

// =====================================================
// TODAY'S DATA PROVIDERS
// =====================================================

// Today's due EMIs
final todayDueEmisProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return [];

  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getTodayDueEmis(profile.id);
});

// Overdue EMIs
final overdueEmisProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return [];

  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getOverdueEmis(profile.id);
});

// Today's collections
final todayCollectionsProvider = FutureProvider<List<CollectionModel>>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return [];

  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getTodayCollections(profile.id);
});

// Today's EMIs (alias for compatibility)
final todayEmisProvider = todayDueEmisProvider;

// Recent collections
final recentCollectionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return [];

  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getRecentCollections(profile.id, limit: 20);
});

// Collection history with parameters
final collectionHistoryProvider = FutureProvider.family<List<Map<String, dynamic>>,
    ({String? staffId, String? customerId, int? year, int? month, String? type, String? paymentMode})>(
    (ref, params) async {
  final repository = ref.watch(collectionRepositoryProvider);
  
  final staffId = params.staffId ?? await ref.watch(currentStaffIdProvider.future);
  if (staffId == null) return [];

  return repository.getCollectionHistory(
    staffId,
    customerId: params.customerId,
    year: params.year,
    month: params.month,
    type: params.type,
    paymentMode: params.paymentMode,
  );
});

// Current staff ID helper
final currentStaffIdProvider = FutureProvider<String?>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  return profile?.id;
});

// Today's stats
final todayCollectionStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) {
    return {
      'total_collected': 0.0,
      'cash_collected': 0.0,
      'digital_collected': 0.0,
      'collection_count': 0,
    };
  }

  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getTodayStats(profile.id);
});

// =====================================================
// CUSTOMER DATA PROVIDERS
// =====================================================

// Customer search
final customerSearchProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
    (ref, query) async {
  if (query.isEmpty) return [];

  final repository = ref.watch(collectionRepositoryProvider);
  return repository.searchCustomers(query);
});

// Customer detail
final customerDetailProvider = FutureProvider.family<Map<String, dynamic>, String>(
    (ref, customerId) async {
  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getCustomerDetail(customerId);
});

// Customer loans
final customerLoansProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
    (ref, customerId) async {
  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getCustomerLoans(customerId);
});

// Customer savings
final customerSavingsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
    (ref, customerId) async {
  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getCustomerSavings(customerId);
});

// Customer collection history
final customerCollectionHistoryProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
    (ref, customerId) async {
  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getCustomerCollectionHistory(customerId, limit: 50);
});

// Frequent customers
final frequentCustomersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return [];

  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getFrequentCustomers(profile.id, limit: 10);
});

// =====================================================
// RECENT SEARCHES NOTIFIER
// =====================================================

class RecentSearchesNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  RecentSearchesNotifier() : super([]);

  void addSearch(String query, int resultCount) {
    state = [
      {
        'query': query,
        'result_count': resultCount,
        'searched_at': DateTime.now().toIso8601String(),
      },
      ...state.where((s) => s['query'] != query),
    ].take(10).toList();
  }

  void clear() {
    state = [];
  }
}

final recentSearchesProvider = StateNotifierProvider<RecentSearchesNotifier, List<Map<String, dynamic>>>(
    (ref) => RecentSearchesNotifier());

// =====================================================
// COLLECTION NOTIFIER WITH OFFLINE SUPPORT
// =====================================================

class CollectionNotifier extends StateNotifier<AsyncValue<CollectionModel?>> {
  final CollectionRepository _repository;
  final Ref _ref;

  CollectionNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  /// Record a collection - supports both online and offline
  Future<CollectionModel?> recordCollection({
    required String staffId,
    String? loanId,
    String? loanScheduleId,
    String? memberId,
    required String memberName,
    String? memberPhone,
    String? loanNumber,
    required double amountExpected,
    required double amountCollected,
    bool isPartial = false,
    bool isAdvance = false,
    required PaymentMode paymentMode,
    String? referenceNumber,
    required double gpsLat,
    required double gpsLng,
    double? gpsAccuracy,
    String? gpsAddress,
    String? remarks,
  }) async {
    state = const AsyncValue.loading();

    try {
      // Check connectivity
      final isOnline = await InternetConnectionChecker().hasConnection;
      
      // Create local collection model
      final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now();
      
      final collection = CollectionModel(
        id: localId,
        staffId: staffId,
        loanId: loanId,
        loanScheduleId: loanScheduleId,
        memberId: memberId,
        memberName: memberName,
        memberPhone: memberPhone,
        loanNumber: loanNumber,
        amountExpected: amountExpected,
        amountCollected: amountCollected,
        isPartial: isPartial,
        isAdvance: isAdvance,
        paymentMode: paymentMode,
        referenceNumber: referenceNumber,
        gpsLat: gpsLat,
        gpsLng: gpsLng,
        gpsAccuracy: gpsAccuracy,
        gpsAddress: gpsAddress,
        collectionDate: now,
        collectionTime: now,
        syncStatus: isOnline ? SyncStatus.synced : SyncStatus.pending,
        remarks: remarks,
        createdAt: now,
        updatedAt: now,
      );

      if (isOnline) {
        // Online - send to Supabase immediately
        final serverCollection = await _repository.recordCollection(
          staffId: staffId,
          loanId: loanId,
          loanScheduleId: loanScheduleId,
          memberId: memberId,
          memberName: memberName,
          memberPhone: memberPhone,
          loanNumber: loanNumber,
          amountExpected: amountExpected,
          amountCollected: amountCollected,
          isPartial: isPartial,
          isAdvance: isAdvance,
          paymentMode: paymentMode,
          referenceNumber: referenceNumber,
          gpsLat: gpsLat,
          gpsLng: gpsLng,
          gpsAccuracy: gpsAccuracy,
          gpsAddress: gpsAddress,
          remarks: remarks,
        );

        state = AsyncValue.data(serverCollection);

        // Update sync status
        _ref.read(syncStatusProvider.notifier).recordSuccess();

        // Invalidate related providers to refresh data
        _invalidateProviders();
        
        return serverCollection;
      } else {
        // Offline - queue for later sync
        await _ref.read(offlineSyncProvider.notifier).queueOperation(
          operation: 'insert',
          table: 'collections',
          data: {
            'staff_id': staffId,
            'loan_id': loanId,
            'loan_schedule_id': loanScheduleId,
            'member_id': memberId,
            'member_name': memberName,
            'member_phone': memberPhone,
            'loan_number': loanNumber,
            'amount_expected': amountExpected,
            'amount_collected': amountCollected,
            'is_partial': isPartial,
            'is_advance': isAdvance,
            'payment_mode': paymentMode.name,
            'reference_number': referenceNumber,
            'gps_lat': gpsLat,
            'gps_lng': gpsLng,
            'gps_accuracy': gpsAccuracy,
            'gps_address': gpsAddress,
            'collection_date': now.toIso8601String(),
            'collection_time': now.toIso8601String(),
            'sync_status': 'pending',
            'remarks': remarks,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
        );

        // Update offline status
        _ref.read(syncStatusProvider.notifier)
          ..updateOnline(false)
          ..addPending(1);

        // Return local collection
        state = AsyncValue.data(collection);
        
        return collection;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  void _invalidateProviders() {
    _ref.invalidate(todayCollectionsProvider);
    _ref.invalidate(todayCollectionStatsProvider);
    _ref.invalidate(staffWalletProvider);
    _ref.invalidate(todayTargetProvider);
    _ref.invalidate(staffStreakProvider);
    _ref.invalidate(todayDueEmisProvider);
    _ref.invalidate(recentCollectionsProvider);
  }

  /// Manually trigger sync
  Future<void> syncPending() async {
    await _ref.read(offlineSyncProvider.notifier).syncPendingOperations();
    _invalidateProviders();
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

// Collection notifier provider
final collectionNotifierProvider =
    StateNotifierProvider<CollectionNotifier, AsyncValue<CollectionModel?>>((ref) {
  final repository = ref.watch(collectionRepositoryProvider);
  return CollectionNotifier(repository, ref);
});

// Overdue collections (alias for compatibility)
final overdueCollectionsProvider = overdueEmisProvider;
