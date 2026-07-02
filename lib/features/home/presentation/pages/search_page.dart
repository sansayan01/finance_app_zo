import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/search_providers.dart';

class SearchPage extends ConsumerStatefulWidget {
  final String? initialQuery;
  const SearchPage({super.key, this.initialQuery});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    // If there's an initial query, set it and trigger search
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _controller.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(searchProvider.notifier).setQuery(widget.initialQuery!);
      });
    } else {
      Future.delayed(300.ms, () => _focusNode.requestFocus());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<SearchResult> get _filteredResults {
    final state = ref.watch(searchProvider);
    if (_selectedFilter == 'All') return state.results;
    return state.results.where((r) {
      switch (_selectedFilter) {
        case 'Members':
          return r.type == SearchResultType.member;
        case 'Staff':
          return r.type == SearchResultType.staff;
        case 'Loans':
          return r.type == SearchResultType.loan;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.98),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.08),
                          ),
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          style: theme.textTheme.bodyLarge,
                          decoration: InputDecoration(
                            hintText: 'Search members, staff, loans...',
                            hintStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textTertiaryLight,
                            ),
                            border: InputBorder.none,
                            icon: Icon(
                              Icons.search_rounded,
                              color: searchState.isLoading
                                  ? theme.colorScheme.primary
                                  : AppColors.textTertiaryLight,
                            ),
                            suffixIcon: _controller.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: AppColors.textTertiaryLight,
                                    ),
                                    onPressed: () {
                                      _controller.clear();
                                      ref.read(searchProvider.notifier).clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (value) {
                            ref.read(searchProvider.notifier).setQuery(value);
                            setState(() {});
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () {
                        ref.read(searchProvider.notifier).clear();
                        context.pop();
                      },
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Chips
              if (_controller.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: _selectedFilter == 'All',
                        onTap: () => setState(() => _selectedFilter = 'All'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Members',
                        isSelected: _selectedFilter == 'Members',
                        onTap: () => setState(() => _selectedFilter = 'Members'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Staff',
                        isSelected: _selectedFilter == 'Staff',
                        onTap: () => setState(() => _selectedFilter = 'Staff'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Loans',
                        isSelected: _selectedFilter == 'Loans',
                        onTap: () => setState(() => _selectedFilter = 'Loans'),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // Results
              Expanded(
                child: _buildContent(searchState),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(SearchState state) {
    final theme = Theme.of(context);
    final filteredResults = _filteredResults;

    if (state.query.length < 2) {
      return _buildEmptyState(
        icon: Icons.search_rounded,
        title: 'Search your organization',
        subtitle: 'Find members, staff, or loans by name, phone, or ID',
      );
    }

    if (state.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Searching...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textTertiaryLight,
              ),
            ),
          ],
        ),
      );
    }

    if (state.error != null) {
      return _buildEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Search failed',
        subtitle: state.error!,
      );
    }

    if (filteredResults.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results found',
        subtitle: 'Try a different search term or filter',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: filteredResults.length,
      itemBuilder: (context, index) {
        final result = filteredResults[index];
        return _SearchResultCard(
          result: result,
          onTap: () => _navigateToResult(result),
        );
      },
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: AppColors.textTertiaryLight.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textTertiaryLight,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textTertiaryLight.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  void _navigateToResult(SearchResult result) {
    ref.read(searchProvider.notifier).clear();
    if (result.route != null) {
      context.push(result.route!);
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.3)
                : isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isSelected
                ? theme.colorScheme.primary
                : AppColors.textTertiaryLight,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const _SearchResultCard({
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Type-specific config
    IconData icon;
    Color color;

    switch (result.type) {
      case SearchResultType.member:
        icon = Icons.person_rounded;
        color = isDark ? AppColors.accentDark : AppColors.accentLight;
        break;
      case SearchResultType.staff:
        icon = Icons.badge_rounded;
        color = isDark ? AppColors.successDark : AppColors.success;
        break;
      case SearchResultType.loan:
        icon = Icons.request_quote_rounded;
        color = isDark ? AppColors.primaryDark : AppColors.primary;
        break;
      case SearchResultType.transaction:
        icon = Icons.receipt_long_rounded;
        color = isDark ? AppColors.warningDark : AppColors.warning;
        break;
      case SearchResultType.savings:
        icon = Icons.savings_rounded;
        color = isDark ? AppColors.successDark : AppColors.success;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (result.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          result.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: AppColors.textTertiaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (result.trailing != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      result.trailing!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiaryLight.withValues(alpha: 0.5),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
