import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../repositories/customer_feedback_repository.dart';
import '../models/customer_feedback_model.dart';
import 'customer_member_provider.dart';

final customerFeedbackRepositoryProvider =
    Provider<CustomerFeedbackRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return CustomerFeedbackRepository(client, orgId);
});

final customerFeedbackProvider =
    FutureProvider<List<CustomerFeedbackModel>>((ref) async {
  final customerId = ref.watch(currentCustomerIdSyncProvider);
  if (customerId == null) return [];
  final repository = ref.watch(customerFeedbackRepositoryProvider);
  return repository.getFeedbacks(customerId);
});

class CreateFeedbackNotifier extends StateNotifier<AsyncValue<void>> {
  final CustomerFeedbackRepository _repository;
  final Ref _ref;

  CreateFeedbackNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  Future<bool> submitFeedback({
    required String customerId,
    required String type,
    String? subject,
    required String message,
    int? rating,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.submitFeedback(
        customerId: customerId,
        type: type,
        subject: subject,
        message: message,
        rating: rating,
      );
      _ref.invalidate(customerFeedbackProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final createFeedbackProvider =
    StateNotifierProvider<CreateFeedbackNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(customerFeedbackRepositoryProvider);
  return CreateFeedbackNotifier(repository, ref);
});
