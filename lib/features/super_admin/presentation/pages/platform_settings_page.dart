import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/providers/super_admin_providers.dart';

class PlatformSettingsPage extends ConsumerStatefulWidget {
  const PlatformSettingsPage({super.key});
  @override
  ConsumerState<PlatformSettingsPage> createState() => _PlatformSettingsPageState();
}

class _PlatformSettingsPageState extends ConsumerState<PlatformSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = D.bg(context);
    final cardBg = D.surface(context);
    final settings = ref.watch(platformSettingsProvider);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: D.bodyPad,
              sliver: SliverToBoxAdapter(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  D.header('Settings', 'Platform configuration', isDark),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
            settings.when(
              data: (s) => SliverPadding(
                padding: D.bodyBottomPad,
                sliver: SliverToBoxAdapter(
                  child: Column(children: [
                    _section(isDark, cardBg, 'General', Icons.settings, D.accent, [
                      _tile(Icons.email, 'SMTP', s['smtp_configured'] == true ? 'Configured' : 'Not configured', s['smtp_configured'] == true ? Colors.green : Colors.orange, isDark),
                      _tile(Icons.sms, 'SMS Gateway', s['sms_configured'] == true ? 'Configured' : 'Not configured', s['sms_configured'] == true ? Colors.green : Colors.orange, isDark),
                      _tile(Icons.storage, 'Storage', s['storage_provider'] ?? 'Supabase', D.accent, isDark),
                      _tile(Icons.api, 'Rate Limit', '${s['api_rate_limit'] ?? 60}/min', D.accent, isDark),
                    ]),
                    const SizedBox(height: 16),
                    _section(isDark, cardBg, 'Security', Icons.security, Colors.green, [
                      _tile(Icons.lock, 'Password Policy', s['password_min_length'] != null ? '${s['password_min_length']} chars' : 'Default', D.accent, isDark),
                      _tile(Icons.timer, 'Session Timeout', s['session_timeout_minutes'] != null ? '${s['session_timeout_minutes']}m' : '30m', D.accent, isDark),
                      _tile(Icons.verified_user, '2FA', s['enforce_2fa'] == true ? 'Enabled' : 'Disabled', s['enforce_2fa'] == true ? Colors.green : D.mutedColor(isDark), isDark),
                    ]),
                    const SizedBox(height: 16),
                    _section(isDark, cardBg, 'App', Icons.info, Colors.purple, [
                      _tile(Icons.info, 'Version', s['app_version'] ?? '1.0.0', D.accent, isDark),
                      _tile(Icons.description, 'Terms', (s['terms_updated'] as String?)?.substring(0, 10) ?? 'N/A', D.accent, isDark),
                      _tile(Icons.privacy_tip, 'Privacy', (s['privacy_updated'] as String?)?.substring(0, 10) ?? 'N/A', D.accent, isDark),
                    ]),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: isDark ? 0.06 : 0.04), borderRadius: BorderRadius.circular(D.radiusLg), border: Border.all(color: Colors.red.withValues(alpha: 0.15))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [Icon(Icons.warning_amber, size: 18, color: Colors.red), const SizedBox(width: 8), Text('Danger Zone', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.red))]),
                        const SizedBox(height: 16),
                        SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.delete_sweep, size: 18), label: const Text('Clear Cache'), style: OutlinedButton.styleFrom(foregroundColor: Colors.orange, side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(D.radius))))),
                        const SizedBox(height: 12),
                        SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () async {
                          HapticService.light();
                          await ref.read(authProvider.notifier).signOut();
                          if (context.mounted) context.go('/auth');
                        }, icon: const Icon(Icons.logout, size: 18), label: const Text('Sign Out'), style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: BorderSide(color: Colors.red.withValues(alpha: 0.3)), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(D.radius))))),
                      ]),
                    ),
                  ]),
                ),
              ),
              loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(bool isDark, Color cardBg, String title, IconData icon, Color iconColor, List<Widget> tiles) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(D.radiusLg), border: Border.all(color: D.border(context))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: iconColor, size: 18)), const SizedBox(width: 10), Text(title, style: D.titleStyle(isDark))]),
        const SizedBox(height: 16),
        ...tiles,
      ]),
    );
  }

  Widget _tile(IconData icon, String label, String value, Color valueColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 18, color: D.iconMuted(context)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: D.valueStyle(isDark))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: valueColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: valueColor))),
      ]),
    );
  }
}
