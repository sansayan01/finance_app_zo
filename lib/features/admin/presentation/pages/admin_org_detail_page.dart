import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../features/super_admin/data/providers/super_admin_providers.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/utils/error_formatter.dart';
import '../../../../features/settings/data/models/activity_log_model.dart';
import '../../../../features/settings/data/repositories/activity_log_repository.dart';

/// Backward-compat alias — any file still importing adminOrgDetailProvider
/// won't break.  The real data comes from orgDetailFullProvider now.
final adminOrgDetailProvider = orgDetailFullProvider;

final adminOrgListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  final response = await client
      .from('organizations')
      .select('id, name, slug, status, plan, created_at')
      .order('created_at', ascending: false);
  return (response as List).cast<Map<String, dynamic>>();
});

class AdminOrgDetailPage extends ConsumerStatefulWidget {
  final String orgId;
  const AdminOrgDetailPage({super.key, required this.orgId});

  @override
  ConsumerState<AdminOrgDetailPage> createState() => _AdminOrgDetailPageState();
}

class _AdminOrgDetailPageState extends ConsumerState<AdminOrgDetailPage> {
  String _memberSearch = '';
  String _memberRoleFilter = '';

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(orgDetailFullProvider(widget.orgId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0F1115), const Color(0xFF1A1F2E)]
                : [const Color(0xFFF8F9FB), const Color(0xFFEEF2FF)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: detailAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => _buildErrorScreen(e, isDark),
            data: (org) {
              if (org == null) return const Center(child: Text('Organization not found'));
              return _buildPage(context, ref, org, isDark);
            },
          ),
        ),
      ),
    );
  }

  // ── Full Page ──────────────────────────────────────────

  Widget _buildPage(BuildContext context, WidgetRef ref, Map<String, dynamic> org, bool isDark) {
    final profiles = (org['profiles'] as List? ?? []).cast<Map<String, dynamic>>();
    final branches = (org['branches'] as List? ?? []).cast<Map<String, dynamic>>();
    final activityLogs = (org['activity_logs'] as List? ?? []).cast<Map<String, dynamic>>();
    final memberCount = (org['member_count'] as int?) ?? 0;
    final staffCount = profiles.where((p) => p['role'] == 'collectionAgent' || p['role'] == 'manager').length;

    return CustomScrollView(
      slivers: [
        // ── App Bar ──────────────────────────────────────
        SliverToBoxAdapter(child: _buildAppBar(context, isDark)),
        // ── Status + Plan Bar ────────────────────────────
        SliverToBoxAdapter(child: _buildStatusPlanBar(context, ref, org, isDark)),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        // ── Metrics Grid ─────────────────────────────────
        SliverToBoxAdapter(child: _buildMetricsGrid(org, profiles, branches, memberCount, staffCount, isDark)),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        // ── Plan Limits ──────────────────────────────────
        SliverToBoxAdapter(child: _buildPlanLimits(org, isDark)),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        // ── Members Section ──────────────────────────────
        SliverToBoxAdapter(child: _buildMembersHeader(org, isDark)),
        SliverToBoxAdapter(
          child: _buildMembersFilters(isDark),
        ),
        _buildMembersList(profiles, isDark),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        // ── Branches Section ─────────────────────────────
        SliverToBoxAdapter(child: _buildBranchesSection(branches, isDark)),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        // ── Activity Feed ────────────────────────────────
        SliverToBoxAdapter(child: _buildActivityFeed(activityLogs, isDark)),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        // ── Danger Zone ──────────────────────────────────
        SliverToBoxAdapter(child: _buildDangerZone(context, ref, org['id'], isDark)),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  // ── App Bar ──────────────────────────────────────────

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: isDark ? Colors.white : const Color(0xFF0F172A)),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text('Organization',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }

  // ── Status + Plan Bar ─────────────────────────────────

  Widget _buildStatusPlanBar(
      BuildContext context, WidgetRef ref, Map<String, dynamic> org, bool isDark) {
    final status = org['status'] as String? ?? 'unknown';
    final plan = org['plan'] as String? ?? 'free';
    final name = org['name'] as String? ?? '';
    final displayName = org['display_name'] as String? ?? name;
    final slug = org['slug'] as String? ?? '';
    final created = org['created_at'] as String? ?? '';
    final dateStr = created.length >= 10 ? created.substring(0, 10) : '';
    final statusColor = _statusColor(status);
    final planColor = _planColor(plan);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A1F2E).withValues(alpha: 0.9), const Color(0xFF222731).withValues(alpha: 0.6)]
              : [Colors.white.withValues(alpha: 0.9), Colors.white.withValues(alpha: 0.6)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          // Org icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary, AppColors.accent]),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6))
              ],
            ),
            child: const Icon(Icons.business_rounded, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 16),
          // Name
          Text(displayName,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : const Color(0xFF0F172A))),
          const SizedBox(height: 8),
          // Status + Plan badges
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _badge(statusColor, status[0].toUpperCase() + status.substring(1), isDark),
              const SizedBox(width: 8),
              _badge(planColor, plan.toUpperCase(), isDark),
            ],
          ),
          const SizedBox(height: 12),
          Text('$slug  •  Created $dateStr',
              style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _badge(Color color, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.3)),
        ],
      ),
    );
  }

  // ── Metrics Grid ──────────────────────────────────────

  Widget _buildMetricsGrid(
      Map<String, dynamic> org,
      List<Map<String, dynamic>> profiles,
      List<Map<String, dynamic>> branches,
      int memberCount,
      int staffCount,
      bool isDark) {
    final totalBranches = branches.length;
    final activeBranches = branches.where((b) => b['status'] == 'active').length;
    final activeStaff = staffCount;

    final metrics = [
      (Icons.people_rounded, '$memberCount', 'Members', AppColors.primary),
      (Icons.groups_rounded, '$activeStaff', 'Staff', AppColors.success),
      (Icons.account_balance_rounded, '$totalBranches', 'Branches', AppColors.accent),
      (Icons.check_circle_rounded, '$activeBranches', 'Active Branches', AppColors.success),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.8,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: metrics.length,
        itemBuilder: (context, i) {
          final (icon, value, label, color) = metrics[i];
          return _metricTile(icon, value, label, color, isDark);
        },
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _metricTile(IconData icon, String value, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2E).withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A))),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Plan Limits ───────────────────────────────────────

  Widget _buildPlanLimits(Map<String, dynamic> org, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1F2E).withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed_rounded, size: 18, color: AppColors.accent),
                const SizedBox(width: 8),
                Text('Plan Limits',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A))),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _limitChip(Icons.business_rounded, 'Branches',
                    '${org['max_branches'] ?? 5}', AppColors.primary, isDark)),
                const SizedBox(width: 12),
                Expanded(child: _limitChip(Icons.groups_rounded, 'Staff',
                    '${org['max_staff'] ?? 20}', AppColors.success, isDark)),
                const SizedBox(width: 12),
                Expanded(child: _limitChip(Icons.person_rounded, 'Members',
                    '${org['max_members'] ?? 500}', AppColors.warning, isDark)),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 150.ms);
  }

  Widget _limitChip(IconData icon, String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A))),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
        ],
      ),
    );
  }

  // ── Members Section ───────────────────────────────────

  Widget _buildMembersHeader(Map<String, dynamic> org, bool isDark) {
    final profiles = (org['profiles'] as List? ?? []).cast<Map<String, dynamic>>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.people_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('Members (${profiles.length})',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A))),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildMembersFilters(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          // Search
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1A1F2E).withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.3)),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _memberSearch = v),
              style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Search members...',
                hintStyle: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                prefixIcon: Icon(Icons.search_rounded,
                    size: 20,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Role filter chips
          Row(
            children: [
              _roleChip('', 'All'),
              _roleChip('executiveAdmin', 'Admin'),
              _roleChip('manager', 'Manager'),
              _roleChip('collectionAgent', 'Agent'),
              _roleChip('customer', 'Customer'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roleChip(String role, String label) {
    final isActive = _memberRoleFilter == role;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () {
          HapticService.selection();
          setState(() => _memberRoleFilter = role);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppColors.primary : Colors.grey.shade500)),
        ),
      ),
    );
  }

  Widget _buildMembersList(List<Map<String, dynamic>> profiles, bool isDark) {
    var filtered = profiles;
    if (_memberSearch.isNotEmpty) {
      final q = _memberSearch.toLowerCase();
      filtered = filtered.where((p) {
        final name = (p['full_name'] as String? ?? '').toLowerCase();
        final email = (p['email'] as String? ?? '').toLowerCase();
        return name.contains(q) || email.contains(q);
      }).toList();
    }
    if (_memberRoleFilter.isNotEmpty) {
      filtered = filtered.where((p) => p['role'] == _memberRoleFilter).toList();
    }

    if (filtered.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) => _memberTile(filtered[i], i, isDark),
        childCount: filtered.length,
      ),
    );
  }

  Widget _memberTile(Map<String, dynamic> profile, int index, bool isDark) {
    final name = profile['full_name'] as String? ?? 'Unknown';
    final email = profile['email'] as String? ?? '';
    final role = profile['role'] as String? ?? '';
    final roleColor = _roleColor(role);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: GestureDetector(
        onTap: () {
          final userId = profile['user_id'] as String? ?? profile['id'] as String? ?? '';
          if (userId.isNotEmpty) context.push('/super-admin/organizations/${widget.orgId}/settings');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1A1F2E).withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: roleColor.withValues(alpha: 0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(color: roleColor, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              // Name + email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    if (email.isNotEmpty)
                      Text(email,
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
                  ],
                ),
              ),
              // Role badge
              _badge(roleColor, _roleLabel(role), isDark),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: (50 + 30 * index).ms);
  }

  // ── Branches Section ──────────────────────────────────

  Widget _buildBranchesSection(List<Map<String, dynamic>> branches, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_rounded, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text('Branches (${branches.length})',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 12),
          if (branches.isEmpty)
            _emptyCard('No branches yet', isDark)
          else
            ...branches.asMap().entries.map((entry) {
              final branch = entry.value;
              final name = branch['name'] as String? ?? '';
              final code = branch['code'] as String? ?? '';
              final status = branch['status'] as String? ?? 'active';
              final statusColor = status == 'active' ? AppColors.success : AppColors.warning;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A1F2E).withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.location_on_rounded, size: 18, color: AppColors.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A))),
                          if (code.isNotEmpty)
                            Text(code,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    _badge(statusColor, status[0].toUpperCase() + status.substring(1), isDark),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms, delay: (100 + 50 * entry.key).ms);
            }),
        ],
      ),
    );
  }

  // ── Activity Feed ─────────────────────────────────────

  Widget _buildActivityFeed(List<Map<String, dynamic>> logs, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 18, color: AppColors.success),
              const SizedBox(width: 8),
              Text('Recent Activity',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 12),
          if (logs.isEmpty)
            _emptyCard('No activity yet', isDark)
          else
            ...logs.take(10).toList().asMap().entries.map((entry) {
              final log = entry.value;
              final action = log['action'] as String? ?? '';
              final details = log['details'] as String? ?? '';
              final userName = log['user_name'] as String? ?? 'System';
              final createdAt = log['created_at'] as String? ?? '';
              final dateStr = createdAt.length >= 16
                  ? createdAt.substring(0, 16).replaceFirst('T', ' ')
                  : createdAt;
              final type = log['type'] as String? ?? '';
              final icon = _activityIcon(type);
              final iconColor = _activityColor(type);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A1F2E).withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 16, color: iconColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(action,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A))),
                          if (details.isNotEmpty)
                            Text(details,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text('$userName • $dateStr',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }

  // ── Danger Zone ───────────────────────────────────────

  Widget _buildDangerZone(BuildContext context, WidgetRef ref, String id, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: isDark ? 0.06 : 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.error),
                const SizedBox(width: 8),
                Text('Danger Zone',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.error)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _suspendOrg(context, ref, id),
                icon: const Icon(Icons.pause_rounded, size: 18),
                label: const Text('Suspend Organization'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  side: BorderSide(color: AppColors.warning.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _deleteOrg(context, ref, id),
                icon: const Icon(Icons.delete_rounded, size: 18),
                label: const Text('Delete Organization'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
    );
  }

  // ── Helpers ───────────────────────────────────────────

  Widget _emptyCard(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2E).withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
      ),
    );
  }

  Widget _buildErrorScreen(Object e, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text('Failed to load organization',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A))),
            const SizedBox(height: 8),
            Text('$e',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) => switch (status) {
    'active' => AppColors.success,
    'trial' => AppColors.warning,
    'suspended' => AppColors.error,
    _ => Colors.grey,
  };

  Color _planColor(String plan) => switch (plan) {
    'enterprise' => AppColors.primary,
    'pro' => AppColors.accent,
    'basic' => AppColors.success,
    _ => Colors.grey,
  };

  Color _roleColor(String role) => switch (role) {
    'superAdmin' => const Color(0xFFEF4444),
    'executiveAdmin' => AppColors.primary,
    'manager' => AppColors.accent,
    'collectionAgent' => AppColors.success,
    'customer' => Colors.grey,
    _ => Colors.grey,
  };

  String _roleLabel(String role) => switch (role) {
    'superAdmin' => 'Super Admin',
    'executiveAdmin' => 'Admin',
    'manager' => 'Manager',
    'collectionAgent' => 'Agent',
    'customer' => 'Customer',
    _ => role,
  };

  IconData _activityIcon(String type) => switch (type) {
    'auth' => Icons.login_rounded,
    'loan' => Icons.account_balance_rounded,
    'payment' => Icons.payments_rounded,
    'savings' => Icons.savings_rounded,
    'member' => Icons.person_add_rounded,
    _ => Icons.circle,
  };

  Color _activityColor(String type) => switch (type) {
    'auth' => AppColors.primary,
    'loan' => AppColors.accent,
    'payment' => AppColors.success,
    'savings' => AppColors.warning,
    'member' => AppColors.primary,
    _ => Colors.grey,
  };

  // ── Actions ───────────────────────────────────────────

  Future<void> _suspendOrg(BuildContext context, WidgetRef ref, String id) async {
    final reason = await _showReasonDialog(
      context,
      title: 'Suspend Organization',
      description: 'Suspended organizations will immediately lose access. All members will be signed out.',
      actionLabel: 'Suspend',
      actionColor: AppColors.warning,
    );
    if (reason == null) return;

    try {
      final client = Supabase.instance.client;
      await client.rpc('suspend_organization', params: {
        'p_org_id': id,
        'p_reason': reason,
      });
      ref.invalidate(orgDetailFullProvider(id));
      ref.invalidate(adminOrgListProvider);
      try {
        await ActivityLogRepository(client).log(
          action: 'Organization Suspended',
          details: 'Suspended org $id. Reason: $reason',
          type: ActivityType.securityAlert,
        );
      } catch (_) {}
      if (context.mounted) showSuccessSnackBar(context, 'Organization suspended');
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e, fallback: 'Failed to suspend organization');
    }
  }

  Future<void> _deleteOrg(BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Organization?'),
        content: const Text(
            'This will soft-delete the organization, sign out all members, '
            'and free the slug for re-use after 30 days.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final reason = await _showReasonDialog(
      context,
      title: 'Reason for deletion',
      description: 'Required for audit. Record kept for 30 days.',
      actionLabel: 'Delete',
      actionColor: AppColors.error,
    );
    if (reason == null) return;

    try {
      final client = Supabase.instance.client;
      await client.rpc('soft_delete_organization', params: {
        'p_org_id': id,
        'p_reason': reason,
      });
      ref.invalidate(orgDetailFullProvider(id));
      ref.invalidate(adminOrgListProvider);
      try {
        await ActivityLogRepository(client).log(
          action: 'Organization Deleted',
          details: 'Soft-deleted org $id. Reason: $reason',
          type: ActivityType.securityAlert,
        );
      } catch (_) {}
      if (context.mounted) {
        showSuccessSnackBar(context, 'Organization deleted. Members have been signed out.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e, fallback: 'Failed to delete organization');
    }
  }

  Future<String?> _showReasonDialog(
    BuildContext context, {
    required String title,
    required String description,
    required String actionLabel,
    required Color actionColor,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description,
                style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.7))),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Required for audit log',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop<String?>(ctx, null),
              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600))),
          TextButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                Navigator.pop<String?>(ctx, text);
              },
              child: Text(actionLabel,
                  style: TextStyle(color: actionColor, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}
