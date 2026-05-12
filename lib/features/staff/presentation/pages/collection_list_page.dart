import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../data/providers/collection_providers.dart';
import '../widgets/collection_list_tile.dart';
import '../widgets/collection_filter_widgets.dart';

class CollectionListPage extends ConsumerStatefulWidget {
  const CollectionListPage({super.key});

  @override
  ConsumerState<CollectionListPage> createState() => _CollectionListPageState();
}

class _CollectionListPageState extends ConsumerState<CollectionListPage>
    with SingleTickerProviderStateMixin {
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  
  late TabController _tabController;
  
  CollectionFilter _selectedFilter = CollectionFilter.all;
  CollectionSort _selectedSort = CollectionSort.dueDate;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _selectedFilter = CollectionFilter.all;
            break;
          case 1:
            _selectedFilter = CollectionFilter.dueToday;
            break;
          case 2:
            _selectedFilter = CollectionFilter.overdue;
            break;
          case 3:
            _selectedFilter = CollectionFilter.paid;
            break;
        }
      });
    }
  }

  Future<void> _onRefresh() async {
    // Refresh all providers
    ref.invalidate(todayEmisProvider);
    ref.invalidate(overdueEmisProvider);
    ref.invalidate(recentCollectionsProvider);
    
    await Future.delayed(const Duration(milliseconds: 500));
    _refreshController.refreshCompleted();
  }

  void _onQuickCollect(Map<String, dynamic> emi) {
    HapticFeedback.mediumImpact();
    // Navigate to collection form with EMI data
    context.push('/staff/collect', extra: {
      'emi': emi,
      'mode': 'quick',
    });
  }

  void _onEmiTap(Map<String, dynamic> emi) {
    HapticFeedback.selectionClick();
    // Navigate to EMI detail
    context.push('/staff/emi/${emi['id']}', extra: emi);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Get EMIs based on filter
    final emisAsync = ref.watch(todayEmisProvider);
    final overdueAsync = ref.watch(overdueEmisProvider);
    final recentCollectionsAsync = ref.watch(recentCollectionsProvider);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // App bar with search
          SliverAppBar(
            floating: true,
            snap: true,
            pinned: true,
            expandedHeight: 120,
            title: _isSearchExpanded ? null : const Text('Collections'),
            actions: [
              // Search toggle
              IconButton(
                onPressed: () {
                  setState(() {
                    _isSearchExpanded = !_isSearchExpanded;
                    if (!_isSearchExpanded) {
                      _searchController.clear();
                    }
                  });
                },
                icon: Icon(
                  _isSearchExpanded ? Icons.close : Icons.search,
                ),
              ),
              // Sort button
              CollectionSortButton(
                currentSort: _selectedSort,
                onSortChanged: (sort) {
                  setState(() => _selectedSort = sort);
                },
              ),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Column(
                children: [
                  // Search bar (when expanded)
                  if (_isSearchExpanded)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search by name, phone, loan number...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  
                  // Filter chips
                  SizedBox(
                    height: 48,
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelPadding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      tabs: [
                        Tab(
                          child: CollectionFilterChip(
                            filter: CollectionFilter.all,
                            isSelected: _selectedFilter == CollectionFilter.all,
                            count: emisAsync.maybeWhen(
                              data: (data) => data.length,
                              orElse: () => null,
                            ),
                          ),
                        ),
                        Tab(
                          child: CollectionFilterChip(
                            filter: CollectionFilter.dueToday,
                            isSelected: _selectedFilter == CollectionFilter.dueToday,
                            count: emisAsync.maybeWhen(
                              data: (data) => data.where((e) => 
                                  e['is_due_today'] == true || 
                                  e['status'] == 'due').length,
                              orElse: () => null,
                            ),
                          ),
                        ),
                        Tab(
                          child: CollectionFilterChip(
                            filter: CollectionFilter.overdue,
                            isSelected: _selectedFilter == CollectionFilter.overdue,
                            count: overdueAsync.maybeWhen(
                              data: (data) => data.length,
                              orElse: () => null,
                            ),
                          ),
                        ),
                        Tab(
                          child: CollectionFilterChip(
                            filter: CollectionFilter.paid,
                            isSelected: _selectedFilter == CollectionFilter.paid,
                            count: recentCollectionsAsync.maybeWhen(
                              data: (data) => data.length,
                              orElse: () => null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: SmartRefresher(
          controller: _refreshController,
          onRefresh: _onRefresh,
          child: emisAsync.when(
            data: (emis) {
              // Apply filters
              List<Map<String, dynamic>> filteredEmis = _filterEmis(emis);
              
              // Apply search
              if (_searchController.text.isNotEmpty) {
                final query = _searchController.text.toLowerCase();
                filteredEmis = filteredEmis.where((e) {
                  final name = (e['member_name'] ?? '').toString().toLowerCase();
                  final phone = (e['member_phone'] ?? '').toString();
                  final loan = (e['loan_number'] ?? '').toString().toLowerCase();
                  return name.contains(query) || 
                         phone.contains(query) || 
                         loan.contains(query);
                }).toList();
              }
              
              // Apply sort
              filteredEmis = _sortEmis(filteredEmis);
              
              if (filteredEmis.isEmpty) {
                return _buildEmptyState(context);
              }
              
              return ListView.builder(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: filteredEmis.length,
                itemBuilder: (context, index) {
                  final emi = filteredEmis[index];
                  return CollectionListTile(
                    emi: emi,
                    isOverdue: emi['is_overdue'] == true,
                    isPaid: emi['is_paid'] == true,
                    onTap: () => _onEmiTap(emi),
                    onQuickCollect: () => _onQuickCollect(emi),
                  );
                },
              );
            },
            loading: () => _buildLoadingSkeleton(),
            error: (err, _) => _buildErrorState(context, err.toString()),
          ),
        ),
      ),
      
      // Quick action FAB
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.push('/staff/collect');
        },
        icon: const Icon(Icons.add),
        label: const Text('New Collection'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  List<Map<String, dynamic>> _filterEmis(List<Map<String, dynamic>> emis) {
    switch (_selectedFilter) {
      case CollectionFilter.all:
        return emis;
      case CollectionFilter.dueToday:
        return emis.where((e) => 
            e['is_due_today'] == true || e['status'] == 'due').toList();
      case CollectionFilter.overdue:
        return emis.where((e) => e['is_overdue'] == true).toList();
      case CollectionFilter.paid:
        return emis.where((e) => e['is_paid'] == true).toList();
      case CollectionFilter.upcoming:
        return emis.where((e) => 
            e['is_upcoming'] == true || e['status'] == 'upcoming').toList();
    }
  }

  List<Map<String, dynamic>> _sortEmis(List<Map<String, dynamic>> emis) {
    final sorted = List<Map<String, dynamic>>.from(emis);
    
    switch (_selectedSort) {
      case CollectionSort.dueDate:
        sorted.sort((a, b) {
          final dateA = DateTime.tryParse(a['due_date'] ?? '');
          final dateB = DateTime.tryParse(b['due_date'] ?? '');
          if (dateA == null || dateB == null) return 0;
          return dateA.compareTo(dateB);
        });
        break;
      case CollectionSort.amountHighToLow:
        sorted.sort((a, b) => 
            ((b['emi'] ?? b['amount'] ?? 0).toDouble())
            .compareTo((a['emi'] ?? a['amount'] ?? 0).toDouble()));
        break;
      case CollectionSort.amountLowToHigh:
        sorted.sort((a, b) => 
            ((a['emi'] ?? a['amount'] ?? 0).toDouble())
            .compareTo((b['emi'] ?? b['amount'] ?? 0).toDouble()));
        break;
      case CollectionSort.nameAZ:
        sorted.sort((a, b) => 
            (a['member_name'] ?? '').toString()
            .compareTo((b['member_name'] ?? '').toString()));
        break;
      case CollectionSort.nameZA:
        sorted.sort((a, b) => 
            (b['member_name'] ?? '').toString()
            .compareTo((a['member_name'] ?? '').toString()));
        break;
      case CollectionSort.area:
        sorted.sort((a, b) => 
            (a['area'] ?? '').toString()
            .compareTo((b['area'] ?? '').toString()));
        break;
    }
    
    return sorted;
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          SizedBox(height: AppSpacing.lg),
          Text(
            'No Collections Found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'There are no EMIs matching your filter',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: () => context.push('/staff/collect'),
            icon: const Icon(Icons.add),
            label: const Text('Add Collection'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: 8,
      itemBuilder: (context, index) => ShimmerLoading(
        child: Card(
          margin: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Container(
                        width: 150,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 60,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
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
            color: AppColors.error.withValues(alpha: 0.5),
          ),
          SizedBox(height: AppSpacing.lg),
          Text(
            'Something went wrong',
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
