import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SuperAdminShell extends ConsumerStatefulWidget {
  final Widget child;
  const SuperAdminShell({super.key, required this.child});

  @override
  ConsumerState<SuperAdminShell> createState() => _SuperAdminShellState();
}

class _SuperAdminShellState extends ConsumerState<SuperAdminShell> {
  final _navSections = [
    _NavSection('Main', [
      _NavItem(Icons.dashboard, 'Dashboard', '/super-admin'),
      _NavItem(Icons.assessment, 'Executive Summary',
          '/super-admin/executive-summary'),
      _NavItem(Icons.business, 'Organizations', '/super-admin/organizations'),
    ]),
    _NavSection('Management', [
      _NavItem(Icons.people, 'Users', '/super-admin/users'),
      _NavItem(Icons.headset_mic, 'Support', '/super-admin/support'),
      _NavItem(Icons.receipt_long, 'Billing', '/super-admin/billing'),
      _NavItem(Icons.history, 'Audit Logs', '/super-admin/audit-logs'),
      _NavItem(Icons.flag, 'Feature Flags', '/super-admin/feature-flags'),
      _NavItem(Icons.campaign, 'Announcements', '/super-admin/announcements'),
    ]),
    _NavSection('System', [
      _NavItem(Icons.miscellaneous_services, 'Platform Health',
          '/super-admin/health'),
      _NavItem(Icons.shield, 'Security Scorecard', '/super-admin/security'),
      _NavItem(Icons.build, 'Maintenance', '/super-admin/maintenance'),
      _NavItem(Icons.settings, 'Settings', '/super-admin/settings'),
      _NavItem(Icons.toggle_on, 'System Controls', '/super-admin/controls'),
    ]),
    _NavSection('Growth', [
      _NavItem(Icons.analytics, 'Analytics', '/super-admin/analytics'),
      _NavItem(Icons.trending_up, 'Feature Adoption', '/super-admin/adoption'),
      _NavItem(Icons.feedback, 'NPS Survey', '/super-admin/nps'),
      _NavItem(Icons.notifications, 'Notification Center',
          '/super-admin/notifications'),
    ]),
    _NavSection('Operations', [
      _NavItem(Icons.receipt, 'Reconciliation', '/super-admin/reconciliation'),
      _NavItem(Icons.checklist, 'Onboarding', '/super-admin/onboarding'),
      _NavItem(Icons.report, 'Report Center', '/super-admin/reports'),
      _NavItem(Icons.queue, 'Background Jobs', '/super-admin/jobs'),
      _NavItem(Icons.map, 'Platform Map', '/super-admin/map'),
    ]),
  ];

  final _mobileItems = [
    _NavItem(Icons.dashboard, 'Dashboard', '/super-admin'),
    _NavItem(Icons.business, 'Orgs', '/super-admin/organizations'),
    _NavItem(Icons.people, 'Users', '/super-admin/users'),
    _NavItem(Icons.headset_mic, 'Support', '/super-admin/support'),
    _NavItem(Icons.settings, 'Settings', '/super-admin/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: D.bg(context),
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              _SideNav(
                sections: _navSections,
                isDark: isDark,
                onSignOut: () async {
                  await ref.read(authProvider.notifier).signOut();
                  if (context.mounted) context.go('/auth');
                },
              ),
            Expanded(
              child: Column(
                children: [
                  if (!wide) _TopBar(isDark: isDark, items: _mobileItems),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          wide ? null : _BottomNav(items: _mobileItems, isDark: isDark),
    );
  }
}

class _NavSection {
  final String label;
  final List<_NavItem> items;
  const _NavSection(this.label, this.items);
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  const _NavItem(this.icon, this.label, this.route);
}

class _SideNav extends StatelessWidget {
  final List<_NavSection> sections;
  final bool isDark;
  final VoidCallback onSignOut;
  const _SideNav(
      {required this.sections, required this.isDark, required this.onSignOut});

  bool _selected(_NavItem item, BuildContext ctx) {
    final loc = GoRouterState.of(ctx).matchedLocation;
    return loc.startsWith(item.route);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: D.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: D.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: D.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'MicroFlow',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: D.text(context),
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Super Admin',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: D.accent,
                    letterSpacing: 0.4,
                  ),
                ),
              ]),
            ]),
          ),
          Divider(height: 1, color: D.border(context)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: sections.map((section) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 6),
                      child: Text(
                        section.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: D.muted(context),
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    ...section.items.map((item) => _sideItem(context, item)),
                  ],
                );
              }).toList(),
            ),
          ),
          _signOut(context, onSignOut),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _sideItem(BuildContext ctx, _NavItem item) {
    final sel = _selected(item, ctx);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => ctx.go(item.route),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: sel
                  ? D.accent.withValues(alpha: isDark ? 0.12 : 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: sel
                  ? Border.all(
                      color: D.accent.withValues(alpha: isDark ? 0.2 : 0.15))
                  : null,
            ),
            child: Row(children: [
              Icon(
                item.icon,
                size: 20,
                color: sel ? D.accent : D.iconMuted(ctx),
              ),
              const SizedBox(width: 14),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                  color: sel ? D.accent : D.text(ctx).withValues(alpha: 0.65),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _signOut(BuildContext ctx, VoidCallback onSignOut) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onSignOut,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: isDark ? 0.08 : 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(Icons.logout,
                  size: 18, color: Colors.red.withValues(alpha: 0.8)),
              const SizedBox(width: 12),
              Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.red.withValues(alpha: 0.8),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool isDark;
  final List<_NavItem> items;
  const _TopBar({required this.isDark, required this.items});

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final current = items.indexWhere((i) => loc.startsWith(i.route));
    final label = current >= 0 ? items[current].label : 'Dashboard';

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.of(context).padding.top + 10,
            16,
            12,
          ),
          decoration: BoxDecoration(
            color: D.surface(context).withValues(alpha: 0.85),
            border: Border(bottom: BorderSide(color: D.border(context))),
          ),
          child: Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: D.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: D.text(context),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final List<_NavItem> items;
  final bool isDark;
  const _BottomNav({required this.items, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: D.surface(context).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: D.border(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: items.asMap().entries.map((e) {
              final item = e.value;
              final sel = loc.startsWith(item.route);
              return GestureDetector(
                onTap: () {
                  HapticService.selection();
                  context.go(item.route);
                },
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 56,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        size: 22,
                        color: sel ? D.accent : D.iconMuted(context),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                          color: sel ? D.accent : D.muted(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
