import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/providers/staff_providers.dart';
import '../../../../core/widgets/branded_loading.dart';

class StaffSettingsPage extends ConsumerStatefulWidget {
  const StaffSettingsPage({super.key});

  @override
  ConsumerState<StaffSettingsPage> createState() => _StaffSettingsPageState();
}

class _StaffSettingsPageState extends ConsumerState<StaffSettingsPage> {
  bool _gpsTracking = true;
  bool _offlineMode = true;
  bool _notificationsEnabled = true;
  bool _biometricEnabled = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final profileAsync = ref.watch(staffProfileProvider);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_rounded,
              color: isDark ? Colors.white70 : Colors.black87),
        ),
        title: Text('Settings',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileCard(theme, isDark, profileAsync),
              const SizedBox(height: 24),
              _buildSection(theme, isDark, 'Preferences', Icons.tune_rounded, [
                _buildSwitchTile(
                    theme,
                    'Dark Mode',
                    'Switch between light and dark themes',
                    Icons.dark_mode_outlined,
                    isDark, (_) {
                  ref.read(themeProvider.notifier).toggleTheme();
                }),
                _buildSwitchTile(
                    theme,
                    'GPS Tracking',
                    'Enable location tracking during collections',
                    Icons.gps_fixed_rounded,
                    _gpsTracking, (v) {
                  setState(() => _gpsTracking = v);
                }),
                _buildSwitchTile(
                    theme,
                    'Offline Mode',
                    'Store data locally when offline',
                    Icons.wifi_off_rounded,
                    _offlineMode, (v) {
                  setState(() => _offlineMode = v);
                }),
                _buildSwitchTile(
                    theme,
                    'Notifications',
                    'Collection reminders and alerts',
                    Icons.notifications_outlined,
                    _notificationsEnabled, (v) {
                  setState(() => _notificationsEnabled = v);
                }),
              ]),
              const SizedBox(height: 16),
              _buildSection(
                  theme, isDark, 'Account', Icons.person_outline_rounded, [
                _buildActionTile(
                    theme,
                    'Edit Profile',
                    'Update your name, phone and email',
                    Icons.badge_outlined,
                    AppColors.primary, () {
                  context.push('/settings/profile');
                }),
                _buildActionTile(
                    theme,
                    'Change Password',
                    'Update your login credentials',
                    Icons.lock_outline_rounded,
                    Colors.orangeAccent,
                    () {}),
                _buildSwitchTile(
                    theme,
                    'Biometric Auth',
                    'Use fingerprint or face ID to login',
                    Icons.fingerprint,
                    _biometricEnabled, (v) {
                  setState(() => _biometricEnabled = v);
                }),
              ]),
              const SizedBox(height: 16),
              _buildSection(
                  theme, isDark, 'Support', Icons.help_outline_rounded, [
                _buildActionTile(
                    theme,
                    'Help Center',
                    'FAQs, guides and tutorials',
                    Icons.library_books_outlined,
                    AppColors.teal,
                    () {}),
                _buildActionTile(
                    theme,
                    'Report an Issue',
                    'Technical support and bug reports',
                    Icons.bug_report_outlined,
                    Colors.orange,
                    () {}),
              ]),
              const SizedBox(height: 16),
              _buildSection(
                  theme, isDark, 'About', Icons.info_outline_rounded, [
                _buildInfoTile(theme, 'App Version', '1.0.4-stable'),
                _buildInfoTile(theme, 'Staff Code',
                    profileAsync.valueOrNull?.staffCode ?? '-'),
                _buildInfoTile(
                    theme,
                    'Role',
                    profileAsync.valueOrNull?.role.displayName
                            .replaceAll('_', ' ')
                            .toUpperCase() ??
                        '-'),
                _buildInfoTile(theme, 'Branch',
                    profileAsync.valueOrNull?.branchName ?? '-'),
              ]),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _handleSignOut(context),
                  icon:
                      const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  label: const Text('Sign Out',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                        color: Colors.redAccent.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(
      ThemeData theme, bool isDark, AsyncValue profileAsync) {
    return profileAsync.when(
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    _getInitials(profile.fullName),
                    style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.fullName,
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18)),
                    const SizedBox(height: 2),
                    Text(profile.staffCode,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(profile.branchName ?? 'No Branch',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11)),
                        const SizedBox(width: 8),
                        Container(
                            width: 1,
                            height: 10,
                            color: Colors.white.withValues(alpha: 0.2)),
                        const SizedBox(width: 8),
                        DynamicBrandText(
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.w800),
                          uppercase: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  profile.role.displayName.toUpperCase(),
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, end: 0);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSection(ThemeData theme, bool isDark, String title,
      IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Text(title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, end: 0);
  }

  Widget _buildSwitchTile(ThemeData theme, String title, String subtitle,
      IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5))),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildActionTile(ThemeData theme, String title, String subtitle,
      IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500)),
          Text(value,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
        ],
      ),
    );
  }

  void _handleSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).signOut();
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
