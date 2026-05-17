import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/collection_providers.dart';

class CustomerSearchPage extends ConsumerStatefulWidget {
  const CustomerSearchPage({super.key});

  @override
  ConsumerState<CustomerSearchPage> createState() => _CustomerSearchPageState();
}

class _CustomerSearchPageState extends ConsumerState<CustomerSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _activeChip = 'frequent';
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final searchResults = ref.watch(customerSearchProvider(_searchQuery));
    final frequentAsync = ref.watch(frequentCustomersProvider);

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
        title: const Text('Customers',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        centerTitle: false,
      ),
      body: Column(
        children: [
          _buildSearchBar(theme, isDark),
          if (_searchQuery.isEmpty) _buildChipRow(theme, isDark),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(frequentCustomersProvider);
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: _searchQuery.isNotEmpty
                  ? _buildSearchResults(theme, isDark, searchResults)
                  : _buildFrequentSection(theme, isDark, frequentAsync),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C24) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        autofocus: true,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Search name, phone, or ID...',
          hintStyle: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.25)),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 18,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  Widget _buildChipRow(ThemeData theme, bool isDark) {
    final chips = [
      {'key': 'frequent', 'label': 'Frequent', 'icon': Icons.star_rounded},
      {'key': 'recent', 'label': 'Recent', 'icon': Icons.history_rounded},
      {'key': 'all', 'label': 'All', 'icon': Icons.people_rounded},
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: chips.map((c) {
          final active = _activeChip == c['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _activeChip = c['key'] as String);
              },
              child: AnimatedContainer(
                duration: 200.ms,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: active
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.06))),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(c['icon'] as IconData,
                        size: 14,
                        color: active
                            ? AppColors.primary
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.3)),
                    const SizedBox(width: 6),
                    Text(c['label'] as String,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? AppColors.primary
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4))),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFrequentSection(ThemeData theme, bool isDark,
      AsyncValue<List<Map<String, dynamic>>> async) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          async.when(
            data: (customers) {
              if (customers.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF181C24) : Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04))),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.people_outline_rounded,
                          size: 56,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.1)),
                      const SizedBox(height: 12),
                      Text('No frequent customers',
                          style: TextStyle(
                              fontSize: 15,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.35))),
                    ]),
                  ),
                ).animate().fadeIn();
              }
              return Column(
                children: customers.asMap().entries.map((entry) {
                  final i = entry.key;
                  final c = entry.value;
                  return _buildCard(
                    theme,
                    isDark,
                    name: c['full_name'] as String? ?? 'Unknown',
                    phone: c['phone'] as String? ?? '',
                    area: c['area'] as String? ?? '',
                    outstanding:
                        (c['outstanding_balance'] as num?)?.toDouble() ?? 0,
                    index: i,
                    onTap: () => context.push('/staff/customers/${c['id']}'),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  size: 14, color: Colors.orangeAccent.withValues(alpha: 0.6)),
              const SizedBox(width: 8),
              Text('Search by name, phone, or member ID',
                  style: TextStyle(
                      fontSize: 12,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.3))),
            ],
          ),
        ].animate(interval: 40.ms).fadeIn().slideY(begin: 0.03, end: 0),
      ),
    );
  }

  Widget _buildSearchResults(ThemeData theme, bool isDark,
      AsyncValue<List<Map<String, dynamic>>> async) {
    return async.when(
      data: (results) {
        if (results.isEmpty && _searchQuery.isNotEmpty) {
          return Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      shape: BoxShape.circle),
                  child: Icon(Icons.search_off_rounded,
                      size: 48,
                      color: AppColors.primary.withValues(alpha: 0.25))),
              const SizedBox(height: 16),
              Text('No results found',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.4))),
              const SizedBox(height: 4),
              Text('Try a different term',
                  style: TextStyle(
                      fontSize: 13,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.25))),
            ]),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          itemCount: results.length,
          itemBuilder: (ctx, i) {
            final c = results[i];
            return _buildCard(
              theme,
              isDark,
              name: c['full_name'] as String? ?? 'Unknown',
              phone: c['phone'] as String? ?? '',
              area: c['area'] as String? ?? '',
              outstanding: (c['outstanding_balance'] as num?)?.toDouble() ?? 0,
              index: i,
              onTap: () => context.push('/staff/customers/${c['id']}'),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildCard(ThemeData theme, bool isDark,
      {required String name,
      required String phone,
      required String area,
      required double outstanding,
      required int index,
      required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C24) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04)),
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
                        colors: [AppColors.primary, AppColors.accent]),
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
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (phone.isNotEmpty) ...[
                            Icon(Icons.phone_rounded,
                                size: 10,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.3)),
                            const SizedBox(width: 2),
                            Text(phone,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.4))),
                            const SizedBox(width: 8),
                          ],
                          if (area.isNotEmpty) ...[
                            Icon(Icons.location_on_outlined,
                                size: 10,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.3)),
                            const SizedBox(width: 2),
                            Flexible(
                                child: Text(area,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.4)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (outstanding > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('₹${outstanding.toStringAsFixed(0)}',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.error,
                                  height: 1.1)),
                          Text('Due',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.error,
                                  height: 1.2)),
                        ]),
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

  String _getInitials(String n) {
    final p = n.trim().split(' ');
    return p.length >= 2
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : n.isNotEmpty
            ? n[0].toUpperCase()
            : '?';
  }
}
