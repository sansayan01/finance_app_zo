import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/providers/brand_provider.dart';
import '../providers/settings_provider.dart';
import '../../../chatbot/presentation/providers/chat_config_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  fontSize: 32,
                ),
              ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.05, end: 0),
              const SizedBox(height: 4),
              Text(
                'Customize your experience',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 15),
              ).animate().fadeIn(delay: 50.ms),
              _SectionCard(
                title: 'Account & Profile',
                icon: Icons.person_outline_rounded,
                children: [
                  _ActionRow(
                    title: 'Edit Profile',
                    subtitle: 'Change name, phone, email or password',
                    icon: Icons.badge_outlined,
                    color: primary,
                    onTap: () => context.push('/settings/profile'),
                  ),
                ],
              ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.04, end: 0),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Appearance',
                icon: Icons.palette_outlined,
                children: [
                  _SwitchRow(
                    title: 'Dark Mode',
                    subtitle: 'Switch between light and dark themes',
                    value: ref.watch(themeProvider) == ThemeMode.dark,
                    onChanged: (_) =>
                        ref.read(themeProvider.notifier).toggleTheme(),
                  ),
                ],
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.04, end: 0),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'System Parameters',
                icon: Icons.tune_rounded,
                children: [
                  _SliderRow(
                      title: 'Default Loan Interest',
                      value: settings.defaultLoanInterest,
                      min: 5,
                      max: 25,
                      unit: '%',
                      onChanged: notifier.updateLoanInterest),
                  _SliderRow(
                      title: 'Savings Maturity Yield',
                      value: settings.defaultSavingsYield,
                      min: 2,
                      max: 15,
                      unit: '%',
                      onChanged: notifier.updateSavingsYield),
                  _SliderRow(
                      title: 'Late Payment Penalty',
                      value: settings.latePenaltyPercentage,
                      min: 0,
                      max: 5,
                      unit: '%',
                      onChanged: notifier.updatePenalty),
                ],
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.04, end: 0),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'App Updates',
                icon: Icons.system_update_rounded,
                children: [
                  _ActionRow(
                    title: 'Publish New Version',
                    subtitle: 'Upload APK, set version, auto-replaces old file',
                    icon: Icons.publish_rounded,
                    color: Colors.indigo,
                    onTap: () => context.push('/settings/app-update'),
                  ),
                ],
              ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.04, end: 0),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Security & Notifications',
                icon: Icons.shield_outlined,
                children: [
                  _SwitchRow(
                      title: 'Biometric Authentication',
                      subtitle: 'Use fingerprint or face ID',
                      value: settings.biometricAuth,
                      onChanged: notifier.toggleBiometric),
                  _SwitchRow(
                      title: 'Notifications',
                      subtitle: 'Late payment and maturity alerts',
                      value: settings.enableNotifications,
                      onChanged: notifier.toggleNotifications),
                ],
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.04, end: 0),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : const Text('Apply Changes',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              letterSpacing: -0.3)),
                ),
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 24),
              _SectionCard(
                title: 'Data & Privacy',
                icon: Icons.lock_outline_rounded,
                children: [
                  _ActionRow(
                    title: 'Export Data',
                    subtitle: 'Download transaction history (PDF/CSV)',
                    icon: Icons.file_download_outlined,
                    color: Colors.blue,
                    onTap: () => _handleExport(context),
                  ),
                ],
              ).animate().fadeIn(delay: 450.ms),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Support & Feedback',
                icon: Icons.help_outline_rounded,
                children: [
                  _ActionRow(
                    title: 'Help Center',
                    subtitle: 'FAQs and user guides',
                    icon: Icons.library_books_outlined,
                    color: Colors.teal,
                    onTap: () {},
                  ),
                  _ActionRow(
                    title: 'Report an Issue',
                    subtitle: 'Technical support and bug reports',
                    icon: Icons.bug_report_outlined,
                    color: Colors.orange,
                    onTap: () {},
                  ),
                ],
              ).animate().fadeIn(delay: 500.ms),
              const SizedBox(height: 16),
              if (ref.watch(currentUserProvider)?.role ==
                  UserRole.executiveAdmin) ...[
                _SectionCard(
                  title: 'Administration',
                  icon: Icons.admin_panel_settings_outlined,
                  children: [
                    _ActionRow(
                      title: 'Branding',
                      subtitle: 'Change system-wide name and logo',
                      icon: Icons.auto_awesome_rounded,
                      color: Colors.purple,
                      onTap: () => _showBrandingDialog(context, ref),
                    ),
                    _ActionRow(
                      title: 'AI Chatbot Config',
                      subtitle: 'Configure NVIDIA NIM API & Model',
                      icon: Icons.psychology_outlined,
                      color: Colors.indigo,
                      onTap: () => _showAIChatConfigDialog(context, ref),
                    ),
                    _ActionRow(
                      title: 'Activity Logs',
                      subtitle: 'Monitor system changes and user actions',
                      icon: Icons.history_rounded,
                      color: AppColors.primary,
                      onTap: () => context.push('/settings/logs'),
                    ),
                  ],
                ).animate().fadeIn(delay: 550.ms),
                const SizedBox(height: 16),
              ],
              _SectionCard(
                title: 'Danger Zone',
                icon: Icons.warning_amber_rounded,
                children: [
                  _ActionRow(
                    title: 'Sign Out',
                    subtitle: 'Exit your current session safely',
                    icon: Icons.logout_rounded,
                    color: Colors.red,
                    onTap: () => _handleSignOut(context, ref),
                  ),
                ],
              ).animate().fadeIn(delay: 600.ms),
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    Text(
                      '${ref.watch(brandProvider).name} v1.0.4-stable',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _FooterLink(label: 'Terms of Service', onTap: () {}),
                        const SizedBox(width: 12),
                        Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                                color: theme.textTheme.bodySmall?.color
                                    ?.withValues(alpha: 0.2),
                                shape: BoxShape.circle)),
                        const SizedBox(width: 12),
                        _FooterLink(label: 'Privacy Policy', onTap: () {}),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 700.ms),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  void _handleExport(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preparing your data for export...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showBrandingDialog(BuildContext context, WidgetRef ref) {
    final brand = ref.read(brandProvider);
    final nameController = TextEditingController(text: brand.name);
    final logoController = TextEditingController(text: brand.logoUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Branding Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Brand Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: logoController,
              decoration:
                  const InputDecoration(labelText: 'Logo URL (Network Image)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(brandProvider.notifier).updateBrand(
                    name: nameController.text.trim(),
                    logoUrl: logoController.text.trim(),
                  );
              Navigator.pop(ctx);
            },
            child: const Text('Apply System-Wide'),
          ),
        ],
      ),
    );
  }

  void _showAIChatConfigDialog(BuildContext context, WidgetRef ref) {
    final config = ref.read(chatConfigProvider);
    final apiKeyController = TextEditingController(text: config.apiKey);
    final modelController = TextEditingController(text: config.modelId);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI Chatbot Configuration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: apiKeyController,
              decoration: const InputDecoration(
                labelText: 'NVIDIA NIM API Key',
                hintText: 'nvapi-...',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: modelController,
              decoration: const InputDecoration(
                labelText: 'Model ID',
                hintText: 'meta/llama3-70b-instruct',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(chatConfigProvider.notifier).updateConfig(
                    apiKey: apiKeyController.text.trim(),
                    modelId: modelController.text.trim(),
                  );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('AI Configuration updated successfully')),
              );
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _handleSave() async {
    setState(() => _isSaving = true);
    await Future.delayed(1.seconds);
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
        SizedBox(width: 12),
        Text('Settings saved successfully'),
      ]),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ));
  }

  void _handleSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to exit your session?'),
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
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SectionCard(
      {required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      AppColors.primary.withValues(alpha: 0.05)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Text(title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow(
      {required this.title,
      required this.subtitle,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 13)),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final String unit;
  final ValueChanged<double> onChanged;
  const _SliderRow(
      {required this.title,
      required this.value,
      required this.min,
      required this.max,
      required this.unit,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${value.toStringAsFixed(1)}$unit',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(value: value, min: min, max: max, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600, color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20,
                color:
                    theme.textTheme.bodySmall?.color?.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FooterLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.primary.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}
