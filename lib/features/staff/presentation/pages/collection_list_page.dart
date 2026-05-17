import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../data/providers/collection_providers.dart';

enum CollectionTab { all, today, overdue, collected }

class CollectionListPage extends ConsumerStatefulWidget {
  const CollectionListPage({super.key});

  @override
  ConsumerState<CollectionListPage> createState() => _CollectionListPageState();
}

class _CollectionListPageState extends ConsumerState<CollectionListPage> {
  CollectionTab _selectedTab = CollectionTab.all;
  final _searchController = TextEditingController();
  bool _isSearchOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded,
              color: isDark ? Colors.white70 : Colors.black87),
        ),
        title: _isSearchOpen
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                    hintText: 'Search members...',
                    border: InputBorder.none,
                    filled: false),
                onChanged: (v) => setState(() {}),
              )
            : const Text('Collections',
                style: TextStyle(
                    fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
                _isSearchOpen ? Icons.close_rounded : Icons.search_rounded,
                color: isDark ? Colors.white70 : Colors.black87),
            onPressed: () => setState(() {
              _isSearchOpen = !_isSearchOpen;
              if (!_isSearchOpen) {
                _searchController.clear();
              }
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsBar(theme, isDark),
          _buildTabBar(theme, isDark),
          Expanded(child: _buildContent(theme, isDark)),
        ],
      ),
    );
  }

  Widget _buildStatsBar(ThemeData theme, bool isDark) {
    final emisAsync = ref.watch(todayDueEmisProvider);
    final overdueAsync = ref.watch(overdueEmisProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.primary.withValues(alpha: 0.08),
          AppColors.accent.withValues(alpha: 0.04)
        ]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          emisAsync.when(
              data: (d) => _statItem(theme, '${d.length}', 'Due'),
              loading: () => _statItem(theme, '...', 'Due'),
              error: (_, __) => _statItem(theme, '0', 'Due')),
          Container(
              width: 1,
              height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: theme.dividerColor.withValues(alpha: 0.3)),
          overdueAsync.when(
              data: (d) =>
                  _statItem(theme, '${d.length}', 'Overdue', AppColors.error),
              loading: () => _statItem(theme, '...', 'Overdue'),
              error: (_, __) => _statItem(theme, '0', 'Overdue')),
          Container(
              width: 1,
              height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: theme.dividerColor.withValues(alpha: 0.3)),
          const _CollectedStat(),
        ],
      ),
    );
  }

  Widget _statItem(ThemeData theme, String value, String label,
      [Color? color]) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color ?? AppColors.primary,
                  height: 1.1)),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  height: 1.2)),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme, bool isDark) {
    final tabs = [
      {
        'tab': CollectionTab.all,
        'label': 'All',
        'icon': Icons.all_inclusive_rounded
      },
      {
        'tab': CollectionTab.today,
        'label': 'Today',
        'icon': Icons.today_rounded
      },
      {
        'tab': CollectionTab.overdue,
        'label': 'Overdue',
        'icon': Icons.warning_amber_rounded
      },
      {
        'tab': CollectionTab.collected,
        'label': 'Done',
        'icon': Icons.check_circle_rounded
      },
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: tabs.map((t) {
          final tab = t['tab'] as CollectionTab;
          final isSelected = _selectedTab == tab;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTab = tab);
              },
              child: AnimatedContainer(
                duration: 200.ms,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.06)))),
                child: Column(
                  children: [
                    Icon(t['icon'] as IconData,
                        size: 16,
                        color: isSelected
                            ? Colors.white
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.35)),
                    const SizedBox(height: 2),
                    Text(t['label'] as String,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.45))),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, bool isDark) {
    switch (_selectedTab) {
      case CollectionTab.all:
        return _buildList(theme, isDark);
      case CollectionTab.today:
        return _buildTodayList(theme, isDark);
      case CollectionTab.overdue:
        return _buildOverdueList(theme, isDark);
      case CollectionTab.collected:
        return _buildCollectedList(theme, isDark);
    }
  }

  Widget _buildList(ThemeData theme, bool isDark) {
    return _baseList(theme, isDark, ref.watch(todayDueEmisProvider), (item) {
      final schedule = item['current_schedule'] ?? {};
      return schedule['is_overdue'] != true;
    });
  }

  Widget _buildTodayList(ThemeData theme, bool isDark) {
    return _baseList(theme, isDark, ref.watch(todayDueEmisProvider), (item) {
      return (item['current_schedule']?['is_overdue'] != true);
    }, emptyMsg: 'All dues cleared today!');
  }

  Widget _buildOverdueList(ThemeData theme, bool isDark) {
    final async = ref.watch(overdueEmisProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(overdueEmisProvider);
        await Future.delayed(500.ms);
      },
      child: async.when(
        data: (items) => items.isEmpty
            ? _empty(theme, Icons.check_circle_outline_rounded, 'No Overdue',
                'Great job!')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                itemCount: items.length,
                itemBuilder: (ctx, i) =>
                    _buildOverdueCard(theme, isDark, items[i], i),
              ),
        loading: () => _shimmerList(),
        error: (_, __) => Center(
            child: Text('Failed',
                style: TextStyle(color: theme.colorScheme.error))),
      ),
    );
  }

  Widget _buildCollectedList(ThemeData theme, bool isDark) {
    final async = ref.watch(recentCollectionsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(recentCollectionsProvider);
        await Future.delayed(500.ms);
      },
      child: async.when(
        data: (items) => items.isEmpty
            ? _empty(theme, Icons.payments_outlined, 'No collections',
                'Start collecting!')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                itemCount: items.length,
                itemBuilder: (ctx, i) =>
                    _buildCollectedCard(theme, isDark, items[i], i),
              ),
        loading: () => _shimmerList(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _baseList(
      ThemeData theme,
      bool isDark,
      AsyncValue<List<Map<String, dynamic>>> async,
      bool Function(Map<String, dynamic>) filter,
      {String emptyMsg = 'All dues are cleared!'}) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(todayDueEmisProvider);
        await Future.delayed(500.ms);
      },
      child: async.when(
        data: (items) {
          final filtered = items.where(filter).toList();
          if (filtered.isEmpty) {
            return _empty(theme, Icons.check_circle_outline_rounded,
                'No collections', emptyMsg);
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final item = filtered[i];
              final s = item['current_schedule'] ?? {};
              final m = item['members'] ?? {};
              return _buildCard(
                theme,
                isDark,
                name: m['full_name'] ?? item['member_name'] ?? 'Unknown',
                amount: (s['emi'] as num?)?.toDouble() ?? 0,
                area: m['area']?.toString() ?? '',
                isOverdue: s['is_overdue'] == true,
                index: i,
                onTap: () => context.push('/staff/collection/${item['id']}',
                    extra: item),
              );
            },
          );
        },
        loading: () => _shimmerList(),
        error: (_, __) => Center(
            child: Text('Failed',
                style: TextStyle(color: theme.colorScheme.error))),
      ),
    );
  }

  Widget _buildCard(ThemeData theme, bool isDark,
      {required String name,
      required double amount,
      required String area,
      bool isOverdue = false,
      required int index,
      required VoidCallback onTap}) {
    final severityColor = isOverdue ? AppColors.error : AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C24) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: isOverdue
                ? AppColors.error.withValues(alpha: 0.15)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04))),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: isOverdue
                            ? [AppColors.error, AppColors.warning]
                            : [AppColors.primary, AppColors.accent]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                      child: Text(_getInitials(name),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (area.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 10,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.3)),
                              const SizedBox(width: 2),
                              Flexible(
                                  child: Text(area,
                                      style: TextStyle(
                                          fontSize: 9,
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.4)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${amount.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: severityColor,
                            height: 1.1)),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: severityColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(isOverdue ? 'Overdue' : 'Collect',
                          style: TextStyle(
                              color: severityColor,
                              fontSize: 8,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 250.ms, delay: (index * 40).ms)
        .slideX(begin: 0.02, end: 0);
  }

  Widget _buildOverdueCard(
      ThemeData theme, bool isDark, Map<String, dynamic> item, int index) {
    final name = item['member_name'] as String? ?? 'Unknown';
    final amount = (item['emi'] as num?)?.toDouble() ?? 0;
    final days = item['days_overdue'] as int? ?? 0;
    final severity = days > 30
        ? AppColors.error
        : (days > 15 ? AppColors.warning : AppColors.orange);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C24) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: severity.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/staff/collection/${item['loan_id']}', extra: item);
        },
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: severity.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14)),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$days',
                        style: TextStyle(
                            color: severity,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            height: 1)),
                    Text('d',
                        style: TextStyle(
                            color: severity,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            height: 1)),
                  ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1),
                    Text('$days days overdue',
                        style: TextStyle(
                            color: severity,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ]),
            ),
            Text('₹${amount.toStringAsFixed(0)}',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: severity,
                    height: 1.1)),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms, delay: (index * 40).ms);
  }

  Widget _buildCollectedCard(
      ThemeData theme, bool isDark, Map<String, dynamic> item, int index) {
    final name = item['member_name'] as String? ?? 'Unknown';
    final amount = (item['amount_collected'] as num?)?.toDouble() ?? 0;
    final mode = item['payment_mode'] as String? ?? 'cash';
    final isDigital = mode != 'cash';
    final color = isDigital ? AppColors.info : AppColors.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C24) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(
                isDigital
                    ? Icons.phone_android_rounded
                    : Icons.payments_rounded,
                color: color,
                size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1),
              Text(mode.toUpperCase(),
                  style: TextStyle(
                      color: color, fontSize: 9, fontWeight: FontWeight.w700)),
            ]),
          ),
          Text('₹${amount.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  height: 1.1)),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms, delay: (index * 40).ms);
  }

  Widget _empty(ThemeData theme, IconData icon, String title, String sub) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                shape: BoxShape.circle),
            child: Icon(icon,
                size: 48, color: AppColors.primary.withValues(alpha: 0.25))),
        const SizedBox(height: 16),
        Text(title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
        const SizedBox(height: 4),
        Text(sub,
            style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.25))),
      ]),
    );
  }

  Widget _shimmerList() => ListView.builder(
      itemCount: 5,
      itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: ShimmerCard(height: 80)));

  String _getInitials(String n) {
    final p = n.trim().split(' ');
    return p.length >= 2
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : n.isNotEmpty
            ? n[0].toUpperCase()
            : '?';
  }
}

class _CollectedStat extends ConsumerWidget {
  const _CollectedStat();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ref.watch(recentCollectionsProvider).when(
          data: (d) => Expanded(
              child: Column(children: [
            Text('${d.length}',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.success,
                    height: 1.1)),
            Text('Collected',
                style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    height: 1.2)),
          ])),
          loading: () => Expanded(
              child: Column(children: [
            Text('...',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.success,
                    height: 1.1)),
            Text('Collected',
                style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    height: 1.2)),
          ])),
          error: (_, __) => const SizedBox.shrink(),
        );
  }
}
