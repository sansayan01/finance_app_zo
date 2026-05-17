import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../models/subscription_plan_model.dart';
import '../models/org_subscription_model.dart';
import '../models/invoice_model.dart';
import '../repositories/billing_repository.dart';

// Repository provider
final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return BillingRepository(client);
});

// All available plans
final subscriptionPlansProvider =
    FutureProvider<List<SubscriptionPlanModel>>((ref) async {
  final repository = ref.watch(billingRepositoryProvider);
  return repository.getPlans();
});

// Current org subscription
final currentSubscriptionProvider =
    FutureProvider<OrgSubscriptionModel?>((ref) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return null;

  final repository = ref.watch(billingRepositoryProvider);
  return repository.getSubscription(orgId);
});

// Subscription status with usage
final subscriptionStatusProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return {};

  final repository = ref.watch(billingRepositoryProvider);
  return repository.getSubscriptionStatus(orgId);
});

// Limit check provider
final limitCheckProvider =
    FutureProvider.family<bool, String>((ref, limitType) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return false;

  final repository = ref.watch(billingRepositoryProvider);
  return repository.checkLimit(orgId, limitType);
});

// Org invoices
final orgInvoicesProvider = FutureProvider<List<InvoiceModel>>((ref) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return [];

  final repository = ref.watch(billingRepositoryProvider);
  return repository.getInvoices(orgId);
});

// Payment methods
final paymentMethodsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return [];

  final repository = ref.watch(billingRepositoryProvider);
  return repository.getPaymentMethods(orgId);
});

// Billing action notifier
class BillingNotifier extends StateNotifier<AsyncValue<void>> {
  final BillingRepository _repository;
  final Ref _ref;

  BillingNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  /// Create checkout session and return URL
  Future<String?> createCheckout({
    required String planId,
    required String billingCycle,
  }) async {
    state = const AsyncValue.loading();
    try {
      final orgId = _ref.read(currentOrgIdProvider);
      if (orgId == null) throw Exception('No organization selected');

      final url = await _repository.createCheckoutSession(
        orgId: orgId,
        planId: planId,
        billingCycle: billingCycle,
        successUrl: 'https://sansayan01.zo.space/billing/success',
        cancelUrl: 'https://sansayan01.zo.space/billing',
      );

      state = const AsyncValue.data(null);
      return url;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Cancel subscription
  Future<bool> cancelSubscription() async {
    state = const AsyncValue.loading();
    try {
      final subscription = await _ref.read(currentSubscriptionProvider.future);
      if (subscription == null) throw Exception('No active subscription');

      await _repository.cancelSubscription(subscription.id);
      _ref.invalidate(currentSubscriptionProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Reactivate subscription
  Future<bool> reactivateSubscription() async {
    state = const AsyncValue.loading();
    try {
      final subscription = await _ref.read(currentSubscriptionProvider.future);
      if (subscription == null) throw Exception('No subscription found');

      await _repository.reactivateSubscription(subscription.id);
      _ref.invalidate(currentSubscriptionProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Update plan
  Future<bool> updatePlan({
    required String planId,
    String billingCycle = 'monthly',
  }) async {
    state = const AsyncValue.loading();
    try {
      final subscription = await _ref.read(currentSubscriptionProvider.future);
      if (subscription == null) throw Exception('No subscription found');

      await _repository.updatePlan(
        subscriptionId: subscription.id,
        newPlanId: planId,
        billingCycle: billingCycle,
      );

      _ref.invalidate(currentSubscriptionProvider);
      _ref.invalidate(subscriptionStatusProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Set default payment method
  Future<bool> setDefaultPaymentMethod(String paymentMethodId) async {
    state = const AsyncValue.loading();
    try {
      final orgId = _ref.read(currentOrgIdProvider);
      if (orgId == null) throw Exception('No organization selected');

      await _repository.setDefaultPaymentMethod(orgId, paymentMethodId);
      _ref.invalidate(paymentMethodsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Delete payment method
  Future<bool> deletePaymentMethod(String paymentMethodId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deletePaymentMethod(paymentMethodId);
      _ref.invalidate(paymentMethodsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final billingNotifierProvider =
    StateNotifierProvider<BillingNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(billingRepositoryProvider);
  return BillingNotifier(repository, ref);
});
