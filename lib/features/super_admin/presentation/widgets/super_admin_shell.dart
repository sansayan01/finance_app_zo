import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/hud_navigation.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/constants/enums.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SuperAdminShell extends ConsumerStatefulWidget {
  final Widget child;
  const SuperAdminShell({super.key, required this.child});

  @override
  ConsumerState<SuperAdminShell> createState() => _SuperAdminShellState();
}

class _SuperAdminShellState extends ConsumerState<SuperAdminShell> {
  static const _navItems = [
    HUDNavItem(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard),
    HUDNavItem(
        label: 'Orgs',
        icon: Icons.business_outlined,
        activeIcon: Icons.business),
    HUDNavItem(
        label: 'Users',
        icon: Icons.people_outline,
        activeIcon: Icons.people),
    HUDNavItem(
        label: 'Settings',
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings),
  ];

  static const _routes = [
    '/super-admin',
    '/super-admin/organizations',
    '/super-admin/users',
    '/super-admin/settings',
  ];

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < _routes.length; i++) {
      if (loc.startsWith(_routes[i])) return i;
    }
    return 0;
  }

  void _onTap(int index, BuildContext context) {
    HapticService.selection();
    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (user.role != UserRole.superAdmin) {
      return const Scaffold(body: Center(child: Text('Access denied')));
    }

    final useHud = MediaQuery.of(context).size.width >= 600;
    final currentIndex = _selectedIndex(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: Stack(
        children: [
          useHud ? widget.child : _NavSafeArea(child: widget.child),
          if (useHud)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Center(
                child: HUDNavigation(
                  currentIndex: currentIndex,
                  onTap: (i) => _onTap(i, context),
                  items: _navItems,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: useHud
          ? null
          : _SuperAdminBottomBar(
              currentIndex: currentIndex,
              onTap: (i) => _onTap(i, context),
            ),
    );
  }
}

// ── Premium Bottom Bar (matches exec admin / branch manager) ──
class _SuperAdminBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _SuperAdminBottomBar(
      {required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    final items = [
      (Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
      (Icons.business_outlined, Icons.business, 'Orgs'),
      (Icons.people_outline, Icons.people, 'Users'),
      (Icons.settings_outlined, Icons.settings, 'Settings'),
    ];

    return SafeArea(
      top: false,
      minimum: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF3E3E4A).withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: isDark ? 0.15 : 0.4),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.5),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: isDark ? 0.6 : 0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                    spreadRadius: -2,
                  ),
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: isDark ? 0.4 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final (icon, activeIcon, label) = entry.value;
                  final sel = currentIndex == i;
                  return GestureDetector(
                    onTap: () {
                      HapticService.selection();
                      onTap(i);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedScale(
                      scale: sel ? 1.1 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel
                              ? primary.withValues(alpha: isDark ? 0.2 : 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              sel ? activeIcon : icon,
                              size: 22,
                              color: sel
                                  ? primary
                                  : (isDark
                                      ? Colors.white54
                                      : Colors.black38),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight:
                                    sel ? FontWeight.w600 : FontWeight.w500,
                                color: sel
                                    ? primary
                                    : (isDark
                                        ? Colors.white54
                                        : Colors.black38),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Mobile Safe Area Inflater ─────────────────────────────
class _NavSafeArea extends StatelessWidget {
  final Widget child;
  const _NavSafeArea({required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
          padding: EdgeInsets.only(bottom: mq.padding.bottom + 15)),
      child: child,
    );
  }
}
