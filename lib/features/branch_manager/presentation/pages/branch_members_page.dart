// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../data/providers/branch_manager_providers.dart';
import '../../data/providers/branch_scoped_providers.dart';

/// Premium branch-scoped members page for Branch Manager Portal.
/// Shows all members belonging to the manager's branch.
class BranchMembersPage extends ConsumerStatefulWidget {
  const BranchMembersPage({super.key});

  @override
  ConsumerState<BranchMembersPage> createState() => _BranchMembersPageState();
}

class _BranchMembersPageState extends ConsumerState<BranchMembersPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _activeFilter = 0; // 0: All, 1: Active, 2: Inactive, 3: New This Month

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
    final branchId = ref.watch(currentUserBranchIdProvider);

    if (branchId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Branch Members')),
        body: const Center(child: Text('No branch assigned to your profile.')),
      );
    }

    final membersAsync = ref.watch(branchMembersProvider(branchId));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF2F2F7),
      body: AuroraBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(branchMembersProvider(branchId));
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
                  'Branch Members',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                systemOverlayStyle:
                    isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
              ),

              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: _buildSearchBar(theme, isDark),
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
                            color: isActive
                                ? AppColors.primary
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
                  data: (members) => _buildSummaryRow(theme, isDark, members),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Member Cards
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
                        final member = filtered[index];
                        return _buildMemberCard(
                          context, theme, isDark, member, index,
                        );
                      },
                    ),
                  );
                },
                loading: () => SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.builder(
                    itemCount: 8,
                    itemBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: ShimmerCard(height: 100),
                    ),
                  ),
                ),
                error: (error, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${error.toString()}'),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/branch/members/add'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded, size: 20),
        label: const Text(
          'Add Member',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.3, end: 0),
    );
  }

  // Search Bar
  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Search members by name or phone...',
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: isDark ? Colors.white38 : Colors.black38, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // Summary Row
  Widget _buildSummaryRow(
    ThemeData theme,
    bool isDark,
    List<Map<String, dynamic>> members,
  ) {
    final total = members.length;
    final active = members.where((m) => (m['status']?.toString() ?? 'active') == 'active').length;
    final now = DateTime.now();
    final newThisMonth = members.where((m) {
      final createdAt = m['created_at']?.toString();
      if (createdAt == null) return false;
      final date = DateTime.tryParse(createdAt);
      if (date == null) return false;
      return date.year == now.year && date.month == now.month;
    }).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatChip(
              theme, isDark,
              icon: Icons.people_rounded,
              label: 'Total',
              value: '$total',
              color: AppColors.info,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatChip(
              theme, isDark,
              icon: Icons.check_circle_rounded,
              label: 'Active',
              value: '$active',
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatChip(
              theme, isDark,
              icon: Icons.person_add_rounded,
              label: 'New',
              value: '$newThisMonth',
              color: AppColors.accent,
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
    );
  }

  Widget _buildStatChip(
    ThemeData theme,
    bool isDark, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // Member Card
  Widget _buildMemberCard(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    Map<String, dynamic> member,
    int index,
  ) {
    final name = member['full_name']?.toString() ?? 'Unknown';
    final phone = member['phone']?.toString() ?? '';
    final status = member['status']?.toString() ?? 'active';
    final memberId = member['id']?.toString() ?? '';
    final kycStatus = member['kyc_status']?.toString() ?? 'pending';
    final createdAt = member['created_at']?.toString();

    final isActive = status == 'active';
    final joinedDate = createdAt != null
        ? AppFormatters.formatDate(DateTime.tryParse(createdAt) ?? DateTime.now())
        : '';

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      onTap: () => context.push('/branch/members/$memberId'),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isActive
                    ? [AppColors.primary.withValues(alpha: 0.8), AppColors.accent.withValues(alpha: 0.6)]
                    : [Colors.grey.withValues(alpha: 0.5), Colors.grey.withValues(alpha: 0.3)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    StatusBadge(
                      label: isActive ? 'Active' : 'Inactive',
                      type: isActive ? StatusType.active : StatusType.defaultStatus,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (phone.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.phone_rounded,
                          size: 13,
                          color: isDark ? Colors.white38 : Colors.black38),
                      const SizedBox(width: 4),
                      Text(
                        AppFormatters.formatPhone(phone),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white54 : Colors.black45,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: kycStatus == 'verified'
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'KYC: ${kycStatus[0].toUpperCase()}${kycStatus.substring(1)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: kycStatus == 'verified'
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    ),
                    if (joinedDate.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Since $joinedDate',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Chevron
          Icon(
            Icons.chevron_right_rounded,
            color: isDark ? Colors.white24 : Colors.black26,
            size: 22,
          ),
        ],
      ),
    ).animate().fadeIn(
          duration: 350.ms,
          delay: Duration(milliseconds: 50 * index.clamp(0, 10)),
        );
  }

  // Empty State
  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : AppColors.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_rounded,
              size: 48,
              color: isDark ? Colors.white24 : AppColors.primary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _searchQuery.isNotEmpty ? 'No members match your search' : 'No members yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Add your first member to get started',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  // Filter Logic
  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> members) {
    var filtered = members;

    // Status filter
    switch (_activeFilter) {
      case 1: // Active
        filtered = filtered.where((m) => (m['status']?.toString() ?? 'active') == 'active').toList();
        break;
      case 2: // Inactive
        filtered = filtered.where((m) => (m['status']?.toString() ?? 'active') != 'active').toList();
        break;
      case 3: // New This Month
        final now = DateTime.now();
        filtered = filtered.where((m) {
          final createdAt = m['created_at']?.toString();
          if (createdAt == null) return false;
          final date = DateTime.tryParse(createdAt);
          if (date == null) return false;
          return date.year == now.year && date.month == now.month;
        }).toList();
        break;
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((m) {
        final name = (m['full_name']?.toString() ?? '').toLowerCase();
        final phone = m['phone']?.toString() ?? '';
        return name.contains(q) || phone.contains(q);
      }).toList();
    }

    return filtered;
  }
}
