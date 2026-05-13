import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../providers/supabase_provider.dart';
import '../data/providers/saas_providers.dart';
import '../models/enterprise_models.dart';
import '../models/analytics_models.dart';

/// SaaS Super Admin Dashboard
class SaaSDashboardPage extends ConsumerStatefulWidget {
  const SaaSDashboardPage({super.key});

  @override
  ConsumerState<SaaSDashboardPage> createState() => _SaaSDashboardPageState();
}

class _SaaSDashboardPageState extends ConsumerState<SaaSDashboardPage> {
  int _selectedIndex = 0;
  
  final List<_NavItem> _navItems = [
    _NavItem(Icons.dashboard, 'Overview', '/saas'),
    _NavItem(Icons.business, 'Organizations', '/saas/organizations'),
    _NavItem(Icons.receipt_long, 'Billing', '/saas/billing'),
    _NavItem(Icons.analytics, 'Analytics', '/saas/analytics'),
    _NavItem(Icons.security, 'Security', '/saas/security'),
    _NavItem(Icons.help, 'Support', '/saas/support'),
    _NavItem(Icons.settings, 'Settings', '/saas/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Row(
        children: [
          // Navigation Rail
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
              context.go(_navItems[index].route);
            },
            labelType: NavigationRailLabelType.all,
            leading: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bolt, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 8),
                Text(
                  'MicroFlow\nSaaS',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
            destinations: _navItems
                .map((item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      label: Text(item.label),
                    ))
                .toList(),
          ),
          
          const VerticalDivider(thickness: 1, width: 1),
          
          // Main Content
          Expanded(
            child: _buildOverviewContent(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewContent(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SaaS Dashboard',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Platform-wide analytics and management',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildQuickAction(theme, Icons.refresh, 'Refresh'),
                  const SizedBox(width: 12),
                  _buildQuickAction(theme, Icons.download, 'Export'),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Stats Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 1200
                  ? 4
                  : constraints.maxWidth > 800
                      ? 2
                      : 1;
              
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.8,
                children: [
                  _buildStatCard(
                    theme,
                    Icons.business,
                    'Total Organizations',
                    '247',
                    '+12 this month',
                    Colors.blue,
                  ),
                  _buildStatCard(
                    theme,
                    Icons.people,
                    'Active Users',
                    '4,892',
                    '+156 this week',
                    Colors.green,
                  ),
                  _buildStatCard(
                    theme,
                    Icons.payments,
                    'Monthly Revenue',
                    '₹12,45,890',
                    '+18% vs last month',
                    Colors.purple,
                  ),
                  _buildStatCard(
                    theme,
                    Icons.trending_up,
                    'Collection Volume',
                    '₹8.2 Cr',
                    'This month',
                    Colors.orange,
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 32),
          
          // Charts Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Revenue Chart
              Expanded(
                flex: 2,
                child: _buildRevenueChart(theme),
              ),
              const SizedBox(width: 24),
              // Top Organizations
              Expanded(
                child: _buildTopOrganizations(theme),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Recent Activity & Alerts
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recent Activity
              Expanded(
                child: _buildRecentActivity(theme),
              ),
              const SizedBox(width: 24),
              // System Alerts
              Expanded(
                child: _buildSystemAlerts(theme),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(ThemeData theme, IconData icon, String label) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    IconData icon,
    String title,
    String value,
    String subtitle,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Icon(Icons.more_vert, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Revenue Trend',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('6M')),
                  ButtonSegment(value: 1, label: Text('1Y')),
                  ButtonSegment(value: 2, label: Text('All')),
                ],
                selected: {1},
                onSelectionChanged: (_) {},
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Placeholder for chart
          SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.show_chart, size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: 8),
                  Text('Revenue Chart', style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopOrganizations(ThemeData theme) {
    final orgs = [
      ('ABC Micro Finance', '₹2.4L/month', 'Enterprise'),
      ('XYZ Credit Society', '₹1.8L/month', 'Professional'),
      ('LMN Finance Corp', '₹1.2L/month', 'Professional'),
      ('PQR Rural Bank', '₹85K/month', 'Growth'),
      ('DEF Loans Ltd', '₹65K/month', 'Growth'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Organizations',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...orgs.map((org) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    org.$1[0],
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(org.$1, style: theme.textTheme.bodyMedium),
                      Text(org.$2, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(org.$3, style: theme.textTheme.labelSmall),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(ThemeData theme) {
    final activities = [
      ('New organization registered', 'ABC Micro Finance', '2 hours ago'),
      ('Subscription upgraded', 'XYZ Credit Society → Enterprise', '5 hours ago'),
      ('Payment received', '₹45,000 from LMN Finance', '1 day ago'),
      ('New staff onboarded', '15 staff members added', '2 days ago'),
      ('Support ticket resolved', 'Issue #1234 closed', '2 days ago'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(onPressed: () {}, child: const Text('View All')),
            ],
          ),
          const SizedBox(height: 16),
          ...activities.map((activity) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(activity.$1, style: theme.textTheme.bodyMedium),
                      Text(activity.$2, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Text(activity.$3, style: theme.textTheme.labelSmall),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildSystemAlerts(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Alerts',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Alert items
          _buildAlertItem(theme, Colors.orange, 'High CPU Usage', 'Server 3 at 89%', 'warning'),
          _buildAlertItem(theme, Colors.red, 'Payment Failed', '3 transactions failed', 'error'),
          _buildAlertItem(theme, Colors.blue, 'Scheduled Maintenance', 'Tonight 2-4 AM IST', 'info'),
          _buildAlertItem(theme, Colors.green, 'Backup Complete', 'All data backed up', 'success'),
        ],
      ),
    );
  }

  Widget _buildAlertItem(ThemeData theme, Color color, String title, String subtitle, String type) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(
              type == 'error' ? Icons.error : type == 'warning' ? Icons.warning : type == 'success' ? Icons.check_circle : Icons.info,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;

  const _NavItem(this.icon, this.label, this.route);
}
