import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import 'package:microflow_pro/core/constants/enums.dart';
import '../models/collection_model.dart';
import '../repositories/collection_repository.dart';
import 'staff_providers.dart';
import 'sync_providers.dart';

import '../../../../core/providers/org_provider.dart';

// Collection repository provider
final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return CollectionRepository(client, orgId);
});

// Today's due EMIs
final todayDueEmisProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return [];

  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getTodayDueEmis(profile.id);
});

// Alias for CollectionListPage
final todayEmisProvider = todayDueEmisProvider;

// Overdue EMIs
final overdueEmisProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return [];

  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getOverdueEmis(profile.id);
});

// Today's collections
final todayCollectionsProvider =
    FutureProvider<List<CollectionModel>>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return [];

  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getTodayCollections(profile.id);
});

// Today's collection stats (Aliased for StaffHomeDashboard)
final todayCollectionStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
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

// Legacy alias
final todayStatsProvider = todayCollectionStatsProvider;

// Customer detail provider
final customerDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
        (ref, customerId) async {
  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getCustomerDetail(customerId);
});

// Customer search provider
final customerSearchProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, query) async {
  if (query.isEmpty) return [];
  final repository = ref.watch(collectionRepositoryProvider);
  return repository.searchCustomers(query);
});

// Customer loans provider
final customerLoansProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, customerId) async {
  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getCustomerLoans(customerId);
});

// Customer savings provider
final customerSavingsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, customerId) async {
  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getCustomerSavings(customerId);
});

// Recent searches provider (Local storage logic should be added here later if needed)
final recentSearchesProvider = StateProvider<List<String>>((ref) => []);

// Collection history with filters
typedef HistoryParams = ({
  String? staffId,
  String? customerId,
  int? year,
  int? month,
  String? type,
  String? paymentMode,
});

final collectionHistoryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, HistoryParams>(
        (ref, params) async {
  final profile = await ref.watch(staffProfileProvider.future);
  final staffId = params.staffId ?? profile?.id;

  if (staffId == null) return [];

  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getCollectionHistory(
    staffId,
    customerId: params.customerId,
    year: params.year,
    month: params.month,
    type: params.type,
    paymentMode: params.paymentMode,
  );
});

// Recent collections
final recentCollectionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return [];

  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getRecentCollections(profile.id);
});

// Frequent customers
final frequentCustomersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return [];

  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getFrequentCustomers(profile.id);
});

// Collection Notifier for recording new collections
class CollectionNotifier extends StateNotifier<AsyncValue<CollectionModel?>> {
  final CollectionRepository _repository;
  final SyncStatusNotifier _syncNotifier;

  CollectionNotifier(this._repository, this._syncNotifier)
      : super(const AsyncValue.data(null));

  Future<void> recordCollection({
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
      try {
        final result = await _repository.recordCollection(
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
          paymentMode: paymentMode,
          referenceNumber: referenceNumber,
          gpsLat: gpsLat,
          gpsLng: gpsLng,
          gpsAccuracy: gpsAccuracy,
          gpsAddress: gpsAddress,
          remarks: remarks,
        );
        state = AsyncValue.data(result);
      } catch (e) {
        // Fallback to offline queue
        await _syncNotifier.queueOperation(
          operation: 'INSERT',
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
            'payment_mode': paymentMode.name,
            'reference_number': referenceNumber,
            'gps_lat': gpsLat,
            'gps_lng': gpsLng,
            'gps_accuracy': gpsAccuracy,
            'gps_address': gpsAddress,
            'remarks': remarks,
            'collection_date':
                DateTime.now().toIso8601String().split('T').first,
            'collection_time': DateTime.now().toUtc().toIso8601String(),
            'sync_status': 'pending',
          },
        );

        // Return a local model for the offline queued collection
        final now = DateTime.now();
        state = AsyncValue.data(CollectionModel(
          id: 'offline_${now.millisecondsSinceEpoch}',
          staffId: staffId,
          memberName: memberName,
          memberPhone: memberPhone,
          loanNumber: loanNumber,
          amountCollected: amountCollected,
          amountExpected: amountExpected,
          paymentMode: paymentMode,
          gpsLat: gpsLat,
          gpsLng: gpsLng,
          gpsAccuracy: gpsAccuracy,
          gpsAddress: gpsAddress,
          collectionDate: now,
          collectionTime: now,
          createdAt: now,
          updatedAt: now,
          syncStatus: SyncState.pending,
        ));
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final collectionNotifierProvider =
    StateNotifierProvider<CollectionNotifier, AsyncValue<CollectionModel?>>(
        (ref) {
  final repository = ref.watch(collectionRepositoryProvider);
  final syncNotifier = ref.watch(syncStatusProvider.notifier);
  return CollectionNotifier(repository, syncNotifier);
});
