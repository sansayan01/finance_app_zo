import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/providers/org_provider.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../branches/presentation/pages/branch_management_page.dart';

final adminMyOrgProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  final orgId = ref.read(currentOrgIdOrThrowProvider);

  // Fetch org data with error handling
  Map<String, dynamic> org;
  try {
    org = await client.from('organizations').select().eq('id', orgId).single();
  } catch (e) {
    throw Exception('Failed to load organization data: $e');
  }

  // Fetch related data with individual error handling
  int staffCount = 0;
  int memberCount = 0;
  int totalLoans = 0;
  int activeLoansCount = 0;
  double totalDisbursed = 0;
  double totalOutstanding = 0;
  List<Map<String, dynamic>> recentCollections = [];
  List<Map<String, dynamic>> staffList = [];

  try {
    final staffData =
        await client.from('staff_profiles').select('id').eq('org_id', orgId);
    staffCount = staffData.length;
  } catch (_) {}

  try {
    final memberData =
        await client.from('members').select('id').eq('org_id', orgId);
    memberCount = memberData.length;
  } catch (_) {}

  try {
    final loansData = await client
        .from('loans')
        .select('status, amount, outstanding_amount')
        .eq('org_id', orgId);
    final activeLoans =
        (loansData as List).where((l) => l['status'] == 'active').toList();
    totalLoans = loansData.length;
    activeLoansCount = activeLoans.length;
    totalDisbursed = loansData.fold<double>(
        0, (s, l) => s + ((l['amount'] as num?)?.toDouble() ?? 0));
    totalOutstanding = activeLoans.fold<double>(
        0, (s, l) => s + ((l['outstanding_amount'] as num?)?.toDouble() ?? 0));
  } catch (_) {}

  try {
    final collectionsData = await client
        .from('collections')
        .select(
            'amount_collected, payment_mode, collection_date, member_name, created_at')
        .eq('org_id', orgId)
        .order('created_at', ascending: false)
        .limit(5);
    recentCollections = List<Map<String, dynamic>>.from(collectionsData);
  } catch (_) {}

  try {
    final staffData = await client
        .from('staff_profiles')
        .select('id, full_name, role, status, branch_id')
        .eq('org_id', orgId)
        .limit(10);
    staffList = List<Map<String, dynamic>>.from(staffData);
  } catch (_) {}

  return {
    'org': org,
    'staff_count': staffCount,
    'member_count': memberCount,
    'total_loans': totalLoans,
    'active_loans': activeLoansCount,
    'total_disbursed': totalDisbursed,
    'total_outstanding': totalOutstanding,
    'recent_collections': recentCollections,
    'staff': staffList,
  };
});
class AdminOrgDashboardPage extends ConsumerWidget {
  const AdminOrgDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(adminMyOrgProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
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
          child: dataAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (data) => RefreshIndicator(
              onRefresh: () async => ref.invalidate(adminMyOrgProvider),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                children: [
                  _buildTopBar(context, ref, isDark),
                  const SizedBox(height: 12),
                  _buildOrgHeader(context, data['org'], isDark),
                  const SizedBox(height: 24),
                  _buildStatsGrid(data, isDark),
                  const SizedBox(height: 24),
                  _buildQuickActions(context, isDark),
                  const SizedBox(height: 24),
                  _buildStaffSnapshot(context, data['staff'], isDark),
                  const SizedBox(height: 24),
                  _buildRecentActivity(data['recent_collections'], isDark),
                  const SizedBox(height: 24),
                  _buildOrgSettingsCard(context, data['org'], isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, WidgetRef ref, bool isDark) {
    final authNotifier = ref.read(authProvider.notifier);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.2)),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
        GestureDetector(
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Sign Out'),
                content: const Text('Are you sure you want to sign out?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Sign Out',
                        style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await authNotifier.signOut();
              if (context.mounted) context.go('/auth');
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.logout_rounded, size: 16, color: AppColors.error),
                const SizedBox(width: 4),
                Text('Sign Out',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrgHeader(
      BuildContext context, Map<String, dynamic>? org, bool isDark) {
    final name = org?['name'] as String? ?? 'My Organization';
    final status = org?['status'] as String? ?? 'active';
    final isActive = status == 'active';
    final slug = org?['slug'] as String? ?? '';
    final plan = org?['plan'] as String? ?? 'Professional';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF1A1F2E).withValues(alpha: 0.9),
                  const Color(0xFF222731).withValues(alpha: 0.6)
                ]
              : [
                  Colors.white.withValues(alpha: 0.9),
                  Colors.white.withValues(alpha: 0.6)
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
            ),
            child: const Icon(Icons.business_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(name,
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A)))),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.success.withValues(alpha: 0.12)
                            : AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: (isActive
                                    ? AppColors.success
                                    : AppColors.warning)
                                .withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isActive
                                      ? AppColors.success
                                      : AppColors.warning)),
                          const SizedBox(width: 4),
                          Text(isActive ? 'Active' : 'Suspended',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isActive
                                      ? AppColors.success
                                      : AppColors.warning)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('$slug  •  $plan Plan',
                    style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildStatsGrid(Map<String, dynamic> data, bool isDark) {
    final stats = [
      _OrgStat(Icons.people_rounded, 'Members', '${data['member_count'] ?? 0}',
          AppColors.primary),
      _OrgStat(Icons.badge_rounded, 'Staff', '${data['staff_count'] ?? 0}',
          AppColors.success),
      _OrgStat(Icons.account_balance_rounded, 'Active Loans',
          '${data['active_loans'] ?? 0}', AppColors.warning),
      _OrgStat(Icons.monetization_on_rounded, 'Disbursed',
          '₹${_formatAmount(data['total_disbursed'] ?? 0)}', AppColors.cyan),
      _OrgStat(Icons.payments_rounded, 'Outstanding',
          '₹${_formatAmount(data['total_outstanding'] ?? 0)}', AppColors.pink),
      _OrgStat(Icons.trending_up_rounded, 'Total Loans',
          '${data['total_loans'] ?? 0}', AppColors.accent),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 14),
          child: Row(
            children: [
              Icon(Icons.analytics_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Overview',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A))),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.9,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: stats.length,
          itemBuilder: (ctx, i) =>
              _StatTile(data: stats[i], isDark: isDark, index: i),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isDark) {
    final actions = [
      _QuickAction(Icons.payments_rounded, 'Collect Payment', AppColors.cyan,
          () => context.push('/staff/collections')),
      _QuickAction(Icons.person_add_rounded, 'Add Staff', AppColors.primary,
          () => context.go('/users/new')),
      _QuickAction(Icons.person_add_rounded, 'New Member', AppColors.success,
          () => context.go('/members/onboarding')),
      _QuickAction(Icons.add_circle_rounded, 'New Loan', AppColors.warning,
          () => context.go('/loans/new')),
      _QuickAction(Icons.savings_rounded, 'New Savings', AppColors.pink,
          () => context.go('/savings/new')),
      _QuickAction(
          Icons.business_rounded,
          'Branches',
          AppColors.orange,
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const BranchManagementPage()))),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 14),
          child: Row(
            children: [
              Icon(Icons.flash_on_rounded, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text('Quick Actions',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A))),
            ],
          ),
        ),
        Column(
          children: [
            Row(
              children: actions.take(4).toList().asMap().entries.map((e) {
                final i = e.key;
                final a = e.value;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                    child: _ActionTile(action: a, isDark: isDark),
                  ),
                );
              }).toList(),
            ),
            if (actions.length > 4)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: actions.skip(4).toList().asMap().entries.map((e) {
                    final i = e.key;
                    final a = e.value;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                        child: _ActionTile(action: a, isDark: isDark),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStaffSnapshot(
      BuildContext context, List<dynamic> staff, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1F2E).withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.badge_rounded, size: 18, color: AppColors.success),
                  const SizedBox(width: 8),
                  Text('Staff (${staff.length})',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A))),
                ],
              ),
              GestureDetector(
                onTap: () => context.go('/users'),
                child: Text('View All',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (staff.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: Text('No staff members yet',
                      style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600))),
            )
          else
            ...staff.take(5).map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            AppColors.primary.withValues(alpha: 0.2),
                            AppColors.accent.withValues(alpha: 0.1)
                          ]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                            child: Text(
                          (s['full_name'] as String? ?? '?')[0].toUpperCase(),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary),
                        )),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s['full_name'] as String? ?? '',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A))),
                            Text(s['role'] as String? ?? '',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: s['status'] == 'active'
                              ? AppColors.success.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(s['status'] as String? ?? '',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: s['status'] == 'active'
                                    ? AppColors.success
                                    : Colors.grey)),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildRecentActivity(List<dynamic> collections, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1F2E).withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              Text('Recent Collections',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 16),
          if (collections.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: Text('No collections yet',
                      style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600))),
            )
          else
            ...collections.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.payments_rounded,
                            color: AppColors.success, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c['member_name'] as String? ?? 'Unknown',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A))),
                            Text(
                                '₹${_formatAmount(c['amount_collected'])} • ${c['payment_mode'] ?? 'cash'}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      Text(
                          AppFormatters.parseIsoDateShort(
                              c['collection_date']?.toString()),
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade500)),
                    ],
                  ),
                )),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }

  Widget _buildOrgSettingsCard(
      BuildContext context, Map<String, dynamic>? org, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.06 : 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Organization Settings',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 16),
          _settingRow('Plan', org?['plan'] as String? ?? 'Professional',
              Icons.workspace_premium_rounded, isDark),
          _settingRow('Max Branches', '${org?['max_branches'] ?? 5}',
              Icons.business_rounded, isDark),
          _settingRow('Max Staff', '${org?['max_staff'] ?? 20}',
              Icons.people_rounded, isDark),
          _settingRow('Max Members', '${org?['max_members'] ?? 500}',
              Icons.person_rounded, isDark),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/admin/org/settings'),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Edit Organization Settings'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side:
                    BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 400.ms);
  }

  Widget _settingRow(String label, String value, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
          const SizedBox(width: 12),
          SizedBox(
              width: 120,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600))),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A)))),
        ],
      ),
    );
  }

  String _formatAmount(dynamic val) {
    final n = (val is num) ? val.toDouble() : 0.0;
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }
}

class _OrgStat {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  _OrgStat(this.icon, this.label, this.value, this.color);
}

class _StatTile extends StatelessWidget {
  final _OrgStat data;
  final bool isDark;
  final int index;
  const _StatTile(
      {required this.data, required this.isDark, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1F2E).withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(data.icon, color: data.color, size: 17),
          ),
          const SizedBox(height: 8),
          Text(data.value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(data.label,
              style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: (100 + 80 * index).ms)
        .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  _QuickAction(this.icon, this.label, this.color, this.onTap);
}

class _ActionTile extends StatelessWidget {
  final _QuickAction action;
  final bool isDark;
  const _ActionTile({required this.action, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1A1F2E).withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(action.icon, color: action.color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(action.label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color:
                        isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}
