// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/glass_text_field.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../branch_manager/data/providers/branch_scoped_providers.dart';
import '../../data/providers/staff_branch_providers.dart';
import '../widgets/premium_helpers.dart';

class StaffUserHubPage extends ConsumerStatefulWidget {
  const StaffUserHubPage({super.key});

  @override
  ConsumerState<StaffUserHubPage> createState() => _StaffUserHubPageState();
}

class _StaffUserHubPageState extends ConsumerState<StaffUserHubPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _activeFilter = 0;

  final List<Map<String, dynamic>> _filters = [
    {'label': 'All', 'icon': Icons.people_rounded},
    {'label': 'Active', 'icon': Icons.check_circle_rounded},
    {'label': 'Inactive', 'icon': Icons.pause_circle_rounded},
    {'label': 'New This Month', 'icon': Icons.person_add_rounded},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final branchAsync = ref.watch(staffBranchIdProvider);

    if (branchAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('User Hub')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final branchId = branchAsync.valueOrNull;

    if (branchId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('User Hub')),
        body: const Center(child: Text('No branch assigned to your profile.\nContact your admin to assign a branch.')),
      );
    }

    final membersAsync = ref.watch(branchMembersProvider(branchId));
    final memberCountAsync = ref.watch(branchMemberCountProvider(branchId));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF2F2F7),
      body: AuroraBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(branchMembersProvider(branchId));
            ref.invalidate(branchMemberCountProvider(branchId));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // App Bar
              SliverAppBar(
                pinned: true,
                elevation: 0,
                backgroundColor: isDark
                    ? const Color(0xFF0A0A0C).withValues(alpha: 0.85)
                    : const Color(0xFFF2F2F7).withValues(alpha: 0.85),
                surfaceTintColor: Colors.transparent,
                title: Text(
                  'User Hub',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                actions: [
                  memberCountAsync.when(
                    data: (count) => Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$count members',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
                systemOverlayStyle:
                    isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
              ),

              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: GlassTextField(
                    controller: _searchController,
                    hintText: 'Search members by name or phone...',
                    prefixIcon: Icons.search_rounded,
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              ),

              // Filter Chips
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      final isActive = _activeFilter == index;
                      return GestureDetector(
                        onTap: () => setState(() => _activeFilter = index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            gradient: isActive
                                ? LinearGradient(colors: [AppColors.primary, AppColors.accent])
                                : null,
                            color: isActive
                                ? null
                                : isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isActive
                                  ? AppColors.primary
                                  : isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                filter['icon'] as IconData,
                                size: 16,
                                color: isActive
                                    ? Colors.white
                                    : isDark
                                        ? Colors.white70
                                        : Colors.black54,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                filter['label'] as String,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                                  color: isActive
                                      ? Colors.white
                                      : isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(
                            duration: 300.ms,
                            delay: Duration(milliseconds: 50 * index),
                          );
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Summary Row
              SliverToBoxAdapter(
                child: membersAsync.when(
                  data: (members) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: PremiumHelpers.sectionHeader(theme, 'Overview'),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
              SliverToBoxAdapter(
                child: membersAsync.when(
                  data: (members) => _buildSummaryRow(theme, isDark, members),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Member Cards
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: PremiumHelpers.sectionHeader(theme, 'Members'),
                ),
              ),
              membersAsync.when(
                data: (members) {
                  final filtered = _applyFilters(members);
                  if (filtered.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(theme, isDark),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        return _buildMemberCard(
                          context, theme, isDark, filtered[index], index,
                        );
                      },
                    ),
                  );
                },
                loading: () => SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.builder(
                    itemCount: 6,
                    itemBuilder: (_, __) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: const ShimmerCard(
                        height: 100,
                        borderRadius: 16,
                      ),
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
                        Text('Error loading members',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 8),
                        Text(e.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white38 : Colors.black38)),
                      ],
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(ThemeData theme, bool isDark, List<Map<String, dynamic>> members) {
    final total = members.length;
    final active = members.where((m) => (m['status'] ?? 'active') == 'active').length;
    final inactive = total - active;
    final thisMonth = members.where((m) {
      final created = m['created_at'] as String?;
      if (created == null) return false;
      final date = DateTime.tryParse(created);
      if (date == null) return false;
      final now = DateTime.now();
      return date.month == now.month && date.year == now.year;
    }).length;

    final chips = [
      _summaryChip(theme, isDark, '$total', 'Total', AppColors.primary),
      _summaryChip(theme, isDark, '$active', 'Active', const Color(0xFF10B981)),
      _summaryChip(theme, isDark, '$inactive', 'Inactive', const Color(0xFFFBBF24)),
      _summaryChip(theme, isDark, '$thisMonth', 'New', const Color(0xFF667EEA)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (int i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: chips[i]
                  .animate()
                  .fadeIn(delay: Duration(milliseconds: 100 * i), duration: 300.ms)
                  .slideY(begin: 0.04, end: 0, delay: Duration(milliseconds: 100 * i), duration: 300.ms, curve: Curves.easeOutCubic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryChip(ThemeData theme, bool isDark, String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        children: [
          Text(count,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildMemberCard(
      BuildContext context, ThemeData theme, bool isDark, Map<String, dynamic> member, int index) {
    final name = member['full_name'] as String? ?? 'Unknown';
    final phone = member['phone'] as String?;
    final status = member['status'] as String? ?? 'active';
    final isActive = status == 'active';
    final totalLoans = (member['total_loans'] as int?) ?? 0;
    final totalSavings = (member['total_savings'] as num?)?.toDouble() ?? 0;
    final f = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final memberId = member['id'] as String;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/staff/user-hub/$memberId'),
          borderRadius: BorderRadius.circular(16),
          child: GlassCard(
            borderRadius: 16,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isActive
                          ? [const Color(0xFF667EEA), const Color(0xFF764BA2)]
                          : [Colors.grey.shade400, Colors.grey.shade500],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: (isActive
                                ? const Color(0xFF667EEA)
                                : Colors.grey.shade400)
                            .withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      if (phone != null)
                        Text(
                          phone,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (totalLoans > 0) ...[
                            Icon(Icons.account_balance_rounded,
                                size: 12,
                                color: isDark ? Colors.white30 : Colors.black26),
                            const SizedBox(width: 3),
                            Text(
                              '$totalLoans loans',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white30 : Colors.black26),
                            ),
                            const SizedBox(width: 10),
                          ],
                          if (totalSavings > 0) ...[
                            Icon(Icons.savings_rounded,
                                size: 12,
                                color: isDark ? Colors.white30 : Colors.black26),
                            const SizedBox(width: 3),
                            Text(
                              f.format(totalSavings),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white30 : Colors.black26),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Status + arrow
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusBadge(
                      label: isActive ? 'Active' : 'Inactive',
                      type: isActive ? StatusType.active : StatusType.warning,
                    ),
                    const SizedBox(height: 8),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(
          delay: Duration(milliseconds: 40 * index.clamp(0, 15)),
          duration: 300.ms,
        )
        .slideX(begin: 0.03, end: 0, delay: Duration(milliseconds: 40 * index.clamp(0, 15)));
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.people_outline_rounded,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              _searchQuery.isNotEmpty ? 'No members found' : 'No members yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : 'Members will appear here once added to your branch',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white38 : Colors.black38),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95));
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> members) {
    var filtered = members;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((m) {
        final name = (m['full_name'] as String? ?? '').toLowerCase();
        final phone = (m['phone'] as String? ?? '').toLowerCase();
        return name.contains(q) || phone.contains(q);
      }).toList();
    }

    // Tab filter
    switch (_activeFilter) {
      case 1: // Active
        filtered = filtered.where((m) => (m['status'] ?? 'active') == 'active').toList();
        break;
      case 2: // Inactive
        filtered = filtered.where((m) => (m['status'] ?? 'active') != 'active').toList();
        break;
      case 3: // New This Month
        final now = DateTime.now();
        filtered = filtered.where((m) {
          final created = m['created_at'] as String?;
          if (created == null) return false;
          final date = DateTime.tryParse(created);
          if (date == null) return false;
          return date.month == now.month && date.year == now.year;
        }).toList();
        break;
    }

    return filtered;
  }
}
