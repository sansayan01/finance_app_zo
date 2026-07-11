import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../features/super_admin/data/models/super_admin_models.dart';
import '../../../../features/super_admin/data/providers/super_admin_providers.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/utils/error_formatter.dart';

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

// =====================================================
// ORGANIZATION DETAIL PAGE
// =====================================================

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
          data: (data) {
            if (data == null) return const Center(child: Text('Organization not found'));
            return _page(context, ref, data, isDark);
          },
        ),
      ),
    );
  }

  // ── Main Page ──────────────────────────────────────

  Widget _page(BuildContext context, WidgetRef ref, OrgDetailData data, bool isDark) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _heroHeader(data, isDark)),
        SliverToBoxAdapter(child: _quickActions(context, ref, data, isDark)),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverToBoxAdapter(child: _metricsOverview(data, isDark)),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverToBoxAdapter(child: _contactCard(data, isDark)),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverToBoxAdapter(child: _planLimits(data, isDark)),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverToBoxAdapter(child: _teamMembersHeader(data, isDark)),
        SliverToBoxAdapter(child: _teamMembersSearch(isDark)),
        _teamMembersList(data, isDark),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverToBoxAdapter(child: _branchesSection(data, isDark)),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverToBoxAdapter(child: _activitySection(data, isDark)),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverToBoxAdapter(child: _dangerZone(context, ref, data, isDark)),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  // ── 1. Hero Header ─────────────────────────────────

  Widget _heroHeader(OrgDetailData data, bool isDark) {
    final initial = data.displayName.isNotEmpty ? data.displayName[0].toUpperCase() : '?';
    final created = data.createdAt;
    final dateStr = created != null ? '${created.day} ${_month(created.month)} ${created.year}' : '';

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20,
                  color: isDark ? Colors.white : const Color(0xFF0F172A)),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 4),
            // Org initial/avatar
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Center(
                child: Text(initial, style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.displayName, style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Row(children: [
                    _pill(_statusColor(data.status), data.status[0].toUpperCase() + data.status.substring(1), isDark),
                    const SizedBox(width: 6),
                    _pill(_planColor(data.plan), data.plan.toUpperCase(), isDark),
                    if (dateStr.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(dateStr, style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
                    ],
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  // ── 2. Quick Actions ───────────────────────────────

  Widget _quickActions(BuildContext context, WidgetRef ref, OrgDetailData data, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          // Status toggle
          Expanded(
            child: GestureDetector(
              onTap: () => _showStatusDialog(context, ref, data),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _statusColor(data.status).withValues(alpha: isDark ? 0.12 : 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _statusColor(data.status).withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_statusIcon(data.status), size: 16, color: _statusColor(data.status)),
                    const SizedBox(width: 6),
                    Text(_statusLabel(data.status),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: _statusColor(data.status))),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Plan selector
          Expanded(
            child: GestureDetector(
              onTap: () => _showPlanDialog(context, ref, data),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _planColor(data.plan).withValues(alpha: isDark ? 0.12 : 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _planColor(data.plan).withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.workspace_premium_rounded, size: 16, color: _planColor(data.plan)),
                    const SizedBox(width: 6),
                    Text('${data.plan[0].toUpperCase()}${data.plan.substring(1)}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: _planColor(data.plan))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 50.ms);
  }

  // ── 3. Metrics Overview ────────────────────────────

  Widget _metricsOverview(OrgDetailData data, bool isDark) {
    final items = [
      (Icons.people_rounded, '${data.memberCount}', 'Members', AppColors.primary),
      (Icons.groups_rounded, '${data.staffCount}', 'Staff', AppColors.success),
      (Icons.account_balance_rounded, '${data.branches.length}', 'Branches', AppColors.accent),
      (Icons.account_balance_wallet_rounded, '${data.activeLoanCount}', 'Active Loans', AppColors.warning),
      (Icons.payments_rounded, '₹${_formatAmount(data.totalLoanAmount)}', 'Loan Volume', AppColors.accent),
      (Icons.receipt_long_rounded, '${data.pendingApprovalCount}', 'Pending', AppColors.error),
    ];

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final (icon, value, label, color) = items[i];
          return Container(
            width: MediaQuery.of(context).size.width * 0.22,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: _cardDeco(isDark),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A))),
                Text(label, style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
              ],
            ),
          );
        },
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  // ── 4. Contact & Location ──────────────────────────

  Widget _contactCard(OrgDetailData data, bool isDark) {
    if (!data.hasContactInfo) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _sectionCard(isDark, children: [
          _sectionHeader(Icons.contact_mail_rounded, 'Contact & Location', AppColors.primary),
          const SizedBox(height: 12),
          Center(
            child: Text('No contact info available',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
          ),
        ]),
      ).animate().fadeIn(duration: 400.ms, delay: 150.ms);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _sectionCard(isDark, children: [
        _sectionHeader(Icons.contact_mail_rounded, 'Contact & Location', AppColors.primary),
        const SizedBox(height: 14),
        if (data.phone != null)
          _infoRow(Icons.phone_rounded, 'Phone', data.phone!, isDark),
        if (data.email != null)
          _infoRow(Icons.email_rounded, 'Email', data.email!, isDark),
        if (data.address != null)
          _infoRow(Icons.home_rounded, 'Address', data.address!, isDark),
        if (data.city != null || data.state != null)
          _infoRow(Icons.location_city_rounded, 'City',
              [data.city, data.state, data.pincode].whereType<String>().join(', '), isDark),
        if (data.gstNumber != null)
          _infoRow(Icons.receipt_rounded, 'GST', data.gstNumber!, isDark),
      ]),
    ).animate().fadeIn(duration: 400.ms, delay: 150.ms);
  }

  // ── 5. Plan & Limits ───────────────────────────────

  Widget _planLimits(OrgDetailData data, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _sectionCard(isDark, children: [
        _sectionHeader(Icons.speed_rounded, 'Plan & Limits', AppColors.accent),
        const SizedBox(height: 14),
        // Plan badge
        Row(children: [
          Text('Current Plan:', style: TextStyle(
              fontSize: 13, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
          const SizedBox(width: 8),
          _pill(_planColor(data.plan), data.plan.toUpperCase(), isDark),
          if (data.trialEndsAt != null) ...[
            const SizedBox(width: 10),
            _trialCountdown(data.trialEndsAt!, isDark),
          ],
        ]),
        const SizedBox(height: 16),
        // Usage bars
        _usageBar('Members', data.memberCount, data.maxMembers, AppColors.primary, isDark),
        const SizedBox(height: 10),
        _usageBar('Staff', data.staffCount, data.maxStaff, AppColors.success, isDark),
        const SizedBox(height: 10),
        _usageBar('Branches', data.branches.length, data.maxBranches, AppColors.accent, isDark),
      ]),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _usageBar(String label, int current, int max, Color color, bool isDark) {
    final ratio = max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : const Color(0xFF0F172A))),
          const Spacer(),
          Text('$current / $max', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(ratio > 0.9 ? AppColors.error : color),
          ),
        ),
      ],
    );
  }

  Widget _trialCountdown(DateTime endsAt, bool isDark) {
    final remaining = endsAt.difference(DateTime.now());
    if (remaining.isNegative) return const SizedBox.shrink();
    final days = remaining.inDays;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('${days}d left', style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warning)),
    );
  }

  // ── 6. Team Members ────────────────────────────────

  Widget _teamMembersHeader(OrgDetailData data, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _sectionHeader(Icons.people_rounded,
          'Team Members (${data.profiles.length})', AppColors.primary),
    ).animate().fadeIn(duration: 400.ms, delay: 250.ms);
  }

  Widget _teamMembersSearch(bool isDark) {
    return Padding(
      padding: const.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: _cardDeco(isDark),
            child: TextField(
              onChanged: (v) => setState(() => _memberSearch = v),
              style: TextStyle(fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Search members...',
                hintStyle: TextStyle(fontSize: 14,
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                prefixIcon: Icon(Icons.search_rounded, size: 20,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip('', 'All'),
                _filterChip('executiveAdmin', 'Admin'),
                _filterChip('manager', 'Manager'),
                _filterChip('collectionAgent', 'Agent'),
                _filterChip('customer', 'Customer'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamMembersList(OrgDetailData data, bool isDark) {
    var filtered = data.profiles;
    if (_memberSearch.isNotEmpty) {
      final q = _memberSearch.toLowerCase();
      filtered = filtered.where((p) =>
          (p['full_name'] as String? ?? '').toLowerCase().contains(q) ||
          (p['email'] as String? ?? '').toLowerCase().contains(q)).toList();
    }
    if (_memberRoleFilter.isNotEmpty) {
      filtered = filtered.where((p) => p['role'] == _memberRoleFilter).toList();
    }

    if (filtered.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) => _memberTile(filtered[i], i, isDark),
          childCount: filtered.length,
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
      decoration: _cardDeco(isDark),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: rc.withValues(alpha: 0.15),
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(color: rc, fontWeight: FontWeight.w700, fontSize: 14)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A))),
            if (email.isNotEmpty)
              Text(email, style: TextStyle(fontSize: 12,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
          ],
        )),
        _pill(rc, _roleLabel(role), isDark),
      ]),
    ).animate().fadeIn(duration: 250.ms, delay: (30 * i).ms);
  }

  // ── 7. Branches ────────────────────────────────────

  Widget _branchesSection(OrgDetailData data, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _sectionCard(isDark, children: [
        _sectionHeader(Icons.account_balance_rounded,
            'Branches (${data.branches.length})', AppColors.accent),
        const SizedBox(height: 12),
        if (data.branches.isEmpty)
          Center(child: Text('No branches yet',
              style: TextStyle(fontSize: 13,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)))
        else
          ...data.branches.asMap().entries.map((entry) {
            final b = entry.value;
            final bName = b['name'] as String? ?? '';
            final code = b['code'] as String? ?? '';
            final status = b['status'] as String? ?? 'active';
            final sc = status == 'active' ? AppColors.success : AppColors.warning;
            final zone = b['zone'] as String? ?? '';
            final district = b['district'] as String? ?? '';
            final loc = [zone, district].where((s) => s.isNotEmpty).join(', ');

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: _cardDeco(isDark),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.location_on_rounded, size: 18, color: AppColors.accent),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    if (loc.isNotEmpty)
                      Text(loc, style: TextStyle(fontSize: 12,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
                  ],
                )),
                if (code.isNotEmpty)
                  Text(code, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
                const SizedBox(width: 8),
                _pill(sc, status[0].toUpperCase() + status.substring(1), isDark),
              ]),
            );
          }),
      ]),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }

  // ── 8. Activity ────────────────────────────────────

  Widget _activitySection(OrgDetailData data, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _sectionCard(isDark, children: [
        _sectionHeader(Icons.history_rounded, 'Recent Activity', AppColors.success),
        const SizedBox(height: 12),
        if (data.activityLogs.isEmpty)
          Center(child: Text('No activity yet',
              style: TextStyle(fontSize: 13,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)))
        else
          ...data.activityLogs.take(10).toList().asMap().entries.map((entry) {
            final log = entry.value;
            final action = log['action'] as String? ?? '';
            final details = log['details'] as String? ?? '';
            final user = log['user_name'] as String? ?? 'System';
            final createdAt = log['created_at'] as String? ?? '';
            final dateStr = createdAt.length >= 16
                ? createdAt.substring(0, 16).replaceFirst('T', ' ')
                : createdAt;
            final type = log['type'] as String? ?? '';
            final icon = _actIcon(type);
            final ic = _actColor(type);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: _cardDeco(isDark, radius: 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: ic.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: ic),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(action, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    if (details.isNotEmpty)
                      Text(details, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12,
                              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
                    const SizedBox(height: 3),
                    Text('$user • $dateStr', style: TextStyle(fontSize: 11,
                        color: isDark ? Colors.grey.shade600 : Colors.grey.shade500)),
                  ],
                )),
              ]),
            );
          }),
      ]),
    ).animate().fadeIn(duration: 400.ms, delay: 350.ms);
  }

  // ── 9. Danger Zone ─────────────────────────────────

  Widget _dangerZone(BuildContext context, WidgetRef ref, OrgDetailData data, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: isDark ? 0.06 : 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.error),
            const SizedBox(width: 8),
            Text('Danger Zone', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.error)),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmDelete(context, ref, data),
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
        ]),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 400.ms);
  }

  // ── Shared: Section Card ───────────────────────────

  Widget _sectionCard(bool isDark, {required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String label, Color color) {
    return Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A))),
    ]);
  }

  // ── Shared: Decorations ────────────────────────────

  BoxDecoration _cardDeco(bool isDark, {double radius = 20}) {
    return BoxDecoration(
      color: isDark
          ? const Color(0xFF1A1F2E).withValues(alpha: 0.7)
          : Colors.white.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.3)),
    );
  }

  Widget _pill(Color color, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  Widget _filterChip(String role, String label) {
    final active = _memberRoleFilter == role;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () { HapticService.selection(); setState(() => _memberRoleFilter = role); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: active ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: active ? AppColors.primary : Colors.grey.shade500)),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 16, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
        const SizedBox(width: 10),
        SizedBox(width: 72, child: Text(label, style: TextStyle(fontSize: 13,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF0F172A)))),
      ]),
    );
  }

  Widget _errorScreen(Object e, bool isDark) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline_rounded, size: 48,
            color: AppColors.error.withValues(alpha: 0.6)),
        const SizedBox(height: 16),
        Text('Failed to load', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A))),
        const SizedBox(height: 8),
        Text('$e', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
      ]),
    ));
  }

  // ── Helpers ────────────────────────────────────────

  String _month(int m) => ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];

  String _formatAmount(double amount) {
    if (amount >= 10000000) return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }

  Color _statusColor(String s) => switch (s) {
    'active' => AppColors.success, 'trial' => AppColors.warning,
    'suspended' => AppColors.error, _ => Colors.grey,
  };
  Color _planColor(String p) => switch (p) {
    'enterprise' => AppColors.primary, 'pro' => AppColors.accent,
    'basic' => AppColors.success, _ => Colors.grey,
  };
  Color _roleColor(String r) => switch (r) {
    'superAdmin' => const Color(0xFFEF4444), 'executiveAdmin' => AppColors.primary,
    'manager' => AppColors.accent, 'collectionAgent' => AppColors.success,
    _ => Colors.grey,
  };
  String _roleLabel(String r) => switch (r) {
    'superAdmin' => 'Super Admin', 'executiveAdmin' => 'Admin',
    'manager' => 'Manager', 'collectionAgent' => 'Agent', _ => r,
  };
  String _statusLabel(String s) => switch (s) {
    'active' => 'Active', 'trial' => 'Trial',
    'suspended' => 'Suspended', _ => s,
  };
  IconData _statusIcon(String s) => switch (s) {
    'active' => Icons.check_circle_rounded, 'trial' => Icons.access_time_rounded,
    'suspended' => Icons.pause_circle_rounded, _ => Icons.help_outline_rounded,
  };
  IconData _actIcon(String t) => switch (t) {
    'auth' => Icons.login_rounded, 'loan' => Icons.account_balance_rounded,
    'payment' => Icons.payments_rounded, 'savings' => Icons.savings_rounded,
    'member' => Icons.person_add_rounded, _ => Icons.circle,
  };
  Color _actColor(String t) => switch (t) {
    'auth' => AppColors.primary, 'loan' => AppColors.accent,
    'payment' => AppColors.success, 'savings' => AppColors.warning,
    _ => Colors.grey,
  };

  // ── Status Change Dialog ───────────────────────────

  Future<void> _showStatusDialog(
      BuildContext context, WidgetRef ref, OrgDetailData data) async {
    final current = data.status;
    final options = <String, String>{
      if (current != 'active') 'active': 'Activate',
      if (current != 'suspended') 'suspended': 'Suspend',
      if (current != 'trial') 'trial': 'Set Trial',
    };

    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(ctx).brightness == Brightness.dark
              ? const Color(0xFF1A1F2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Change Status', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700,
              color: Theme.of(ctx).brightness == Brightness.dark
                  ? Colors.white : const Color(0xFF0F172A))),
          const SizedBox(height: 16),
          ...options.entries.map((e) => ListTile(
            leading: Icon(_statusIcon(e.key), color: _statusColor(e.key)),
            title: Text(e.value),
            onTap: () => Navigator.pop(ctx, e.key),
          )),
          const SizedBox(height: 8),
        ]),
      ),
    );

    if (chosen == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client
          .from('organizations')
          .update({'status': chosen, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', data.id);
      ref.invalidate(orgDetailFullProvider(widget.orgId));
      ref.invalidate(adminOrgListProvider);
      messenger.showSnackBar(SnackBar(
        content: Text('Status changed to ${_statusLabel(chosen)}'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e, fallback: 'Failed to update status');
    }
  }

  // ── Plan Change Dialog ─────────────────────────────

  Future<void> _showPlanDialog(
      BuildContext context, WidgetRef ref, OrgDetailData data) async {
    final plans = ['free', 'basic', 'pro', 'enterprise'];
    final colors = {
      'free': Colors.grey, 'basic': AppColors.success,
      'pro': AppColors.accent, 'enterprise': AppColors.primary,
    };

    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(ctx).brightness == Brightness.dark
              ? const Color(0xFF1A1F2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Change Plan', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700,
              color: Theme.of(ctx).brightness == Brightness.dark
                  ? Colors.white : const Color(0xFF0F172A))),
          const SizedBox(height: 16),
          ...plans.map((p) => ListTile(
            leading: Icon(Icons.workspace_premium_rounded, color: colors[p]),
            title: Text(p[0].toUpperCase() + p.substring(1)),
            trailing: data.plan == p
                ? const Icon(Icons.check_circle, color: AppColors.success)
                : null,
            onTap: () => Navigator.pop(ctx, p),
          )),
          const SizedBox(height: 8),
        ]),
      ),
    );

    if (chosen == null || !context.mounted || chosen == data.plan) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client
          .from('organizations')
          .update({'plan': chosen, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', data.id);
      ref.invalidate(orgDetailFullProvider(widget.orgId));
      ref.invalidate(adminOrgListProvider);
      messenger.showSnackBar(SnackBar(
        content: Text('Plan changed to ${chosen[0].toUpperCase()}${chosen.substring(1)}'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e, fallback: 'Failed to update plan');
    }
  }

  // ── Delete Confirmation ────────────────────────────

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, OrgDetailData data) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Organization?'),
        content: Text(
            'This will permanently remove ${data.displayName} and all associated data. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(
                color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client
          .from('organizations')
          .delete()
          .eq('id', data.id);
      ref.invalidate(adminOrgListProvider);
      messenger.showSnackBar(const SnackBar(
        content: Text('Organization deleted'),
        backgroundColor: AppColors.success,
      ));
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e, fallback: 'Failed to delete');
    }
  }
}
