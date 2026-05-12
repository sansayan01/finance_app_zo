import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/providers/collection_providers.dart';

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
    final isDark = theme.brightness == Brightness.dark;
    final overdueState = ref.watch(overdueEmisProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A14) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Overdue Collections'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilterSheet,
          ),
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            onPressed: _showSortSheet,
          ),
        ],
      ),
      body: SmartRefresher(
        controller: _refreshController,
        onRefresh: () async {
          ref.invalidate(overdueEmisProvider);
          _refreshController.refreshCompleted();
        },
        child: overdueState.when(
          data: (collections) {
            if (collections.isEmpty) {
              return _buildEmptyState(theme);
            }

            final filtered = _applyFilter(collections);
            final sorted = _applySort(filtered);

            if (sorted.isEmpty) {
              return _buildEmptyState(theme);
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length,
              itemBuilder: (context, index) {
                final collection = sorted[index];
                return _buildOverdueCard(collection, theme, isDark);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }

  List<dynamic> _applyFilter(List<dynamic> collections) {
    if (_selectedFilter == 'all') return collections;
    
    return collections.where((c) {
      final days = c['days_overdue'] as int? ?? 0;
      if (_selectedFilter == '1-7') return days >= 1 && days <= 7;
      if (_selectedFilter == '8-15') return days >= 8 && days <= 15;
      if (_selectedFilter == '16-30') return days >= 16 && days <= 30;
      if (_selectedFilter == '30+') return days > 30;
      return true;
    }).toList();
  }

  List<dynamic> _applySort(List<dynamic> collections) {
    final list = List.from(collections);
    if (_selectedSort == 'days') {
      list.sort((a, b) => (b['days_overdue'] as int? ?? 0).compareTo(a['days_overdue'] as int? ?? 0));
    } else if (_selectedSort == 'amount') {
      list.sort((a, b) => (b['emi_amount'] as num? ?? 0).compareTo(a['emi_amount'] as num? ?? 0));
    } else if (_selectedSort == 'name') {
      list.sort((a, b) => (a['member_name'] as String? ?? '').compareTo(b['member_name'] as String? ?? ''));
    } else if (_selectedSort == 'date') {
      list.sort((a, b) => (a['due_date'] as String? ?? '').compareTo(b['due_date'] as String? ?? ''));
    }
    return list;
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 80,
            color: Colors.green.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Overdue Collections',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'all' 
              ? 'All your collections are up to date!'
              : 'No collections found for this filter.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverdueCard(dynamic collection, ThemeData theme, bool isDark) {
    final daysOverdue = collection['days_overdue'] as int? ?? 0;
    final amount = (collection['emi_amount'] as num? ?? 0).toDouble();
    final memberName = collection['member_name'] as String? ?? 'Unknown Member';
    final loanNumber = collection['loan_number'] as String? ?? 'N/A';
    final phone = collection['member_phone'] as String?;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getOverdueColor(daysOverdue).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: _getOverdueColor(daysOverdue),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        memberName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Loan: $loanNumber',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${amount.toStringAsFixed(0)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      '$daysOverdue Days',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _getOverdueColor(daysOverdue),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _callCustomer(phone),
                    icon: const Icon(Icons.phone_rounded, size: 16),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(color: theme.colorScheme.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      context.push('/staff/collections/new/${collection['loan_id']}', extra: collection);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Collect'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getOverdueColor(int days) {
    if (days > 30) return Colors.red;
    if (days > 15) return Colors.orange;
    if (days > 7) return Colors.amber;
    return Colors.blue;
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
                  RadioGroup<String>(
                    groupValue: _selectedFilter,
                    onChanged: (v) {
                      setState(() => _selectedFilter = v!);
                      this.setState(() {}); // Update main page
                      Navigator.pop(context);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFilterOption('all', 'All Overdue'),
                        _buildFilterOption('1-7', '1-7 Days'),
                        _buildFilterOption('8-15', '8-15 Days'),
                        _buildFilterOption('16-30', '16-30 Days'),
                        _buildFilterOption('30+', '30+ Days'),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterOption(String value, String label) {
    return RadioListTile<String>(
      title: Text(label),
      value: value,
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
                  RadioGroup<String>(
                    groupValue: _selectedSort,
                    onChanged: (v) {
                      setState(() => _selectedSort = v!);
                      this.setState(() {}); // Update main page
                      Navigator.pop(context);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSortOption('days', 'Days Overdue (High to Low)'),
                        _buildSortOption('amount', 'Amount (High to Low)'),
                        _buildSortOption('name', 'Customer Name'),
                        _buildSortOption('date', 'Due Date'),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortOption(String value, String label) {
    return RadioListTile<String>(
      title: Text(label),
      value: value,
    );
  }

  void _callCustomer(String? phone) async {
    if (phone != null && phone.isNotEmpty) {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }
}
