import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../data/providers/branch_providers.dart';
import '../../models/branch_model.dart';

// ─── Main Page ───

class BranchManagementPage extends ConsumerStatefulWidget {
  const BranchManagementPage({super.key});

  @override
  ConsumerState<BranchManagementPage> createState() =>
      _BranchManagementPageState();
}

class _BranchManagementPageState extends ConsumerState<BranchManagementPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final branchesAsync = ref.watch(branchesProvider);
    final orgAsync = ref.watch(currentOrgProvider);
    final branchCount = branchesAsync.valueOrNull?.length ?? 0;
    final activeCount =
        branchesAsync.valueOrNull?.where((b) => b.isActive).length ?? 0;
    final inactiveCount = branchCount - activeCount;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(branchesProvider);
              ref.invalidate(branchCountProvider);
            },
            displacement: 20,
            color: theme.colorScheme.primary,
            backgroundColor: theme.cardColor,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                // ── App Bar ──
                SliverToBoxAdapter(
                  child: _buildAppBar(context, isDark, orgAsync, branchCount),
                ),

                // ── Summary Strip ──
                SliverToBoxAdapter(
                  child: _buildSummaryStrip(
                      isDark, branchCount, activeCount, inactiveCount),
                ),

                // ── Section Header ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    child: _SectionHeader(
                      icon: Icons.business_rounded,
                      title: 'All Branches',
                      color: AppColors.primary,
                      trailing: GestureDetector(
                        onTap: () {
                          final org = orgAsync.valueOrNull;
                          final maxBranches = org?['max_branches'] ?? 5;
                          if (branchCount >= maxBranches) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Branch limit reached ($maxBranches). Contact support to increase your limit.'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                            return;
                          }
                          _showBranchDialog(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary.withValues(alpha: 0.9),
                                AppColors.accent.withValues(alpha: 0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                'Add Branch',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 200.ms),
                      ),
                    ),
                  ),
                ),

                // ── Branch List ──
                branchesAsync.when(
                  loading: () => SliverToBoxAdapter(
                    child: _buildLoadingState(),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: _buildErrorState(context, isDark, e.toString()),
                  ),
                  data: (branches) => branches.isEmpty
                      ? SliverToBoxAdapter(
                          child: _buildEmptyState(context, isDark))
                      : SliverPadding(
                          padding:
                              const EdgeInsets.fromLTRB(24, 0, 24, 100),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final branch = branches[index];
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 14),
                                  child: _BranchCard(
                                    branch: branch,
                                    index: index,
                                    onTap: () =>
                                        _showBranchDetails(branch),
                                    onEdit: () =>
                                        _showBranchDialog(context,
                                            branch: branch),
                                    onStaff: () => context.push(
                                        '/users?branch_id=${branch.id}'),
                                    onAddUser: () => context.push(
                                        '/users/new?branch_id=${branch.id}'),
                                    onDelete: () =>
                                        _confirmDelete(branch),
                                  ),
                                );
                              },
                              childCount: branches.length,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── App Bar ───

  Widget _buildAppBar(BuildContext context, bool isDark,
      AsyncValue<Map<String, dynamic>?> orgAsync, int branchCount) {
    final maxBranches = orgAsync.valueOrNull?['max_branches'] ?? 5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Branch Management',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '$branchCount of $maxBranches branches',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.9),
                  AppColors.accent.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                  spreadRadius: -3,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.business_rounded,
                    size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  '$branchCount',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  // ─── Summary Strip ───

  Widget _buildSummaryStrip(
      bool isDark, int total, int active, int inactive) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _SummaryChip(
              icon: Icons.business_rounded,
              label: 'Total',
              value: '$total',
              color: AppColors.primary,
              isDark: isDark,
            ),
            const SizedBox(width: 10),
            _SummaryChip(
              icon: Icons.check_circle_rounded,
              label: 'Active',
              value: '$active',
              color: AppColors.success,
              isDark: isDark,
            ),
            const SizedBox(width: 10),
            _SummaryChip(
              icon: Icons.pause_circle_rounded,
              label: 'Inactive',
              value: '$inactive',
              color: AppColors.warning,
              isDark: isDark,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 100.ms).slideX(begin: 0.03, end: 0);
  }

  // ─── Loading State ───

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      child: Column(
        children: List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: ShimmerCard(height: 180),
          ),
        ),
      ),
    );
  }

  // ─── Error State ───

  Widget _buildErrorState(BuildContext context, bool isDark, String error) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 100),
      child: GlassCard(
        glassmorphic: true,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.error_outline, size: 36, color: AppColors.error),
            ),
            const SizedBox(height: 20),
            Text(
              'Unable to Load Branches',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                ref.invalidate(branchesProvider);
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Empty State ───

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 100),
      child: GlassCard(
        glassmorphic: true,
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.2),
                    AppColors.accent.withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.business_rounded,
                  size: 44, color: AppColors.primary.withValues(alpha: 0.8)),
            ).animate().scale(
                delay: 100.ms, duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 28),
            Text(
              'No Branches Yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Create your first branch to start organizing\nyour staff and members by location.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => _showBranchDialog(context),
              icon: const Icon(Icons.add_business_rounded, size: 20),
              label: const Text('Create Branch',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0);
  }

  // ─── Dialogs & Sheets ───

  void _showBranchDialog(BuildContext context, {BranchModel? branch}) {
    showDialog(
      context: context,
      builder: (ctx) => BranchFormDialog(
        branch: branch,
        onSave: (data) async {
          final notifier = ref.read(branchNotifierProvider.notifier);
          if (branch != null) {
            final result = await notifier.updateBranch(branch.id, data);
            if (result == null) {
              final errorState = ref.read(branchNotifierProvider);
              final errorMsg = errorState.error?.toString() ?? 'Update failed';
              throw Exception(errorMsg);
            }
          } else {
            final result = await notifier.createBranch(
              name: data['name'],
              code: data['code'],
              address: data['address'],
              city: data['city'],
              addressState: data['state'],
              pincode: data['pincode'],
              phone: data['phone'],
              email: data['email'],
              managerId: data['manager_id'],
            );
            if (result == null) {
              final errorState = ref.read(branchNotifierProvider);
              final errorMsg = errorState.error?.toString() ?? 'Creation failed';
              throw Exception(errorMsg);
            }
          }
        },
      ),
    );
  }

  void _showBranchDetails(BranchModel branch) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BranchDetailSheet(branch: branch),
    );
  }

  Future<void> _confirmDelete(BranchModel branch) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF141824).withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.2),
              width: 0.8,
            ),
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    size: 32, color: AppColors.error),
              ),
              const SizedBox(height: 20),
              Text(
                'Delete Branch?',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Are you sure you want to delete "${branch.name}"? This will unassign all staff and members from this branch.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color
                      ?.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.black.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text('Cancel',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Delete',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      final notifier = ref.read(branchNotifierProvider.notifier);
      await notifier.deleteBranch(branch.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${branch.name} deleted successfully',
                style: const TextStyle(fontWeight: FontWeight.w500)),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: isDark ? AppColors.successDark : AppColors.success,
          ),
        );
      }
    }
  }
}

// ─── Section Header ───

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Widget? trailing;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ─── Summary Chip ───

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: isDark ? 0.02 : 0.4),
            blurRadius: 0,
            offset: const Offset(0, -0.5),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color:
                      theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Branch Card (Compact) ───

class _BranchCard extends StatelessWidget {
  final BranchModel branch;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onStaff;
  final VoidCallback onAddUser;
  final VoidCallback onDelete;

  const _BranchCard({
    required this.branch,
    required this.index,
    required this.onTap,
    required this.onEdit,
    required this.onStaff,
    required this.onAddUser,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = branch.isActive;
    final accentColor = isActive ? AppColors.success : AppColors.warning;

    return GlassCard(
      glassmorphic: true,
      borderColor: accentColor.withValues(alpha: 0.12),
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Row: Avatar + Name + Status ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Gradient Initial Avatar (smaller)
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isActive
                        ? [AppColors.primary, AppColors.accent]
                        : [Colors.grey.shade400, Colors.grey.shade600],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: (isActive ? AppColors.primary : Colors.grey)
                          .withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                      spreadRadius: -1,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    branch.code
                        .substring(0, branch.code.length > 3 ? 3 : branch.code.length)
                        .toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name + Location + Manager (inline)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      branch.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 12,
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.4)),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            branch.city ?? 'No location',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Manager inline with location
                        if (branch.managerName != null) ...[
                          Container(
                            width: 2,
                            height: 2,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Icon(Icons.person_outline_rounded,
                              size: 11,
                              color: AppColors.primary.withValues(alpha: 0.5)),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              branch.managerName!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: AppColors.primary.withValues(alpha: 0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Status Badge (smaller)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: accentColor.withValues(alpha: 0.2), width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      branch.status.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Quick Actions (compact pills) ──
          Row(
            children: [
              _CompactPill(
                icon: Icons.edit_outlined,
                label: 'Edit',
                color: AppColors.primary,
                onTap: onEdit,
              ),
              const SizedBox(width: 6),
              _CompactPill(
                icon: Icons.people_outline_rounded,
                label: 'Staff',
                color: AppColors.accentLight,
                onTap: onStaff,
              ),
              const SizedBox(width: 6),
              _CompactPill(
                icon: Icons.person_add_outlined,
                label: 'Add User',
                color: AppColors.success,
                onTap: onAddUser,
              ),
              const Spacer(),
              _CompactPill(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                color: AppColors.error,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 350.ms, delay: (index * 60).ms)
        .slideY(begin: 0.06, end: 0);
  }
}

// ─── Compact Action Pill ───

class _CompactPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CompactPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withValues(alpha: 0.12),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Branch Form Dialog — Premium Glassmorphic
// ═══════════════════════════════════════════════════════════════════════════

class BranchFormDialog extends StatefulWidget {
  final BranchModel? branch;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const BranchFormDialog({super.key, this.branch, required this.onSave});

  @override
  State<BranchFormDialog> createState() => _BranchFormDialogState();
}

class _BranchFormDialogState extends State<BranchFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String? _selectedManagerId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.branch != null) {
      _nameCtrl.text = widget.branch!.name;
      _codeCtrl.text = widget.branch!.code;
      _addressCtrl.text = widget.branch!.address ?? '';
      _cityCtrl.text = widget.branch!.city ?? '';
      _stateCtrl.text = widget.branch!.state ?? '';
      _pincodeCtrl.text = widget.branch!.pincode ?? '';
      _phoneCtrl.text = widget.branch!.phone ?? '';
      _emailCtrl.text = widget.branch!.email ?? '';
      _selectedManagerId = widget.branch!.managerId;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEdit = widget.branch != null;
    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: size.width > 600 ? 80 : 20,
        vertical: 40,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0C1018).withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: 0.88),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.5),
                width: 0.8,
              ),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Premium Header ──
                    _buildHeader(isDark, isEdit),
                    const SizedBox(height: 28),

                    // ── Section 1: Branch Details ──
                    _SectionLabel(
                      icon: Icons.info_outline_rounded,
                      label: 'Branch Details',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),
                    _PremiumField(
                      ctrl: _nameCtrl,
                      label: 'Branch Name',
                      icon: Icons.business_rounded,
                      isDark: isDark,
                      required: true,
                    ).animate().fadeIn(delay: 0.ms, duration: 350.ms).slideY(begin: 0.04, end: 0),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _PremiumField(
                            ctrl: _codeCtrl,
                            label: 'Branch Code',
                            icon: Icons.tag_rounded,
                            isDark: isDark,
                            required: true,
                            hint: 'e.g. BR001',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PremiumField(
                            ctrl: _cityCtrl,
                            label: 'City',
                            icon: Icons.location_city_rounded,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 50.ms, duration: 350.ms).slideY(begin: 0.04, end: 0),

                    const SizedBox(height: 24),

                    // ── Section 2: Address ──
                    _SectionLabel(
                      icon: Icons.map_outlined,
                      label: 'Address & Contact',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),
                    _PremiumField(
                      ctrl: _addressCtrl,
                      label: 'Address',
                      icon: Icons.location_on_outlined,
                      isDark: isDark,
                    ).animate().fadeIn(delay: 100.ms, duration: 350.ms).slideY(begin: 0.04, end: 0),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _PremiumField(
                            ctrl: _stateCtrl,
                            label: 'State',
                            icon: Icons.map_outlined,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PremiumField(
                            ctrl: _pincodeCtrl,
                            label: 'Pincode',
                            icon: Icons.pin_drop_rounded,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 150.ms, duration: 350.ms).slideY(begin: 0.04, end: 0),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _PremiumField(
                            ctrl: _phoneCtrl,
                            label: 'Phone',
                            icon: Icons.phone_rounded,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PremiumField(
                            ctrl: _emailCtrl,
                            label: 'Email',
                            icon: Icons.email_outlined,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 200.ms, duration: 350.ms).slideY(begin: 0.04, end: 0),

                    const SizedBox(height: 24),

                    // ── Section 3: Assignment ──
                    _SectionLabel(
                      icon: Icons.person_outline_rounded,
                      label: 'Assignment',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),
                    _buildManagerDropdown(isDark)
                        .animate()
                        .fadeIn(delay: 250.ms, duration: 350.ms)
                        .slideY(begin: 0.04, end: 0),

                    const SizedBox(height: 32),

                    // ── Premium Submit Button ──
                    _buildSubmitButton(isDark, isEdit),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Premium Header ───

  Widget _buildHeader(bool isDark, bool isEdit) {
    final theme = Theme.of(context);
    return Row(
      children: [
        // Animated gradient icon with glow
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.accent],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 6),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 0),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Icon(
            isEdit ? Icons.edit_rounded : Icons.add_business_rounded,
            color: Colors.white,
            size: 26,
          ),
        ).animate().scale(
            begin: const Offset(0.85, 0.85),
            end: const Offset(1, 1),
            duration: 400.ms,
            curve: Curves.elasticOut),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? 'Edit Branch' : 'Create New Branch',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                isEdit
                    ? 'Update branch information below'
                    : 'Set up a new branch for your organization',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Glassmorphic close button
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              width: 0.5,
            ),
          ),
          child: IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  // ─── Premium Submit Button ───

  Widget _buildSubmitButton(bool isDark, bool isEdit) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          padding: EdgeInsets.zero,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.accent],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            alignment: Alignment.center,
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isEdit
                            ? Icons.check_circle_outline_rounded
                            : Icons.add_circle_outline_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isEdit ? 'Update Branch' : 'Create Branch',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.04, end: 0);
  }

  // ─── Manager Dropdown ───

  Widget _buildManagerDropdown(bool isDark) {
    return Consumer(
      builder: (context, ref, _) {
        final managersAsync = ref.watch(potentialManagersProvider);
        return managersAsync.when(
          loading: () => const SizedBox(
              height: 56,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          error: (_, __) => const SizedBox.shrink(),
          data: (managers) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline_rounded,
                          size: 16,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'Assign Branch Manager',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedManagerId,
                  decoration: InputDecoration(
                    hintText: 'No manager assigned',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF1A1F2E).withValues(alpha: 0.6)
                        : const Color(0xFFF1F5F9).withValues(alpha: 0.8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  dropdownColor: isDark
                      ? const Color(0xFF1A1F2E)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  icon: Icon(
                    Icons.expand_more_rounded,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Row(
                        children: [
                          Icon(Icons.person_off_outlined,
                              size: 18, color: Colors.grey),
                          SizedBox(width: 10),
                          Text('No manager assigned',
                              style: TextStyle(fontSize: 14, color: Colors.grey)),
                        ],
                      ),
                    ),
                    ...managers.map((m) => DropdownMenuItem(
                          value: m['id'] as String,
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    (m['full_name'] as String? ?? '?')[0]
                                        .toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(m['full_name'] ?? 'Unknown',
                                  style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedManagerId = v),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── Save ───

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await widget.onSave({
        'name': _nameCtrl.text.trim(),
        'code': _codeCtrl.text.trim().toUpperCase(),
        'address':
            _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        'state':
            _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
        'pincode':
            _pincodeCtrl.text.trim().isEmpty ? null : _pincodeCtrl.text.trim(),
        'phone':
            _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'email':
            _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'manager_id': _selectedManagerId,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('$e')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ─── Premium Form Field ───

class _PremiumField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool isDark;
  final bool required;
  final String? hint;

  const _PremiumField({
    required this.ctrl,
    required this.label,
    required this.icon,
    required this.isDark,
    this.required = false,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        floatingLabelStyle: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(14)),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary.withValues(alpha: 0.7)),
        ),
        filled: true,
        fillColor: isDark
            ? const Color(0xFF1A1F2E).withValues(alpha: 0.6)
            : const Color(0xFFF1F5F9).withValues(alpha: 0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: AppColors.error.withValues(alpha: 0.4), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: AppColors.error.withValues(alpha: 0.6), width: 1.2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.white : const Color(0xFF0F172A),
      ),
      validator: required
          ? (v) => v?.trim().isEmpty == true ? 'Required' : null
          : null,
    );
  }
}

// ─── Section Label ───

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primary, AppColors.accent],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon,
            size: 16,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Branch Detail Sheet
// ═══════════════════════════════════════════════════════════════════════════

class BranchDetailSheet extends ConsumerWidget {
  final BranchModel branch;

  const BranchDetailSheet({super.key, required this.branch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statsAsync = ref.watch(branchStatsProvider(branch.id));
    final isActive = branch.isActive;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0C1018).withValues(alpha: 0.97)
            : const Color(0xFFF8F9FB).withValues(alpha: 0.97),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        children: [
          // ── Drag Handle ──
          Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          const SizedBox(height: 4),

          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              children: [
                // Branch Avatar
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isActive
                          ? [AppColors.primary, AppColors.accent]
                          : [Colors.grey.shade400, Colors.grey.shade600],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: (isActive ? AppColors.primary : Colors.grey)
                            .withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      branch.code
                          .substring(0,
                              branch.code.length > 3 ? 3 : branch.code.length)
                          .toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          letterSpacing: -0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        branch.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 15,
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.5)),
                          const SizedBox(width: 4),
                          Text(
                            branch.city ?? 'No location set',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isActive ? AppColors.success : AppColors.warning)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (isActive ? AppColors.success : AppColors.warning)
                          .withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.success
                              : AppColors.warning,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        branch.status.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isActive
                              ? AppColors.success
                              : AppColors.warning,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Divider(
              color: theme.dividerColor.withValues(alpha: 0.1), height: 1),

          // ── Stats Body ──
          Expanded(
            child: statsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Unable to load stats: $e',
                    style: const TextStyle(color: AppColors.error)),
              ),
              data: (stats) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Stats Grid ──
                    Row(
                      children: [
                        Expanded(
                          child: _DetailStatCard(
                            icon: Icons.people_outline_rounded,
                            label: 'Staff',
                            value: '${stats.totalStaff}',
                            color: AppColors.primary,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DetailStatCard(
                            icon: Icons.person_outline_rounded,
                            label: 'Members',
                            value: '${stats.totalMembers}',
                            color: AppColors.accentLight,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DetailStatCard(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'Total Savings',
                            value:
                                stats.totalSavings.toStringAsFixed(0),
                            color: AppColors.success,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DetailStatCard(
                            icon: Icons.trending_up_rounded,
                            label: 'Active Loans',
                            value:
                                stats.activeLoans.toStringAsFixed(0),
                            color: AppColors.info,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),

                    // ── Branch Details ──
                    if (branch.managerName != null ||
                        branch.address != null ||
                        branch.phone != null ||
                        branch.email != null) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Branch Details',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GlassCard(
                        glassmorphic: true,
                        padding: const EdgeInsets.all(16),
                        borderRadius: 16,
                        child: Column(
                          children: [
                            if (branch.managerName != null)
                              _DetailInfoRow(
                                icon: Icons.person_outline_rounded,
                                label: 'Manager',
                                value: branch.managerName!,
                                color: AppColors.primary,
                                isDark: isDark,
                              ),
                            if (branch.phone != null) ...[
                              const Divider(height: 20),
                              _DetailInfoRow(
                                icon: Icons.phone_rounded,
                                label: 'Phone',
                                value: branch.phone!,
                                color: AppColors.success,
                                isDark: isDark,
                              ),
                            ],
                            if (branch.email != null) ...[
                              const Divider(height: 20),
                              _DetailInfoRow(
                                icon: Icons.email_outlined,
                                label: 'Email',
                                value: branch.email!,
                                color: AppColors.info,
                                isDark: isDark,
                              ),
                            ],
                            if (branch.address != null) ...[
                              const Divider(height: 20),
                              _DetailInfoRow(
                                icon: Icons.location_on_outlined,
                                label: 'Address',
                                value: branch.address!,
                                color: AppColors.warning,
                                isDark: isDark,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // ── Timestamps ──
                    GlassCard(
                      glassmorphic: true,
                      padding: const EdgeInsets.all(16),
                      borderRadius: 16,
                      child: Column(
                        children: [
                          _DetailInfoRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'Created',
                            value: AppFormatters.formatDate(branch.createdAt),
                            color: AppColors.accentLight,
                            isDark: isDark,
                          ),
                          const Divider(height: 20),
                          _DetailInfoRow(
                            icon: Icons.update_rounded,
                            label: 'Last Updated',
                            value: AppFormatters.formatDate(branch.updatedAt),
                            color: AppColors.primary,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ─── Detail Stat Card ───

class _DetailStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _DetailStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: color,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  color: theme.textTheme.bodySmall?.color
                      ?.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Detail Info Row ───

class _DetailInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _DetailInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  color: theme.textTheme.bodySmall?.color
                      ?.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
