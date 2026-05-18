// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../branches/data/providers/branch_providers.dart';
import '../../../invitations/data/models/org_invitation_model.dart';
import '../../../invitations/data/providers/invitation_providers.dart';
import '../../data/csv_utils.dart';
import '../../data/repositories/user_repository.dart';
import '../providers/user_list_provider.dart';
import 'bulk_import_members_page.dart';
import 'org_chart_page.dart';
import 'user_audit_page.dart';

/// Premium User Hub.
///
/// Provides a single command-center surface for the entire workforce —
/// team members, customers, pending invitations, and suspended accounts —
/// with rich filtering, sorting, pagination, bulk admin tools and inline
/// per-row actions.
class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

/// Lightweight scope exposing the page's selection state to descendants
/// without forcing them to walk the widget tree on every build.
class _SelectionScope extends InheritedWidget {
  final Set<String> selected;
  final bool selectionMode;
  final void Function(String id, {required bool execAdminOnly}) toggle;

  const _SelectionScope({
    required this.selected,
    required this.selectionMode,
    required this.toggle,
    required super.child,
  });

  static _SelectionScope of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_SelectionScope>();
    assert(scope != null, '_SelectionScope missing in widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(_SelectionScope old) =>
      selectionMode != old.selectionMode ||
      !setEquals(selected, old.selected);
}

bool setEquals<T>(Set<T> a, Set<T> b) {
  if (a.length != b.length) return false;
  for (final v in a) {
    if (!b.contains(v)) return false;
  }
  return true;
}

class _UsersPageState extends ConsumerState<UsersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _teamScroll = ScrollController();
  final ScrollController _customersScroll = ScrollController();
  final ScrollController _suspendedScroll = ScrollController();

  final Set<String> _selected = {};
  bool _selectionMode = false;
  bool _fabOpen = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(_onTabChanged);
    _teamScroll.addListener(() => _maybeLoadMore(_teamScroll, UserHubTab.team));
    _customersScroll.addListener(
        () => _maybeLoadMore(_customersScroll, UserHubTab.customers));
    _suspendedScroll.addListener(
        () => _maybeLoadMore(_suspendedScroll, UserHubTab.suspended));
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

  UserHubTab get _currentTab => UserHubTab.values[_tabController.index];

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final query = ref.read(userHubQueryProvider(_currentTab));
    _searchCtrl.text = query.search;
    if (mounted) setState(() {});
  }

  void _maybeLoadMore(ScrollController c, UserHubTab tab) {
    if (!c.hasClients) return;
    if (c.position.pixels >= c.position.maxScrollExtent - 240) {
      ref.read(userHubPageProvider(tab).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final currentUser = ref.watch(currentUserProvider);
    final isExecAdmin = currentUser?.role == UserRole.executiveAdmin;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: _selectionMode
          ? null
          : _SpeedDialFab(
              isExecAdmin: isExecAdmin,
              isOpen: _fabOpen,
              onToggle: () => setState(() => _fabOpen = !_fabOpen),
              onAdd: () {
                setState(() => _fabOpen = false);
                context.push('/users/new');
              },
              onImport: () {
                setState(() => _fabOpen = false);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BulkImportMembersPage(),
                  ),
                );
              },
              onExport: () {
                setState(() => _fabOpen = false);
                _exportCurrentTab();
              },
              onOrgChart: () {
                setState(() => _fabOpen = false);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OrgChartPage()),
                );
              },
            ),
      body: _SelectionScope(
        selected: _selected,
        selectionMode: _selectionMode,
        toggle: _toggleSelect,
        child: Stack(
          children: [
            const _AuroraBackdrop(),
            if (_fabOpen) _ScrimTap(onTap: () => setState(() => _fabOpen = false)),
            SafeArea(
              child: Column(
                children: [
                _buildAppBar(theme, isDark),
                if (!_selectionMode) _buildHero(theme),
                if (!_selectionMode) const SizedBox(height: 18),
                if (!_selectionMode) const _StatsRail(),
                if (!_selectionMode) const SizedBox(height: 18),
                _SmartSearchBar(
                  controller: _searchCtrl,
                  hint: _searchHint(_currentTab),
                  hasActiveFilters: _hasActiveFilters(_currentTab),
                  onChanged: (v) {
                    ref
                        .read(userHubQueryProvider(_currentTab).notifier)
                        .setSearch(v);
                    ref
                        .read(userHubPageProvider(_currentTab).notifier)
                        .loadFirstPage();
                  },
                  onClear: () {
                    _searchCtrl.clear();
                    ref
                        .read(userHubQueryProvider(_currentTab).notifier)
                        .setSearch('');
                    ref
                        .read(userHubPageProvider(_currentTab).notifier)
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
                    physics: _selectionMode
                        ? const NeverScrollableScrollPhysics()
                        : const BouncingScrollPhysics(),
                    children: [
                      _TeamTabView(scroll: _teamScroll),
                      _CustomersTabView(scroll: _customersScroll),
                      const _InvitesTabView(),
                      _SuspendedTabView(scroll: _suspendedScroll),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_selectionMode) _buildBulkDock(theme, primary),
        ],
        ),
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
          if (_selectionMode)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Cancel selection',
              onPressed: () => setState(() {
                _selectionMode = false;
                _selected.clear();
              }),
            )
          else
            const SizedBox(width: 8),
          Expanded(
            child: _selectionMode
                ? Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_selected.length}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('selected',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          if (!_selectionMode)
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

  Widget _buildHero(ThemeData theme) {
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
                  'COMMAND CENTER',
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
                  'Your entire workforce, in one place',
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
          const _TotalUsersChip(),
        ],
      ),
    );
  }

  Widget _buildBulkDock(ThemeData theme, Color primary) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 20,
      child: _BulkDock(
        count: _selected.length,
        onCancel: () => setState(() {
          _selectionMode = false;
          _selected.clear();
        }),
        onNotify: _bulkNotify,
        onExport: _bulkExport,
        onSuspend: () => _bulkSetStatus(AccountStatus.suspended, 'suspended'),
        onDelete: _bulkDelete,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search & filter helpers
  // ---------------------------------------------------------------------------

  String _searchHint(UserHubTab tab) => switch (tab) {
        UserHubTab.team =>
          'Search team by name, email, phone or staff code…',
        UserHubTab.customers =>
          'Search customers by name, phone, email or member ID…',
        UserHubTab.invites => 'Search invitees by email…',
        UserHubTab.suspended =>
          'Search suspended users by name, email or phone…',
      };

  bool _hasActiveFilters(UserHubTab tab) {
    final q = ref.watch(userHubQueryProvider(tab));
    return q.branchId != null ||
        q.roleFilter != null ||
        q.sortBy != UserSortBy.createdDesc;
  }

  void _openFilterSheet() {
    final tab = _currentTab;
    final query = ref.read(userHubQueryProvider(tab));
    String? branchId = query.branchId;
    UserRole? roleFilter = query.roleFilter;
    UserSortBy sort = query.sortBy;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final branchesAsync = ref.watch(activeBranchesProvider);
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
                if (tab == UserHubTab.team) ...[
                  _SheetSectionLabel('Role'),
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
                        UserRole.executiveAdmin,
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
                if (tab != UserHubTab.invites) ...[
                  _SheetSectionLabel('Branch'),
                  const SizedBox(height: 8),
                  branchesAsync.when(
                    data: (branches) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ChoiceChip(
                          label: 'All branches',
                          icon: Icons.public_rounded,
                          selected: branchId == null,
                          onSelected: () => setSheet(() => branchId = null),
                        ),
                        for (final b in branches)
                          _ChoiceChip(
                            label: b.name,
                            icon: Icons.location_city_rounded,
                            selected: branchId == b.id,
                            onSelected: () =>
                                setSheet(() => branchId = b.id),
                          ),
                      ],
                    ),
                    loading: () => const SizedBox(
                      height: 32,
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 22),
                ],
                _SheetSectionLabel('Sort'),
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
                            branchId = null;
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
                              .read(userHubQueryProvider(tab).notifier)
                            ..setBranch(branchId)
                            ..setRole(roleFilter)
                            ..setSort(sort);
                          ref
                              .read(userHubPageProvider(tab).notifier)
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

  // ---------------------------------------------------------------------------
  // Selection / bulk actions
  // ---------------------------------------------------------------------------

  void _toggleSelect(String id, {required bool execAdminOnly}) {
    final user = ref.read(currentUserProvider);
    if (execAdminOnly && user?.role != UserRole.executiveAdmin) return;
    HapticService.medium();
    setState(() {
      _selectionMode = true;
      if (_selected.contains(id)) {
        _selected.remove(id);
        if (_selected.isEmpty) _selectionMode = false;
      } else {
        _selected.add(id);
      }
    });
  }

  Future<void> _bulkDelete() async {
    final ok = await _confirm(
      title: 'Delete selected users?',
      message:
          'This permanently removes ${_selected.length} record(s). This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (ok != true) return;
    final ids = _selected.toList();
    final notifier = ref.read(userAdminProvider.notifier);
    final success = await notifier.deleteUsers(ids);
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
    if (!mounted) return;
    _toast(success ? 'Deleted ${ids.length} record(s)' : 'Delete failed',
        success: success);
  }

  Future<void> _bulkSetStatus(AccountStatus status, String verb) async {
    final ok = await _confirm(
      title: 'Mark as ${status.label.toLowerCase()}?',
      message: '${_selected.length} user(s) will be marked as $verb.',
      confirmLabel: status.label,
    );
    if (ok != true) return;
    final notifier = ref.read(userAdminProvider.notifier);
    int n = 0;
    for (final id in _selected) {
      if (await notifier.changeStatus(id, status)) n++;
    }
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
    if (!mounted) return;
    _toast('Updated $n user(s)', success: n > 0);
  }

  Future<void> _bulkNotify() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Notify ${_selected.length} user(s)'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Type a message…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    // Real push/SMS delivery requires server function; stub to a clipboard
    // copy of the recipient phone list so the admin can paste into their
    // SMS gateway. Replace with a Supabase function call when available.
    final phones = await _resolveSelectedPhones();
    await Clipboard.setData(ClipboardData(text: phones.join(',')));
    if (!mounted) return;
    _toast(
      '${phones.length} contact(s) copied to clipboard. '
      'Paste into your SMS provider to send: "$result"',
      success: true,
    );
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
  }

  Future<List<String>> _resolveSelectedPhones() async {
    final phones = <String>[];
    final tabState = ref.read(userHubPageProvider(_currentTab));
    for (final id in _selected) {
      final p = tabState.items.firstWhere(
        (e) => e.id == id,
        orElse: () => ProfileModel(id: id),
      );
      if ((p.phone ?? '').isNotEmpty) phones.add(p.phone!);
    }
    return phones;
  }

  Future<void> _bulkExport() async {
    final tabState = ref.read(userHubPageProvider(_currentTab));
    final selected = tabState.items.where((p) => _selected.contains(p.id));
    await _exportProfiles(selected.toList(), prefix: 'selected');
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
  }

  Future<void> _exportCurrentTab() async {
    final tabState = ref.read(userHubPageProvider(_currentTab));
    if (tabState.items.isEmpty) {
      _toast('Nothing to export on this tab', success: false);
      return;
    }
    await _exportProfiles(tabState.items, prefix: _currentTab.name);
  }

  Future<void> _exportProfiles(List<ProfileModel> profiles,
      {required String prefix}) async {
    if (profiles.isEmpty) return;
    final rows = <List<String>>[
      [
        'id',
        'full_name',
        'email',
        'phone',
        'role',
        'status',
        'branch',
        'member_id',
        'created_at',
      ],
      ...profiles.map((p) => [
            p.id,
            p.fullName ?? '',
            p.email ?? '',
            p.phone ?? '',
            p.role?.name ?? '',
            p.status.label,
            p.branchName ?? '',
            p.memberCode ?? '',
            p.createdAt?.toIso8601String() ?? '',
          ]),
    ];
    final csv = CsvUtils.encode(rows);
    try {
      final dir = await getTemporaryDirectory();
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/${prefix}_$ts.csv');
      await file.writeAsString(csv);
      await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path)], subject: 'User export · $prefix'));
    } catch (e) {
      // Fallback: copy to clipboard.
      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      _toast('Could not share file. CSV copied to clipboard.', success: false);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) {
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

  void _toast(String msg, {bool success = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

// =============================================================================
// HERO PIECES
// =============================================================================

class _TotalUsersChip extends ConsumerWidget {
  const _TotalUsersChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(userStatsProvider);
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

class _StatsRail extends ConsumerWidget {
  const _StatsRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final stats = ref.watch(userStatsProvider);

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
              onTap: null,
            ),
            _StatTileData(
              label: 'Admins',
              value: s['admins'] ?? 0,
              icon: Icons.shield_rounded,
              color: isDark ? AppColors.accentDark : AppColors.accent,
              onTap: null,
            ),
            _StatTileData(
              label: 'Managers',
              value: s['managers'] ?? 0,
              icon: Icons.manage_accounts_rounded,
              color: theme.colorScheme.secondary,
              onTap: null,
            ),
            _StatTileData(
              label: 'Staff',
              value: s['staff'] ?? 0,
              icon: Icons.support_agent_rounded,
              color: isDark ? AppColors.warningDark : AppColors.orange,
              onTap: null,
            ),
            _StatTileData(
              label: 'Customers',
              value: s['members'] ?? 0,
              icon: Icons.groups_rounded,
              color: isDark ? AppColors.successDark : AppColors.success,
              onTap: null,
            ),
            _StatTileData(
              label: 'Suspended',
              value: s['suspended'] ?? 0,
              icon: Icons.block_rounded,
              color: AppColors.error,
              onTap: null,
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
  final VoidCallback? onTap;
  _StatTileData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.gradient,
    this.onTap,
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
// SEARCH BAR + ACTIVE FILTERS
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

class _ActiveFiltersStrip extends ConsumerWidget {
  final UserHubTab tab;
  const _ActiveFiltersStrip({required this.tab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(userHubQueryProvider(tab));
    final notifier = ref.read(userHubQueryProvider(tab).notifier);
    final pageNotifier = ref.read(userHubPageProvider(tab).notifier);
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

    if (query.branchId != null) {
      // Resolve branch name
      final branches =
          ref.watch(activeBranchesProvider).maybeWhen(data: (d) => d, orElse: () => []);
      final name = branches.firstWhere(
        (b) => b.id == query.branchId,
        orElse: () =>
            // ignore: prefer_const_constructors, avoid_dynamic_calls
            branches.isNotEmpty ? branches.first : _PlaceholderBranch(),
      );
      final label = name is _PlaceholderBranch ? 'Branch' : (name.name);
      chips.add(_FilterChipPill(
        icon: Icons.location_city_rounded,
        label: 'Branch · $label',
        color: theme.colorScheme.secondary,
        onClose: () {
          notifier.setBranch(null);
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

class _PlaceholderBranch {
  final String name = '—';
  final String id = '';
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
    final stats = ref.watch(userStatsProvider);
    final invites = ref.watch(orgInvitationsProvider);

    int? counts(UserHubTab t) => switch (t) {
          UserHubTab.team => stats.maybeWhen(
              data: (s) =>
                  (s['admins'] ?? 0) +
                  (s['managers'] ?? 0) +
                  (s['staff'] ?? 0),
              orElse: () => null),
          UserHubTab.customers =>
            stats.maybeWhen(data: (s) => s['members'] ?? 0, orElse: () => null),
          UserHubTab.invites => invites.maybeWhen(
              data: (l) => l.where((i) => i.isPending).length,
              orElse: () => null),
          UserHubTab.suspended =>
            stats.maybeWhen(data: (s) => s['suspended'] ?? 0, orElse: () => null),
        };

    const tabs = [
      ('Team', Icons.shield_outlined, UserHubTab.team),
      ('Customers', Icons.people_outline_rounded, UserHubTab.customers),
      ('Invites', Icons.mail_outline_rounded, UserHubTab.invites),
      ('Suspended', Icons.block_outlined, UserHubTab.suspended),
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
    final state = ref.watch(userHubPageProvider(UserHubTab.team));

    return _PaginatedList(
      tab: UserHubTab.team,
      state: state,
      scroll: scroll,
      buildItem: (p) => _UserRow(
        profile: p,
        showStatus: true,
        showLastSeen: true,
      ),
      emptyTitle: 'No team members',
      emptyHint: 'Tap + to invite or create staff.',
      emptyIcon: Icons.shield_moon_rounded,
    );
  }
}

class _CustomersTabView extends ConsumerWidget {
  final ScrollController scroll;
  const _CustomersTabView({required this.scroll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userHubPageProvider(UserHubTab.customers));
    return _PaginatedList(
      tab: UserHubTab.customers,
      state: state,
      scroll: scroll,
      buildItem: (p) => _UserRow(
        profile: p,
        showStatus: false,
        showLastSeen: false,
      ),
      emptyTitle: 'No customers',
      emptyHint: 'Add a customer or import a CSV to get started.',
      emptyIcon: Icons.groups_rounded,
    );
  }
}

class _SuspendedTabView extends ConsumerWidget {
  final ScrollController scroll;
  const _SuspendedTabView({required this.scroll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userHubPageProvider(UserHubTab.suspended));
    return _PaginatedList(
      tab: UserHubTab.suspended,
      state: state,
      scroll: scroll,
      buildItem: (p) => _UserRow(
        profile: p,
        showStatus: true,
        showLastSeen: true,
      ),
      emptyTitle: 'No suspended accounts',
      emptyHint: 'Suspended or deactivated users will appear here.',
      emptyIcon: Icons.block_rounded,
    );
  }
}

class _InvitesTabView extends ConsumerWidget {
  const _InvitesTabView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(orgInvitationsProvider);
    final query = ref.watch(userHubQueryProvider(UserHubTab.invites));
    return invitesAsync.when(
      data: (invites) {
        var filtered = invites;
        if (query.search.trim().isNotEmpty) {
          final q = query.search.trim().toLowerCase();
          filtered = invites
              .where((i) => i.email.toLowerCase().contains(q))
              .toList();
        }
        if (filtered.isEmpty) {
          return const _EmptyState(
            title: 'No invitations',
            hint: 'Invite a teammate from the + menu.',
            icon: Icons.mail_outline_rounded,
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(orgInvitationsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 140),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final inv = filtered[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _InviteRow(invitation: inv),
              );
            },
          ),
        );
      },
      loading: () => const _RowShimmerList(),
      error: (e, _) => _EmptyState(
        title: 'Could not load invitations',
        hint: '$e',
        icon: Icons.error_outline_rounded,
      ),
    );
  }
}

// =============================================================================
// PAGINATED LIST shell
// =============================================================================

class _PaginatedList extends StatelessWidget {
  final UserHubTab tab;
  final UserHubPageState state;
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
        await container.read(userHubPageProvider(tab).notifier).loadFirstPage();
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
  final bool showLastSeen;

  const _UserRow({
    required this.profile,
    required this.showStatus,
    required this.showLastSeen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scope = _SelectionScope.of(context);
    final isSelected = scope.selected.contains(profile.id);
    final selectionMode = scope.selectionMode;
    final primary = theme.colorScheme.primary;
    final roleColor = _roleColor(profile.role);

    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderColor: isSelected ? primary : null,
      onTap: () {
        HapticService.selection();
        if (selectionMode) {
          scope.toggle(profile.id, execAdminOnly: true);
        } else {
          context.push('/users/${profile.id}');
        }
      },
      child: GestureDetector(
        onLongPress: () {
          if (profile.isMember) return;
          scope.toggle(profile.id, execAdminOnly: true);
        },
        behavior: HitTestBehavior.opaque,
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
                          if ((profile.branchName ?? '').isNotEmpty)
                            _BranchChip(name: profile.branchName!),
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
                if (selectionMode)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primary
                            : theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? primary
                              : theme.dividerColor.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 16)
                          : null,
                    ),
                  )
                else
                  _RowActions(profile: profile),
              ],
            ),
          ],
        ),
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
            if (!profile.isMember && profile.userId != null)
              const PopupMenuItem(
                  value: 'audit',
                  child: ListTile(
                      leading: Icon(Icons.history_rounded),
                      title: Text('View audit trail'))),
            if (!profile.isMember) const PopupMenuDivider(),
            if (!profile.isMember)
              const PopupMenuItem(
                  value: 'role',
                  child: ListTile(
                      leading: Icon(Icons.swap_horiz_rounded),
                      title: Text('Change role'))),
            if (!profile.isMember && profile.status != AccountStatus.suspended)
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
            if (!profile.isMember && (profile.email ?? '').isNotEmpty)
              const PopupMenuItem(
                  value: 'reset',
                  child: ListTile(
                      leading: Icon(Icons.lock_reset_rounded),
                      title: Text('Send password reset'))),
            if (!profile.isMember && profile.userId != null)
              const PopupMenuItem(
                  value: 'logout',
                  child: ListTile(
                      leading: Icon(Icons.logout_rounded,
                          color: AppColors.warning),
                      title: Text('Force logout'))),
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
        context.push('/users/${profile.id}');
        break;
      case 'audit':
        final uid = profile.userId;
        if (uid == null) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => UserAuditPage(userId: uid)),
        );
        break;
      case 'role':
        final newRole = await _pickRole(context, profile.role);
        if (newRole == null || newRole == profile.role) return;
        final ok = await notifier.changeRole(profile.id, newRole);
        if (context.mounted) {
          _snack(context, ok ? 'Role updated' : 'Failed to update role',
              success: ok);
        }
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
      case 'reset':
        final email = profile.email;
        if (email == null || email.isEmpty) return;
        final ok = await notifier.sendPasswordReset(email);
        if (context.mounted) {
          _snack(
              context, ok ? 'Password reset sent to $email' : 'Failed to send',
              success: ok);
        }
        break;
      case 'logout':
        final confirmed = await _confirm(context,
            title: 'Force logout ${profile.fullName ?? "this user"}?',
            message: 'They will be signed out from all devices.',
            confirmLabel: 'Force logout',
            destructive: true);
        if (confirmed != true) return;
        final ok =
            await notifier.forceLogout(profile.id, userId: profile.userId);
        if (context.mounted) {
          _snack(context, ok ? 'User signed out' : 'Failed to sign out',
              success: ok);
        }
        break;
    }
  }

  Future<UserRole?> _pickRole(BuildContext context, UserRole? current) {
    return showModalBottomSheet<UserRole>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Change role',
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            for (final r in const [
              UserRole.executiveAdmin,
              UserRole.manager,
              UserRole.collectionAgent,
              UserRole.customer,
            ])
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: _roleColor(r).withValues(alpha: 0.15),
                  child: Icon(_roleIcon(r), color: _roleColor(r), size: 18),
                ),
                title: Text(_roleLabel(r)),
                trailing: r == current
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.success)
                    : null,
                onTap: () => Navigator.pop(ctx, r),
              ),
          ],
        ),
      ),
    );
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
// INVITE ROW
// =============================================================================

class _InviteRow extends ConsumerWidget {
  final OrgInvitationModel invitation;
  const _InviteRow({required this.invitation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = invitation.isPending
        ? AppColors.orange
        : invitation.isAccepted
            ? AppColors.success
            : AppColors.error;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.25),
                  color.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(Icons.mail_outline_rounded, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invitation.email,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        invitation.roleDisplay,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: color,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _inviteSubtitle(invitation),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontSize: 11.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              invitation.status.toUpperCase(),
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: 0.6,
              ),
            ),
          ),
          if (invitation.isPending)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                    value: 'resend',
                    child: ListTile(
                        leading: Icon(Icons.refresh_rounded),
                        title: Text('Resend invitation'))),
                PopupMenuItem(
                    value: 'revoke',
                    child: ListTile(
                        leading: Icon(Icons.cancel_outlined,
                            color: AppColors.error),
                        title: Text('Revoke invitation'))),
              ],
              onSelected: (v) async {
                final notifier = ref.read(invitationNotifierProvider.notifier);
                if (v == 'resend') {
                  final ok = await notifier.resendInvitation(invitation.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:
                          Text(ok ? 'Invitation resent' : 'Resend failed'),
                      backgroundColor:
                          ok ? AppColors.success : AppColors.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ));
                  }
                } else if (v == 'revoke') {
                  final ok = await notifier.revokeInvitation(invitation.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:
                          Text(ok ? 'Invitation revoked' : 'Revoke failed'),
                      backgroundColor:
                          ok ? AppColors.success : AppColors.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ));
                  }
                }
              },
            ),
        ],
      ),
    );
  }

  String _inviteSubtitle(OrgInvitationModel inv) {
    final fmt = DateFormat('MMM d, yyyy');
    if (inv.isPending) return 'Expires ${fmt.format(inv.expiresAt)}';
    if (inv.isAccepted) {
      return 'Accepted ${inv.acceptedAt != null ? fmt.format(inv.acceptedAt!) : ""}';
    }
    return fmt.format(inv.createdAt);
  }
}

// =============================================================================
// BULK DOCK
// =============================================================================

class _BulkDock extends StatelessWidget {
  final int count;
  final VoidCallback onCancel;
  final VoidCallback onNotify;
  final VoidCallback onExport;
  final VoidCallback onSuspend;
  final VoidCallback onDelete;

  const _BulkDock({
    required this.count,
    required this.onCancel,
    required this.onNotify,
    required this.onExport,
    required this.onSuspend,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withValues(alpha: isDark ? 0.18 : 0.10),
            theme.colorScheme.secondary.withValues(alpha: isDark ? 0.12 : 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: primary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            InkWell(
              onTap: onCancel,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.close_rounded,
                        size: 16, color: theme.colorScheme.onSurface),
                    const SizedBox(width: 4),
                    Text('$count',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        )),
                  ],
                ),
              ),
            ),
            Container(
              width: 1,
              height: 32,
              color: theme.dividerColor.withValues(alpha: 0.4),
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _BulkAction(
                    icon: Icons.notifications_active_rounded,
                    label: 'Notify',
                    onTap: onNotify,
                  ),
                  _BulkAction(
                    icon: Icons.ios_share_rounded,
                    label: 'Export',
                    onTap: onExport,
                  ),
                  _BulkAction(
                    icon: Icons.block_rounded,
                    label: 'Suspend',
                    color: AppColors.warning,
                    onTap: onSuspend,
                  ),
                  _BulkAction(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    color: AppColors.error,
                    onTap: onDelete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().slideY(
          begin: 1.2,
          end: 0,
          duration: 350.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _BulkAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _BulkAction(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: c, size: 18),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: c, fontSize: 10.5, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SPEED-DIAL FAB
// =============================================================================

class _SpeedDialFab extends StatelessWidget {
  final bool isExecAdmin;
  final bool isOpen;
  final VoidCallback onToggle;
  final VoidCallback onAdd;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onOrgChart;

  const _SpeedDialFab({
    required this.isExecAdmin,
    required this.isOpen,
    required this.onToggle,
    required this.onAdd,
    required this.onImport,
    required this.onExport,
    required this.onOrgChart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isExecAdmin && isOpen) ...[
            _MiniFabRow(
              label: 'Org chart',
              icon: Icons.account_tree_rounded,
              color: AppColors.indigo,
              onTap: onOrgChart,
              order: 0,
            ),
            const SizedBox(height: 10),
            _MiniFabRow(
              label: 'Bulk import',
              icon: Icons.upload_file_rounded,
              color: AppColors.teal,
              onTap: onImport,
              order: 1,
            ),
            const SizedBox(height: 10),
            _MiniFabRow(
              label: 'Export this tab',
              icon: Icons.ios_share_rounded,
              color: AppColors.orange,
              onTap: onExport,
              order: 2,
            ),
            const SizedBox(height: 10),
            _MiniFabRow(
              label: 'Add user',
              icon: Icons.person_add_alt_1_rounded,
              color: primary,
              onTap: onAdd,
              order: 3,
            ),
            const SizedBox(height: 14),
          ],
          GestureDetector(
            onLongPress: isExecAdmin ? null : onAdd,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, secondary],
                ),
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
                    if (isExecAdmin) {
                      onToggle();
                    } else {
                      onAdd();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedRotation(
                          turns: isExecAdmin && isOpen ? 0.125 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: Icon(
                            isExecAdmin
                                ? (isOpen
                                    ? Icons.add_rounded
                                    : Icons.add_rounded)
                                : Icons.person_add_alt_1_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isExecAdmin
                              ? (isOpen ? 'Close' : 'Quick actions')
                              : 'Add User',
                          style: const TextStyle(
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
              .scale(delay: 250.ms, duration: 300.ms, curve: Curves.easeOutBack),
        ],
      ),
    );
  }
}

class _MiniFabRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int order;
  const _MiniFabRow({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticService.selection();
              onTap();
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.75)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 200.ms, delay: (50 * order).ms)
        .slideY(begin: 0.4, end: 0, curve: Curves.easeOutCubic);
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
      tag: 'user_avatar_${profile.id}',
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
                        image: NetworkImage(profile.avatarUrl!),
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

class _BranchChip extends StatelessWidget {
  final String name;
  const _BranchChip({required this.name});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_city_rounded, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            name,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.4,
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
// AURORA / SCRIM
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

class _ScrimTap extends StatelessWidget {
  final VoidCallback onTap;
  const _ScrimTap({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          color: Colors.black.withValues(alpha: 0.18),
        ).animate().fadeIn(duration: 200.ms),
      ),
    );
  }
}

// =============================================================================
// UTIL — Count-up
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
