// ignore_for_file: deprecated_member_use
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/layout.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../users/data/repositories/user_repository.dart';
import '../../../users/presentation/providers/new_user_provider.dart';
import '../../../users/presentation/providers/user_list_provider.dart';
import '../../data/providers/branch_manager_providers.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';

// =============================================================================
// BRANCH-SCOPED TAB ENUM
// =============================================================================

enum _BranchTab { team, customers, suspended }

// =============================================================================
// BRANCH-SCOPED QUERY STATE
// =============================================================================

class _BranchQuery {
  final String search;
  final UserRole? roleFilter;
  final UserSortBy sortBy;

  const _BranchQuery({
    this.search = '',
    this.roleFilter,
    this.sortBy = UserSortBy.createdDesc,
  });

  _BranchQuery copyWith({
    String? search,
    Object? roleFilter = const Object(),
    UserSortBy? sortBy,
  }) {
    return _BranchQuery(
      search: search ?? this.search,
      roleFilter: roleFilter == const Object()
          ? this.roleFilter
          : roleFilter as UserRole?,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  bool get hasFilter => search.isNotEmpty || roleFilter != null;
}

class _BranchQueryNotifier extends StateNotifier<_BranchQuery> {
  _BranchQueryNotifier() : super(const _BranchQuery());

  void setSearch(String v) => state = state.copyWith(search: v);
  void setRole(UserRole? r) => state = state.copyWith(roleFilter: r);
  void setSort(UserSortBy s) => state = state.copyWith(sortBy: s);
  void reset() => state = const _BranchQuery();
}

final _branchQueryProvider = StateNotifierProvider.family<
    _BranchQueryNotifier, _BranchQuery, _BranchTab>(
  (ref, tab) => _BranchQueryNotifier(),
);

// =============================================================================
// BRANCH-SCOPED STATS PROVIDER
// =============================================================================

final _branchUserStatsProvider =
    FutureProvider.family<Map<String, int>, String>((ref, branchId) async {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  final stats = <String, int>{
    'total': 0,
    'staff': 0,
    'customers': 0,
    'suspended': 0,
  };

  try {
    final response = await client
        .from('profiles')
        .select('role,status')
        .eq('org_id', orgId)
        .eq('branch_id', branchId);

    for (final r in (response as List? ?? [])) {
      if (r is! Map) continue;
      final role = (r['role'] ?? '').toString().toLowerCase();
      final status = (r['status'] ?? 'active').toString().toLowerCase();

      if (status == 'suspended' || status == 'inactive') {
        stats['suspended'] = (stats['suspended'] ?? 0) + 1;
        continue;
      }
      if (role.contains('manager') ||
          role.contains('agent') ||
          role == 'staff' ||
          role == 'collector') {
        stats['staff'] = (stats['staff'] ?? 0) + 1;
      } else if (role.contains('customer')) {
        stats['customers'] = (stats['customers'] ?? 0) + 1;
      }
    }
  } catch (e) {
    debugPrint('_branchUserStatsProvider profiles error: $e');
  }

  try {
    final r = await client
        .from('members')
        .select('id')
        .eq('org_id', orgId)
        .eq('branch_id', branchId)
        .isFilter('profile_id', null);
    stats['customers'] =
        (stats['customers'] ?? 0) + ((r as List?)?.length ?? 0);
  } catch (e) {
    debugPrint('_branchUserStatsProvider members error: $e');
  }

  stats['total'] = (stats['staff']! + stats['customers']! + stats['suspended']!)
      .toInt();
  return stats;
});

// =============================================================================
// BRANCH-SCOPED PAGE STATE
// =============================================================================

class _BranchPageState {
  final List<ProfileModel> items;
  final bool isLoading;
  final bool hasMore;
  final Object? error;

  const _BranchPageState({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  _BranchPageState copyWith({
    List<ProfileModel>? items,
    bool? isLoading,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) {
    return _BranchPageState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class _BranchPageNotifier extends StateNotifier<_BranchPageState> {
  final UserRepository _repo;
  final _BranchTab _tab;
  final _BranchQuery _query;
  final String _branchId;

  static const int _pageSize = 25;

  _BranchPageNotifier(this._repo, this._tab, this._query, this._branchId)
      : super(const _BranchPageState()) {
    loadFirstPage();
  }

  Future<void> loadFirstPage() async {
    state = const _BranchPageState(isLoading: true, hasMore: true);
    await _fetch(0);
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true, clearError: true);
    await _fetch(state.items.length);
  }

  Future<void> _fetch(int offset) async {
    try {
      final batch = await _runQuery(offset);
      final merged = offset == 0 ? batch : [...state.items, ...batch];
      state = state.copyWith(
        items: merged,
        isLoading: false,
        hasMore: batch.length >= _pageSize,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<List<ProfileModel>> _runQuery(int offset) async {
    switch (_tab) {
      case _BranchTab.team:
        final roles = _query.roleFilter != null
            ? <UserRole>{_query.roleFilter!}
            : <UserRole>{UserRole.manager, UserRole.collectionAgent};
        return _repo.getProfilesPaginated(
          roles: roles,
          excludeStatuses: const {
            AccountStatus.suspended,
            AccountStatus.inactive,
          },
          branchId: _branchId,
          search: _query.search,
          sortBy: _query.sortBy,
          offset: offset,
          limit: _pageSize,
        );
      case _BranchTab.customers:
        return _repo.getMembersPaginated(
          branchId: _branchId,
          search: _query.search,
          sortBy: _query.sortBy,
          offset: offset,
          limit: _pageSize,
        );
      case _BranchTab.suspended:
        return _repo.getProfilesPaginated(
          includeStatuses: const {
            AccountStatus.suspended,
            AccountStatus.inactive,
          },
          branchId: _branchId,
          search: _query.search,
          sortBy: _query.sortBy,
          offset: offset,
          limit: _pageSize,
        );
    }
  }
}

final _branchPageProvider = StateNotifierProvider.family<_BranchPageNotifier,
    _BranchPageState, _BranchTab>(
  (ref, tab) {
    final repo = ref.watch(userRepositoryProvider);
    final query = ref.watch(_branchQueryProvider(tab));
    final branchId = ref.watch(currentUserBranchIdProvider);
    return _BranchPageNotifier(repo, tab, query, branchId ?? '');
  },
);

// =============================================================================
// MAIN PAGE
// =============================================================================

class BranchUsersPage extends ConsumerStatefulWidget {
  const BranchUsersPage({super.key});

  @override
  ConsumerState<BranchUsersPage> createState() => _BranchUsersPageState();
}

class _BranchUsersPageState extends ConsumerState<BranchUsersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _teamScroll = ScrollController();
  final ScrollController _customersScroll = ScrollController();
  final ScrollController _suspendedScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_onTabChanged);
    _teamScroll.addListener(
        () => _maybeLoadMore(_teamScroll, _BranchTab.team));
    _customersScroll.addListener(
        () => _maybeLoadMore(_customersScroll, _BranchTab.customers));
    _suspendedScroll.addListener(
        () => _maybeLoadMore(_suspendedScroll, _BranchTab.suspended));
    Future.microtask(() {
      final branchId = ref.read(currentUserBranchIdProvider);
      if (branchId != null) {
        ref.invalidate(_branchUserStatsProvider(branchId));
      }
      for (final tab in _BranchTab.values) {
        ref.invalidate(_branchPageProvider(tab));
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchCtrl.dispose();
    _teamScroll.dispose();
    _customersScroll.dispose();
    _suspendedScroll.dispose();
    super.dispose();
  }

  _BranchTab get _currentTab => _BranchTab.values[_tabController.index];

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final query = ref.read(_branchQueryProvider(_currentTab));
    _searchCtrl.text = query.search;
    if (mounted) setState(() {});
  }

  void _maybeLoadMore(ScrollController c, _BranchTab tab) {
    if (!c.hasClients) return;
    if (c.position.pixels >= c.position.maxScrollExtent - 240) {
      ref.read(_branchPageProvider(tab).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final branchId = ref.watch(currentUserBranchIdProvider);

    if (branchId == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off_rounded,
                  size: 56, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('No branch assigned',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: Padding(
        padding: kFabSafeAreaPadding,
        child: _AddUserFab(
          onTap: () => context.push('/branch/users/new'),
        ),
      ),
      body: Stack(
        children: [
          const _AuroraBackdrop(),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(theme, isDark),
                _buildHero(theme, branchId),
                const SizedBox(height: 18),
                _BranchStatsRail(branchId: branchId),
                const SizedBox(height: 18),
                _SmartSearchBar(
                  controller: _searchCtrl,
                  hint: _searchHint(_currentTab),
                  hasActiveFilters: _hasActiveFilters(_currentTab),
                  onChanged: (v) {
                    ref
                        .read(_branchQueryProvider(_currentTab).notifier)
                        .setSearch(v);
                    ref
                        .read(_branchPageProvider(_currentTab).notifier)
                        .loadFirstPage();
                  },
                  onClear: () {
                    _searchCtrl.clear();
                    ref
                        .read(_branchQueryProvider(_currentTab).notifier)
                        .setSearch('');
                    ref
                        .read(_branchPageProvider(_currentTab).notifier)
                        .loadFirstPage();
                  },
                  onTune: _openFilterSheet,
                ),
                _ActiveFiltersStrip(tab: _currentTab),
                const SizedBox(height: 14),
                _SegmentedTabs(controller: _tabController),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _TeamTabView(scroll: _teamScroll),
                      _CustomersTabView(scroll: _customersScroll),
                      _SuspendedTabView(scroll: _suspendedScroll),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Layout building blocks
  // ---------------------------------------------------------------------------

  Widget _buildAppBar(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: () => context.pop(),
          ),
          const Spacer(),
          _GlassIconButton(
            icon: Icons.tune_rounded,
            tooltip: 'Filter & sort',
            highlight: _hasActiveFilters(_currentTab),
            onTap: _openFilterSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildHero(ThemeData theme, String branchId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BRANCH TEAM',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.2,
                    fontSize: 10,
                    color: theme.colorScheme.primary,
                  ),
                ).animate().fadeIn(duration: 350.ms).slideX(begin: -0.1, end: 0),
                const SizedBox(height: 4),
                ShaderMask(
                  shaderCallback: (rect) => LinearGradient(
                    colors: [
                      theme.colorScheme.onSurface,
                      theme.colorScheme.primary,
                    ],
                  ).createShader(rect),
                  child: Text(
                    'User Hub',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.4,
                      fontSize: 32,
                      color: Colors.white,
                    ),
                  ),
                ).animate().fadeIn(delay: 80.ms).slideX(begin: -0.05, end: 0),
                const SizedBox(height: 4),
                Text(
                  'Your branch workforce at a glance',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.7),
                  ),
                ).animate().fadeIn(delay: 160.ms),
              ],
            ),
          ),
          _TotalChip(branchId: branchId),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search & filter helpers
  // ---------------------------------------------------------------------------

  String _searchHint(_BranchTab tab) => switch (tab) {
        _BranchTab.team =>
          'Search staff by name, email, phone or staff code…',
        _BranchTab.customers =>
          'Search customers by name, phone, email or member ID…',
        _BranchTab.suspended =>
          'Search suspended users by name, email or phone…',
      };

  bool _hasActiveFilters(_BranchTab tab) {
    final q = ref.watch(_branchQueryProvider(tab));
    return q.roleFilter != null || q.sortBy != UserSortBy.createdDesc;
  }

  void _openFilterSheet() {
    final tab = _currentTab;
    final query = ref.read(_branchQueryProvider(tab));
    UserRole? roleFilter = query.roleFilter;
    UserSortBy sort = query.sortBy;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.fromLTRB(
                20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.tune_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text('Filter & sort',
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            )),
                  ],
                ),
                const SizedBox(height: 22),
                if (tab == _BranchTab.team) ...[
                  const _SheetSectionLabel('Role'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ChoiceChip(
                        label: 'All',
                        selected: roleFilter == null,
                        onSelected: () => setSheet(() => roleFilter = null),
                      ),
                      for (final r in const [
                        UserRole.manager,
                        UserRole.collectionAgent,
                      ])
                        _ChoiceChip(
                          label: _roleLabel(r),
                          icon: _roleIcon(r),
                          selected: roleFilter == r,
                          onSelected: () => setSheet(() => roleFilter = r),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                ],
                const _SheetSectionLabel('Sort'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in UserSortBy.values)
                      _ChoiceChip(
                        label: s.label,
                        selected: sort == s,
                        onSelected: () => setSheet(() => sort = s),
                      ),
                  ],
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setSheet(() {
                            roleFilter = null;
                            sort = UserSortBy.createdDesc;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          ref
                              .read(_branchQueryProvider(tab).notifier)
                            ..setRole(roleFilter)
                            ..setSort(sort);
                          ref
                              .read(_branchPageProvider(tab).notifier)
                              .loadFirstPage();
                          Navigator.pop(ctx);
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Apply',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

}

// =============================================================================
// HERO PIECES
// =============================================================================

class _TotalChip extends ConsumerWidget {
  final String branchId;
  const _TotalChip({required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(_branchUserStatsProvider(branchId));
    final total = stats.maybeWhen(data: (s) => s['total'] ?? 0, orElse: () => 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.16),
            theme.colorScheme.secondary.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.groups_2_rounded,
              size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          _CountUp(
            target: total,
            duration: const Duration(milliseconds: 800),
            builder: (v) => Text(
              v.toString(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'total',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary.withValues(alpha: 0.75),
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 220.ms).scale(
        begin: const Offset(0.85, 0.85),
        end: const Offset(1, 1),
        curve: Curves.easeOutBack);
  }
}

// =============================================================================
// STATS RAIL
// =============================================================================

class _BranchStatsRail extends ConsumerWidget {
  final String branchId;
  const _BranchStatsRail({required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final stats = ref.watch(_branchUserStatsProvider(branchId));

    return SizedBox(
      height: 110,
      child: stats.when(
        data: (s) {
          final tiles = <_StatTileData>[
            _StatTileData(
              label: 'Total',
              value: s['total'] ?? 0,
              icon: Icons.people_alt_rounded,
              color: primary,
              gradient: AppColors.premiumGradient,
            ),
            _StatTileData(
              label: 'Staff',
              value: s['staff'] ?? 0,
              icon: Icons.support_agent_rounded,
              color: isDark ? AppColors.warningDark : AppColors.orange,
            ),
            _StatTileData(
              label: 'Customers',
              value: s['customers'] ?? 0,
              icon: Icons.groups_rounded,
              color: isDark ? AppColors.successDark : AppColors.success,
            ),
            _StatTileData(
              label: 'Suspended',
              value: s['suspended'] ?? 0,
              icon: Icons.block_rounded,
              color: AppColors.error,
            ),
          ];
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            physics: const BouncingScrollPhysics(),
            itemBuilder: (ctx, i) => _StatTile(data: tiles[i], index: i),
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: tiles.length,
          );
        },
        loading: () => ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemBuilder: (_, __) => const _StatTileSkeleton(),
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemCount: 4,
        ),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}

class _StatTileData {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final List<Color>? gradient;
  _StatTileData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.gradient,
  });
}

class _StatTile extends StatelessWidget {
  final _StatTileData data;
  final int index;
  const _StatTile({required this.data, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: 138,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: data.gradient != null
              ? [
                  data.gradient![0].withValues(alpha: isDark ? 0.18 : 0.10),
                  data.gradient![1].withValues(alpha: isDark ? 0.10 : 0.06),
                ]
              : [
                  data.color.withValues(alpha: isDark ? 0.15 : 0.10),
                  data.color.withValues(alpha: isDark ? 0.06 : 0.04),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: data.color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: data.color.withValues(alpha: isDark ? 0.10 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(data.icon, color: data.color, size: 16),
              ),
              const Spacer(),
              _CountUp(
                target: data.value,
                duration: Duration(milliseconds: 700 + index * 80),
                builder: (v) => Text(
                  v.toString(),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: data.color,
                    letterSpacing: -1,
                    fontSize: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            data.label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color:
                  theme.textTheme.bodySmall?.color?.withValues(alpha: 0.85),
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 18,
            child: _MiniSparkline(
              color: data.color,
              seed: data.label.codeUnitAt(0) + data.value,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: (60 * index).ms, duration: 350.ms)
        .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic);
  }
}

class _StatTileSkeleton extends StatelessWidget {
  const _StatTileSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.surfaceContainerHighest
        .withValues(alpha: 0.4);
    return Container(
      width: 138,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

// =============================================================================
// MINI SPARKLINE
// =============================================================================

class _MiniSparkline extends StatelessWidget {
  final Color color;
  final int seed;
  const _MiniSparkline({required this.color, required this.seed});

  @override
  Widget build(BuildContext context) {
    final rng = math.Random(seed);
    final pts = List.generate(12, (_) => 0.3 + rng.nextDouble() * 0.7);
    return CustomPaint(
      painter: _SparklinePainter(points: pts, color: color),
      size: Size.infinite,
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;
  _SparklinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final dx = size.width / (points.length - 1);
    final path = Path();
    final fill = Path();
    for (int i = 0; i < points.length; i++) {
      final x = i * dx;
      final y = size.height - points[i] * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        final prevX = (i - 1) * dx;
        final prevY = size.height - points[i - 1] * size.height;
        final cpx = (prevX + x) / 2;
        path.cubicTo(cpx, prevY, cpx, y, x, y);
        fill.cubicTo(cpx, prevY, cpx, y, x, y);
      }
    }
    fill
      ..lineTo(size.width, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.30),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fill, fillPaint);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.95);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}

// =============================================================================
// SEARCH BAR
// =============================================================================

class _SmartSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool hasActiveFilters;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onTune;

  const _SmartSearchBar({
    required this.controller,
    required this.hint,
    required this.hasActiveFilters,
    required this.onChanged,
    required this.onClear,
    required this.onTune,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.04),
              blurRadius: 18,
              offset: const Offset(0, 6),
              spreadRadius: -8,
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Icon(Icons.search_rounded,
                size: 20,
                color: theme.textTheme.bodySmall?.color
                    ?.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.6),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.cancel_rounded, size: 18),
                color:
                    theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                onPressed: onClear,
              ),
            const SizedBox(width: 4),
            _TuneChip(
                primary: primary,
                onTap: onTune,
                isActive: hasActiveFilters),
            const SizedBox(width: 4),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 280.ms).slideY(begin: 0.1, end: 0);
  }
}

class _TuneChip extends StatelessWidget {
  final Color primary;
  final VoidCallback onTap;
  final bool isActive;
  const _TuneChip(
      {required this.primary, required this.onTap, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [
                    primary,
                    primary.withValues(alpha: 0.7),
                  ],
                )
              : null,
          color: isActive ? null : primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(
                Icons.tune_rounded,
                size: 18,
                color: isActive ? Colors.white : primary,
              ),
            ),
            if (isActive)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ACTIVE FILTERS STRIP
// =============================================================================

class _ActiveFiltersStrip extends ConsumerWidget {
  final _BranchTab tab;
  const _ActiveFiltersStrip({required this.tab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(_branchQueryProvider(tab));
    final notifier = ref.read(_branchQueryProvider(tab).notifier);
    final pageNotifier = ref.read(_branchPageProvider(tab).notifier);
    final theme = Theme.of(context);

    final chips = <Widget>[];

    if (query.roleFilter != null) {
      chips.add(_FilterChipPill(
        icon: _roleIcon(query.roleFilter!),
        label: 'Role · ${_roleLabel(query.roleFilter!)}',
        color: _roleColor(query.roleFilter),
        onClose: () {
          notifier.setRole(null);
          pageNotifier.loadFirstPage();
        },
      ));
    }

    if (query.sortBy != UserSortBy.createdDesc) {
      chips.add(_FilterChipPill(
        icon: Icons.sort_rounded,
        label: 'Sort · ${query.sortBy.label}',
        color: theme.colorScheme.primary,
        onClose: () {
          notifier.setSort(UserSortBy.createdDesc);
          pageNotifier.loadFirstPage();
        },
      ));
    }

    if (chips.isEmpty) return const SizedBox(height: 0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemBuilder: (_, i) => chips[i],
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemCount: chips.length,
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

class _FilterChipPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onClose;
  const _FilterChipPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 13, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SEGMENTED TABS
// =============================================================================

class _SegmentedTabs extends ConsumerWidget {
  final TabController controller;
  const _SegmentedTabs({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final branchId = ref.watch(currentUserBranchIdProvider);
    final stats = branchId != null
        ? ref.watch(_branchUserStatsProvider(branchId))
        : null;

    int? counts(_BranchTab t) => stats?.maybeWhen(
          data: (s) => switch (t) {
            _BranchTab.team => s['staff'] ?? 0,
            _BranchTab.customers => s['customers'] ?? 0,
            _BranchTab.suspended => s['suspended'] ?? 0,
          },
          orElse: () => null,
        );

    const tabs = [
      ('Team', Icons.shield_outlined, _BranchTab.team),
      ('Customers', Icons.people_outline_rounded, _BranchTab.customers),
      ('Suspended', Icons.block_outlined, _BranchTab.suspended),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.04),
          ),
        ),
        child: AnimatedBuilder(
          animation: controller.animation ?? const AlwaysStoppedAnimation(0),
          builder: (ctx, _) {
            return LayoutBuilder(
              builder: (ctx, c) {
                final segWidth = c.maxWidth / tabs.length;
                final pos =
                    (controller.animation?.value ?? controller.index.toDouble())
                        .clamp(0.0, (tabs.length - 1).toDouble());
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      left: pos * segWidth,
                      top: 0,
                      bottom: 0,
                      width: segWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primary,
                              primary.withValues(alpha: 0.85),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.30),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < tabs.length; i++)
                          Expanded(
                            child: _SegmentTab(
                              label: tabs[i].$1,
                              icon: tabs[i].$2,
                              selected: controller.index == i,
                              count: counts(tabs[i].$3),
                              onTap: () {
                                HapticService.selection();
                                controller.animateTo(i);
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    ).animate().fadeIn(delay: 320.ms).slideY(begin: 0.1, end: 0);
  }
}

class _SegmentTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final int? count;
  final VoidCallback onTap;
  const _SegmentTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? Colors.white
        : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.65);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  count! > 99 ? '99+' : count.toString(),
                  style: TextStyle(
                    color: selected ? Colors.white : theme.colorScheme.primary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// TAB VIEWS
// =============================================================================

class _TeamTabView extends ConsumerWidget {
  final ScrollController scroll;
  const _TeamTabView({required this.scroll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_branchPageProvider(_BranchTab.team));

    return _PaginatedList(
      tab: _BranchTab.team,
      state: state,
      scroll: scroll,
      buildItem: (p) => _UserRow(profile: p, showStatus: true),
      emptyTitle: 'No staff members',
      emptyHint: 'Tap + to add staff to your branch.',
      emptyIcon: Icons.shield_moon_rounded,
    );
  }
}

class _CustomersTabView extends ConsumerWidget {
  final ScrollController scroll;
  const _CustomersTabView({required this.scroll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_branchPageProvider(_BranchTab.customers));
    return _PaginatedList(
      tab: _BranchTab.customers,
      state: state,
      scroll: scroll,
      buildItem: (p) => _UserRow(profile: p, showStatus: false),
      emptyTitle: 'No customers',
      emptyHint: 'Add a customer to get started.',
      emptyIcon: Icons.groups_rounded,
    );
  }
}

class _SuspendedTabView extends ConsumerWidget {
  final ScrollController scroll;
  const _SuspendedTabView({required this.scroll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_branchPageProvider(_BranchTab.suspended));
    return _PaginatedList(
      tab: _BranchTab.suspended,
      state: state,
      scroll: scroll,
      buildItem: (p) => _UserRow(profile: p, showStatus: true),
      emptyTitle: 'No suspended accounts',
      emptyHint: 'Suspended or deactivated users will appear here.',
      emptyIcon: Icons.block_rounded,
    );
  }
}

// =============================================================================
// PAGINATED LIST SHELL
// =============================================================================

class _PaginatedList extends StatelessWidget {
  final _BranchTab tab;
  final _BranchPageState state;
  final ScrollController scroll;
  final Widget Function(ProfileModel) buildItem;
  final String emptyTitle;
  final String emptyHint;
  final IconData emptyIcon;
  const _PaginatedList({
    required this.tab,
    required this.state,
    required this.scroll,
    required this.buildItem,
    required this.emptyTitle,
    required this.emptyHint,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty && state.isLoading) {
      return const _RowShimmerList();
    }
    if (state.items.isEmpty && state.error != null) {
      return _EmptyState(
        title: 'Something went wrong',
        hint: '${state.error}',
        icon: Icons.error_outline_rounded,
      );
    }
    if (state.items.isEmpty) {
      return _EmptyState(
        title: emptyTitle,
        hint: emptyHint,
        icon: emptyIcon,
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        // ignore: use_build_context_synchronously
        final container = ProviderScope.containerOf(context, listen: false);
        await container
            .read(_branchPageProvider(tab).notifier)
            .loadFirstPage();
      },
      child: ListView.builder(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 140),
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i >= state.items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: buildItem(state.items[i]),
          );
        },
      ),
    );
  }
}

class _RowShimmerList extends StatelessWidget {
  const _RowShimmerList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.surfaceContainerHighest
        .withValues(alpha: 0.4);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 140),
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (_, __) => Container(
        height: 88,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: 6,
    );
  }
}

// =============================================================================
// USER ROW
// =============================================================================

class _UserRow extends ConsumerWidget {
  final ProfileModel profile;
  final bool showStatus;

  const _UserRow({
    required this.profile,
    required this.showStatus,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final roleColor = _roleColor(profile.role);

    return GlassCard(
      padding: const EdgeInsets.all(14),
      onTap: () {
        HapticService.selection();
        context.push('/branch/members/${profile.id}');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(profile: profile, color: roleColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile.fullName ?? 'Unknown',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (showStatus) _StatusChip(status: profile.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _RoleChip(role: profile.role, color: roleColor),
                        if ((profile.phone ?? '').isNotEmpty)
                          _MutedChipText(
                            icon: Icons.phone_rounded,
                            text: profile.phone!,
                          ),
                        if ((profile.memberCode ?? '').isNotEmpty)
                          _MutedChipText(
                            icon: Icons.badge_rounded,
                            text: profile.memberCode!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              _RowActions(profile: profile),
            ],
          ),
        ],
      ),
    );
  }
}

class _MutedChipText extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MutedChipText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 10.5,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6)),
        const SizedBox(width: 3),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _RowActions extends ConsumerWidget {
  final ProfileModel profile;
  const _RowActions({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if ((profile.phone ?? '').isNotEmpty)
          _IconBtn(
            icon: Icons.call_rounded,
            tooltip: 'Call',
            onTap: () => _launch('tel:${profile.phone!}'),
          ),
        if ((profile.phone ?? '').isNotEmpty)
          _IconBtn(
            icon: Icons.chat_bubble_rounded,
            tooltip: 'WhatsApp',
            onTap: () => _launch('https://wa.me/${profile.phone!}'),
          ),
        PopupMenuButton<String>(
          tooltip: 'More',
          icon: const Icon(Icons.more_vert_rounded, size: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          itemBuilder: (ctx) => [
            const PopupMenuItem(
                value: 'view',
                child: ListTile(
                    leading: Icon(Icons.visibility_outlined),
                    title: Text('View profile'))),
            if (!profile.isMember &&
                profile.status != AccountStatus.suspended)
              const PopupMenuItem(
                  value: 'suspend',
                  child: ListTile(
                      leading: Icon(Icons.block_rounded),
                      title: Text('Suspend'))),
            if (!profile.isMember &&
                (profile.status == AccountStatus.suspended ||
                    profile.status == AccountStatus.inactive))
              const PopupMenuItem(
                  value: 'reactivate',
                  child: ListTile(
                      leading: Icon(Icons.power_settings_new_rounded,
                          color: AppColors.success),
                      title: Text('Reactivate'))),
          ],
          onSelected: (v) => _handleAction(context, ref, v),
        ),
      ],
    );
  }

  Future<void> _handleAction(
      BuildContext context, WidgetRef ref, String value) async {
    final notifier = ref.read(userAdminProvider.notifier);
    switch (value) {
      case 'view':
        context.push('/branch/members/${profile.id}');
        break;
      case 'suspend':
        final confirmed = await _confirm(context,
            title: 'Suspend ${profile.fullName ?? "this user"}?',
            message:
                'They will lose access immediately. You can reactivate them later.',
            confirmLabel: 'Suspend',
            destructive: true);
        if (confirmed != true) return;
        final ok =
            await notifier.changeStatus(profile.id, AccountStatus.suspended);
        if (context.mounted) {
          _snack(context, ok ? 'User suspended' : 'Failed to suspend',
              success: ok);
        }
        break;
      case 'reactivate':
        final ok =
            await notifier.changeStatus(profile.id, AccountStatus.active);
        if (context.mounted) {
          _snack(context, ok ? 'User reactivated' : 'Failed to reactivate',
              success: ok);
        }
        break;
    }
  }

  Future<bool?> _confirm(BuildContext context,
      {required String title,
      required String message,
      required String confirmLabel,
      bool destructive = false}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: destructive
                ? TextButton.styleFrom(foregroundColor: AppColors.error)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String msg, {bool success = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

// =============================================================================
// ADD USER FAB
// =============================================================================

class _AddUserFab extends StatelessWidget {
  final VoidCallback onTap;
  const _AddUserFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;
    return GestureDetector(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [primary, secondary]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              HapticService.light();
              onTap();
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_add_alt_1_rounded,
                      color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Add User',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .scale(delay: 250.ms, duration: 300.ms, curve: Curves.easeOutBack);
  }
}

// =============================================================================
// SMALL WIDGETS
// =============================================================================

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool highlight;
  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: highlight
                ? primary.withValues(alpha: 0.14)
                : theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: highlight
                  ? primary.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(icon,
                    size: 20,
                    color: highlight ? primary : theme.colorScheme.onSurface),
              ),
              if (highlight)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _IconBtn(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticService.selection();
            onTap();
          },
          borderRadius: BorderRadius.circular(10),
          child: Tooltip(
            message: tooltip,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: primary),
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final ProfileModel profile;
  final Color color;
  const _Avatar({required this.profile, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOnline = profile.status == AccountStatus.active && !profile.isMember;
    final isSuspended = profile.status == AccountStatus.suspended ||
        profile.status == AccountStatus.inactive;
    return Hero(
      tag: 'branch_user_avatar_${profile.id}',
      child: Container(
        width: 52,
        height: 52,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.85),
              color.withValues(alpha: 0.35),
            ],
          ),
        ),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: (profile.avatarUrl != null &&
                        profile.avatarUrl!.trim().isNotEmpty)
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withValues(alpha: 0.95),
                          color.withValues(alpha: 0.55),
                        ],
                      ),
                image: (profile.avatarUrl != null &&
                        profile.avatarUrl!.trim().isNotEmpty)
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(profile.avatarUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                border: Border.all(
                  color: theme.scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
              child: (profile.avatarUrl != null &&
                      profile.avatarUrl!.trim().isNotEmpty)
                  ? null
                  : Center(
                      child: Text(
                        ((profile.fullName ?? '?').isNotEmpty
                                ? (profile.fullName![0])
                                : '?')
                            .toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
            ),
            if (isSuspended)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: theme.scaffoldBackgroundColor, width: 2),
                  ),
                ),
              )
            else if (isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: theme.scaffoldBackgroundColor, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final UserRole? role;
  final Color color;
  const _RoleChip({required this.role, required this.color});

  @override
  Widget build(BuildContext context) {
    if (role == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_roleIcon(role!), size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            _roleLabel(role!).toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final AccountStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AccountStatus.active => AppColors.success,
      AccountStatus.pending => AppColors.orange,
      AccountStatus.onLeave => AppColors.warning,
      AccountStatus.inactive => AppColors.error,
      AccountStatus.suspended => AppColors.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status.label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onSelected;
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [primary, primary.withValues(alpha: 0.8)],
                )
              : null,
          color: selected ? null : primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : primary.withValues(alpha: 0.20),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                    spreadRadius: -3,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: selected ? Colors.white : primary),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetSectionLabel extends StatelessWidget {
  final String text;
  const _SheetSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w900,
            fontSize: 10.5,
            letterSpacing: 1.5,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String hint;
  final IconData icon;
  const _EmptyState({
    required this.title,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primary.withValues(alpha: 0.18),
                    primary.withValues(alpha: 0.05),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: primary.withValues(alpha: 0.18)),
              ),
              child: Icon(icon, size: 38, color: primary),
            )
                .animate()
                .scale(
                    duration: 350.ms,
                    curve: Curves.easeOutBack,
                    begin: const Offset(0.6, 0.6),
                    end: const Offset(1, 1))
                .fadeIn(),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 6),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 13,
                height: 1.4,
              ),
            ).animate().fadeIn(delay: 160.ms),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// AURORA BACKDROP
// =============================================================================

class _AuroraBackdrop extends StatelessWidget {
  const _AuroraBackdrop();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;
    return Stack(
      children: [
        Positioned(
          top: -160,
          right: -120,
          child: Container(
            width: 420,
            height: 420,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  primary.withValues(alpha: 0.10),
                  primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -120,
          left: -80,
          child: Container(
            width: 360,
            height: 360,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  secondary.withValues(alpha: 0.08),
                  secondary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 220,
          left: -60,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.success.withValues(alpha: 0.05),
                  AppColors.success.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// COUNT-UP ANIMATION
// =============================================================================

class _CountUp extends StatefulWidget {
  final int target;
  final Duration duration;
  final Widget Function(int value) builder;

  const _CountUp({
    required this.target,
    required this.duration,
    required this.builder,
  });

  @override
  State<_CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<_CountUp>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _previousTarget = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: widget.duration);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _CountUp old) {
    super.didUpdateWidget(old);
    if (old.target != widget.target) {
      _previousTarget = (_previousTarget +
              (old.target - _previousTarget) * _controller.value)
          .round();
      _controller
        ..duration = widget.duration
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final value = (_previousTarget +
                (widget.target - _previousTarget) * _controller.value)
            .round();
        return widget.builder(value);
      },
    );
  }
}

// =============================================================================
// HELPERS
// =============================================================================

String _roleLabel(UserRole r) => switch (r) {
      UserRole.superAdmin => 'Super admin',
      UserRole.executiveAdmin => 'Admin',
      UserRole.manager => 'Manager',
      UserRole.collectionAgent => 'Collection',
      UserRole.customer => 'Customer',
    };

IconData _roleIcon(UserRole r) => switch (r) {
      UserRole.superAdmin => Icons.shield_moon_rounded,
      UserRole.executiveAdmin => Icons.shield_rounded,
      UserRole.manager => Icons.manage_accounts_rounded,
      UserRole.collectionAgent => Icons.support_agent_rounded,
      UserRole.customer => Icons.person_rounded,
    };

Color _roleColor(UserRole? r) {
  switch (r) {
    case UserRole.superAdmin:
      return AppColors.error;
    case UserRole.executiveAdmin:
      return AppColors.accent;
    case UserRole.manager:
      return AppColors.primary;
    case UserRole.collectionAgent:
      return AppColors.orange;
    case UserRole.customer:
      return AppColors.success;
    default:
      return AppColors.primary;
  }
}
