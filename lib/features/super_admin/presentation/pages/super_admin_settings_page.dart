import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SuperAdminSettingsPage extends ConsumerWidget {
  const SuperAdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    // ── Header ────────────────────────────────
                    Text('Settings', style: D.h1(isDark)),
                    const SizedBox(height: 4),
                    Text(
                      'Platform configuration',
                      style: TextStyle(fontSize: 14, color: D.muted(context)),
                    ),
                    const SizedBox(height: 32),

                    // ── Appearance ───────────────────────────
                    _themeToggle(context, ref, isDark),
                    const SizedBox(height: 16),

                    // ── Danger Zone ──────────────────────────
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: D.card(context).color,
                        borderRadius: BorderRadius.circular(D.radius),
                        border: Border.all(
                          color:
                              const Color(0xFFEF4444).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  size: 18, color: Color(0xFFEF4444)),
                              const SizedBox(width: 8),
                              Text(
                                'Danger Zone',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: () async {
                              HapticService.selection();
                              await ref
                                  .read(authProvider.notifier)
                                  .signOut();
                              if (context.mounted) context.go('/auth');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444)
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFEF4444)
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.logout,
                                      size: 16, color: Color(0xFFEF4444)),
                                  SizedBox(width: 8),
                                  Text(
                                    'Sign Out',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeToggle(BuildContext context, WidgetRef ref, bool isDark) {
    final themeMode = ref.watch(themeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: D.card(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: D.accent.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isDarkMode ? Icons.dark_mode : Icons.light_mode,
              size: 18,
              color: D.accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: D.text(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isDarkMode ? 'Dark mode' : 'Light mode',
                  style: TextStyle(
                    fontSize: 12,
                    color: D.muted(context),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isDarkMode,
            onChanged: (v) {
              HapticService.selection();
              ref.read(themeProvider.notifier).toggleTheme();
            },
            activeThumbColor: D.accent,
          ),
        ],
      ),
    );
  }
}
