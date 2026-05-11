import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/models/collection_model.dart';
import '../../data/providers/collection_providers.dart';
import '../widgets/collection_list_tile.dart';

class OverdueListPage extends ConsumerStatefulWidget {
  const OverdueListPage({super.key});

  @override
  ConsumerState<OverdueListPage> createState() => _OverdueListPageState();
}

class _OverdueListPageState extends ConsumerState<OverdueListPage> {
  final RefreshController _refreshController = RefreshController();
  String _selectedFilter = 'all';
  String _selectedSort = 'days';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Overdue Collections'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCard(theme),
          Expanded(
            child: user != null
                ? _buildOverdueList(user.id)
                : const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.error.withOpacity(0.1),
            theme.colorScheme.error.withOpacity(0.05),
          ],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              theme,
              'Total Overdue',
              '₹45,200',
              Icons.warning_rounded,
              theme.colorScheme.error,
            ),
          ),
          Container(
            height: 40,
            width: 1,
            color: theme.dividerColor,
          ),
          Expanded(
            child: _buildSummaryItem(
              theme,
              'Customers',
              '12',
              Icons.people,
              theme.colorScheme.error,
            ),
          ),
          Container(
            height: 40,
            width: 1,
            color: theme.dividerColor,
          ),
          Expanded(
            child: _buildSummaryItem(
              theme,
              'Avg Days',
              '15',
              Icons.calendar_today,
              theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
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

  Widget _buildOverdueList(String staffId) {
    final overdueAsync = ref.watch(overdueCollectionsProvider(staffId));

    return overdueAsync.when(
      data: (overdues) {
        if (overdues.isEmpty) {
          return _buildEmptyState();
        }

        return SmartRefresher(
          controller: _refreshController,
          enablePullDown: true,
          onRefresh: () {
            ref.invalidate(overdueCollectionsProvider(staffId));
            _refreshController.refreshCompleted();
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: overdues.length,
            itemBuilder: (context, index) {
              return _buildOverdueCard(overdues[index], theme);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildOverdueCard(Map<String, dynamic> overdue, ThemeData theme) {
    final daysOverdue = overdue['days_overdue'] as int? ?? 0;
    final penalty = overdue['penalty'] as double? ?? 0;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      overdue['member_name'] ?? 'Unknown',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Loan: ${overdue['loan_number'] ?? 'N/A'}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getDaysColor(daysOverdue),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$daysOverdue days',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              _buildInfoColumn('Due Amount', '₹${overdue['emi'] ?? 0}'),
              const SizedBox(width: 24),
              _buildInfoColumn('Penalty', '₹$penalty'),
              const SizedBox(width: 24),
              _buildInfoColumn('Total', '₹${(overdue['emi'] ?? 0) + penalty}'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _callCustomer(overdue['member_phone']),
                  icon: const Icon(Icons.call, size: 18),
                  label: const Text('Call'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _navigateToCollect(overdue['loan_id']),
                  icon: const Icon(Icons.payments, size: 18),
                  label: const Text('Collect'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getDaysColor(int days) {
    if (days <= 7) return Colors.orange;
    if (days <= 15) return Colors.deepOrange;
    if (days <= 30) return Colors.red;
    return Colors.purple;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          Text(
            'No Overdue Collections!',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Great job! All collections are up to date.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter Overdue',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildFilterOption('all', 'All Overdue', setState),
                  _buildFilterOption('1-7', '1-7 Days', setState),
                  _buildFilterOption('8-15', '8-15 Days', setState),
                  _buildFilterOption('16-30', '16-30 Days', setState),
                  _buildFilterOption('30+', '30+ Days', setState),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterOption(String value, String label, StateSetter setState) {
    return RadioListTile<String>(
      title: Text(label),
      value: value,
      groupValue: _selectedFilter,
      onChanged: (v) {
        setState(() => _selectedFilter = v!);
        Navigator.pop(context);
      },
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sort By',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildSortOption('days', 'Days Overdue (High to Low)', setState),
                  _buildSortOption('amount', 'Amount (High to Low)', setState),
                  _buildSortOption('name', 'Customer Name', setState),
                  _buildSortOption('date', 'Due Date', setState),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortOption(String value, String label, StateSetter setState) {
    return RadioListTile<String>(
      title: Text(label),
      value: value,
      groupValue: _selectedSort,
      onChanged: (v) {
        setState(() => _selectedSort = v!);
        Navigator.pop(context);
      },
    );
  }

  void _callCustomer(String? phone) {
    if (phone != null) {
      // Launch phone call
    }
  }

  void _navigateToCollect(String? loanId) {
    if (loanId != null) {
      context.push('/staff/collect/$loanId');
    }
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }
}
