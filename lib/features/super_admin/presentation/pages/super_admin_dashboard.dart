import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/super_admin_providers.dart';

class SuperAdminDashboard extends ConsumerWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final metrics = ref.watch(platformMetricsProvider);
    final revenue = ref.watch(revenueSummaryProvider);
    final activity = ref.watch(activityFeedProvider);

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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              // ── Header ──────────────────────────────────
              _buildHeader(context, isDark),
              const SizedBox(height: 24),

              // ── Metrics Grid ────────────────────────────
              metrics.when(
                data: (m) => _buildMetrics(context, m, isDark),
                loading: () => const Center(
                    child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                )),
                error: (e, _) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  decoration: BoxDecoration(
    color: Colors.red.withValues(alpha: 0.15),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Text('Error: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
),
              ),
              const SizedBox(height: 24),

              // ── Revenue ─────────────────────────────────
              revenue.when(
                data: (r) => _buildRevenue(context, r, isDark),
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  decoration: BoxDecoration(
    color: Colors.red.withValues(alpha: 0.15),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Text('Error: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
),
              ),
              const SizedBox(height: 24),

              // ── Quick Actions ───────────────────────────
              _buildQuickActions(context, isDark),
              const SizedBox(height: 24),

              // ── Recent Activity ─────────────────────────
              activity.when(
                data: (a) => _buildActivity(context, a, isDark),
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  decoration: BoxDecoration(
    color: Colors.red.withValues(alpha: 0.15),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Text('Error: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, bool isDark) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Here\'s your platform overview',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  // ── Metrics Grid ────────────────────────────────────────
  Widget _buildMetrics(BuildContext context, dynamic m, bool isDark) {
    final fmt = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹');
    final stats = [
      _StatData(Icons.business_rounded, 'Orgs', '${m.totalOrganizations}', AppColors.primary),
      _StatData(Icons.people_rounded, 'Users', '${m.totalUsers}', AppColors.success),
      _StatData(Icons.group_rounded, 'Members', '${m.totalMembers}', AppColors.info),
      _StatData(Icons.account_balance_rounded, 'Loans', '${m.totalLoans}', AppColors.warning),
      _StatData(Icons.payments_rounded, 'Collections', fmt.format(m.totalCollections), AppColors.cyan),
      _StatData(Icons.savings_rounded, 'Savings', fmt.format(m.totalSavings), AppColors.accent),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Overview', Icons.analytics_rounded, AppColors.primary),
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
          itemBuilder: (_, i) => _statTile(context, stats[i], i, isDark),
        ),
      ],
    );
  }

  Widget _statTile(
      BuildContext context, _StatData data, int index, bool isDark) {
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
              : Colors.white.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
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
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, color: data.color, size: 17),
          ),
          const SizedBox(height: 8),
          Text(
            data.value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: (100 + 80 * index).ms)
        .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
  }

  // ── Revenue ─────────────────────────────────────────────
  Widget _buildRevenue(
      BuildContext context, Map<String, dynamic> r, bool isDark) {
    final total = (r['total_revenue'] ?? 0).toDouble();
    final avg = (r['avg_monthly_revenue'] ?? 0).toDouble();
    final count = r['transaction_count'] ?? 0;
    final fmt = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹');

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
              : Colors.white.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Revenue', Icons.trending_up_rounded, AppColors.success),
          const SizedBox(height: 14),
          Row(
            children: [
              _revStat(context, 'Total', fmt.format(total), AppColors.success, isDark),
              Container(
                  width: 1,
                  height: 40,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.08)),
              _revStat(context, 'Avg/Month', fmt.format(avg), AppColors.info, isDark),
              Container(
                  width: 1,
                  height: 40,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.08)),
              _revStat(context, 'Transactions', '$count', AppColors.warning, isDark),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 400.ms);
  }

  Widget _revStat(BuildContext context, String label, String value,
      Color color, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? Colors.grey.shade500
                      : Colors.grey.shade600)),
        ],
      ),
    );
  }

  // ── Quick Actions ───────────────────────────────────────
  Widget _buildQuickActions(BuildContext context, bool isDark) {
    final actions = [
      _ActionData(Icons.business_rounded, 'Orgs', AppColors.primary,
          () => context.push('/super-admin/organizations')),
      _ActionData(Icons.people_rounded, 'Users', AppColors.success,
          () => context.push('/super-admin/users')),
      _ActionData(Icons.settings_rounded, 'Settings', AppColors.accent,
          () => context.push('/super-admin/settings')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
            'Quick Actions', Icons.flash_on_rounded, AppColors.accent),
        const SizedBox(height: 14),
        Row(
          children: actions.asMap().entries.map((entry) {
            final i = entry.key;
            final a = entry.value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                child: GestureDetector(
                  onTap: a.onTap,
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
                            : Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: a.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child:
                              Icon(a.icon, color: a.color, size: 20),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          a.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 500.ms);
  }

  // ── Recent Activity ─────────────────────────────────────
  Widget _buildActivity(
      BuildContext context, List<Map<String, dynamic>> items, bool isDark) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(isDark),
        child: Center(
          child: Text(
            'No recent activity',
            style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
              'Recent Activity', Icons.history_rounded, AppColors.warning),
          const SizedBox(height: 14),
          ...items.take(5).map((a) {
            final type = a['activity_type'] as String? ?? 'unknown';
            final createdAt =
                DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
            final ago = _timeAgo(DateTime.now().difference(createdAt));
            final title = type
                .replaceAll('_', ' ')
                .split(' ')
                .map((e) => e[0].toUpperCase() + e.substring(1))
                .join(' ');
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A))),
                        if (a['organizations']?['name'] != null)
                          Text(a['organizations']['name'],
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.primary)),
                      ],
                    ),
                  ),
                  Text(ago,
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600)),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 600.ms);
  }

  // ── Helpers ─────────────────────────────────────────────
  Widget _sectionTitle(String label, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark
          ? const Color(0xFF1A1F2E).withValues(alpha: 0.7)
          : Colors.white.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.3),
      ),
    );
  }

  String _timeAgo(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d ago';
    if (d.inHours > 0) return '${d.inHours}h ago';
    if (d.inMinutes > 0) return '${d.inMinutes}m ago';
    return 'now';
  }
}

// ── Data classes ──────────────────────────────────────────
class _StatData {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatData(this.icon, this.label, this.value, this.color);
}

class _ActionData {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionData(this.icon, this.label, this.color, this.onTap);
}
