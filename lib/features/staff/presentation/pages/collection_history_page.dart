import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../data/providers/collection_providers.dart';

class CollectionHistoryPage extends ConsumerStatefulWidget {
  final String? staffId;
  final String? customerId;

  const CollectionHistoryPage({
    super.key,
    this.staffId,
    this.customerId,
  });

  @override
  ConsumerState<CollectionHistoryPage> createState() => _CollectionHistoryPageState();
}

class _CollectionHistoryPageState extends ConsumerState<CollectionHistoryPage>
    with SingleTickerProviderStateMixin {
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  
  late TabController _tabController;
  
  DateTime _selectedDate = DateTime.now();
  String _selectedFilter = 'all'; // all, cash, digital
  String _groupBy = 'date'; // date, customer

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    ref.invalidate(collectionHistoryProvider);
    await Future.delayed(const Duration(milliseconds: 500));
    _refreshController.refreshCompleted();
  }

  void _onDateChanged(DateTime date) {
    setState(() => _selectedDate = date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection History'),
        actions: [
          // Filter
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _selectedFilter = value);
            },
            itemBuilder: (context) => [
              _buildFilterItem('all', 'All Types', Icons.all_inclusive),
              _buildFilterItem('cash', 'Cash Only', Icons.money),
              _buildFilterItem('digital', 'Digital Only', Icons.phone_android),
            ],
          ),
          // Group by
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() => _groupBy = value);
            },
            itemBuilder: (context) => [
              _buildFilterItem('date', 'By Date', Icons.calendar_today),
              _buildFilterItem('customer', 'By Customer', Icons.person),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Date selector
              _buildDateSelector(context),
              
              // Tab bar
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Loans'),
                  Tab(text: 'Savings'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHistoryList(context, 'all'),
          _buildHistoryList(context, 'loan'),
          _buildHistoryList(context, 'savings'),
        ],
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM yyyy');
    
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          // Previous month
          IconButton(
            onPressed: () {
              setState(() {
                _selectedDate = DateTime(
                  _selectedDate.year,
                  _selectedDate.month - 1,
                );
              });
            },
            icon: const Icon(Icons.chevron_left),
          ),
          
          // Current month/year
          Expanded(
            child: GestureDetector(
              onTap: () => _showDatePicker(context),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Text(
                      dateFormat.format(_selectedDate),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Next month
          IconButton(
            onPressed: () {
              setState(() {
                _selectedDate = DateTime(
                  _selectedDate.year,
                  _selectedDate.month + 1,
                );
              });
            },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  PopupMenuItem<String> _buildFilterItem(String value, String label, IconData icon) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: (_selectedFilter == value || _groupBy == value) 
                ? AppColors.primary 
                : null,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: (_selectedFilter == value || _groupBy == value) 
                  ? FontWeight.w600 
                  : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context, String type) {
    final historyAsync = ref.watch(
      collectionHistoryProvider(
        staffId: widget.staffId,
        customerId: widget.customerId,
        year: _selectedDate.year,
        month: _selectedDate.month,
        type: type,
        paymentMode: _selectedFilter,
      ),
    );

    return SmartRefresher(
      controller: _refreshController,
      onRefresh: _onRefresh,
      child: historyAsync.when(
        data: (history) {
          if (history.isEmpty) {
            return _buildEmptyState(context);
          }
          
          // Group by date or customer
          final grouped = _groupBy == 'date' 
              ? _groupByDate(history)
              : _groupByCustomer(history);
          
          return _buildGroupedList(context, grouped);
        },
        loading: () => _buildLoadingSkeleton(),
        error: (err, _) => _buildErrorState(context, err.toString()),
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupByDate(List<Map<String, dynamic>> history) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    final dateFormat = DateFormat('yyyy-MM-dd');
    
    for (final item in history) {
      final dateStr = item['collected_at'] ?? item['created_at'] ?? '';
      final date = DateTime.tryParse(dateStr) ?? DateTime.now();
      final key = dateFormat.format(date);
      
      grouped.putIfAbsent(key, () => []).add(item);
    }
    
    // Sort by date descending
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    
    return Map.fromEntries(
      sortedKeys.map((key) => MapEntry(key, grouped[key]!)),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupByCustomer(List<Map<String, dynamic>> history) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    
    for (final item in history) {
      final key = item['member_name'] ?? item['member_id'] ?? 'Unknown';
      grouped.putIfAbsent(key, () => []).add(item);
    }
    
    return grouped;
  }

  Widget _buildGroupedList(
    BuildContext context,
    Map<String, List<Map<String, dynamic>>> grouped,
  ) {
    final items = grouped.entries.toList();
    
    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: items.length,
      itemBuilder: (context, groupIndex) {
        final entry = items[groupIndex];
        final groupTotal = entry.value.fold<double>(
          0,
          (sum, item) => sum + (item['amount'] ?? 0).toDouble(),
        );
        
        return Column(
          children: [
            // Group header
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  Icon(
                    _groupBy == 'date' ? Icons.calendar_today : Icons.person,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    _groupBy == 'date'
                        ? AppFormatters.formatDate(
                            DateTime.tryParse(entry.key) ?? DateTime.now(),
                          )
                        : entry.key,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '₹${AppFormatters.formatCompactCurrency(groupTotal)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    '${entry.value.length} collections',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            
            // Items
            ...entry.value.map((item) => _buildHistoryItem(context, item)),
          ],
        );
      },
    );
  }

  Widget _buildHistoryItem(BuildContext context, Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final amount = (item['amount'] ?? 0).toDouble();
    final memberName = item['member_name'] ?? 'Unknown';
    final loanNumber = item['loan_number'] ?? '';
    final type = item['type'] ?? item['collection_type'] ?? 'emi';
    final paymentMode = item['payment_mode'] ?? 'cash';
    final time = item['collected_at'] ?? item['created_at'] ?? '';
    final receiptNumber = item['receipt_number'] ?? '';
    final staffName = item['staff_name'] ?? '';
    final isOffline = item['is_offline'] == true || item['sync_status'] == 'pending';

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          type == 'savings' ? Icons.savings : Icons.payments,
          color: AppColors.success,
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Text(
            '₹${AppFormatters.formatCompactCurrency(amount)}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          _buildPaymentModeChip(paymentMode),
          if (isOffline) ...[
            SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.cloud_off,
              size: 16,
              color: Colors.orange,
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(memberName),
          if (loanNumber.isNotEmpty)
            Text(
              'Loan: $loanNumber',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            time.isNotEmpty
                ? AppFormatters.formatTime(DateTime.tryParse(time) ?? DateTime.now())
                : '',
            style: theme.textTheme.bodySmall,
          ),
          if (receiptNumber.isNotEmpty)
            Text(
              receiptNumber,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
      onTap: () {
        context.push('/staff/collection/${item['id']}', extra: item);
      },
    );
  }

  Widget _buildPaymentModeChip(String mode) {
    Color color;
    IconData icon;
    
    switch (mode.toLowerCase()) {
      case 'cash':
        color = AppColors.success;
        icon = Icons.money;
        break;
      case 'upi':
        color = AppColors.primary;
        icon = Icons.phone_android;
        break;
      case 'bank_transfer':
        color = AppColors.info;
        icon = Icons.account_balance;
        break;
      default:
        color = Colors.grey;
        icon = Icons.payment;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 4),
          Text(
            mode.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          SizedBox(height: AppSpacing.lg),
          Text(
            'No Collections Found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'No collections for the selected period',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: 10,
      itemBuilder: (context, index) => ShimmerLoading(
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          title: Container(
            width: double.infinity,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          subtitle: Container(
            width: 100,
            height: 12,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: AppColors.error.withOpacity(0.5),
          ),
          SizedBox(height: AppSpacing.lg),
          Text(
            'Failed to load history',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            error,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: _onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
