import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final adminOrgListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  final orgs = await client.from('organizations').select('id, name, slug, status, created_at').order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(orgs);
});

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgsAsync = ref.watch(adminOrgListProvider);
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
          child: orgsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (orgs) {
              final totalOrgs = orgs.length;
              final activeOrgs = orgs.where((o) => o['status'] == 'active').length;
              final suspended = orgs.where((o) => o['status'] == 'suspended').length;

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(adminOrgListProvider),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  children: [
                    _buildHeader(context, ref, theme, isDark),
                    const SizedBox(height: 28),
                    _buildStatsRow(totalOrgs, activeOrgs, suspended, isDark),
                    const SizedBox(height: 28),
                    _buildSectionHeader('Organizations', '${orgs.length} total', isDark),
                    const SizedBox(height: 16),
                    ...orgs.asMap().entries.map((e) =>
                      _buildOrgCard(context, e.value, e.key, isDark)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Super Admin', style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800, letterSpacing: -0.8)),
                const SizedBox(height: 4),
                Text('Platform Overview', style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 15)),
              ],
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => context.go('/admin/my-org'),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.grid_view_rounded, size: 18, color: Colors.white),
                        SizedBox(width: 6),
                        Text('My Org', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.2)),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    await ref.read(authProvider.notifier).signOut();
                    if (context.mounted) context.go('/auth');
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.logout_rounded, size: 20, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildStatsRow(int total, int active, int suspended, bool isDark) {
    final stats = [
      _StatData(Icons.business_rounded, 'Total', '$total', AppColors.primary, AppColors.primaryLight),
      _StatData(Icons.check_circle_rounded, 'Active', '$active', AppColors.success, AppColors.success.withValues(alpha: 0.7)),
      _StatData(Icons.pause_circle_rounded, 'Suspended', '$suspended', AppColors.warning, AppColors.warning.withValues(alpha: 0.7)),
      _StatData(Icons.trending_up_rounded, 'Rate', '${total == 0 ? 0 : (active * 100 ~/ total)}%', AppColors.cyan, AppColors.cyan.withValues(alpha: 0.7)),
    ];

    return Row(
      children: stats.asMap().entries.map((e) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: e.key == 0 ? 0 : 8),
            child: _StatCard(data: e.value, isDark: isDark, index: e.key),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF0F172A))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(subtitle, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey.shade400 : AppColors.primary)),
        ),
      ],
    );
  }

  Widget _buildOrgCard(BuildContext context, Map<String, dynamic> org, int index, bool isDark) {
    final status = org['status'] as String? ?? 'unknown';
    final isActive = status == 'active';
    final name = org['name'] as String? ?? '';
    final slug = org['slug'] as String? ?? '';
    final created = org['created_at'] as String? ?? '';
    final dateStr = created.length >= 10 ? created.substring(0, 10) : '';

    final statusColor = isActive ? AppColors.success : AppColors.warning;
    final statusLabel = isActive ? 'Active' : 'Suspended';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassmorphicCard(
        onTap: () => context.go('/admin/org/${org['id']}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.warning.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isActive
                        ? [AppColors.success.withValues(alpha: 0.2), AppColors.success.withValues(alpha: 0.05)]
                        : [AppColors.warning.withValues(alpha: 0.2), AppColors.warning.withValues(alpha: 0.05)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(isActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                  color: statusColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    const SizedBox(height: 3),
                    Text('$slug  •  $dateStr', style: TextStyle(
                      fontSize: 12, color: isDark ? Colors.grey.shade500 : Colors.grey.shade500)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                ),
                child: Text(statusLabel, style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: statusColor, letterSpacing: 0.3)),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400, size: 22),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 400.ms, delay: (100 * index).ms).slideX(begin: 0.1, end: 0),
    );
  }
}

class _StatData {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color lightColor;
  _StatData(this.icon, this.label, this.value, this.color, this.lightColor);
}

class _StatCard extends StatelessWidget {
  final _StatData data;
  final bool isDark;
  final int index;
  const _StatCard({required this.data, required this.isDark, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2E).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : data.color.withValues(alpha: 0.08),
            blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: data.color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(data.value, style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(data.label, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: (150 + 100 * index).ms).slideY(begin: 0.2, end: 0);
  }
}

class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const GlassmorphicCard({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: child,
          ),
        ),
      ),
    );
  }
}
