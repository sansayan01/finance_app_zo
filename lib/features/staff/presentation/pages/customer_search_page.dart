import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/providers/collection_providers.dart';

class CustomerSearchPage extends ConsumerStatefulWidget {
  const CustomerSearchPage({super.key});

  @override
  ConsumerState<CustomerSearchPage> createState() => _CustomerSearchPageState();
}

class _CustomerSearchPageState extends ConsumerState<CustomerSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSearching = false;
  String _selectedFilter = 'all'; // all, name, phone, loan

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    if (query.isEmpty) {
      setState(() => _isSearching = false);
      return;
    }
    
    setState(() => _isSearching = true);
    // Trigger search provider
  }

  void _onCustomerTap(Map<String, dynamic> customer) {
    HapticFeedback.selectionClick();
    context.push('/staff/customer/${customer['id']}', extra: customer);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          autofocus: true,
          decoration: InputDecoration(
            hintText: _getSearchHint(),
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          style: theme.textTheme.titleMedium,
          onChanged: _onSearch,
          textInputAction: TextInputAction.search,
          onSubmitted: _onSearch,
        ),
        actions: [
          // Filter dropdown
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _selectedFilter = value);
            },
            itemBuilder: (context) => [
              _buildFilterItem('all', 'All Fields', Icons.search),
              _buildFilterItem('name', 'Name Only', Icons.person_outline),
              _buildFilterItem('phone', 'Phone Only', Icons.phone_outlined),
              _buildFilterItem('loan', 'Loan Number', Icons.confirmation_number_outlined),
            ],
          ),
          // Clear button
          if (_searchController.text.isNotEmpty)
            IconButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _isSearching = false);
              },
              icon: const Icon(Icons.clear),
            ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  String _getSearchHint() {
    switch (_selectedFilter) {
      case 'name':
        return 'Search by name...';
      case 'phone':
        return 'Search by phone number...';
      case 'loan':
        return 'Search by loan number...';
      default:
        return 'Search by name, phone, or loan number...';
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
            color: _selectedFilter == value ? AppColors.primary : null,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: _selectedFilter == value 
                  ? FontWeight.w600 
                  : FontWeight.w400,
            ),
          ),
          if (_selectedFilter == value) ...[
            const Spacer(),
            const Icon(Icons.check, size: 18, color: AppColors.primary),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (!_isSearching || _searchController.text.isEmpty) {
      return _buildRecentSearches(context);
    }

    // Use the search provider
    final searchResults = ref.watch(
      customerSearchProvider(_searchController.text),
    );

    return searchResults.when(
      data: (results) {
        if (results.isEmpty) {
          return _buildNoResults(context);
        }
        return _buildSearchResults(context, results);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => _buildError(context, err.toString()),
    );
  }

  Widget _buildRecentSearches(BuildContext context) {
    final theme = Theme.of(context);
    final recentSearchesAsync = ref.watch(recentSearchesProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick access
          Text(
            'Quick Access',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _buildQuickAccessChip('Today\'s Dues', Icons.today, () {
                context.go('/staff/collections?filter=today');
              }),
              _buildQuickAccessChip('Overdue', Icons.warning_amber, () {
                context.go('/staff/collections?filter=overdue');
              }),
              _buildQuickAccessChip('Recent Collections', Icons.history, () {
                context.go('/staff/collections?filter=recent');
              }),
            ],
          ),
          
          SizedBox(height: AppSpacing.xl),
          
          // Recent searches
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(recentSearchesProvider.notifier).clear();
                },
                child: const Text('Clear All'),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          
          recentSearchesAsync.when(
            data: (searches) {
              if (searches.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(
                    child: Text(
                      'No recent searches',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: searches.take(5).map((search) {
                  return ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(search['query'] ?? ''),
                    subtitle: Text(
                      '${search['result_count'] ?? 0} results',
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.north_west),
                      onPressed: () {
                        _searchController.text = search['query'] ?? '';
                        _onSearch(search['query'] ?? '');
                      },
                    ),
                    onTap: () {
                      _searchController.text = search['query'] ?? '';
                      _onSearch(search['query'] ?? '');
                    },
                  );
                }).toList(),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          
          SizedBox(height: AppSpacing.xl),
          
          // Frequent customers
          Text(
            'Frequent Customers',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          
          _buildFrequentCustomers(context),
        ],
      ),
    );
  }

  Widget _buildQuickAccessChip(String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }

  Widget _buildFrequentCustomers(BuildContext context) {
    final frequentAsync = ref.watch(frequentCustomersProvider);

    return frequentAsync.when(
      data: (customers) {
        if (customers.isEmpty) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];
              return _buildCustomerCard(customer);
            },
          ),
        );
      },
      loading: () => const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> customer) {
    final theme = Theme.of(context);
    final name = customer['full_name'] ?? customer['member_name'] ?? 'Unknown';
    final phone = customer['phone'] ?? '';
    final initials = name.split(' ').map((e) => e[0]).take(2).join().toUpperCase();

    return GestureDetector(
      onTap: () => _onCustomerTap(customer),
      child: Container(
        width: 140,
        margin: EdgeInsets.only(right: AppSpacing.sm),
        padding: EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text(
                initials,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              name,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2),
            Text(
              phone,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, List<Map<String, dynamic>> results) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final customer = results[index];
        return _buildSearchResultTile(customer);
      },
    );
  }

  Widget _buildSearchResultTile(Map<String, dynamic> customer) {
    final theme = Theme.of(context);
    final name = customer['full_name'] ?? customer['member_name'] ?? 'Unknown';
    final phone = customer['phone'] ?? '';
    final loanNumber = customer['loan_number'] ?? '';
    final area = customer['area'] ?? '';
    final outstandingAmount = (customer['outstanding_amount'] ?? 0).toDouble();

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withOpacity(0.1),
        child: Text(
          name.split(' ').map((e) => e[0]).take(2).join().toUpperCase(),
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      title: Text(
        name,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (phone.isNotEmpty) ...[
                Icon(Icons.phone, size: 12, color: theme.colorScheme.onSurfaceVariant),
                SizedBox(width: 4),
                Text(phone, style: theme.textTheme.bodySmall),
                SizedBox(width: AppSpacing.sm),
              ],
              if (area.isNotEmpty) ...[
                Icon(Icons.location_on, size: 12, color: theme.colorScheme.onSurfaceVariant),
                SizedBox(width: 4),
                Text(area, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
          if (loanNumber.isNotEmpty)
            Text(
              'Loan: $loanNumber',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '₹${AppFormatters.formatCompactCurrency(outstandingAmount)}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Outstanding',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      onTap: () => _onCustomerTap(customer),
    );
  }

  Widget _buildNoResults(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          SizedBox(height: AppSpacing.lg),
          Text(
            'No Results Found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Try a different search term',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
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
            'Search Failed',
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
            onPressed: () => _onSearch(_searchController.text),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
