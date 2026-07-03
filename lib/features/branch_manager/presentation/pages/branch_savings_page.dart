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
import '../../../savings/data/models/savings_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/providers/branch_scoped_providers.dart';

/// Premium branch-scoped savings page for Branch Manager Portal.
/// Shows all savings plans belonging to the manager's branch members.
class BranchSavingsPage extends ConsumerStatefulWidget {
  const BranchSavingsPage({super.key});

  @override
  ConsumerState<BranchSavingsPage> createState() => _BranchSavingsPageState();
}

class _BranchSavingsPageState extends ConsumerState<BranchSavingsPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _activeFilter = 0; // 0: All, 1: Active, 2: Matured, 3: Closed

  final List<Map<String, dynamic>> _filters = [
    {'label': 'All', 'icon': Icons.savings_rounded},
    {'label': 'Active', 'icon': Icons.bolt_rounded},
    {'label': 'Matured', 'icon': Icons.verified_rounded},
    {'label': 'Closed', 'icon': Icons.pause_circle_rounded},
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
    final user = ref.watch(authProvider).user;
    final branchId = user?.branchId;

    if (branchId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Branch Savings')),
        body: const Center(child: Text('No branch assigned to your profile.')),
      );
    }

    final savingsAsync = ref.watch(branchSavingsProvider(branchId));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF2F2F7),
      body: AuroraBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(branchSavingsProvider(branchId));
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
                  'Branch Savings',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () => context.push('/branch/savings/new'),
                    tooltip: 'New Savings',
                  ),
                ],
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

              // Summary Cards
              SliverToBoxAdapter(
                child: savingsAsync.when(
                  data: (savings) => _buildSummaryRow(theme, isDark, savings),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Savings Cards
              savingsAsync.when(
                data: (savings) {
                  final filtered = _applyFilters(savings);
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
                        final saving = filtered[index];
                        return _buildSavingsCard(context, theme, isDark, saving, index);
                      },
                    ),
                  );
                },
                loading: () => SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.builder(
                    itemCount: 6,
                    itemBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: ShimmerCard(height: 140),
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
          hintText: 'Search by member name or plan...',
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
  Widget _buildSummaryRow(ThemeData theme, bool isDark, List<SavingsModel> savings) {
    final activeSavings = savings.where((s) => s.status == 'active').toList();
    final totalSaved = activeSavings.fold<double>(0, (sum, s) => sum + s.currentAmount);
    final totalTarget = activeSavings.fold<double>(0, (sum, s) => sum + s.targetAmount);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatChip(
              theme, isDark,
              icon: Icons.savings_rounded,
              label: 'Total Saved',
              value: AppFormatters.formatCurrency(totalSaved),
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatChip(
              theme, isDark,
              icon: Icons.bolt_rounded,
              label: 'Active Plans',
              value: '${activeSavings.length}',
              color: AppColors.info,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatChip(
              theme, isDark,
              icon: Icons.track_changes_rounded,
              label: 'Target',
              value: AppFormatters.formatCurrency(totalTarget),
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

  // Savings Card
  Widget _buildSavingsCard(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    SavingsModel saving,
    int index,
  ) {
    final progress = saving.targetAmount > 0
        ? (saving.currentAmount / saving.targetAmount).clamp(0.0, 1.0)
        : 0.0;

    StatusType statusType;
    String statusLabel;
    switch (saving.status) {
      case 'active':
        statusType = StatusType.active;
        statusLabel = 'Active';
        break;
      case 'matured':
        statusType = StatusType.completed;
        statusLabel = 'Matured';
        break;
      case 'closed':
      case 'withdrawn':
      case 'cancelled':
        statusType = StatusType.defaultStatus;
        statusLabel = 'Closed';
        break;
      default:
        statusType = StatusType.standard;
        statusLabel = saving.status;
    }

    final maturityStr = AppFormatters.formatDate(saving.maturityDate);

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      onTap: () => context.push('/branch/savings/${saving.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.success.withValues(alpha: 0.8),
                      AppColors.teal.withValues(alpha: 0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.savings_rounded, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      saving.memberName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      saving.planName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(label: statusLabel, type: statusType),
            ],
          ),
          const SizedBox(height: 16),

          // Amount Details
          Row(
            children: [
              Expanded(
                child: _buildDetailColumn(
                  theme, isDark,
                  label: 'Saved',
                  value: AppFormatters.formatCurrency(saving.currentAmount),
                  valueColor: AppColors.success,
                ),
              ),
              Expanded(
                child: _buildDetailColumn(
                  theme, isDark,
                  label: 'Target',
                  value: AppFormatters.formatCurrency(saving.targetAmount),
                ),
              ),
              Expanded(
                child: _buildDetailColumn(
                  theme, isDark,
                  label: saving.collectionType[0].toUpperCase() +
                      saving.collectionType.substring(1),
                  value: AppFormatters.formatCurrency(saving.monthlyDeposit),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor:
                  isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(
                progress >= 1
                    ? AppColors.success
                    : progress >= 0.5
                        ? AppColors.teal
                        : AppColors.info,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toStringAsFixed(0)}% of target',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 11,
                ),
              ),
              Text(
                'Matures: $maturityStr',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(
          duration: 350.ms,
          delay: Duration(milliseconds: 60 * index.clamp(0, 8)),
        );
  }

  Widget _buildDetailColumn(
    ThemeData theme,
    bool isDark, {
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
            fontSize: 13,
          ),
        ),
      ],
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
                  : AppColors.success.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.savings_rounded,
              size: 48,
              color: isDark ? Colors.white24 : AppColors.success.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _searchQuery.isNotEmpty ? 'No savings match your search' : 'No savings plans yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Savings plans for your branch will appear here',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  // Filter Logic
  List<SavingsModel> _applyFilters(List<SavingsModel> savings) {
    var filtered = savings;

    // Status filter
    switch (_activeFilter) {
      case 1: // Active
        filtered = filtered.where((s) => s.status == 'active').toList();
        break;
      case 2: // Matured
        filtered = filtered.where((s) => s.status == 'matured').toList();
        break;
      case 3: // Closed
        filtered = filtered.where((s) {
          return s.status == 'closed' || s.status == 'withdrawn' || s.status == 'cancelled';
        }).toList();
        break;
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((s) {
        final name = s.memberName.toLowerCase();
        final plan = s.planName.toLowerCase();
        final id = s.id.toLowerCase();
        return name.contains(q) || plan.contains(q) || id.contains(q);
      }).toList();
    }

    return filtered;
  }
}
