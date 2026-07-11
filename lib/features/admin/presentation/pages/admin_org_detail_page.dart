import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../features/super_admin/data/models/super_admin_models.dart';
import '../../../../features/super_admin/data/providers/super_admin_providers.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/utils/error_formatter.dart';

/// Legacy alias � any file importing adminOrgDetailProvider won't break.
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
// PREMIUM ORGANIZATION DETAIL PAGE � CLEAN SUMMARY VIEW
// =====================================================

class AdminOrgDetailPage extends ConsumerStatefulWidget {
  final String orgId;
  const AdminOrgDetailPage({super.key, required this.orgId});
  @override
  ConsumerState<AdminOrgDetailPage> createState() => _AdminOrgDetailPageState();
}

class _AdminOrgDetailPageState extends ConsumerState<AdminOrgDetailPage> {
  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(orgDetailFullProvider(widget.orgId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: AuroraBackground(
        child: detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
          data: (data) {
            if (data == null) return const Center(child: Text('Organization not found'));
            return _buildContent(context, ref, data, theme, isDark);
          },
        ),
      ),
    );
  }

  // -- Main Content -----------------------------------

  Widget _buildContent(BuildContext context, WidgetRef ref, OrgDetailData data, ThemeData theme, bool isDark) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(orgDetailFullProvider(widget.orgId));
      },
      displacement: 20,
      color: theme.colorScheme.primary,
      backgroundColor: theme.cardColor,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          // -- Sliver AppBar --
          _buildSliverAppBar(context, ref, data, theme, isDark),

          // -- Profile Header --
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _buildProfileHeader(data, theme, isDark),
            ),
          ),

          // -- Quick Actions --
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _buildQuickActions(context, ref, data, theme, isDark),
            ),
          ),

          // -- Stats Grid --
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _buildStatsGrid(data, theme, isDark),
            ),
          ),

          // -- Contact & Location --
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _buildContactSection(data, theme, isDark),
            ),
          ),

          // -- Plan & Limits --
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _buildPlanLimitsSection(data, theme, isDark),
            ),
          ),

          // -- Quick Access Tiles --
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _buildSectionTitle(theme, 'Quick Access', Icons.grid_view_rounded),
            ),
          ),

          // -- Team Members Tile --
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _buildTeamMembersTile(context, data, theme, isDark),
            ),
          ),

          // -- Branches Tile --
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _buildBranchesTile(context, data, theme, isDark),
            ),
          ),

          // -- Activity Tile --
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _buildActivityTile(context, data, theme, isDark),
            ),
          ),


  // ── Bottom spacer for HUD nav clearance ──
  const SliverToBoxAdapter(
    child: SizedBox(height: 90),
  ),
          // -- Danger Zone --
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 150),
              child: _buildDangerZone(context, ref, data, theme, isDark),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  // -- Sliver App Bar ---------------------------------

  Widget _buildSliverAppBar(BuildContext context, WidgetRef ref, OrgDetailData data, ThemeData theme, bool isDark) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: isDark
          ? AppColors.backgroundDark.withValues(alpha: 0.85)
          : AppColors.backgroundLight.withValues(alpha: 0.85),
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      title: Text(
        data.displayName,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      centerTitle: true,
      actions: [
        // Status toggle
        GestureDetector(
          onTap: () => _showStatusDialog(context, ref, data),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _statusColor(data.status).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _statusColor(data.status).withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_statusIcon(data.status), size: 14, color: _statusColor(data.status)),
                const SizedBox(width: 4),
                Text(
                  _statusLabel(data.status),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _statusColor(data.status),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Plan selector
        GestureDetector(
          onTap: () => _showPlanDialog(context, ref, data),
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _planColor(data.plan).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _planColor(data.plan).withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.workspace_premium_rounded, size: 14, color: AppColors.accent),
                const SizedBox(width: 4),
                Text(
                  data.plan.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _planColor(data.plan),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // -- Profile Header ---------------------------------

  Widget _buildProfileHeader(OrgDetailData data, ThemeData theme, bool isDark) {
    final initial = data.displayName.isNotEmpty ? data.displayName[0].toUpperCase() : '?';
    final created = data.createdAt;
    final dateStr = created != null ? '${created.day} ${_month(created.month)} ${created.year}' : '';

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Glowing Avatar
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: AppColors.premiumGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: isDark ? const Color(0xFF0F1115) : Colors.white,
              child: CircleAvatar(
                radius: 28,
                backgroundColor: isDark ? const Color(0xFF141416) : Colors.grey[100],
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: -1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Org Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.displayName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    StatusBadge(
                      label: _statusLabel(data.status),
                      type: _statusType(data.status),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _planColor(data.plan).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        data.plan.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _planColor(data.plan),
                        ),
                      ),
                    ),
                  ],
                ),
                if (dateStr.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 12, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Text(
                        'Created $dateStr',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  // -- Quick Actions ----------------------------------

  Widget _buildQuickActions(BuildContext context, WidgetRef ref, OrgDetailData data, ThemeData theme, bool isDark) {
    return Row(
      children: [
        // Status toggle
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 14),
            onTap: () => _showStatusDialog(context, ref, data),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_statusIcon(data.status), size: 18, color: _statusColor(data.status)),
                const SizedBox(width: 8),
                Text(
                  _statusLabel(data.status),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _statusColor(data.status),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Plan selector
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 14),
            onTap: () => _showPlanDialog(context, ref, data),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.workspace_premium_rounded, size: 18, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(
                  '${data.plan[0].toUpperCase()}${data.plan.substring(1)} Plan',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  // -- Stats Grid -------------------------------------

  Widget _buildStatsGrid(OrgDetailData data, ThemeData theme, bool isDark) {
    final stats = <Map<String, dynamic>>[
      {'icon': Icons.people_rounded, 'value': '${data.memberCount}', 'label': 'Members', 'color': AppColors.primary},
      {'icon': Icons.groups_rounded, 'value': '${data.staffCount}', 'label': 'Staff', 'color': AppColors.success},
      {'icon': Icons.account_balance_rounded, 'value': '${data.branches.length}', 'label': 'Branches', 'color': AppColors.accent},
      {'icon': Icons.account_balance_wallet_rounded, 'value': '${data.activeLoanCount}', 'label': 'Active Loans', 'color': AppColors.warning},
    ];
  return Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (int i = 0; i < stats.length; i++)
        _buildStatCard(
          stats[i]['icon'] as IconData,
          stats[i]['value'] as String,
          stats[i]['label'] as String,
          stats[i]['color'] as Color,
          theme,
          isDark,
        ),
    ],
  ).animate().fadeIn(duration: 400.ms, delay: 150.ms);
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color color, ThemeData theme, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -- Contact Section --------------------------------

  Widget _buildContactSection(OrgDetailData data, ThemeData theme, bool isDark) {
    if (!data.hasContactInfo) {
      return GlassCard(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.contact_mail_rounded, size: 40, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text(
                'No contact info available',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
    }

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(theme, 'Contact & Location', Icons.contact_mail_rounded),
          const SizedBox(height: 16),
          if (data.phone != null)
            _buildInfoRow(Icons.phone_rounded, 'Phone', data.phone!, isDark),
          if (data.email != null)
            _buildInfoRow(Icons.email_rounded, 'Email', data.email!, isDark),
          if (data.address != null)
            _buildInfoRow(Icons.home_rounded, 'Address', data.address!, isDark),
          if (data.city != null || data.state != null)
            _buildInfoRow(
              Icons.location_city_rounded,
              'City',
              [data.city, data.state, data.pincode].whereType<String>().join(', '),
              isDark,
            ),
          if (data.gstNumber != null)
            _buildInfoRow(Icons.receipt_rounded, 'GST', data.gstNumber!, isDark),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 250.ms);
  }

  // -- Plan & Limits ----------------------------------

  Widget _buildPlanLimitsSection(OrgDetailData data, ThemeData theme, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(theme, 'Plan & Limits', Icons.speed_rounded),
          const SizedBox(height: 16),

          // Plan badge
          Row(
            children: [
              Text(
                'Current Plan:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _planColor(data.plan).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  data.plan.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _planColor(data.plan),
                  ),
                ),
              ),
              if (data.trialEndsAt != null) ...[
                const SizedBox(width: 12),
                _buildTrialCountdown(data.trialEndsAt!),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // Usage bars
          _buildUsageBar('Members', data.memberCount, data.maxMembers, AppColors.primary, isDark),
          const SizedBox(height: 14),
          _buildUsageBar('Staff', data.staffCount, data.maxStaff, AppColors.success, isDark),
          const SizedBox(height: 14),
          _buildUsageBar('Branches', data.branches.length, data.maxBranches, AppColors.accent, isDark),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }

  Widget _buildUsageBar(String label, int current, int max, Color color, bool isDark) {
    final ratio = max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            Text(
              '$current / $max',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
            valueColor: AlwaysStoppedAnimation<Color>(ratio > 0.9 ? AppColors.error : color),
          ),
        ),
      ],
    );
  }

  Widget _buildTrialCountdown(DateTime endsAt) {
    final remaining = endsAt.difference(DateTime.now());
    if (remaining.isNegative) return const SizedBox.shrink();
    final days = remaining.inDays;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_rounded, size: 12, color: AppColors.warning),
          const SizedBox(width: 4),
          Text(
            '${days}d left',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  // -- Quick Access Tiles -----------------------------

  Widget _buildTeamMembersTile(BuildContext context, OrgDetailData data, ThemeData theme, bool isDark) {
    final previewAvatars = data.profiles.take(5).toList();
    final totalCount = data.profiles.length;

    return GestureDetector(
      onTap: () => _navigateToTeamMembers(context, data),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.primary.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.people_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Team Members',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$totalCount',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Preview avatars
                  Row(
                    children: [
                      SizedBox(
                        height: 28,
                        child: Stack(
                          children: [
                            for (int i = 0; i < previewAvatars.length && i < 5; i++)
                              Positioned(
                                left: i * 16.0,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        _roleColor(previewAvatars[i]['role'] as String? ?? '').withValues(alpha: 0.8),
                                        _roleColor(previewAvatars[i]['role'] as String? ?? '').withValues(alpha: 0.6),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      ((previewAvatars[i]['full_name'] as String? ?? '').isNotEmpty
                                          ? (previewAvatars[i]['full_name'] as String? ?? '?')[0]
                                          : '?')
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (totalCount > 5)
                              Positioned(
                                left: 5 * 16.0,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '+${totalCount - 5}',
                                      style: TextStyle(
                                        color: isDark ? Colors.white70 : Colors.black54,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white24 : Colors.black26,
              size: 24,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 350.ms);
  }

  Widget _buildBranchesTile(BuildContext context, OrgDetailData data, ThemeData theme, bool isDark) {
    final previewBranches = data.branches.take(3).toList();
    final totalCount = data.branches.length;

    return GestureDetector(
      onTap: () => _navigateToBranches(context, data),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.15),
                    AppColors.accent.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.account_balance_rounded, color: AppColors.accent, size: 24),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Branches',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$totalCount',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (previewBranches.isNotEmpty)
                    Text(
                      previewBranches.map((b) => b['name'] as String? ?? '').join(', ') +
                          (totalCount > 3 ? '...' : ''),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      'No branches yet',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),

            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white24 : Colors.black26,
              size: 24,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 400.ms);
  }

  Widget _buildActivityTile(BuildContext context, OrgDetailData data, ThemeData theme, bool isDark) {
    final totalCount = data.activityLogs.length;
    final latestActivity = data.activityLogs.isNotEmpty ? data.activityLogs.first : null;

    return GestureDetector(
      onTap: () => _navigateToActivity(context, data),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.success.withValues(alpha: 0.15),
                    AppColors.success.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.history_rounded, color: AppColors.success, size: 24),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Recent Activity',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$totalCount',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (latestActivity != null)
                    Text(
                      latestActivity['action'] as String? ?? 'No activity',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      'No activity yet',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),

            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white24 : Colors.black26,
              size: 24,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 450.ms);
  }

  // -- Navigation Methods -----------------------------

  void _navigateToTeamMembers(BuildContext context, OrgDetailData data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _OrgTeamMembersPage(data: data),
      ),
    );
  }

  void _navigateToBranches(BuildContext context, OrgDetailData data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _OrgBranchesPage(data: data),
      ),
    );
  }

  void _navigateToActivity(BuildContext context, OrgDetailData data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _OrgActivityPage(data: data),
      ),
    );
  }

  // -- Danger Zone ------------------------------------

  Widget _buildDangerZone(BuildContext context, WidgetRef ref, OrgDetailData data, ThemeData theme, bool isDark) {
    return Container(
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
              const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.error),
              const SizedBox(width: 8),
              Text(
                'Danger Zone',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
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
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 500.ms);
  }

  // -- Shared: Section Headers ------------------------

  Widget _buildSectionTitle(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isDark ? Colors.white38 : Colors.black38),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // -- Helpers ----------------------------------------

  String _month(int m) => ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];

  Color _statusColor(String s) => switch (s) {
    'active' => AppColors.success,
    'trial' => AppColors.warning,
    'suspended' => AppColors.error,
    _ => Colors.grey,
  };

  Color _planColor(String p) => switch (p) {
    'enterprise' => AppColors.primary,
    'pro' => AppColors.accent,
    'basic' => AppColors.success,
    _ => Colors.grey,
  };

  Color _roleColor(String r) => switch (r) {
    'superAdmin' => AppColors.error,
    'executiveAdmin' => AppColors.primary,
    'manager' => AppColors.accent,
    'collectionAgent' => AppColors.success,
    _ => Colors.grey,
  };

  String _statusLabel(String s) => switch (s) {
    'active' => 'Active',
    'trial' => 'Trial',
    'suspended' => 'Suspended',
    _ => s,
  };

  IconData _statusIcon(String s) => switch (s) {
    'active' => Icons.check_circle_rounded,
    'trial' => Icons.access_time_rounded,
    'suspended' => Icons.pause_circle_rounded,
    _ => Icons.help_outline_rounded,
  };

  StatusType _statusType(String s) => switch (s) {
    'active' => StatusType.active,
    'trial' => StatusType.pending,
    'suspended' => StatusType.defaultStatus,
    _ => StatusType.standard,
  };

  // -- Status Change Dialog ---------------------------

  Future<void> _showStatusDialog(BuildContext context, WidgetRef ref, OrgDetailData data) async {
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
              ? const Color(0xFF1A1F2E)
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Change Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Theme.of(ctx).brightness == Brightness.dark
                    ? Colors.white
                    : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            ...options.entries.map((e) => ListTile(
                  leading: Icon(_statusIcon(e.key), color: _statusColor(e.key)),
                  title: Text(e.value),
                  onTap: () => Navigator.pop(ctx, e.key),
                )),
            const SizedBox(height: 8),
          ],
        ),
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

  // -- Plan Change Dialog -----------------------------

  Future<void> _showPlanDialog(BuildContext context, WidgetRef ref, OrgDetailData data) async {
    final plans = ['free', 'basic', 'pro', 'enterprise'];
    final colors = {
      'free': Colors.grey,
      'basic': AppColors.success,
      'pro': AppColors.accent,
      'enterprise': AppColors.primary,
    };

    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(ctx).brightness == Brightness.dark
              ? const Color(0xFF1A1F2E)
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Change Plan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Theme.of(ctx).brightness == Brightness.dark
                    ? Colors.white
                    : const Color(0xFF0F172A),
              ),
            ),
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
          ],
        ),
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

  // -- Delete Confirmation ----------------------------

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, OrgDetailData data) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Organization?'),
        content: Text(
            'This will permanently remove ${data.displayName} and all associated data. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
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

// =====================================================
// TEAM MEMBERS DETAIL PAGE
// =====================================================

class _OrgTeamMembersPage extends StatefulWidget {
  final OrgDetailData data;
  const _OrgTeamMembersPage({required this.data});

  @override
  State<_OrgTeamMembersPage> createState() => _OrgTeamMembersPageState();
}

class _OrgTeamMembersPageState extends State<_OrgTeamMembersPage> {
  String _search = '';
  String _roleFilter = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final data = widget.data;

    var filtered = data.profiles;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      filtered = filtered.where((p) =>
          (p['full_name'] as String? ?? '').toLowerCase().contains(q) ||
          (p['email'] as String? ?? '').toLowerCase().contains(q)).toList();
    }
    if (_roleFilter.isNotEmpty) {
      filtered = filtered.where((p) => p['role'] == _roleFilter).toList();
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: AuroraBackground(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverAppBar(
              pinned: true,
              elevation: 0,
              backgroundColor: isDark
                  ? AppColors.backgroundDark.withValues(alpha: 0.85)
                  : AppColors.backgroundLight.withValues(alpha: 0.85),
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Team Members (${data.profiles.length})',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),

            // Search & Filters
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
                        onChanged: (v) => setState(() => _search = v),
                        style: theme.textTheme.bodyMedium,
                        decoration: InputDecoration(
                          hintText: 'Search members...',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          prefixIcon: Icon(Icons.search_rounded, size: 20, color: isDark ? Colors.white38 : Colors.black38),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildFilterChip('', 'All'),
                          _buildFilterChip('executiveAdmin', 'Admin'),
                          _buildFilterChip('manager', 'Manager'),
                          _buildFilterChip('collectionAgent', 'Agent'),
                          _buildFilterChip('customer', 'Customer'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Member List
            if (filtered.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('No members found')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _buildMemberCard(filtered[i], i, theme, isDark),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String role, String label) {
    final active = _roleFilter == role;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          HapticService.selection();
          setState(() => _roleFilter = role);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? AppColors.primary : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> p, int i, ThemeData theme, bool isDark) {
    final name = p['full_name'] as String? ?? 'Unknown';
    final email = p['email'] as String? ?? '';
    final role = p['role'] as String? ?? '';
    final rc = _roleColor(role);

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [rc.withValues(alpha: 0.8), rc.withValues(alpha: 0.6)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (email.isNotEmpty)
                  Text(email, style: theme.textTheme.bodySmall?.copyWith(color: isDark ? Colors.white54 : Colors.black45, fontSize: 12)),
              ],
            ),
          ),
          StatusBadge(label: _roleLabel(role), type: StatusType.standard),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms, delay: Duration(milliseconds: 50 * i.clamp(0, 10)));
  }

  Color _roleColor(String r) => switch (r) {
    'superAdmin' => AppColors.error,
    'executiveAdmin' => AppColors.primary,
    'manager' => AppColors.accent,
    'collectionAgent' => AppColors.success,
    _ => Colors.grey,
  };

  String _roleLabel(String r) => switch (r) {
    'superAdmin' => 'Super Admin',
    'executiveAdmin' => 'Admin',
    'manager' => 'Manager',
    'collectionAgent' => 'Agent',
    _ => r,
  };
}

// =====================================================
// BRANCHES DETAIL PAGE
// =====================================================

class _OrgBranchesPage extends StatelessWidget {
  final OrgDetailData data;
  const _OrgBranchesPage({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: AuroraBackground(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverAppBar(
              pinned: true,
              elevation: 0,
              backgroundColor: isDark
                  ? AppColors.backgroundDark.withValues(alpha: 0.85)
                  : AppColors.backgroundLight.withValues(alpha: 0.85),
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Branches (${data.branches.length})',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),

            if (data.branches.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('No branches yet')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList.builder(
                  itemCount: data.branches.length,
                  itemBuilder: (ctx, i) => _buildBranchCard(data.branches[i], i, theme, isDark),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchCard(Map<String, dynamic> b, int i, ThemeData theme, bool isDark) {
    final bName = b['name'] as String? ?? '';
    final code = b['code'] as String? ?? '';
    final status = b['status'] as String? ?? 'active';
    final zone = b['zone'] as String? ?? '';
    final district = b['district'] as String? ?? '';
    final loc = [zone, district].where((s) => s.isNotEmpty).join(', ');

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.accent.withValues(alpha: 0.15), AppColors.accent.withValues(alpha: 0.05)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.location_on_rounded, color: AppColors.accent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (loc.isNotEmpty)
                  Text(loc, style: theme.textTheme.bodySmall?.copyWith(color: isDark ? Colors.white54 : Colors.black45, fontSize: 12)),
              ],
            ),
          ),
          if (code.isNotEmpty)
            Text(code, style: theme.textTheme.bodySmall?.copyWith(color: isDark ? Colors.white54 : Colors.black45, fontSize: 11)),
          const SizedBox(width: 10),
          StatusBadge(
            label: status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : 'Unknown',
            type: status == 'active' ? StatusType.active : StatusType.pending,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms, delay: Duration(milliseconds: 50 * i.clamp(0, 10)));
  }
}

// =====================================================
// ACTIVITY DETAIL PAGE
// =====================================================

class _OrgActivityPage extends StatelessWidget {
  final OrgDetailData data;
  const _OrgActivityPage({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: AuroraBackground(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverAppBar(
              pinned: true,
              elevation: 0,
              backgroundColor: isDark
                  ? AppColors.backgroundDark.withValues(alpha: 0.85)
                  : AppColors.backgroundLight.withValues(alpha: 0.85),
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Recent Activity (${data.activityLogs.length})',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),

            if (data.activityLogs.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('No activity yet')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList.builder(
                  itemCount: data.activityLogs.length,
                  itemBuilder: (ctx, i) => _buildActivityCard(data.activityLogs[i], i, theme, isDark),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> log, int i, ThemeData theme, bool isDark) {
    final action = log['action'] as String? ?? '';
    final details = log['details'] as String? ?? '';
    final user = log['user_name'] as String? ?? 'System';
    final createdAt = log['created_at'] as String? ?? '';
    final dateStr = createdAt.length >= 16 ? createdAt.substring(0, 16).replaceFirst('T', ' ') : createdAt;
    final type = log['type'] as String? ?? '';
    final icon = _actIcon(type);
    final ic = _actColor(type);

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ic.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: ic),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (details.isNotEmpty)
                  Text(details, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: isDark ? Colors.white54 : Colors.black45, fontSize: 12)),
                const SizedBox(height: 4),
                Text('$user � $dateStr', style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms, delay: Duration(milliseconds: 50 * i.clamp(0, 10)));
  }

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
    _ => Colors.grey,
  };
}
