import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import 'package:microflow_pro/core/constants/enums.dart';
import '../models/collection_model.dart';
import '../repositories/collection_repository.dart';
import 'staff_providers.dart';
import 'sync_providers.dart';

import '../../../../core/providers/branding_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../../core/providers/sms_provider.dart';
import '../../../home/data/providers/dashboard_providers.dart' show dashboardLoansProvider, loanSummaryProvider, todayAgendaProvider;

// Collection repository provider
final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return CollectionRepository(client, orgId);
});

// Today's due EMIs
final todayDueEmisProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return [];

  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getTodayDueEmis(profile.id);
});

// Alias for CollectionListPage
final todayEmisProvider = todayDueEmisProvider;

// Overdue EMIs
final overdueEmisProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return [];

  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getOverdueEmis(profile.id);
});

// Today's collections
final todayCollectionsProvider =
    FutureProvider.autoDispose<List<CollectionModel>>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return [];

  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getTodayCollections(profile.id);
});

// Today's collection stats (Aliased for StaffHomeDashboard)
final todayCollectionStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
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
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>(
        (ref, customerId) async {
  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getCustomerDetail(customerId);
});

// Customer search provider
final customerSearchProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, query) async {
  if (query.isEmpty) return [];
  final repository = ref.watch(collectionRepositoryProvider);
  return repository.searchCustomers(query);
});

// Customer loans provider
final customerLoansProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, customerId) async {
  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getCustomerLoans(customerId);
});

// Customer savings provider
final customerSavingsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, customerId) async {
  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getCustomerSavings(customerId);
});

// Recent searches provider (Local storage logic should be added here later if needed)
final recentSearchesProvider = StateProvider.autoDispose<List<String>>((ref) => []);

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
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, HistoryParams>(
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
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return [];

  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getRecentCollections(profile.id);
});

// Frequent customers
final frequentCustomersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return [];

  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getFrequentCustomers(profile.id);
});

// Collection Notifier for recording new collections
class CollectionNotifier extends StateNotifier<AsyncValue<CollectionModel?>> {
  final CollectionRepository _repository;
  final SyncStatusNotifier _syncNotifier;
  final Ref _ref;

  CollectionNotifier(this._ref, this._repository, this._syncNotifier)
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
    double? outstandingBalance,
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

        // Invalidate all related providers for real-time UI updates
        _ref.invalidate(todayDueEmisProvider);
        _ref.invalidate(todayCollectionsProvider);
        _ref.invalidate(todayCollectionStatsProvider);
        _ref.invalidate(recentCollectionsProvider);
        _ref.invalidate(staffWalletProvider);
        _ref.invalidate(dashboardLoansProvider);
        _ref.invalidate(loanSummaryProvider);
        _ref.invalidate(todayStatsProvider);
        _ref.invalidate(todayAgendaProvider);

        // Fire SMS notification in background (non-blocking)
        _sendSmsNotification(
          collectionId: result.id,
          memberId: memberId,
          memberPhone: memberPhone,
          loanNumber: loanNumber,
          amountCollected: amountCollected,
          outstandingBalance: outstandingBalance,
        );
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
            'collection_time': '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}',
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

  /// Sends SMS notification to customer in background. Never blocks collection flow.
  void _sendSmsNotification({
    required String collectionId,
    String? memberId,
    String? memberPhone,
    String? loanNumber,
    required double amountCollected,
    double? outstandingBalance,
  }) async {
    try {
      if (memberPhone == null || memberPhone.isEmpty) {
        await _logSms(
          collectionId: collectionId,
          memberId: memberId,
          memberPhone: memberPhone,
          message: '',
          status: 'skipped',
          errorMessage: 'No phone number',
        );
        return;
      }

      final smsService = _ref.read(smsServiceProvider);
      final branding = _ref.read(brandingProvider).valueOrNull;
      final orgName = branding?.displayName ?? 'MicroFlow Finance';

      // Get collector name from staff profile
      final staffProfile = await _ref.read(staffProfileProvider.future);
      final collectorName = staffProfile?.fullName ?? 'Staff';

      final balance = outstandingBalance != null
          ? 'Rs${outstandingBalance.toStringAsFixed(0)}'
          : 'N/A';

      final message = smsService.buildCollectionSms(
        amount: 'Rs${amountCollected.toStringAsFixed(0)}',
        collectorName: collectorName,
        orgName: orgName,
        loanNumber: loanNumber ?? 'N/A',
        outstandingBalance: balance,
        date: DateTime.now(),
      );

      final sent = await smsService.sendSms(
        phoneNumber: memberPhone,
        message: message,
      );

      await _logSms(
        collectionId: collectionId,
        memberId: memberId,
        memberPhone: memberPhone,
        message: message,
        status: sent ? 'sent' : 'failed',
      );
    } catch (e) {
      debugPrint('SMS notification error: $e');
      await _logSms(
        collectionId: collectionId,
        memberId: memberId,
        memberPhone: memberPhone,
        message: '',
        status: 'failed',
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _logSms({
    required String collectionId,
    String? memberId,
    String? memberPhone,
    required String message,
    required String status,
    String? errorMessage,
  }) async {
    try {
      final client = _ref.read(supabaseClientProvider);
      final orgId = _ref.read(currentOrgIdProvider);
      final staffProfile = await _ref.read(staffProfileProvider.future);

      await client.from('sms_notifications').insert({
        'org_id': orgId,
        'collection_id': collectionId,
        'member_id': memberId,
        'member_phone': memberPhone ?? '',
        'message': message,
        'status': status,
        'error_message': errorMessage,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'sent_by': staffProfile?.id,
      });
    } catch (e) {
      debugPrint('SMS log error: $e');
    }
  }
}

final collectionNotifierProvider =
    StateNotifierProvider.autoDispose<CollectionNotifier, AsyncValue<CollectionModel?>>(
        (ref) {
  final repository = ref.watch(collectionRepositoryProvider);
  final syncNotifier = ref.watch(syncStatusProvider.notifier);
  return CollectionNotifier(ref, repository, syncNotifier);
});
