import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../data/providers/collection_providers.dart';

class CustomerSearchPage extends ConsumerStatefulWidget {
  const CustomerSearchPage({super.key});

  @override
  ConsumerState<CustomerSearchPage> createState() => _CustomerSearchPageState();
}

class _CustomerSearchPageState extends ConsumerState<CustomerSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchResults = ref.watch(customerSearchProvider(_searchQuery));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Customers'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Name, Phone, or ID...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
        ),
      ),
      body: _searchQuery.isEmpty
          ? _buildInitialState(context)
          : searchResults.when(
              data: (customers) => _buildSearchResults(context, customers),
              loading: () => _buildLoadingState(),
              error: (err, _) => _buildErrorState(context, err.toString()),
            ),
    );
  }

  Widget _buildInitialState(BuildContext context) {
    final theme = Theme.of(context);
    final recentSearches = ref.watch(recentSearchesProvider);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search_outlined,
            size: 80,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          SizedBox(height: AppSpacing.lg),
          Text(
            'Search for customers',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (recentSearches.isNotEmpty) ...[
            SizedBox(height: AppSpacing.xl),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recent', style: theme.textTheme.titleSmall),
                  Wrap(
                    spacing: 8,
                    children: recentSearches.map((s) => ActionChip(
                      label: Text(s),
                      onPressed: () {
                        _searchController.text = s;
                        setState(() => _searchQuery = s);
                      },
                    )).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, List<Map<String, dynamic>> customers) {
    if (customers.isEmpty) {
      return Center(
        child: Text('No customers found for "$_searchQuery"'),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(AppSpacing.md),
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final customer = customers[index];
        return GlassCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                (customer['full_name'] ?? 'U')[0].toUpperCase(),
                style: const TextStyle(color: AppColors.primary),
              ),
            ),
            title: Text(customer['full_name'] ?? 'Unknown'),
            subtitle: Text(customer['phone'] ?? 'No phone'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              HapticFeedback.selectionClick();
              // Update recent searches
              final recent = ref.read(recentSearchesProvider);
              if (!recent.contains(_searchQuery) && _searchQuery.isNotEmpty) {
                ref.read(recentSearchesProvider.notifier).state = [
                  _searchQuery,
                  ...recent.take(4),
                ];
              }
              context.push('/staff/customer/${customer['id']}', extra: customer);
            },
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: ShimmerCard(height: 80),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error searching: $error', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
