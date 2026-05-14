import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/providers/branch_manager_providers.dart';
import '../../data/models/branch_stats_model.dart';

class BranchManagerDashboard extends ConsumerWidget {
  const BranchManagerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final branchId = user?.branchId;
    final dashboardData = ref.watch(branchManagerDashboardProvider);
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    if (branchId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Branch Manager Dashboard')),
        body: const Center(
          child: Text('No branch assigned to your profile.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${user?.fullName ?? 'Manager'} - Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/branch-manager/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/branch-manager/settings'),
          ),
        ],
      ),
      body: dashboardData.when(
        data: (data) {
          final stats = data['stats'] as BranchStats;
          final pendingCount = data['pending_approvals_count'] as int;
          final dailySummary = data['daily_summary'] as Map<String, dynamic>;
          final targets = data['targets'] as Map<String, dynamic>;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(branchManagerDashboardProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Branch Info Card
                  _buildBranchInfoCard(theme, stats),
                  const SizedBox(height: 16),

                  // Pending Approvals Alert
                  if (pendingCount > 0)
                    _buildPendingApprovalsCard(context, theme, pendingCount)
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 16),

                  // Daily Summary
                  _buildDailySummaryCard(theme, dailySummary, currencyFormat),
                  const SizedBox(height: 16),

                  // Collection Progress
                  _buildCollectionProgressCard(theme, stats, targets, currencyFormat),
                  const SizedBox(height: 16),

                  // Staff Performance
                  _buildStaffPerformanceCard(context, theme, branchId, stats),
                  const SizedBox(height: 16),

                  // Overdue Alert
                  if (stats.overdueLoans > 0)
                    _buildOverdueAlertCard(context, theme, stats),
                  const SizedBox(height: 16),

                  // Quick Actions
                  _buildQuickActionsCard(context, theme),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: ${error.toString()}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(branchManagerDashboardProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context, 0),
    );
  }

  Widget _buildBranchInfoCard(ThemeData theme, BranchStats stats) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
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
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.store,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stats.branchName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        stats.branchAddress,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: stats.isActive ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    stats.isActive ? 'Active' : 'Inactive',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildPendingApprovalsCard(BuildContext context, ThemeData theme, int count) {
    return Card(
      color: theme.colorScheme.errorContainer,
      child: InkWell(
        onTap: () => context.push('/branch-manager/approvals'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.pending_actions,
                color: theme.colorScheme.onErrorContainer,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pending Approvals',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$count requests awaiting your review',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: theme.colorScheme.onErrorContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailySummaryCard(ThemeData theme, Map<String, dynamic> summary, NumberFormat currencyFormat) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Summary',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    theme,
                    Icons.payments_outlined,
                    'Collections',
                    currencyFormat.format(summary['total_collections'] ?? 0),
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    theme,
                    Icons.people_outline,
                    'Visits',
                    '${summary['total_visits'] ?? 0}',
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    theme,
                    Icons.assignment_turned_in_outlined,
                    'Completed',
                    '${summary['completed_tasks'] ?? 0}',
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildSummaryItem(ThemeData theme, IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionProgressCard(ThemeData theme, BranchStats stats, Map<String, dynamic> targets, NumberFormat currencyFormat) {
    final collectionTarget = (targets['collection_target'] ?? 0) as num;
    final progress = collectionTarget > 0 ? stats.totalCollections / collectionTarget : 0.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
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
                  'Monthly Collection Progress',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(1)}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: progress >= 1 ? Colors.green : theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 12,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  progress >= 1 ? Colors.green : theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Collected: ${currencyFormat.format(stats.totalCollections)}',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  'Target: ${currencyFormat.format(collectionTarget)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildStaffPerformanceCard(BuildContext context, ThemeData theme, String branchId, BranchStats stats) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => context.push('/branch-manager/staff'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Staff Performance',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/branch-manager/staff'),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStaffStat(theme, Icons.person_outline, '${stats.totalStaff}', 'Active Staff'),
                  const SizedBox(width: 24),
                  _buildStaffStat(theme, Icons.trending_up, '85%', 'Avg. Efficiency'),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }

  Widget _buildStaffStat(ThemeData theme, IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverdueAlertCard(BuildContext context, ThemeData theme, BranchStats stats) {
    return Card(
      color: Colors.orange.withValues(alpha: 0.1),
      child: InkWell(
        onTap: () => context.push('/branch-manager/overdue'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.orange, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${stats.overdueLoans} Overdue Loans',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Requires immediate attention',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.orange),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard(BuildContext context, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildQuickActionChip(
                  context,
                  Icons.people_alt_outlined,
                  'Add Staff',
                  () => context.push('/branch-manager/staff/add'),
                ),
                _buildQuickActionChip(
                  context,
                  Icons.assignment_outlined,
                  'Assign Areas',
                  () => context.push('/branch-manager/areas'),
                ),
                _buildQuickActionChip(
                  context,
                  Icons.flag_outlined,
                  'Set Targets',
                  () => context.push('/branch-manager/targets'),
                ),
                _buildQuickActionChip(
                  context,
                  Icons.assessment_outlined,
                  'Reports',
                  () => context.push('/branch-manager/reports'),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 400.ms);
  }

  Widget _buildQuickActionChip(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: theme.colorScheme.primaryContainer,
      labelStyle: TextStyle(color: theme.colorScheme.onPrimaryContainer),
    );
  }

  Widget _buildBottomNav(BuildContext context, int currentIndex) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            context.go('/branch-manager');
            break;
          case 1:
            context.go('/branch-manager/staff');
            break;
          case 2:
            context.go('/branch-manager/collections');
            break;
          case 3:
            context.go('/branch-manager/reports');
            break;
          case 4:
            context.go('/branch-manager/profile');
            break;
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'Staff',
        ),
        NavigationDestination(
          icon: Icon(Icons.payments_outlined),
          selectedIcon: Icon(Icons.payments),
          label: 'Collections',
        ),
        NavigationDestination(
          icon: Icon(Icons.assessment_outlined),
          selectedIcon: Icon(Icons.assessment),
          label: 'Reports',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
