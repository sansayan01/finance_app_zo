import 'dart:io';

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

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
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
          : _Fab(
              isExecAdmin: isExecAdmin,
              onAdd: () => context.push('/users/new'),
              onImport: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BulkImportMembersPage(),
                ),
              ),
              onExport: _exportCurrentTab,
              onOrgChart: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OrgChartPage()),
              ),
            ),
      body: Stack(
        children: [
          const _AuroraBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(theme, isDark),
                _buildHeader(theme),
                const SizedBox(height: 12),
                _StatsCarousel(),
                const SizedBox(height: 16),
                _buildSearchBar(theme, primary),
                const SizedBox(height: 12),
                _buildTabBar(theme, primary),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
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
          if (_selectionMode) _buildBulkActions(theme, primary),
        ],
      ),
    );
  }

  Widget _buildAppBar(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
      child: Row(
        children: [
          if (_selectionMode)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() {
                _selectionMode = false;
                _selected.clear();
              }),
            )
          else
            const SizedBox(width: 8),
          Expanded(
            child: _selectionMode
                ? Text('${_selected.length} selected',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900))
                : const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 22),
            tooltip: 'Filter & sort',
            onPressed: _openFilterSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    if (_selectionMode) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMMAND CENTER',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontSize: 10,
              color: theme.colorScheme.primary,
            ),
          ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0),
          const SizedBox(height: 2),
          Text(
            'User Hub',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
              fontSize: 30,
            ),
          ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.05, end: 0),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, Color primary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: primary.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded,
                size: 20, color: theme.textTheme.bodySmall?.color),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) {
                  ref
                      .read(userHubQueryProvider(_currentTab).notifier)
                      .setSearch(v);
                  ref
                      .read(userHubPageProvider(_currentTab).notifier)
                      .loadFirstPage();
                },
                decoration: InputDecoration(
                  hintText: switch (_currentTab) {
                    UserHubTab.team =>
                      'Search team by name, email, phone or staff code…',
                    UserHubTab.customers =>
                      'Search customers by name, phone, email or member ID…',
                    UserHubTab.invites => 'Search invitees by email…',
                    UserHubTab.suspended =>
                      'Search suspended users by name, email or phone…',
                  },
                  hintStyle: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (_searchCtrl.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _searchCtrl.clear();
                  ref
                      .read(userHubQueryProvider(_currentTab).notifier)
                      .setSearch('');
                  ref
                      .read(userHubPageProvider(_currentTab).notifier)
                      .loadFirstPage();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme, Color primary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicator: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(14),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor:
              theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
          labelStyle: theme.textTheme.labelLarge
              ?.copyWith(fontWeight: FontWeight.w800, fontSize: 12),
          padding: const EdgeInsets.all(4),
          tabs: const [
            Tab(text: 'Team'),
            Tab(text: 'Customers'),
            Tab(text: 'Invites'),
            Tab(text: 'Suspended'),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkActions(ThemeData theme, Color primary) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        borderRadius: 20,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _BulkAction(
              icon: Icons.notifications_active_rounded,
              label: 'Notify',
              onTap: _bulkNotify,
            ),
            _BulkAction(
              icon: Icons.ios_share_rounded,
              label: 'Export',
              onTap: _bulkExport,
            ),
            _BulkAction(
              icon: Icons.block_rounded,
              label: 'Suspend',
              color: AppColors.warning,
              onTap: () =>
                  _bulkSetStatus(AccountStatus.suspended, 'suspended'),
            ),
            _BulkAction(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: AppColors.error,
              onTap: _bulkDelete,
            ),
          ],
        ),
      ),
    ).animate().slideY(begin: 1, end: 0, curve: Curves.easeOutBack);
  }

  // ---------------------------------------------------------------------------
  // Filter sheet
  // ---------------------------------------------------------------------------

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
      builder: (ctx) {
        final branchesAsync = ref.watch(activeBranchesProvider);
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20,
                MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filter & sort',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                if (tab == UserHubTab.team) ...[
                  Text('Role',
                      style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          )),
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
                          selected: roleFilter == r,
                          onSelected: () => setSheet(() => roleFilter = r),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (tab != UserHubTab.invites) ...[
                  Text('Branch',
                      style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          )),
                  const SizedBox(height: 8),
                  branchesAsync.when(
                    data: (branches) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ChoiceChip(
                          label: 'All branches',
                          selected: branchId == null,
                          onSelected: () => setSheet(() => branchId = null),
                        ),
                        for (final b in branches)
                          _ChoiceChip(
                            label: b.name,
                            selected: branchId == b.id,
                            onSelected: () => setSheet(() => branchId = b.id),
                          ),
                      ],
                    ),
                    loading: () => const SizedBox(
                        height: 32,
                        child: Center(
                            child: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)))),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                ],
                Text('Sort',
                    style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        )),
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
                const SizedBox(height: 24),
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
                        child: const Text('Apply'),
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
      await SharePlus.instance
          .share(ShareParams(files: [XFile(file.path)], subject: 'User export · $prefix'));
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
    final ids = state.items
        .where((p) => p.userId != null)
        .map((p) => p.userId!)
        .toList();
    final lastSeen = ref.watch(lastActivityProvider(ids));
    final agentIds = state.items
        .where((p) => p.role == UserRole.collectionAgent)
        .map((p) => p.id)
        .toList();
    final perf = ref.watch(staffPerformanceTodayProvider(agentIds));

    return _PaginatedList(
      tab: UserHubTab.team,
      state: state,
      scroll: scroll,
      buildItem: (p) {
        final DateTime? lastSeenAt = p.userId == null
            ? null
            : (lastSeen.valueOrNull ?? const <String, DateTime>{})[p.userId!];
        final double? today = p.role != UserRole.collectionAgent
            ? null
            : (perf.valueOrNull ?? const <String, double>{})[p.id];
        return _UserRow(
          profile: p,
          showStatus: true,
          showLastSeen: true,
          lastSeen: lastSeenAt,
          performanceToday: today,
        );
      },
      emptyTitle: 'No team members',
      emptyHint: 'Tap + to invite or create staff.',
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
          return _EmptyState(
            title: 'No invitations',
            hint: 'Invite a teammate from the + menu.',
            icon: Icons.mail_outline_rounded,
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(orgInvitationsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
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
  const _PaginatedList({
    required this.tab,
    required this.state,
    required this.scroll,
    required this.buildItem,
    required this.emptyTitle,
    required this.emptyHint,
  });

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty && state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.items.isEmpty && state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error: ${state.error}'),
        ),
      );
    }
    if (state.items.isEmpty) {
      return _EmptyState(
        title: emptyTitle,
        hint: emptyHint,
        icon: Icons.person_search_rounded,
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
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i >= state.items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: buildItem(state.items[i])
                .animate()
                .fadeIn(duration: 300.ms, delay: (i * 20).ms)
                .slideY(begin: 0.05, end: 0),
          );
        },
      ),
    );
  }
}

// =============================================================================
// ROW WIDGETS
// =============================================================================

class _UserRow extends ConsumerWidget {
  final ProfileModel profile;
  final bool showStatus;
  final bool showLastSeen;
  final DateTime? lastSeen;
  final double? performanceToday;

  const _UserRow({
    required this.profile,
    required this.showStatus,
    required this.showLastSeen,
    this.lastSeen,
    this.performanceToday,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = context
        .findAncestorStateOfType<_UsersPageState>(); // for selection mode hooks
    final isSelected = state?._selected.contains(profile.id) ?? false;
    final selectionMode = state?._selectionMode ?? false;
    final primary = theme.colorScheme.primary;
    final roleColor = _roleColor(profile.role);

    return InkWell(
      onTap: () {
        HapticService.selection();
        if (selectionMode) {
          state?._toggleSelect(profile.id, execAdminOnly: true);
        } else {
          context.push('/users/${profile.id}');
        }
      },
      onLongPress: () {
        if (profile.isMember) return; // Don't bulk-act on raw member rows
        state?._toggleSelect(profile.id, execAdminOnly: true);
      },
      borderRadius: BorderRadius.circular(20),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderColor: isSelected ? primary : null,
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
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (showStatus) _StatusChip(status: profile.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _RoleChip(role: profile.role, color: roleColor),
                          if ((profile.branchName ?? '').isNotEmpty)
                            _BranchChip(name: profile.branchName!),
                          if ((profile.phone ?? '').isNotEmpty)
                            Text(
                              profile.phone!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (selectionMode)
                  Checkbox(
                    value: isSelected,
                    activeColor: primary,
                    shape: const CircleBorder(),
                    onChanged: (_) =>
                        state?._toggleSelect(profile.id, execAdminOnly: true),
                  )
                else
                  _RowActions(profile: profile),
              ],
            ),
            if (showLastSeen || performanceToday != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (showLastSeen)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 11,
                              color: theme.textTheme.bodySmall?.color),
                          const SizedBox(width: 4),
                          Text(
                            _formatLastSeen(lastSeen),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (performanceToday != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Today: ${NumberFormat.compactCurrency(symbol: "₹", decimalDigits: 0).format(performanceToday)}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatLastSeen(DateTime? dt) {
    if (dt == null) return 'No activity';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
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
    ));
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.mail_outline_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invitation.email,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  '${invitation.roleDisplay} · ${_inviteSubtitle(invitation)}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              invitation.status.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (invitation.isPending)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 20),
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
                      content: Text(ok ? 'Invitation resent' : 'Resend failed'),
                      backgroundColor:
                          ok ? AppColors.success : AppColors.error,
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
// SMALL WIDGETS
// =============================================================================

class _Fab extends StatelessWidget {
  final bool isExecAdmin;
  final VoidCallback onAdd;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onOrgChart;

  const _Fab({
    required this.isExecAdmin,
    required this.onAdd,
    required this.onImport,
    required this.onExport,
    required this.onOrgChart,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isExecAdmin) ...[
            _MiniFab(
              icon: Icons.account_tree_rounded,
              tooltip: 'Org chart',
              onTap: onOrgChart,
            ),
            const SizedBox(height: 8),
            _MiniFab(
              icon: Icons.upload_file_rounded,
              tooltip: 'Bulk import CSV',
              onTap: onImport,
            ),
            const SizedBox(height: 8),
            _MiniFab(
              icon: Icons.ios_share_rounded,
              tooltip: 'Export this tab',
              onTap: onExport,
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton.extended(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Add User'),
          ),
        ],
      ),
    ).animate().scale(
        delay: 300.ms, duration: 350.ms, curve: Curves.easeOutBack);
  }
}

class _MiniFab extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _MiniFab(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'mini-$tooltip',
      tooltip: tooltip,
      onPressed: onTap,
      child: Icon(icon, size: 18),
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
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: c, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: c,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ],
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
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 18),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(32, 32),
        foregroundColor: Theme.of(context).colorScheme.primary,
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
    return Hero(
      tag: 'user_avatar_${profile.id}',
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.85),
              color.withValues(alpha: 0.45),
            ],
          ),
        ),
        child: Stack(
          children: [
            Center(
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
            if (profile.status == AccountStatus.suspended ||
                profile.status == AccountStatus.inactive)
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _roleLabel(role!).toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_city_rounded, size: 9, color: color),
          const SizedBox(width: 3),
          Text(
            name,
            style: TextStyle(
              fontSize: 9,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  const _ChoiceChip(
      {required this.label, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? primary : primary.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : primary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _StatsCarousel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final stats = ref.watch(userStatsProvider);
    return SizedBox(
      height: 88,
      child: stats.when(
        data: (s) => ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          physics: const BouncingScrollPhysics(),
          children: [
            _StatCard(
                label: 'Total',
                value: s['total'].toString(),
                icon: Icons.people_rounded,
                color: primary),
            const SizedBox(width: 10),
            _StatCard(
                label: 'Admins',
                value: s['admins'].toString(),
                icon: Icons.shield_rounded,
                color: isDark ? AppColors.accentDark : AppColors.accent),
            const SizedBox(width: 10),
            _StatCard(
                label: 'Managers',
                value: s['managers'].toString(),
                icon: Icons.manage_accounts_rounded,
                color: theme.colorScheme.secondary),
            const SizedBox(width: 10),
            _StatCard(
                label: 'Staff',
                value: s['staff'].toString(),
                icon: Icons.support_agent_rounded,
                color: isDark ? AppColors.warningDark : AppColors.orange),
            const SizedBox(width: 10),
            _StatCard(
                label: 'Customers',
                value: s['members'].toString(),
                icon: Icons.groups_rounded,
                color: isDark ? AppColors.successDark : AppColors.success),
            const SizedBox(width: 10),
            _StatCard(
                label: 'Suspended',
                value: s['suspended'].toString(),
                icon: Icons.block_rounded,
                color: AppColors.error),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 110,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const Spacer(),
              Text(value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: color,
                  )),
            ],
          ),
          const Spacer(),
          Text(label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w800,
              )),
        ],
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 64,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(hint, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _AuroraBackground extends StatelessWidget {
  const _AuroraBackground();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Stack(
      children: [
        Positioned(
          top: -150,
          right: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary.withValues(alpha: 0.05),
            ),
          ),
        ).animate(onPlay: (c) => c.repeat()).moveY(
            begin: 0, end: 50, duration: 8.seconds, curve: Curves.easeInOut),
        Positioned(
          bottom: -100,
          left: -50,
          child: Container(
            width: 350,
            height: 350,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success.withValues(alpha: 0.03),
            ),
          ),
        ).animate(onPlay: (c) => c.repeat()).moveY(
            begin: 0, end: -30, duration: 7.seconds, curve: Curves.easeInOut),
      ],
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
