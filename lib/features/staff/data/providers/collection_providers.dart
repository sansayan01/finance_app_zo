import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/supabase_provider.dart';
import '../models/collection_model.dart';
import '../repositories/collection_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'staff_providers.dart';

// Repository provider
final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return CollectionRepository(client);
});

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

// Recent searches
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

// Frequent customers
final frequentCustomersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return [];

  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getFrequentCustomers(profile.id, limit: 10);
});

// Notifier for recording collections
class CollectionNotifier extends StateNotifier<AsyncValue<CollectionModel?>> {
  final CollectionRepository _repository;
  final Ref _ref;

  CollectionNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

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
      final collection = await _repository.recordCollection(
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

      state = AsyncValue.data(collection);

      // Invalidate related providers to refresh data
      _ref.invalidate(todayCollectionsProvider);
      _ref.invalidate(todayCollectionStatsProvider);
      _ref.invalidate(staffWalletProvider);
      _ref.invalidate(todayTargetProvider);
      _ref.invalidate(staffStreakProvider);
      _ref.invalidate(todayDueEmisProvider);
      _ref.invalidate(recentCollectionsProvider);

      return collection;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
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
