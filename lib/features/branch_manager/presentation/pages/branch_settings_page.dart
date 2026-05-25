// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/providers/branch_scoped_providers.dart';

/// Premium branch settings page for Branch Manager Portal.
/// Shows branch info, manager profile, operations, and account settings.
class BranchSettingsPage extends ConsumerWidget {
  const BranchSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authProvider).user;
    final branchId = user?.branchId;

    final branchAsync = branchId != null
        ? ref.watch(branchInfoProvider(branchId))
        : const AsyncData<Map<String, dynamic>?>(null);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF2F2F7),
      body: AuroraBackground(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // App Bar
            SliverAppBar(
              pinned: true,
              elevation: 0,
              backgroundColor: isDark
                  ? const Color(0xFF0A0A0C).withValues(alpha: 0.85)
                  : const Color(0xFFF2F2F7).withValues(alpha: 0.85),
              surfaceTintColor: Colors.transparent,
              title: Text(
                'Settings',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              systemOverlayStyle: isDark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
            ),

            // Profile Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: _buildProfileCard(theme, isDark, user),
              ),
            ),

            // Branch Info Section
            SliverToBoxAdapter(
              child: branchAsync.when(
                data: (branch) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: _buildBranchInfoCard(context, theme, isDark, branch),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // Operations Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: _buildSectionCard(
                  theme, isDark,
                  title: 'Operations',
                  icon: Icons.settings_rounded,
                  items: [
                    _SettingItem(
                      icon: Icons.receipt_long_rounded,
                      title: 'Collection Settings',
                      subtitle: 'Payment modes and receipt settings',
                      onTap: () {},
                    ),
                    _SettingItem(
                      icon: Icons.notifications_active_rounded,
                      title: 'Notifications',
                      subtitle: 'Configure branch alerts and reminders',
                      onTap: () {},
                    ),
                    _SettingItem(
                      icon: Icons.print_rounded,
                      title: 'Receipt Template',
                      subtitle: 'Customize branch receipt format',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),

            // Account Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: _buildSectionCard(
                  theme, isDark,
                  title: 'Account',
                  icon: Icons.person_rounded,
                  items: [
                    _SettingItem(
                      icon: Icons.lock_rounded,
                      title: 'Change Password',
                      subtitle: 'Update your account password',
                      onTap: () {},
                    ),
                    _SettingItem(
                      icon: Icons.security_rounded,
                      title: 'Privacy & Security',
                      subtitle: 'Manage your account security',
                      onTap: () {},
                    ),
                    _SettingItem(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & Support',
                      subtitle: 'Get help with the app',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),

            // Logout
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: GestureDetector(
                  onTap: () => _showLogoutDialog(context, ref),
                  child: GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Logout',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // App Info
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Center(
                  child: Text(
                    'MicroFlow Pro v1.0.0',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white30 : Colors.black38,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // Profile Card
  Widget _buildProfileCard(ThemeData theme, bool isDark, UserModel? user) {
    final name = user?.fullName ?? 'Branch Manager';
    final email = user?.email ?? '';
    final phone = user?.phone ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'B';

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.8),
                  AppColors.accent.withValues(alpha: 0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    phone,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Manager',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  // Branch Info Card
  Widget _buildBranchInfoCard(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    Map<String, dynamic>? branch,
  ) {
    final name = branch?['name']?.toString() ?? 'Branch';
    final address = branch?['address']?.toString() ?? '';
    final city = branch?['city']?.toString() ?? '';
    final code = branch?['code']?.toString() ?? '';
    final status = branch?['status']?.toString() ?? 'active';
    final phone = branch?['phone']?.toString() ?? '';
    final email = branch?['email']?.toString() ?? '';

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.business_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                'Branch Information',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 'active'
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status[0].toUpperCase() + status.substring(1),
                  style: TextStyle(
                    color: status == 'active' ? AppColors.success : AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          if (code.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Code: $code',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white54 : Colors.black45,
                fontSize: 12,
              ),
            ),
          ],
          if (address.isNotEmpty || city.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              theme, isDark,
              icon: Icons.location_on_rounded,
              label: [address, city].where((s) => s.isNotEmpty).join(', '),
            ),
          ],
          if (phone.isNotEmpty)
            _buildInfoRow(
              theme, isDark,
              icon: Icons.phone_rounded,
              label: phone,
              onTap: () => launchUrl(Uri.parse('tel:$phone')),
            ),
          if (email.isNotEmpty)
            _buildInfoRow(
              theme, isDark,
              icon: Icons.email_rounded,
              label: email,
              onTap: () => launchUrl(Uri.parse('mailto:$email')),
            ),
          if (branch == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Branch details not available',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildInfoRow(
    ThemeData theme,
    bool isDark, {
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 16, color: isDark ? Colors.white38 : Colors.black38),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 13,
                  decoration: onTap != null ? TextDecoration.underline : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Section Card
  Widget _buildSectionCard(
    ThemeData theme,
    bool isDark, {
    required String title,
    required IconData icon,
    required List<_SettingItem> items,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.asMap().entries.map((entry) {
            final item = entry.value;
            final isLast = entry.key == items.length - 1;
            return Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: item.onTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : AppColors.primary.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              item.icon,
                              size: 18,
                              color: isDark ? Colors.white60 : AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  item.subtitle,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color:
                                isDark ? Colors.white24 : Colors.black26,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Divider(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05),
                    height: 1,
                  ),
              ],
            );
          }),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  // Logout Dialog
  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).signOut();
              context.go('/login');
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
