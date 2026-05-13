import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/providers/billing_providers.dart';

class UsageLimitsPage extends ConsumerWidget {
  const UsageLimitsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statusAsync = ref.watch(subscriptionStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usage & Limits'),
      ),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading usage: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(subscriptionStatusProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (status) {
          if (status.isEmpty) {
            return const Center(
              child: Text('No subscription data available'),
            );
          }

          final membersUsed = status['members_used'] as int? ?? 0;
          final membersLimit = status['members_limit'] as int? ?? 100;
          final branchesUsed = status['branches_used'] as int? ?? 0;
          final branchesLimit = status['branches_limit'] as int? ?? 1;
          final staffUsed = status['staff_used'] as int? ?? 0;
          final staffLimit = status['staff_limit'] as int? ?? 5;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current plan
                _PlanInfoCard(
                  planName: status['plan_name'] as String? ?? 'Unknown',
                  status: status['status'] as String? ?? 'active',
                ),

                const SizedBox(height: 32),

                // Usage bars
                Text(
                  'Current Usage',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),

                _UsageBar(
                  label: 'Members',
                  used: membersUsed,
                  limit: membersLimit,
                  icon: Icons.people,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),

                _UsageBar(
                  label: 'Branches',
                  used: branchesUsed,
                  limit: branchesLimit,
                  icon: Icons.store,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),

                _UsageBar(
                  label: 'Staff',
                  used: staffUsed,
                  limit: staffLimit,
                  icon: Icons.badge,
                  color: Colors.purple,
                ),

                const SizedBox(height: 32),

                // What happens at limit
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          Text(
                            'What happens at limit?',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'When you reach your limit, you won\'t be able to add more items. '
                        'Upgrade your plan to continue growing.',
                        style: TextStyle(
                          color: Colors.orange[900],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Upgrade CTA
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to billing
                    },
                    icon: const Icon(Icons.arrow_upward),
                    label: const Text('Upgrade Plan'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlanInfoCard extends StatelessWidget {
  final String planName;
  final String status;

  const _PlanInfoCard({
    required this.planName,
    required this.status,
  });

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
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Plan',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  planName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  final String label;
  final int used;
  final int limit;
  final IconData icon;
  final Color color;

  const _UsageBar({
    required this.label,
    required this.used,
    required this.limit,
    required this.icon,
    required this.color,
  });

  double get percentage => limit > 0 ? used / limit : 0;
  bool get isNearLimit => percentage > 0.8;
  bool get isAtLimit => percentage >= 1.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayColor = isAtLimit ? Colors.red : (isNearLimit ? Colors.orange : color);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: displayColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$used / ${limit == 0 ? '∞' : limit}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: displayColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: limit > 0 ? percentage.clamp(0.0, 1.0) : 0.1,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(displayColor),
                minHeight: 8,
              ),
            ),
            if (isNearLimit || isAtLimit) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    isAtLimit ? Icons.error : Icons.warning,
                    size: 14,
                    color: displayColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isAtLimit
                        ? 'Limit reached - upgrade to add more'
                        : 'Approaching limit - consider upgrading',
                    style: TextStyle(
                      color: displayColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
