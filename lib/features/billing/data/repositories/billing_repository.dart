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
    try {
      final response = await _client
          .from('subscription_plans')
          .select('id, name, description, price_monthly, price_yearly, currency, max_members, max_branches, max_staff, max_loans, features, is_active, is_popular, sort_order')
          .eq('is_active', true)
          .order('sort_order');

      return response
          .map<SubscriptionPlanModel>(
              (json) => SubscriptionPlanModel.fromJson(json))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Get plan by ID
  Future<SubscriptionPlanModel?> getPlan(String planId) async {
    try {
      final response = await _client
          .from('subscription_plans')
          .select('id, name, description, price_monthly, price_yearly, currency, max_members, max_branches, max_staff, max_loans, features, is_active, is_popular, sort_order')
          .eq('id', planId)
          .maybeSingle();

      if (response == null) return null;
      return SubscriptionPlanModel.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  // ==================== SUBSCRIPTION ====================

  /// Get current subscription for org
  Future<OrgSubscriptionModel?> getSubscription(String orgId) async {
    try {
      final response = await _client.from('subscriptions').select('''
            id, org_id, plan_id, billing_cycle, status, current_period_start, current_period_end, trial_start, trial_end, cancel_at_period_end, canceled_at, created_at, updated_at,
            plan_name:subscription_plans(name)
          ''').eq('org_id', orgId).maybeSingle();

      if (response == null) return null;

      // Flatten plan_name
      return OrgSubscriptionModel.fromJson({
        ...response,
        'plan_name': response['plan_name']?['name'],
      });
    } catch (_) {
      return null;
    }
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
    try {
      await _client.from('subscriptions').update({
        'cancel_at_period_end': true,
        'canceled_at': DateTime.now().toIso8601String(),
      }).eq('id', subscriptionId);
    } catch (_) {
      // subscriptions table may not exist yet
    }
  }

  /// Reactivate canceled subscription
  Future<void> reactivateSubscription(String subscriptionId) async {
    try {
      await _client.from('subscriptions').update({
        'cancel_at_period_end': false,
        'canceled_at': null,
      }).eq('id', subscriptionId);
    } catch (_) {
      // subscriptions table may not exist yet
    }
  }

  /// Update subscription plan (upgrade/downgrade)
  Future<void> updatePlan({
    required String subscriptionId,
    required String newPlanId,
    String billingCycle = 'monthly',
  }) async {
    try {
      await _client.from('subscriptions').update({
        'plan_id': newPlanId,
        'billing_cycle': billingCycle,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', subscriptionId);
    } catch (_) {
      // subscriptions table may not exist yet
    }
  }

  // ==================== INVOICES ====================

  /// Get invoices for org
  Future<List<InvoiceModel>> getInvoices(
    String orgId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _client
          .from('invoices')
          .select('id, org_id, subscription_id, invoice_number, amount, currency, tax_amount, discount_amount, total_amount, status, invoice_url, invoice_pdf, due_date, paid_at, created_at')
          .eq('org_id', orgId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response
          .map<InvoiceModel>((json) => InvoiceModel.fromJson(json))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Get single invoice
  Future<InvoiceModel?> getInvoice(String invoiceId) async {
    try {
      final response = await _client
          .from('invoices')
          .select('id, org_id, subscription_id, invoice_number, amount, currency, tax_amount, discount_amount, total_amount, status, invoice_url, invoice_pdf, due_date, paid_at, lines, created_at')
          .eq('id', invoiceId)
          .maybeSingle();

      if (response == null) return null;
      return InvoiceModel.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  /// Download invoice PDF
  Future<String?> getInvoicePdf(String invoiceId) async {
    try {
      final response = await _client
          .from('invoices')
          .select('invoice_pdf')
          .eq('id', invoiceId)
          .maybeSingle();

      return response?['invoice_pdf'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ==================== PAYMENT METHODS ====================

  /// Get payment methods for org
  Future<List<Map<String, dynamic>>> getPaymentMethods(String orgId) async {
    try {
      final response = await _client
          .from('payment_methods')
          .select('id, org_id, type, card_brand, card_last4, card_exp_month, card_exp_year, upi_id, bank_name, bank_last4, is_default, is_verified, created_at, updated_at')
          .eq('org_id', orgId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  /// Set default payment method
  Future<void> setDefaultPaymentMethod(
      String orgId, String paymentMethodId) async {
    try {
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
    } catch (_) {
      // payment_methods table may not exist yet
    }
  }

  /// Delete payment method
  Future<void> deletePaymentMethod(String paymentMethodId) async {
    try {
      await _client.from('payment_methods').delete().eq('id', paymentMethodId);
    } catch (_) {
      // payment_methods table may not exist yet
    }
  }

  // ==================== USAGE ====================

  /// Get usage history for org
  Future<List<Map<String, dynamic>>> getUsageHistory(
    String orgId, {
    int months = 6,
  }) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: months * 30));

      final response = await _client
          .from('usage_records')
          .select('id, org_id, period_start, period_end, resource_type, quantity, unit_price, total_cost, created_at')
          .eq('org_id', orgId)
          .gte('period_start', startDate.toIso8601String())
          .order('period_start', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }
}
