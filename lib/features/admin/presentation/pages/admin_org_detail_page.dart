import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../features/super_admin/data/providers/super_admin_providers.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/utils/error_formatter.dart';
import '../../../../features/settings/data/models/activity_log_model.dart';
import '../../../../features/settings/data/repositories/activity_log_repository.dart';

/// Legacy alias — any file importing adminOrgDetailProvider won't break.
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

class _AdminOrgDetailPageState extends ConsumerState<AdminOrgDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String _memberSearch = '';
  String _memberRoleFilter = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(orgDetailFullProvider(widget.orgId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        child: detailAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => _errorScreen(e, isDark),
          data: (org) {
            if (org == null) return const Center(child: Text('Not found'));
            return _page(context, ref, org, isDark);
          },
        ),
      ),
    );
  }

  // ── Page ────────────────────────────────────────────

  Widget _page(BuildContext context, WidgetRef ref,
      Map<String, dynamic> org, bool isDark) {
    final profiles =
        (org['profiles'] as List? ?? []).cast<Map<String, dynamic>>();
    final branches =
        (org['branches'] as List? ?? []).cast<Map<String, dynamic>>();
    final activityLogs =
        (org['activity_logs'] as List? ?? []).cast<Map<String, dynamic>>();
    final memberCount = (org['member_count'] as int?) ?? 0;
    final staffCount = profiles
        .where((p) =>
            p['role'] == 'collectionAgent' || p['role'] == 'manager')
        .length;

    return Column(
      children: [
        // ── Header ─────────────────────────────────────
        _header(context, org, isDark),
        // ── Quick Stats ────────────────────────────────
        _quickStats(org, profiles, branches, memberCount, staffCount, isDark),
        const SizedBox(height: 4),
        // ── Tab Bar ────────────────────────────────────
        _tabBar(isDark),
        // ── Tab Content ────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _membersTab(profiles, isDark),
              _branchesTab(branches, isDark),
              _activityTab(activityLogs, isDark),
            ],
          ),
        ),
      ],
    );
  }

  // ── Header ──────────────────────────────────────────

  Widget _header(
      BuildContext context, Map<String, dynamic> org, bool isDark) {
    final status = org['status'] as String? ?? 'unknown';
    final plan = org['plan'] as String? ?? 'free';
    final name = org['name'] as String? ?? '';
    final created = org['created_at'] as String? ?? '';
    final dateStr = created.length >= 10 ? created.substring(0, 10) : '';

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: isDark ? Colors.white : const Color(0xFF0F172A)),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A))),
                  Text('$plan  •  $status  •  $dateStr',
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600)),
                ],
              ),
            ),
            // Inline status actions
            _headerAction(
                Icons.pause_circle_outline_rounded,
                'Suspend',
                AppColors.warning,
                () => _suspendOrg(context, ref, org['id']),
                isDark),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _headerAction(IconData icon, String label, Color color,
      VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }

  // ── Quick Stats ─────────────────────────────────────

  Widget _quickStats(
      Map<String, dynamic> org,
      List<Map<String, dynamic>> profiles,
      List<Map<String, dynamic>> branches,
      int memberCount,
      int staffCount,
      bool isDark) {
    final activeBranches = branches.where((b) => b['status'] == 'active').length;
    final items = [
      (Icons.people_rounded, '$memberCount', 'Members', AppColors.primary),
      (Icons.groups_rounded, '$staffCount', 'Staff', AppColors.success),
      (Icons.account_balance_rounded,
          '${branches.length}', 'Branches', AppColors.accent),
      (Icons.check_circle_rounded,
          '$activeBranches', 'Active', AppColors.success),
    ];
    return SizedBox(
      height: 76,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final (icon, value, label, color) = items[i];
          return Container(
            width: MediaQuery.of(context).size.width * 0.21,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1A1F2E).withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF0F172A))),
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey.shade600)),
              ],
            ),
          );
        },
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  // ── Tab Bar ─────────────────────────────────────────

  Widget _tabBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1F2E).withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.3)),
      ),
      child: TabBar(
        controller: _tab,
        indicator: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.primary,
        unselectedLabelColor: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(text: 'Members'),
          Tab(text: 'Branches'),
          Tab(text: 'Activity'),
        ],
      ),
    );
  }

  // ── Members Tab ─────────────────────────────────────

  Widget _membersTab(
      List<Map<String, dynamic>> profiles, bool isDark) {
    var filtered = profiles;
    if (_memberSearch.isNotEmpty) {
      final q = _memberSearch.toLowerCase();
      filtered = filtered
          .where((p) =>
              (p['full_name'] as String? ?? '').toLowerCase().contains(q) ||
              (p['email'] as String? ?? '').toLowerCase().contains(q))
          .toList();
    }
    if (_memberRoleFilter.isNotEmpty) {
      filtered = filtered
          .where((p) => p['role'] == _memberRoleFilter)
          .toList();
    }

    return Column(
      children: [
        // Search + filters
        Padding(
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
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.white.withValues(alpha: 0.3)),
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
                        color:
                            isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 20,
                        color:
                            isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Role chips
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _roleChip('', 'All'),
                    _roleChip('executiveAdmin', 'Admin'),
                    _roleChip('manager', 'Manager'),
                    _roleChip('collectionAgent', 'Agent'),
                    _roleChip('customer', 'Customer'),
                  ],
                ),
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: filtered.isEmpty
              ? _empty('No members match', isDark)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _memberTile(filtered[i], i, isDark),
                ),
        ),
      ],
    );
  }

  Widget _roleChip(String role, String label) {
    final active = _memberRoleFilter == role;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () {
          HapticService.selection();
          setState(() => _memberRoleFilter = role);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: active ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.primary : Colors.grey.shade500)),
        ),
      ),
    );
  }

  Widget _memberTile(Map<String, dynamic> p, int i, bool isDark) {
    final name = p['full_name'] as String? ?? 'Unknown';
    final email = p['email'] as String? ?? '';
    final role = p['role'] as String? ?? '';
    final rc = _roleColor(role);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1F2E).withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: rc.withValues(alpha: 0.15),
            child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                    color: rc, fontWeight: FontWeight.w700, fontSize: 14)),
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
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF0F172A))),
                if (email.isNotEmpty)
                  Text(email,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600)),
              ],
            ),
          ),
          _pill(rc, _roleLabel(role), isDark),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms, delay: (30 * i).ms);
  }

  // ── Branches Tab ────────────────────────────────────

  Widget _branchesTab(
      List<Map<String, dynamic>> branches, bool isDark) {
    if (branches.isEmpty) return _empty('No branches yet', isDark);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      itemCount: branches.length,
      itemBuilder: (ctx, i) {
        final b = branches[i];
        final name = b['name'] as String? ?? '';
        final code = b['code'] as String? ?? '';
        final status = b['status'] as String? ?? 'active';
        final sc = status == 'active' ? AppColors.success : AppColors.warning;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1A1F2E).withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.3)),
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
                child: const Icon(Icons.location_on_rounded,
                    size: 18, color: AppColors.accent),
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
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A))),
                    if (code.isNotEmpty)
                      Text(code,
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600)),
                  ],
                ),
              ),
              _pill(sc, status[0].toUpperCase() + status.substring(1), isDark),
            ],
          ),
        ).animate().fadeIn(duration: 250.ms, delay: (50 * i).ms);
      },
    );
  }

  // ── Activity Tab ────────────────────────────────────

  Widget _activityTab(
      List<Map<String, dynamic>> logs, bool isDark) {
    if (logs.isEmpty) return _empty('No activity yet', isDark);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      itemCount: logs.length,
      itemBuilder: (ctx, i) {
        final log = logs[i];
        final action = log['action'] as String? ?? '';
        final details = log['details'] as String? ?? '';
        final user = log['user_name'] as String? ?? 'System';
        final createdAt = log['created_at'] as String? ?? '';
        final dateStr =
            createdAt.length >= 16 ? createdAt.substring(0, 16).replaceFirst('T', ' ') : createdAt;
        final type = log['type'] as String? ?? '';
        final icon = _actIcon(type);
        final iconColor = _actColor(type);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1A1F2E).withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.3)),
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
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A))),
                    if (details.isNotEmpty)
                      Text(details,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600)),
                    const SizedBox(height: 3),
                    Text('$user • $dateStr',
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.grey.shade600
                                : Colors.grey.shade500)),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 250.ms, delay: (40 * i).ms);
      },
    );
  }

  // ── Shared helpers ──────────────────────────────────

  Widget _pill(Color color, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }

  Widget _empty(String label, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
      ),
    );
  }

  Widget _errorScreen(Object e, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.error.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text('Failed to load',
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

  Color _roleColor(String r) => switch (r) {
        'superAdmin' => const Color(0xFFEF4444),
        'executiveAdmin' => AppColors.primary,
        'manager' => AppColors.accent,
        'collectionAgent' => AppColors.success,
        'customer' => Colors.grey,
        _ => Colors.grey,
      };
  String _roleLabel(String r) => switch (r) {
        'superAdmin' => 'Super Admin',
        'executiveAdmin' => 'Admin',
        'manager' => 'Manager',
        'collectionAgent' => 'Agent',
        'customer' => 'Customer',
        _ => r,
      };
  IconData _actIcon(String t) => switch (t) {
        'auth' => Icons.login_rounded,
        'loan' => Icons.account_balance_rounded,
        'payment' => Icons.payments_rounded,
        'savings' => Icons.savings_rounded,
        'member' => Icons.person_add_rounded,
        _ => Icons.circle,
      };
  Color _actColor(String t) => switch (t) {
        'auth' => AppColors.primary,
        'loan' => AppColors.accent,
        'payment' => AppColors.success,
        'savings' => AppColors.warning,
        'member' => AppColors.primary,
        _ => Colors.grey,
      };

  // ── Actions ─────────────────────────────────────────

  Future<void> _suspendOrg(
      BuildContext context, WidgetRef ref, String id) async {
    final reason = await _reasonDialog(
      context,
      title: 'Suspend Organization',
      description:
          'All members will immediately lose access and be signed out.',
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
      if (context.mounted) {
        showSuccessSnackBar(context, 'Organization suspended');
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, e, fallback: 'Failed to suspend');
      }
    }
  }

  Future<String?> _reasonDialog(
    BuildContext context, {
    required String title,
    required String description,
    required String actionLabel,
    required Color actionColor,
  }) async {
    final ctrl = TextEditingController();
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
                style: TextStyle(
                    color: Theme.of(ctx)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7))),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
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
              child: const Text('Cancel',
                  style: TextStyle(fontWeight: FontWeight.w600))),
          TextButton(
              onPressed: () {
                final t = ctrl.text.trim();
                if (t.isEmpty) return;
                Navigator.pop<String?>(ctx, t);
              },
              child: Text(actionLabel,
                  style: TextStyle(
                      color: actionColor, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }
}
