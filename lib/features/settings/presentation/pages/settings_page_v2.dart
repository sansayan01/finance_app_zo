import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/powered_by_badge.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/providers/brand_provider.dart';
import '../providers/settings_provider.dart';

class SettingsPageV2 extends ConsumerWidget {
  const SettingsPageV2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final isExecAdmin = user?.role == UserRole.executiveAdmin;
    final brand = ref.watch(brandProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Premium Large App Bar
            SliverAppBar(
              expandedHeight: 140.0,
              collapsedHeight: 70.0,
              floating: false,
              pinned: true,
              backgroundColor: theme.scaffoldBackgroundColor,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                centerTitle: false,
                title: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        color: theme.textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.email ?? 'Organization Administration',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.normal,
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Scrollable Menu List
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ─── SECTION 1: ACCOUNT & PERSONAL ──────────────────
                  _buildSectionHeader(theme, 'ACCOUNT & PREFERENCES'),
                  _buildMenuCard(
                    theme: theme,
                    icon: Icons.person_outline_rounded,
                    title: 'Profile Settings',
                    subtitle: 'Name, phone, email, and security password',
                    color: AppColors.primary,
                    onTap: () => context.push('/settings/profile'),
                  ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 12),
                  
                  _buildQuickSettingsCard(theme, ref)
                      .animate()
                      .fadeIn(delay: 80.ms)
                      .slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 28),

                  // ─── SECTION 2: ORGANIZATION (Exec Admin Only) ──────
                  if (isExecAdmin) ...[
                    _buildSectionHeader(theme, 'ORGANIZATION CONTROLS'),
                    _buildMenuCard(
                      theme: theme,
                      icon: Icons.business_outlined,
                      title: 'Organization Settings',
                      subtitle: 'Brand identity, legal profile, address, compliance, and home screen icon',
                      color: Colors.blue,
                      onTap: () => context.push('/settings/organization'),
                    ).animate().fadeIn(delay: 110.ms).slideY(begin: 0.05, end: 0),
                    const SizedBox(height: 12),

                    _buildMenuCard(
                      theme: theme,
                      icon: Icons.account_balance_outlined,
                      title: 'Loan & Savings Products',
                      subtitle: 'Setup loan schemes, savings rules, yield rates, and limits',
                      color: Colors.indigo,
                      badgeText: 'P0',
                      badgeColor: Colors.red,
                      onTap: () => _showComingSoon(
                        context,
                        'Product Engine CRUD',
                        'Allows complete creation and editing of dynamic loan types (rates, charges, grace buffers) and savings programs.',
                        Colors.red,
                      ),
                    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05, end: 0),
                    const SizedBox(height: 28),
                  ],

                  // ─── SECTION 3: INTEGRATIONS & SHIELD ───────────────
                  if (isExecAdmin) ...[
                    _buildSectionHeader(theme, 'SYSTEM CONNECTIVITY'),
                    _buildMenuCard(
                      theme: theme,
                      icon: Icons.integration_instructions_outlined,
                      title: 'Integrations & Third-Party APIs',
                      subtitle: 'Configure NVIDIA NIM, Twilio SMS alerts, WhatsApp, and SMTP',
                      color: Colors.teal,
                      onTap: () => context.push('/settings/integrations'),
                    ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.05, end: 0),
                    const SizedBox(height: 28),
                  ],

                  // ─── SECTION 4: SECURITY & COMPLIANCE ────────────────
                  _buildSectionHeader(theme, 'SECURITY & COMPLIANCE'),
                  _buildMenuCard(
                    theme: theme,
                    icon: Icons.security_rounded,
                    title: 'Security Shield & Activity Logs',
                    subtitle: 'Audit logs, session locks, passwords, and data exports',
                    color: Colors.orange,
                    onTap: () => context.push('/settings/security'),
                  ).animate().fadeIn(delay: 210.ms).slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 28),

                  // ─── SECTION 5: UTILITIES & SUPPORT ──────────────────
                  _buildSectionHeader(theme, 'UTILITIES & SUPPORT'),
                  _buildMenuCard(
                    theme: theme,
                    icon: Icons.support_agent_rounded,
                    title: 'Technical Help & Legal Policy',
                    subtitle: 'FAQs, ticket creation, privacy policies, and terms of service',
                    color: Colors.blueGrey,
                    onTap: () => _showSupportDialog(context),
                  ).animate().fadeIn(delay: 240.ms).slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 12),

                  _buildMenuCard(
                    theme: theme,
                    icon: Icons.logout_rounded,
                    title: 'Sign Out',
                    subtitle: 'Safely terminate active MFI session from this device',
                    color: Colors.redAccent,
                    onTap: () => _confirmSignOut(context, ref),
                  ).animate().fadeIn(delay: 270.ms).slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 48),

                  // App Version Footer
                  Center(
                    child: Column(
                      children: [
                        Text(
                          '${brand.name} Enterprise Edition',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'v1.0.8-production • Sealed SSL Layer',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.3),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const PoweredByBadge(compact: true),
                      ],
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── HELPER WIDGETS ────────────────────────────────────────────────
  Widget _buildSectionHeader(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.45),
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    String? badgeText,
    Color? badgeColor,
  }) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (badgeColor ?? Colors.grey).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: badgeColor ?? Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.3),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickSettingsCard(ThemeData theme, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                'Quick Device Preferences',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          
          // Dark Mode Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Interface Dark Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('Switch app background shading', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              Switch.adaptive(
                value: isDark,
                onChanged: (_) => ref.read(themeProvider.notifier).toggleTheme(),
                activeTrackColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Biometrics Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Biometric Authentication', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('Fingerprint or Face ID shortcut', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              Switch.adaptive(
                value: settings.biometricAuth,
                onChanged: notifier.toggleBiometric,
                activeTrackColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Push Notifications Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Push Alerts & Pings', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('Alerts on approvals & tasks', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              Switch.adaptive(
                value: settings.enableNotifications,
                onChanged: notifier.toggleNotifications,
                activeTrackColor: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── ACTION DIALOGS ────────────────────────────────────────────────
  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to exit your administrative session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).signOut();
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String title, String description, Color color) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ROADMAP',
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.construction_rounded, size: 16, color: Colors.amber),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Development pipeline schedule. Fully offline capable.',
                      style: TextStyle(fontSize: 12, color: Colors.amber),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSupportDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Technical Support & Policy',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.help_center_outlined, color: AppColors.primary),
              title: const Text('Help Center & FAQs', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Guides, tutorials, and troubleshooting walkthroughs'),
              onTap: () {
                Navigator.pop(ctx);
                _showComingSoon(context, 'Help Center', 'Full searchable handbook of support articles and localized videos.', Colors.blueGrey);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined, color: Colors.orange),
              title: const Text('Report a System Glitch', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Submit ticket directly to the platform Super Admins'),
              onTap: () {
                Navigator.pop(ctx);
                _showComingSoon(context, 'Support Ticketing', 'Seamless logging of errors with active screenshots and device log attachments.', Colors.blueGrey);
              },
            ),
            ListTile(
              leading: const Icon(Icons.policy_outlined, color: Colors.teal),
              title: const Text('Privacy Policy & Terms', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Information on regulatory compliance and data storage'),
              onTap: () {
                Navigator.pop(ctx);
                _showComingSoon(context, 'Policies & Disclosures', 'Official legal disclosures and local regulatory mandates.', Colors.blueGrey);
              },
            ),
          ],
        ),
      ),
    );
  }
}
