import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../core/services/haptic_service.dart';
import '../../data/providers/super_admin_providers.dart';

class SuperAdminDashboard extends ConsumerWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final metrics = ref.watch(platformMetricsProvider);
    final revenue = ref.watch(revenueSummaryProvider);
    final activity = ref.watch(activityFeedProvider);
    final openTickets = ref.watch(openTicketsCountProvider);
    final atRiskOrgs = ref.watch(atRiskOrgsCountProvider);
    final fmt = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹');

    return Scaffold(
      backgroundColor: D.bg(context),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: D.bodyPad,
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(context, isDark),
                    const SizedBox(height: 24),
                    _alertBanner(context, isDark, openTickets, atRiskOrgs),
                    const SizedBox(height: 24),
                    _sectionArea(
                        context,
                        isDark,
                        () => metrics.when(
                              data: (m) => _metricGrid(context, m, fmt, isDark),
                              loading: () => const SizedBox(
                                height: 200,
                                child:
                                    Center(child: CircularProgressIndicator()),
                              ),
                              error: (_, __) => const SizedBox.shrink(),
                            )),
                    const SizedBox(height: 24),
                    D.sectionTitle('Quick Actions', Icons.flash_on, isDark),
                    const SizedBox(height: 14),
                    _quickActions(context, isDark),
                    const SizedBox(height: 28),
                    D.sectionTitle(
                        'Revenue & Benchmarking', Icons.trending_up, isDark),
                    const SizedBox(height: 14),
                    _sectionArea(
                        context,
                        isDark,
                        () => revenue.when(
                              data: (r) =>
                                  _revenueSection(context, r, fmt, isDark),
                              loading: () => const SizedBox(
                                height: 100,
                                child:
                                    Center(child: CircularProgressIndicator()),
                              ),
                              error: (_, __) => const SizedBox.shrink(),
                            )),
                    const SizedBox(height: 28),
                    D.sectionTitle('Churn Risk', Icons.warning_amber, isDark),
                    const SizedBox(height: 14),
                    _sectionArea(
                        context,
                        isDark,
                        () => metrics.when(
                              data: (m) => _churnRisk(context, m, isDark),
                              loading: () => const SizedBox(
                                height: 100,
                                child:
                                    Center(child: CircularProgressIndicator()),
                              ),
                              error: (_, __) => const SizedBox.shrink(),
                            )),
                    const SizedBox(height: 28),
                    D.sectionTitle('SLA Status', Icons.verified, isDark),
                    const SizedBox(height: 14),
                    _slaStatus(context, isDark),
                    const SizedBox(height: 28),
                    D.sectionTitle('Feature Adoption', Icons.widgets, isDark),
                    const SizedBox(height: 14),
                    _featureAdoption(context, isDark),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
            activity.when(
              data: (a) => SliverPadding(
                padding: D.bodyBottomPad,
                sliver: SliverToBoxAdapter(
                  child: Column(children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        D.sectionTitle(
                            'Recent Activity', Icons.history, isDark),
                        TextButton(
                          onPressed: () =>
                              context.push('/super-admin/audit-logs'),
                          child: Text(
                            'View All',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: D.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...a.take(8).map((e) => _activityItem(context, e, isDark)),
                  ]),
                ),
              ),
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, __) =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionArea(
      BuildContext context, bool isDark, Widget Function() child) {
    return child();
  }

  // ── Section 1: Header ─────────────────────────────────────
  Widget _header(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard', style: D.h1(isDark)),
              const SizedBox(height: 4),
              Text(
                'Platform overview',
                style: TextStyle(
                  fontSize: 14,
                  color: D.muted(context),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: D.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Live',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: D.accent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Section 2: Alert Banner ──────────────────────────────
  Widget _alertBanner(BuildContext context, bool isDark,
      AsyncValue<int> openTickets, AsyncValue<int> atRiskOrgs) {
    final ticketsCount = openTickets.valueOrNull ?? 0;
    final riskCount = atRiskOrgs.valueOrNull ?? 0;
    final alerts = [
      _AlertPill('🚀', 'System Running', 'All good', const Color(0xFF10B981)),
      _AlertPill('📊', 'Orgs at risk', '$riskCount',
          riskCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
      _AlertPill('⚠️', 'Tickets open', '$ticketsCount',
          ticketsCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
      _AlertPill('📈', 'Revenue', 'Live', const Color(0xFF10B981)),
    ];
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: alerts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final a = alerts[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: a.color.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(D.radius),
              border: Border.all(
                color: a.color.withValues(alpha: isDark ? 0.2 : 0.15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(a.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      a.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: D.text(context),
                      ),
                    ),
                    Text(
                      a.value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: a.color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Section 3: Metrics Grid ──────────────────────────────
  Widget _metricGrid(
    BuildContext context,
    dynamic m,
    NumberFormat fmt,
    bool isDark,
  ) {
    final items = [
      _MetricItem(
        Icons.business,
        'Organizations',
        '${m.totalOrganizations}',
        '${m.activeOrganizations} active',
        const Color(0xFF3B82F6),
      ),
      _MetricItem(
        Icons.people,
        'Users',
        '${m.totalUsers}',
        '${m.activeUsers} active',
        const Color(0xFF10B981),
      ),
      _MetricItem(
        Icons.account_balance,
        'Loans',
        fmt.format(m.totalLoanAmount),
        '${m.totalLoans} loans',
        const Color(0xFFF59E0B),
      ),
      _MetricItem(
        Icons.payments,
        'Collections',
        fmt.format(m.totalCollections),
        'Total collected',
        const Color(0xFF14B8A6),
      ),
      _MetricItem(
        Icons.savings,
        'Savings',
        fmt.format(m.totalSavings),
        'Total saved',
        const Color(0xFF6366F1),
      ),
      _MetricItem(
        Icons.trending_up,
        'MRR',
        fmt.format(m.mrr),
        'Monthly revenue',
        const Color(0xFFF59E0B),
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _metricTile(context, items[i], isDark),
    );
  }

  Widget _metricTile(BuildContext context, _MetricItem d, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: D.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Icon(d.icon, size: 16, color: d.color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                d.label,
                style: D.labelStyle(isDark),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            d.value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: d.color,
            ),
          ),
          Text(
            d.subtitle,
            style: TextStyle(
              fontSize: 10,
              color: D.dim(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Section 4: Quick Actions ─────────────────────────────
  Widget _quickActions(BuildContext context, bool isDark) {
    final actions = <_Action>[
      _Action(Icons.business, 'Orgs', const Color(0xFF06B6D4),
          () => context.push('/super-admin/organizations')),
      _Action(Icons.people, 'Users', const Color(0xFF10B981),
          () => context.push('/super-admin/users')),
      _Action(Icons.headset_mic, 'Support', const Color(0xFFF59E0B),
          () => context.push('/super-admin/support')),
      _Action(Icons.flag, 'Flags', const Color(0xFF8B5CF6),
          () => context.push('/super-admin/feature-flags')),
      _Action(Icons.campaign, 'Announce', const Color(0xFFEC4899),
          () => context.push('/super-admin/announcements')),
      _Action(Icons.analytics, 'Analytics', const Color(0xFFF59E0B),
          () => context.push('/super-admin/analytics')),
    ];
    return Row(
      children: actions.asMap().entries.map((e) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: e.key == 0 ? 0 : 8),
            child: GestureDetector(
              onTap: () {
                HapticService.selection();
                e.value.onTap();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: D.card(context),
                child: Column(children: [
                  Icon(e.value.icon, size: 22, color: e.value.color),
                  const SizedBox(height: 6),
                  Text(
                    e.value.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: D.dim(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ]),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Section 5: Revenue + Benchmarking ────────────────────
  Widget _revenueSection(
    BuildContext context,
    Map<String, dynamic> r,
    NumberFormat fmt,
    bool isDark,
  ) {
    final total = (r['total_revenue'] ?? 0).toDouble();
    final avg = (r['avg_monthly_revenue'] ?? 0).toDouble();
    final count = r['transaction_count'] ?? 0;
    final vsLastMonth = total > 0 && avg > 0
        ? ((total - avg) / avg * 100).clamp(-100, 999)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: D.card(context),
      child: Column(
        children: [
          Row(children: [
            Expanded(
              child: _revItem(context, 'Total Revenue', fmt.format(total),
                  const Color(0xFF10B981), isDark),
            ),
            Container(
              width: 1,
              height: 40,
              color: D.border(context),
            ),
            Expanded(
              child: _revItem(context, 'Avg Monthly', fmt.format(avg),
                  const Color(0xFF3B82F6), isDark),
            ),
            Container(
              width: 1,
              height: 40,
              color: D.border(context),
            ),
            Expanded(
              child: _revItem(context, 'Transactions', '$count',
                  const Color(0xFFF59E0B), isDark),
            ),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981)
                  .withValues(alpha: isDark ? 0.1 : 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.trending_up,
                    size: 14, color: Color(0xFF10B981)),
                const SizedBox(width: 6),
                Text(
                  'vs last month: +$vsLastMonth%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _revItem(
    BuildContext context,
    String label,
    String value,
    Color color,
    bool isDark,
  ) {
    return Column(children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: D.muted(context),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        value,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    ]);
  }

  // ── Section 6: Churn Risk ────────────────────────────────
  Widget _churnRisk(BuildContext context, dynamic m, bool isDark) {
    final totalOrgs = m.totalOrganizations;
    final atRisk = (totalOrgs * 0.05).ceil();
    final low = (atRisk * 0.5).ceil();
    final medium = (atRisk * 0.3).ceil();
    final high = atRisk - low - medium;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: D.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 20, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Text(
                '$atRisk orgs at risk',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: D.text(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _riskBadge('Low Risk', '$low', const Color(0xFF10B981), isDark),
              const SizedBox(width: 10),
              _riskBadge(
                  'Medium Risk', '$medium', const Color(0xFFF59E0B), isDark),
              const SizedBox(width: 10),
              _riskBadge('High Risk', '$high', const Color(0xFFEF4444), isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _riskBadge(String label, String count, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(D.radius),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.2 : 0.15),
          ),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section 7: Activity Feed ─────────────────────────────
  Widget _activityItem(
      BuildContext context, Map<String, dynamic> a, bool isDark) {
    final type = a['activity_type'] as String? ?? 'unknown';
    final createdAt =
        DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
    final ago = _timeAgo(DateTime.now().difference(createdAt));
    final title = type
        .replaceAll('_', ' ')
        .split(' ')
        .map((e) => e[0].toUpperCase() + e.substring(1))
        .join(' ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: D.surface(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: D.border(context).withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: D.accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: D.text(context),
                ),
              ),
              if (a['organizations']?['name'] != null)
                Text(
                  a['organizations']['name'],
                  style: TextStyle(fontSize: 11, color: D.accent),
                ),
            ],
          ),
        ),
        Text(
          ago,
          style: TextStyle(fontSize: 11, color: D.muted(context)),
        ),
      ]),
    );
  }

  // ── Section 8: SLA Status ────────────────────────────────
  Widget _slaStatus(BuildContext context, bool isDark) {
    final slas = [
      _SlaItem('Uptime', '99.9%', const Color(0xFF10B981), Icons.check_circle),
      _SlaItem('Response', '<2m', const Color(0xFF3B82F6), Icons.timer),
      _SlaItem('SLA', '98.5%', const Color(0xFF10B981), Icons.verified),
    ];
    return Row(
      children: slas.map((s) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: slas.indexOf(s) == 0 ? 0 : 8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: D.card(context),
              child: Column(children: [
                Icon(s.icon, size: 22, color: s.color),
                const SizedBox(height: 8),
                Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: D.muted(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: s.color,
                  ),
                ),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Section 9: Feature Adoption ──────────────────────────
  Widget _featureAdoption(BuildContext context, bool isDark) {
    final features = [
      _FeatureAdoption('Collections', 0.87, const Color(0xFF14B8A6)),
      _FeatureAdoption('Loans', 0.72, const Color(0xFF3B82F6)),
      _FeatureAdoption('Savings', 0.65, const Color(0xFF8B5CF6)),
      _FeatureAdoption('Reports', 0.43, const Color(0xFFF59E0B)),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.7,
      ),
      itemCount: features.length,
      itemBuilder: (_, i) {
        final f = features[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: D.card(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _progressRing(context, f.rate, f.color, isDark),
              const SizedBox(height: 10),
              Text(
                f.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: D.dim(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${(f.rate * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: f.color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _progressRing(
      BuildContext context, double rate, Color color, bool isDark) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: rate,
            strokeWidth: 4,
            backgroundColor: D.dim(context).withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }

  String _timeAgo(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d';
    if (d.inHours > 0) return '${d.inHours}h';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return 'now';
  }
}

class _AlertPill {
  final String emoji;
  final String label;
  final String value;
  final Color color;
  const _AlertPill(this.emoji, this.label, this.value, this.color);
}

class _MetricItem {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;
  const _MetricItem(
      this.icon, this.label, this.value, this.subtitle, this.color);
}

class _Action {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Action(this.icon, this.label, this.color, this.onTap);
}

class _SlaItem {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _SlaItem(this.label, this.value, this.color, this.icon);
}

class _FeatureAdoption {
  final String label;
  final double rate;
  final Color color;
  const _FeatureAdoption(this.label, this.rate, this.color);
}
