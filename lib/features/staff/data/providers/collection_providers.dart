import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateUtils;
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
  if (profile == null || profile.branchId == null) return [];

  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getTodayDueEmis(profile.id, profile.branchId!);
});

// Alias for CollectionListPage
final todayEmisProvider = todayDueEmisProvider;

// Overdue EMIs
final overdueEmisProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null || profile.branchId == null) return [];

  final repository = ref.watch(collectionRepositoryProvider);
  return repository.getOverdueEmis(profile.id, profile.branchId!);
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

  /// Enqueues an SMS via the durable-outbox notifier.
  void _sendSms(CollectionModel collection) async {
    try {
      final staffProfile = await _ref.read(staffProfileProvider.future);
      final branding = _ref.read(brandingProvider).valueOrNull;
      final collectorName = staffProfile?.fullName ?? 'Staff';

      // Fallback: fetch phone from members table if not in collection model
      String? phone = collection.memberPhone;
      if ((phone == null || phone.isEmpty) && collection.memberId != null) {
        try {
          final client = _ref.read(supabaseClientProvider);
          final memberInfo = await client
              .from('members')
              .select('phone')
              .eq('id', collection.memberId!)
              .maybeSingle();
          phone = memberInfo?['phone']?.toString();
        } catch (_) {}
      }

      await _ref.read(collectionSmsSenderProvider.notifier).enqueueCollection(
        phone: phone,
        memberId: collection.memberId,
        memberName: collection.memberName,
        loanNumber: collection.loanNumber,
        amount: collection.amountCollected,
        outstandingBalance: collection.amountExpected,
        collectorName: collectorName,
        sentBy: collection.staffId,
        orgName: branding?.displayName,
      );
    } catch (e) {
      debugPrint('SMS dispatch error: $e');
    }
  }

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
    DateTime? collectionDate,
    DateTime? collectionTime,
    String? backdateReason,
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
          collectionDate: collectionDate,
          collectionTime: collectionTime,
          backdateReason: backdateReason,
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
        _sendSms(result);

        // Log activity for timeline (non-blocking)
        _logActivity(
          staffId: staffId,
          entityId: result.id,
          amount: amountCollected,
          memberName: memberName,
          paymentMode: paymentMode.name,
        );
      } catch (e) {
        // Fallback to offline queue
        final staffProfile = await _ref.read(staffProfileProvider.future);
        final orgId = _ref.read(currentOrgIdProvider);
        final now = DateTime.now();
        final effectiveDate = collectionDate ?? now;
        final effectiveTime = collectionTime ?? effectiveDate;
        final isBackdated = !DateUtils.isSameDay(effectiveDate, now);

        await _syncNotifier.queueOperation(
          operation: 'INSERT',
          table: 'collections',
          data: {
            'org_id': orgId,
            'branch_id': staffProfile?.branchId,
            'staff_id': staffId,
            'collected_by_user_id': staffProfile?.userId ?? staffId,
            'collected_by_name': staffProfile?.fullName ?? '',
            'collected_by_role': staffProfile?.role.dbValue ?? 'collectionAgent',
            'collected_at': now.toIso8601String(),
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
                effectiveDate.toIso8601String().split('T').first,
            'collection_time':
                '${effectiveTime.hour.toString().padLeft(2, '0')}:${effectiveTime.minute.toString().padLeft(2, '0')}:${effectiveTime.second.toString().padLeft(2, '0')}',
            'is_backdated': isBackdated ? true : null,
            'backdate_reason': isBackdated ? backdateReason : null,
            'sync_status': 'pending',
          },
        );

        // Return a local model for the offline queued collection
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
          collectionDate: effectiveDate,
          collectionTime: effectiveTime,
          createdAt: now,
          updatedAt: now,
          syncStatus: SyncState.pending,
        ));
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Logs collection activity to activity_logs for the timeline. Never blocks collection flow.
  void _logActivity({
    required String staffId,
    required String entityId,
    required double amount,
    required String memberName,
    required String paymentMode,
  }) async {
    try {
      final client = _ref.read(supabaseClientProvider);
      final orgId = _ref.read(currentOrgIdProvider);

      await client.from('activity_logs').insert({
        'org_id': orgId,
        'staff_id': staffId,
        'action': 'collection_recorded',
        'entity_type': 'collection',
        'entity_id': entityId,
        'details': 'Collected Rs${amount.toStringAsFixed(0)} from $memberName',
        'metadata': {
          'amount': amount,
          'member_name': memberName,
          'payment_mode': paymentMode,
        },
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Failed to log activity: $e');
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
