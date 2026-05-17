import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subscription_plan_model.dart';
import '../models/org_subscription_model.dart';
import '../models/invoice_model.dart';

/// Billing repository for subscription management
class BillingRepository {
  final SupabaseClient _client;

  BillingRepository(this._client);

  // ==================== PLANS ====================

  /// Get all available plans
  Future<List<SubscriptionPlanModel>> getPlans() async {
    final response = await _client
        .from('subscription_plans')
        .select()
        .eq('is_active', true)
        .order('sort_order');

    return response
        .map<SubscriptionPlanModel>(
            (json) => SubscriptionPlanModel.fromJson(json))
        .toList();
  }

  /// Get plan by ID
  Future<SubscriptionPlanModel?> getPlan(String planId) async {
    final response = await _client
        .from('subscription_plans')
        .select()
        .eq('id', planId)
        .maybeSingle();

    if (response == null) return null;
    return SubscriptionPlanModel.fromJson(response);
  }

  // ==================== SUBSCRIPTION ====================

  /// Get current subscription for org
  Future<OrgSubscriptionModel?> getSubscription(String orgId) async {
    final response = await _client.from('subscriptions').select('''
          *,
          plan_name:subscription_plans(name)
        ''').eq('org_id', orgId).maybeSingle();

    if (response == null) return null;

    // Flatten plan_name
    return OrgSubscriptionModel.fromJson({
      ...response,
      'plan_name': response['plan_name']?['name'],
    });
  }

  /// Get subscription status with usage
  Future<Map<String, dynamic>> getSubscriptionStatus(String orgId) async {
    final response = await _client.rpc('get_subscription_status',
        params: {'p_org_id': orgId}).maybeSingle();

    return response ?? {};
  }

  /// Check if limit reached for a resource
  Future<bool> checkLimit(String orgId, String limitType) async {
    final response = await _client.rpc('check_subscription_limit', params: {
      'p_org_id': orgId,
      'p_limit_type': limitType,
    });

    return response as bool? ?? false;
  }

  /// Create checkout session for plan upgrade
  Future<String?> createCheckoutSession({
    required String orgId,
    required String planId,
    required String billingCycle,
    String? successUrl,
    String? cancelUrl,
  }) async {
    // This would call a Supabase Edge Function that creates a Stripe checkout
    try {
      final response = await _client.functions.invoke(
        'create-checkout-session',
        body: {
          'org_id': orgId,
          'plan_id': planId,
          'billing_cycle': billingCycle,
          'success_url': successUrl,
          'cancel_url': cancelUrl,
        },
      );

      if (response.status == 200) {
        return response.data['checkout_url'] as String?;
      }
      return null;
    } catch (e) {
      // For now, return null - checkout would integrate with Edge Function
      return null;
    }
  }

  /// Cancel subscription at period end
  Future<void> cancelSubscription(String subscriptionId) async {
    await _client.from('subscriptions').update({
      'cancel_at_period_end': true,
      'canceled_at': DateTime.now().toIso8601String(),
    }).eq('id', subscriptionId);
  }

  /// Reactivate canceled subscription
  Future<void> reactivateSubscription(String subscriptionId) async {
    await _client.from('subscriptions').update({
      'cancel_at_period_end': false,
      'canceled_at': null,
    }).eq('id', subscriptionId);
  }

  /// Update subscription plan (upgrade/downgrade)
  Future<void> updatePlan({
    required String subscriptionId,
    required String newPlanId,
    String billingCycle = 'monthly',
  }) async {
    await _client.from('subscriptions').update({
      'plan_id': newPlanId,
      'billing_cycle': billingCycle,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', subscriptionId);
  }

  // ==================== INVOICES ====================

  /// Get invoices for org
  Future<List<InvoiceModel>> getInvoices(
    String orgId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _client
        .from('invoices')
        .select()
        .eq('org_id', orgId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return response
        .map<InvoiceModel>((json) => InvoiceModel.fromJson(json))
        .toList();
  }

  /// Get single invoice
  Future<InvoiceModel?> getInvoice(String invoiceId) async {
    final response = await _client
        .from('invoices')
        .select()
        .eq('id', invoiceId)
        .maybeSingle();

    if (response == null) return null;
    return InvoiceModel.fromJson(response);
  }

  /// Download invoice PDF
  Future<String?> getInvoicePdf(String invoiceId) async {
    final response = await _client
        .from('invoices')
        .select('invoice_pdf')
        .eq('id', invoiceId)
        .maybeSingle();

    return response?['invoice_pdf'] as String?;
  }

  // ==================== PAYMENT METHODS ====================

  /// Get payment methods for org
  Future<List<Map<String, dynamic>>> getPaymentMethods(String orgId) async {
    final response = await _client
        .from('payment_methods')
        .select()
        .eq('org_id', orgId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Set default payment method
  Future<void> setDefaultPaymentMethod(
      String orgId, String paymentMethodId) async {
    // Unset current default
    await _client
        .from('payment_methods')
        .update({'is_default': false})
        .eq('org_id', orgId)
        .eq('is_default', true);

    // Set new default
    await _client
        .from('payment_methods')
        .update({'is_default': true}).eq('id', paymentMethodId);
  }

  /// Delete payment method
  Future<void> deletePaymentMethod(String paymentMethodId) async {
    await _client.from('payment_methods').delete().eq('id', paymentMethodId);
  }

  // ==================== USAGE ====================

  /// Get usage history for org
  Future<List<Map<String, dynamic>>> getUsageHistory(
    String orgId, {
    int months = 6,
  }) async {
    final startDate = DateTime.now().subtract(Duration(days: months * 30));

    final response = await _client
        .from('usage_records')
        .select()
        .eq('org_id', orgId)
        .gte('period_start', startDate.toIso8601String())
        .order('period_start', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }
}
