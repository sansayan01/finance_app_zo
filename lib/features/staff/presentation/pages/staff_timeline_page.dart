import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../branch_manager/data/providers/branch_scoped_providers.dart';
import '../../../home/presentation/providers/staff_providers.dart';
import '../../data/providers/staff_branch_providers.dart';

class StaffTimelinePage extends ConsumerStatefulWidget {
  const StaffTimelinePage({super.key});

  @override
  ConsumerState<StaffTimelinePage> createState() => _StaffTimelinePageState();
}

class _StaffTimelinePageState extends ConsumerState<StaffTimelinePage> {
  String _activeFilter = 'all'; // 'all', 'collections', 'savings'
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  // Client-side pagination state
  final List<Map<String, dynamic>> _displayed = [];
  bool _hasMore = true;
  bool _initialLoaded = false;
  static const _pageSize = 20;

  // Full dataset cached from provider
  List<Map<String, dynamic>> _allFiltered = [];
  bool _needsRebuild = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (!_hasMore || !_initialLoaded) return;
    final nextBatch =
        _allFiltered.skip(_displayed.length).take(_pageSize).toList();
    setState(() {
      _displayed.addAll(nextBatch);
      _hasMore = _displayed.length < _allFiltered.length;
    });
  }

  void _resetAndRebuild(List<Map<String, dynamic>> source) {
    _allFiltered = _applyFilterAndSearch(source);
    setState(() {
      _displayed.clear();
      _displayed.addAll(_allFiltered.take(_pageSize));
      _hasMore = _displayed.length < _allFiltered.length;
      _initialLoaded = true;
    });
  }

  List<Map<String, dynamic>> _applyFilterAndSearch(
      List<Map<String, dynamic>> source) {
    var list = source;

    // Filter by type
    switch (_activeFilter) {
      case 'collections':
        list = list
            .where((c) => (c['collection_type'] ?? 'emi') != 'savings')
            .toList();
        break;
      case 'savings':
        list = list
            .where((c) => (c['collection_type'] ?? 'emi') == 'savings')
            .toList();
        break;
    }

    // Search by member name
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((c) {
        final name = (c['member_name'] as String? ?? '').toLowerCase();
        return name.contains(q);
      }).toList();
    }

    return list;
  }

  Future<void> _onRefresh() async {
    final branchId = ref.read(staffBranchIdProvider).valueOrNull;
    if (branchId != null) {
      ref.invalidate(staffCollectionHistoryProvider(branchId));
      ref.invalidate(branchRecentTransactionsProvider(branchId));
      ref.invalidate(staffTodayStatsProvider);
    }
    _needsRebuild = true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final branchAsync = ref.watch(staffBranchIdProvider);
    final todayStats = ref.watch(staffTodayStatsProvider);

    if (branchAsync.isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final branchId = branchAsync.valueOrNull;
    if (branchId == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(
          child: Text(
            'No branch assigned to your profile.\nContact your admin to assign a branch.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final collectionsAsync = ref.watch(staffCollectionHistoryProvider(branchId));

    // Rebuild displayed list when data arrives or filters change
    collectionsAsync.whenData((data) {
      if (_needsRebuild) {
        _needsRebuild = false;
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _resetAndRebuild(data));
      }
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            displacement: 20,
            color: theme.colorScheme.primary,
            backgroundColor: theme.cardColor,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                // ─── Header ───
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.arrow_back_rounded,
                                color: theme.colorScheme.primary, size: 20),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'COLLECTION TIMELINE',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  fontSize: 10,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              Text(
                                'My Collections',
                                style:
                                    theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ─── Today's Stats ───
                SliverToBoxAdapter(
                  child: todayStats.when(
                    data: (stats) => _buildTodayStats(stats, theme, isDark),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ─── Search Bar ───
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color:
                            isDark ? AppColors.fillDark : AppColors.fillLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.1)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) {
                          if (v.isEmpty && _searchQuery.isNotEmpty) {
                            _searchQuery = '';
                            _needsRebuild = true;
                            setState(() {});
                          }
                        },
                        onSubmitted: (v) {
                          _searchQuery = v;
                          _needsRebuild = true;
                          setState(() {});
                          // Trigger rebuild from cached data
                          final branchId =
                              ref.read(staffBranchIdProvider).valueOrNull;
                          if (branchId != null) {
                            final data = ref
                                .read(staffCollectionHistoryProvider(branchId))
                                .valueOrNull;
                            if (data != null) _resetAndRebuild(data);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Search by member name...',
                          hintStyle: theme.textTheme.bodySmall,
                          prefixIcon: Icon(Icons.search_rounded,
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.6),
                              size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded,
                                      size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchQuery = '';
                                    final branchId = ref
                                        .read(staffBranchIdProvider)
                                        .valueOrNull;
                                    if (branchId != null) {
                                      final data = ref
                                          .read(staffCollectionHistoryProvider(
                                              branchId))
                                          .valueOrNull;
                                      if (data != null) {
                                        _resetAndRebuild(data);
                                      }
                                    }
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                    ).animate().fadeIn(delay: 200.ms),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ─── Filter Chips ───
                SliverToBoxAdapter(
                  child: _buildFilterChips(theme, isDark),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ─── Collection List ───
                collectionsAsync.when(
                  data: (_) {
                    if (!_initialLoaded) {
                      return const SliverFillRemaining(
                        child:
                            Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (_displayed.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(theme, isDark),
                      );
                    }
                    return _buildCollectionSliver(theme, isDark);
                  },
                  loading: () => SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList.builder(
                      itemCount: 6,
                      itemBuilder: (_, __) => const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: _ShimmerCardPlaceholder(),
                      ),
                    ),
                  ),
                  error: (e, _) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 48, color: Color(0xFFEF4444)),
                          const SizedBox(height: 16),
                          Text('Error loading timeline',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.black87)),
                        ],
                      ),
                    ),
                  ),
                ),

                // Loading indicator at bottom
                if (_initialLoaded && !_hasMore && _displayed.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                      child: Center(
                        child: Text(
                          '— All ${_displayed.length} collections loaded —',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.4),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  const SliverToBoxAdapter(
                      child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Today's Stats Row ───

  Widget _buildTodayStats(
      StaffTodayStats stats, ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _StatMini(
              label: "TODAY'S COLLECTED",
              value: AppFormatters.formatCompactCurrency(stats.collected),
              icon: Icons.arrow_downward_rounded,
              color: AppColors.success,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatMini(
              label: 'PENDING DUES',
              value: stats.totalDues.toString(),
              icon: Icons.schedule_rounded,
              color: AppColors.warning,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatMini(
              label: 'COLLECTIONS',
              value: stats.collectedCount.toString(),
              icon: Icons.receipt_long_rounded,
              color: theme.colorScheme.primary,
              isDark: isDark,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  // ─── Filter Chips ───

  Widget _buildFilterChips(ThemeData theme, bool isDark) {
    final primary = theme.colorScheme.primary;
    final filters = [
      {'label': 'All', 'value': 'all', 'icon': Icons.receipt_long_rounded},
      {
        'label': 'Collections',
        'value': 'collections',
        'icon': Icons.payments_rounded
      },
      {'label': 'Savings', 'value': 'savings', 'icon': Icons.savings_rounded},
    ];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _activeFilter == filter['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() =>
                    _activeFilter = filter['value'] as String);
                // Rebuild from cached provider data
                final branchId =
                    ref.read(staffBranchIdProvider).valueOrNull;
                if (branchId != null) {
                  final data = ref
                      .read(staffCollectionHistoryProvider(branchId))
                      .valueOrNull;
                  if (data != null) _resetAndRebuild(data);
                }
              },
              child: AnimatedContainer(
                duration: 200.ms,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primary
                      : (isDark ? AppColors.fillDark : AppColors.fillLight),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? primary
                        : theme.dividerColor.withValues(alpha: 0.1),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Icon(
                      filter['icon'] as IconData,
                      size: 14,
                      color: isSelected
                          ? Colors.white
                          : theme.textTheme.bodyMedium?.color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      filter['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  // ─── Collection Sliver (grouped by date) ───

  Widget _buildCollectionSliver(ThemeData theme, bool isDark) {
    final grouped = _groupByDate(_displayed);
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final dateKey = dates[index];
            final items = grouped[dateKey]!;
            return _buildDateGroup(dateKey, items, theme, isDark);
          },
          childCount: dates.length,
        ),
      ),
    );
  }

  Widget _buildDateGroup(String dateKey, List<Map<String, dynamic>> items,
      ThemeData theme, bool isDark) {
    final label = _dateLabel(dateKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Divider(
                    color: theme.dividerColor.withValues(alpha: 0.15)),
              ),
            ],
          ),
        ),
        ...items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CollectionCard(
              collection: item,
              index: idx,
            ),
          );
        }),
      ],
    );
  }

  // ─── Date Helpers ───

  Map<String, List<Map<String, dynamic>>> _groupByDate(
      List<Map<String, dynamic>> collections) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final c in collections) {
      final date = c['collection_date'] as String? ?? 'Unknown';
      map.putIfAbsent(date, () => []).add(c);
    }
    return map;
  }

  String _dateLabel(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return AppFormatters.formatDate(date);
  }

  // ─── Empty State ───

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    final primary = theme.colorScheme.primary;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.timeline_rounded,
                size: 56, color: primary.withValues(alpha: 0.3)),
          ),
          const SizedBox(height: 20),
          Text('No Collections Found',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Collections will appear here as they are recorded.',
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

// ─── Collection Card (mirrors admin _TransactionCard) ───

class _CollectionCard extends StatelessWidget {
  final Map<String, dynamic> collection;
  final int index;

  const _CollectionCard({required this.collection, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final amount =
        (collection['amount_collected'] as num?)?.toDouble() ?? 0;
    final memberName =
        collection['member_name'] as String? ?? 'Unknown Member';
    final paymentMode = collection['payment_mode'] as String?;
    final collectionType =
        collection['collection_type'] as String? ?? 'emi';
    final time = collection['collection_time'] as String?;
    final collector =
        collection['collector'] as Map<String, dynamic>?;
    final collectorName = collector?['full_name'] as String?;
    final loanNumber = collection['loan_number'] as String?;

    final isSavings = collectionType == 'savings';
    final typeColor = isSavings
        ? (isDark ? AppColors.successDark : AppColors.success)
        : (isDark ? AppColors.successDark : AppColors.success);
    final typeIcon =
        isSavings ? Icons.savings_rounded : Icons.payments_rounded;
    final typeLabel = isSavings ? 'Savings Deposit' : 'EMI Payment';

    // Relative time
    String relativeTime = '';
    if (time != null) {
      final dateStr = collection['collection_date'] as String? ?? '';
      final parsed =
          DateTime.tryParse('${dateStr}T$time');
      if (parsed != null) {
        relativeTime = AppFormatters.formatRelativeTime(parsed);
      }
    }

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Type icon container
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: typeColor.withValues(alpha: 0.15)),
            ),
            child: Icon(typeIcon, color: typeColor, size: 22),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  memberName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(typeIcon, size: 10, color: typeColor),
                    const SizedBox(width: 4),
                    Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: typeColor,
                      ),
                    ),
                    if (paymentMode != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          paymentMode.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                    if (loanNumber != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        loanNumber,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? Colors.white30
                              : Colors.black26,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                if (relativeTime.isNotEmpty)
                  Text(
                    relativeTime,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: theme.textTheme.bodySmall?.color
                          ?.withValues(alpha: 0.6),
                    ),
                  ),
                if (collectorName != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded,
                          size: 11,
                          color: theme.textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.6)),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          'Collected by $collectorName',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${AppFormatters.formatCurrency(amount)}',
                style: TextStyle(
                  color: typeColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(
          delay: Duration(milliseconds: 50 * index.clamp(0, 15)),
          duration: 300.ms,
        );
  }
}

// ─── Stats Mini Card ───

class _StatMini extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatMini({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color:
                  theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shimmer Placeholder ───

class _ShimmerCardPlaceholder extends StatelessWidget {
  const _ShimmerCardPlaceholder();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
