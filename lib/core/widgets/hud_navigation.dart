import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/haptic_service.dart';

/// A premium iOS-style floating top navigation bar for desktop.
class HUDNavigation extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<HUDNavItem> items;

  const HUDNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  State<HUDNavigation> createState() => _HUDNavigationState();
}

class _HUDNavigationState extends State<HUDNavigation>
    with SingleTickerProviderStateMixin {
  // Created once in initState. The shell rebuilds this widget on every route
  // change, but the element (and thus this state) is preserved — so the
  // entrance animation plays exactly once instead of replaying on each tap.
  late final AnimationController _enterController;

  @override
  void initState() {
    super.initState();
    _enterController =
        AnimationController(vsync: this, duration: 400.ms)
          ..forward();
  }

  @override
  void dispose() {
    _enterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    final nav = Container(
      margin: const EdgeInsets.only(top: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: isDark ? 0.08 : 0.25),
                  Colors.transparent,
                ],
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.3),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                widget.items.length,
                (index) => _buildHUDItem(context, index, primary),
              ),
            ),
          ),
        ),
      ),
    );

    return Animate(
      controller: _enterController,
      effects: const [
        FadeEffect(duration: Duration(milliseconds: 400)),
        SlideEffect(
          begin: Offset(0, -0.2),
          end: Offset.zero,
          curve: Curves.easeOut,
        ),
      ],
      child: nav,
    );
  }

  Widget _buildHUDItem(BuildContext context, int index, Color primary) {
    final item = widget.items[index];
    final isSelected = widget.currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticService.selection();
        widget.onTap(index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: isDark ? 0.2 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? item.activeIcon : item.icon,
              color: isSelected
                  ? primary
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.4)),
              size: 20,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                item.label,
                style: TextStyle(
                  color: primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class HUDNavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const HUDNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

class FloatingHUD extends StatelessWidget {
  final Widget child;
  final bool showNav;
  final int currentIndex;
  final ValueChanged<int>? onNavTap;
  final List<HUDNavItem>? navItems;

  const FloatingHUD({
    super.key,
    required this.child,
    this.showNav = true,
    this.currentIndex = 0,
    this.onNavTap,
    this.navItems,
  });

  @override
  Widget build(BuildContext context) {
    final useHudNav = MediaQuery.of(context).size.width >= 600;

    return Stack(
      children: [
        child,
        if (showNav && useHudNav && navItems != null && onNavTap != null)
          Positioned(
            left: 0,
            right: 0,
            top: 16,
            child: Center(
              child: HUDNavigation(
                currentIndex: currentIndex,
                onTap: onNavTap!,
                items: navItems!,
              ),
            ),
          ),
      ],
    );
  }
}
