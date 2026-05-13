import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/providers/billing_providers.dart';
import '../data/models/subscription_plan_model.dart';
import '../data/models/org_subscription_model.dart';

class BillingPage extends ConsumerWidget {
  const BillingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subscriptionAsync = ref.watch(currentSubscriptionProvider);
    final plansAsync = ref.watch(subscriptionPlansProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing & Plans'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/billing/invoices'),
            icon: const Icon(Icons.receipt_long, size: 18),
            label: const Text('Invoices'),
          ),
        ],
      ),
      body: subscriptionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading subscription: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(currentSubscriptionProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (subscription) => plansAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading plans: $e')),
          data: (plans) => _BillingContent(
            subscription: subscription,
            plans: plans,
          ),
        ),
      ),
    );
  }
}

class _BillingContent extends ConsumerWidget {
  final OrgSubscriptionModel? subscription;
  final List<SubscriptionPlanModel> plans;

  const _BillingContent({
    this.subscription,
    required this.plans,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final billingNotifier = ref.read(billingNotifierProvider.notifier);
    final billingState = ref.watch(billingNotifierProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current subscription card
          if (subscription != null) _CurrentSubscriptionCard(subscription: subscription!),
          
          const SizedBox(height: 32),

          // Plan selection
          Text(
            'Choose a Plan',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the plan that best fits your organization',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),

          // Billing cycle toggle
          _BillingCycleToggle(),
          
          const SizedBox(height: 24),

          // Plans grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              final isCurrentPlan = subscription?.planId == plan.id;
              return _PlanCard(
                plan: plan,
                isCurrentPlan: isCurrentPlan,
                isTrial: subscription?.isTrial ?? false,
                onSelect: () async {
                  if (plan.isEnterprise) {
                    // Show contact sales dialog
                    _showContactSalesDialog(context);
                  } else {
                    // Create checkout
                    final url = await billingNotifier.createCheckout(
                      planId: plan.id,
                      billingCycle: 'monthly',
                    );
                    if (url != null && context.mounted) {
                      // Would open Stripe checkout
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Checkout would open Stripe page'),
                        ),
                      );
                    }
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _showContactSalesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contact Sales'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enterprise plans are customized for your needs.'),
            SizedBox(height: 16),
            Text('📧 Email: sales@microflowpro.com'),
            Text('📞 Phone: +91 9876543210'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Would open email
            },
            child: const Text('Send Email'),
          ),
        ],
      ),
    );
  }
}

class _CurrentSubscriptionCard extends StatelessWidget {
  final OrgSubscriptionModel subscription;

  const _CurrentSubscriptionCard({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Plan',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subscription.planName,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              _StatusBadge(status: subscription.status),
            ],
          ),
          
          if (subscription.isTrial) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${subscription.trialDaysRemaining} days left in trial',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (subscription.cancelAtPeriodEnd) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Cancels at period end',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, text) = switch (status) {
      'active' => (Colors.green, 'Active'),
      'trialing' => (Colors.blue, 'Trial'),
      'past_due' => (Colors.red, 'Past Due'),
      'canceled' => (Colors.grey, 'Canceled'),
      'paused' => (Colors.orange, 'Paused'),
      _ => (Colors.grey, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _BillingCycleToggle extends StatefulWidget {
  @override
  State<_BillingCycleToggle> createState() => _BillingCycleToggleState();
}

class _BillingCycleToggleState extends State<_BillingCycleToggle> {
  bool _isYearly = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(
            label: 'Monthly',
            isSelected: !_isYearly,
            onTap: () => setState(() => _isYearly = false),
          ),
          _ToggleButton(
            label: 'Yearly',
            isSelected: _isYearly,
            badge: 'Save 17%',
            onTap: () => setState(() => _isYearly = true),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final String? badge;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isSelected,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: badge != null ? 8 : 12,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.black : Colors.grey[600],
              ),
            ),
            if (badge != null) ...[
              const SizedBox(height: 2),
              Text(
                badge!,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? Colors.green[700] : Colors.grey[500],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlanModel plan;
  final bool isCurrentPlan;
  final bool isTrial;
  final VoidCallback onSelect;

  const _PlanCard({
    required this.plan,
    required this.isCurrentPlan,
    required this.isTrial,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: plan.isPopular ? theme.colorScheme.primary : Colors.grey[300]!,
          width: plan.isPopular ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (plan.isPopular)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Popular',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                
                const SizedBox(height: 12),
                
                Text(
                  plan.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      plan.formattedMonthly,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '/month',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Features
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: plan.features.take(5).map((feature) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.check, size: 16, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  feature,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // CTA button
                SizedBox(
                  width: double.infinity,
                  child: isCurrentPlan
                      ? OutlinedButton(
                          onPressed: null,
                          child: const Text('Current Plan'),
                        )
                      : ElevatedButton(
                          onPressed: onSelect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: plan.isPopular
                                ? theme.colorScheme.primary
                                : null,
                          ),
                          child: Text(
                            isTrial ? 'Start Plan' : (plan.isEnterprise ? 'Contact Sales' : 'Select'),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
