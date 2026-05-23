import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/staff_repository.dart';
import 'staff_providers.dart';

final visitCheckInProvider =
    StateNotifierProvider.autoDispose<VisitCheckInNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(staffRepositoryProvider);
  return VisitCheckInNotifier(ref, repository);
});

class VisitCheckInNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final StaffRepository _repository;

  VisitCheckInNotifier(this._ref, this._repository)
      : super(const AsyncValue.data(null));

  Future<bool> checkIn({
    required String staffId,
    String? customerId,
    required String purpose,
    required double lat,
    required double lng,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.logVisit(
        staffId: staffId,
        customerId: customerId,
        purpose: purpose,
        checkInLat: lat,
        checkInLng: lng,
        notes: notes,
      );
      state = const AsyncValue.data(null);
      _ref.invalidate(activeVisitProvider);
      _ref.invalidate(recentActivitiesProvider);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> checkOut({
    required String staffId,
    required double lat,
    required double lng,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.completeVisit(
        staffId: staffId,
        checkOutLat: lat,
        checkOutLng: lng,
      );
      state = const AsyncValue.data(null);
      _ref.invalidate(activeVisitProvider);
      _ref.invalidate(recentActivitiesProvider);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}
