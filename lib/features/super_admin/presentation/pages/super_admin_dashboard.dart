import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../data/providers/super_admin_providers.dart';

/// Super Admin Dashboard
/// Central hub for platform-wide management
class SuperAdminDashboard extends ConsumerWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(platformMetricsProvider);
    final revenueAsync = ref.watch(revenueSummaryProvider);
    final activityAsync = ref.watch(activityFeedProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar.large(
            title: const Text('Platform Dashboard'),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => context.push('/super-admin/announcements'),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push('/super-admin/settings'),
              ),
            ],
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Metrics Grid
                metricsAsync.when(
                  data: (metrics) => _buildMetricsGrid(context, metrics, isDark),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _buildErrorCard(context, e.toString()),
                ),

                const SizedBox(height: 24),

                // Quick Actions
                _buildQuickActions(context, isDark),

                const SizedBox(height: 24),

                // Revenue Summary
                revenueAsync.when(
                  data: (revenue) => _buildRevenueCard(context, revenue, isDark),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 24),

                // Recent Activity
                activityAsync.when(
                  data: (activities) => _buildActivityFeed(context, activities, isDark),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context, dynamic metrics, bool isDark) {
    final currencyFormat = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹');

    final items = [
      _MetricItem(
        icon: Icons.business_outlined,
        label: 'Organizations',
        value: '${metrics.totalOrganizations}',
        subtext: '${metrics.activeOrganizations} active',
        color: Colors.blue,
      ),
      _MetricItem(
        icon: Icons.people_outlined,
        label: 'Total Users',
        value: '${metrics.totalUsers}',
        subtext: '${metrics.activeUsers} active',
        color: Colors.green,
      ),
      _MetricItem(
        icon: Icons.account_tree_outlined,
        label: 'Branches',
        value: '${metrics.totalBranches}',
        color: Colors.orange,
      ),
      _MetricItem(
        icon: Icons.person_outline,
        label: 'Members',
        value: '${metrics.totalMembers}',
        color: Colors.purple,
      ),
      _MetricItem(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Total Loans',
        value: currencyFormat.format(metrics.totalLoanAmount),
        subtext: '${metrics.totalLoans} loans',
        color: Colors.red,
      ),
      _MetricItem(
        icon: Icons.payments_outlined,
        label: 'Collections',
        value: currencyFormat.format(metrics.totalCollections),
        color: Colors.teal,
      ),
      _MetricItem(
        icon: Icons.savings_outlined,
        label: 'Total Savings',
        value: currencyFormat.format(metrics.totalSavings),
        color: Colors.indigo,
      ),
      _MetricItem(
        icon: Icons.trending_up_outlined,
        label: 'MRR',
        value: currencyFormat.format(metrics.mrr),
        color: Colors.amber,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Platform Overview',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _MetricCard(item: item, isDark: isDark)
                .animate()
                .fadeIn(delay: Duration(milliseconds: index * 50))
                .slideY(begin: 0.1, end: 0);
          },
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isDark) {
    final actions = [
      _QuickAction(
        icon: Icons.business,
        label: 'Organizations',
        route: '/super-admin/organizations',
        color: Colors.blue,
      ),
      _QuickAction(
        icon: Icons.people,
        label: 'Users',
        route: '/super-admin/users',
        color: Colors.green,
      ),
      _QuickAction(
        icon: Icons.flag,
        label: 'Feature Flags',
        route: '/super-admin/feature-flags',
        color: Colors.orange,
      ),
      _QuickAction(
        icon: Icons.campaign,
        label: 'Announcements',
        route: '/super-admin/announcements',
        color: Colors.purple,
      ),
      _QuickAction(
        icon: Icons.support_agent,
        label: 'Support',
        route: '/super-admin/support',
        color: Colors.red,
      ),
      _QuickAction(
        icon: Icons.history,
        label: 'Audit Logs',
        route: '/super-admin/audit-logs',
        color: Colors.teal,
      ),
      _QuickAction(
        icon: Icons.build,
        label: 'Maintenance',
        route: '/super-admin/maintenance',
        color: Colors.indigo,
      ),
      _QuickAction(
        icon: Icons.analytics,
        label: 'Analytics',
        route: '/super-admin/analytics',
        color: Colors.amber,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return _QuickActionCard(action: action, isDark: isDark)
                .animate()
                .fadeIn(delay: Duration(milliseconds: 100 + index * 50))
                .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
          },
        ),
      ],
    );
  }

  Widget _buildRevenueCard(BuildContext context, Map<String, dynamic> revenue, bool isDark) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Card(
      elevation: 0,
      color: isDark ? Colors.grey[900] : Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.trending_up, color: Colors.green),
                ),
                const SizedBox(width: 12),
                Text(
                  'Revenue Overview',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildRevenueItem(
                    context,
                    'Total Revenue',
                    currencyFormat.format(revenue['total_revenue'] ?? 0),
                    Icons.account_balance_wallet,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildRevenueItem(
                    context,
                    'Avg Monthly',
                    currencyFormat.format(revenue['avg_monthly_revenue'] ?? 0),
                    Icons.calendar_month,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildRevenueItem(
                    context,
                    'Transactions',
                    '${revenue['transaction_count'] ?? 0}',
                    Icons.receipt_long,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildRevenueItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityFeed(BuildContext context, List<Map<String, dynamic>> activities, bool isDark) {
    if (activities.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: isDark ? Colors.grey[900] : Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/super-admin/activity'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...activities.take(10).map((activity) => _buildActivityItem(context, activity, isDark)),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildActivityItem(BuildContext context, Map<String, dynamic> activity, bool isDark) {
    final type = activity['activity_type'] as String? ?? 'unknown';
    final createdAt = DateTime.tryParse(activity['created_at'] ?? '') ?? DateTime.now();
    final timeAgo = _formatTimeAgo(DateTime.now().difference(createdAt));

    final icon = _getActivityIcon(type);
    final color = _getActivityColor(type);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(
        _formatActivityTitle(type, activity),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: Text(
        timeAgo,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
        ),
      ),
    );
  }

  String _formatTimeAgo(Duration duration) {
    if (duration.inDays > 0) return '${duration.inDays}d ago';
    if (duration.inHours > 0) return '${duration.inHours}h ago';
    if (duration.inMinutes > 0) return '${duration.inMinutes}m ago';
    return 'Just now';
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'login':
        return Icons.login;
      case 'collection':
        return Icons.payments;
      case 'loan_disbursed':
        return Icons.account_balance_wallet;
      case 'member_created':
        return Icons.person_add;
      case 'organization_created':
        return Icons.business;
      default:
        return Icons.circle;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'login':
        return Colors.blue;
      case 'collection':
        return Colors.green;
      case 'loan_disbursed':
        return Colors.orange;
      case 'member_created':
        return Colors.purple;
      case 'organization_created':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _formatActivityTitle(String type, Map<String, dynamic> activity) {
    final orgName = activity['organizations']?['name'] ?? 'Unknown Org';
    final userName = activity['profiles']?['name'] ?? 'Unknown User';

    switch (type) {
      case 'login':
        return '$userName logged in';
      case 'collection':
        return 'Collection made in $orgName';
      case 'loan_disbursed':
        return 'Loan disbursed in $orgName';
      case 'member_created':
        return 'New member in $orgName';
      case 'organization_created':
        return 'New organization: $orgName';
      default:
        return type.replaceAll('_', ' ').split(' ').map((e) => e[0].toUpperCase() + e.substring(1)).join(' ');
    }
  }

  Widget _buildErrorCard(BuildContext context, String error) {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Error loading metrics: $error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricItem {
  final IconData icon;
  final String label;
  final String value;
  final String? subtext;
  final Color color;

  const _MetricItem({
    required this.icon,
    required this.label,
    required this.value,
    this.subtext,
    required this.color,
  });
}

class _MetricCard extends StatelessWidget {
  final _MetricItem item;
  final bool isDark;

  const _MetricCard({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: isDark ? Colors.grey[900] : Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(item.icon, size: 20, color: item.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: item.color,
              ),
            ),
            if (item.subtext != null) ...[
              const SizedBox(height: 2),
              Text(
                item.subtext!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final String route;
  final Color color;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.route,
    required this.color,
  });
}

class _QuickActionCard extends StatelessWidget {
  final _QuickAction action;
  final bool isDark;

  const _QuickActionCard({required this.action, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(action.route),
        borderRadius: BorderRadius.circular(12),
        child: Card(
          elevation: 0,
          color: isDark ? Colors.grey[900] : Colors.grey[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: action.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(action.icon, size: 24, color: action.color),
                ),
                const SizedBox(height: 8),
                Text(
                  action.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
