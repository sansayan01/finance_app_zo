// SKETCH — Restructured Executive Admin Settings Page
//
// This file is a side-by-side draft. To activate it:
//   1. Review against existing settings_page.dart
//   2. Replace the import in router/app_router.dart
//   3. Delete the old file once parity is confirmed
//
// What changed vs settings_page.dart:
//   ✗ Removed fake "Apply Changes" button (settings auto-save anyway)
//   ✗ Removed global System Parameter sliders (need full Product CRUD pages)
//   ✓ Reorganized into 6 logical sections: Personal / Organization /
//     Integrations / Security & Compliance / Subscription / Support
//   ✓ Role-based section visibility (Exec Admin sees Org + Integrations)
//   ✓ Wired up previously dead onTap handlers via _showComingSoon
//   ✓ Each unbuilt feature shows a priority tag (P0/P1/P2)
//   ✓ Branding dialog gains primary color field
//   ✓ Existing working items preserved (Edit Profile, Dark Mode, Biometric,
//     Activity Logs, App Update, AI Chatbot)

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

/// Priority tag for un-implemented features.
enum _Priority { p0, p1, p2 }

extension _PriorityX on _Priority {
  String get label => switch (this) {
        _Priority.p0 => 'P0',
        _Priority.p1 => 'P1',
        _Priority.p2 => 'P2',
      };
  Color get color => switch (this) {
        _Priority.p0 => Colors.red,
        _Priority.p1 => Colors.orange,
        _Priority.p2 => Colors.blueGrey,
      };
  String get tooltip => switch (this) {
        _Priority.p0 => 'Critical — production blocker',
        _Priority.p1 => 'Important — needed soon',
        _Priority.p2 => 'Nice to have',
      };
}

class SettingsPageV2 extends ConsumerWidget {
  const SettingsPageV2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final isExecAdmin = user?.role == UserRole.executiveAdmin;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(theme: theme, user: user),
              const SizedBox(height: 16),

              // ─── 1. PERSONAL ─────────────────────────────────────────
              _PersonalSection(ref: ref).animate().fadeIn(delay: 50.ms),
              const SizedBox(height: 16),

              // ─── 2. ORGANIZATION ─────────────────────────────────────
              if (isExecAdmin) ...[
                _OrganizationSection(ref: ref)
                    .animate()
                    .fadeIn(delay: 100.ms),
                const SizedBox(height: 16),
              ],

              // ─── 3. INTEGRATIONS ─────────────────────────────────────
              if (isExecAdmin) ...[
                _IntegrationsSection(ref: ref)
                    .animate()
                    .fadeIn(delay: 150.ms),
                const SizedBox(height: 16),
              ],

              // ─── 4. SECURITY & COMPLIANCE ────────────────────────────
              _SecuritySection(ref: ref, isExecAdmin: isExecAdmin)
                  .animate()
                  .fadeIn(delay: 200.ms),
              const SizedBox(height: 16),

              // ─── 5. SUBSCRIPTION (read-only for exec admin) ──────────
              if (isExecAdmin) ...[
                _SubscriptionSection().animate().fadeIn(delay: 250.ms),
                const SizedBox(height: 16),
              ],

              // ─── 6. SUPPORT ──────────────────────────────────────────
              _SupportSection().animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 16),

              // ─── DANGER ZONE ─────────────────────────────────────────
              _DangerSection().animate().fadeIn(delay: 350.ms),
              const SizedBox(height: 40),

              _Footer(ref: ref),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SECTION 1: PERSONAL
// ═══════════════════════════════════════════════════════════════════════
class _PersonalSection extends StatelessWidget {
  final WidgetRef ref;
  const _PersonalSection({required this.ref});

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;

    return _SectionCard(
      title: 'Personal',
      subtitle: 'Settings that apply only to you',
      icon: Icons.person_outline_rounded,
      children: [
        _ActionRow(
          title: 'Edit Profile',
          subtitle: 'Name, phone, email, password',
          icon: Icons.badge_outlined,
          color: AppColors.primary,
          onTap: () => context.push('/settings/profile'),
        ),
        _SwitchRow(
          title: 'Dark Mode',
          subtitle: 'Switch between light and dark themes',
          value: isDark,
          onChanged: (_) => ref.read(themeProvider.notifier).toggleTheme(),
        ),
        _SwitchRow(
          title: 'Biometric Login',
          subtitle: 'Use fingerprint or face ID on this device',
          value: settings.biometricAuth,
          onChanged: notifier.toggleBiometric,
        ),
        _SwitchRow(
          title: 'Push Notifications',
          subtitle: 'Late payment alerts, approvals, mentions',
          value: settings.enableNotifications,
          onChanged: notifier.toggleNotifications,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SECTION 2: ORGANIZATION (Exec Admin only)
// ═══════════════════════════════════════════════════════════════════════
class _OrganizationSection extends StatelessWidget {
  final WidgetRef ref;
  const _OrganizationSection({required this.ref});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Organization',
      subtitle: 'Settings that apply to all users in your organization',
      icon: Icons.apartment_rounded,
      children: [
        _ActionRow(
          title: 'Organization Profile',
          subtitle: 'Legal name, GST/PAN, registered address, fiscal year',
          icon: Icons.business_outlined,
          color: Colors.blue,
          onTap: () => context.push('/settings/organization'),
        ),
        _ActionRow(
          title: 'Branding',
          subtitle: 'Brand name, logo, primary color',
          icon: Icons.auto_awesome_rounded,
          color: Colors.purple,
          onTap: () => _showBrandingDialog(context, ref),
        ),
        _ActionRow(
          title: 'Loan Products',
          subtitle: 'Multiple products with their own rates and terms',
          icon: Icons.account_balance_outlined,
          color: Colors.indigo,
          priority: _Priority.p0,
          onTap: () => _showComingSoon(
            context,
            'Loan Products',
            'CRUD for loan products: name, interest %, method '
                '(flat/reducing), min/max amount, tenure range, '
                'processing fee, prepayment penalty, grace period.',
            _Priority.p0,
          ),
        ),
        _ActionRow(
          title: 'Savings Products',
          subtitle: 'RD, FD, daily collection schemes',
          icon: Icons.savings_outlined,
          color: Colors.teal,
          priority: _Priority.p0,
          onTap: () => _showComingSoon(
            context,
            'Savings Products',
            'CRUD for savings products: name, yield %, tenure, '
                'min/max deposit, frequency (daily/weekly/monthly).',
            _Priority.p0,
          ),
        ),
        _ActionRow(
          title: 'Tax & Fees',
          subtitle: 'GST %, processing fees, documentation charges',
          icon: Icons.receipt_long_outlined,
          color: Colors.brown,
          priority: _Priority.p1,
          onTap: () => _showComingSoon(
            context,
            'Tax & Fees',
            'Configure GST %, processing fees, documentation '
                'charges per loan/savings product.',
            _Priority.p1,
          ),
        ),
        _ActionRow(
          title: 'Approval Workflow & Limits',
          subtitle: 'Per-role approval thresholds, escalations',
          icon: Icons.rule_rounded,
          color: Colors.deepOrange,
          priority: _Priority.p1,
          onTap: () => _showComingSoon(
            context,
            'Approval Workflow',
            'Loan approval limits per role (e.g., Branch Manager '
                '≤ ₹50K), dual-approval thresholds, auto-escalation.',
            _Priority.p1,
          ),
        ),
        _ActionRow(
          title: 'Field Staff Policies',
          subtitle: 'Cash limits, geofence, GPS sampling',
          icon: Icons.directions_walk_rounded,
          color: Colors.green,
          priority: _Priority.p1,
          onTap: () => _showComingSoon(
            context,
            'Field Staff Policies',
            'Max cash-in-hand per agent, mandatory deposit time, '
                'geofence radius for visit verification, GPS '
                'sampling frequency, auto-checkout time.',
            _Priority.p1,
          ),
        ),
        _ActionRow(
          title: 'NPA / PAR Configuration',
          subtitle: 'Overdue thresholds, risk buckets',
          icon: Icons.trending_down_rounded,
          color: Colors.red,
          priority: _Priority.p2,
          onTap: () => _showComingSoon(
            context,
            'NPA / PAR Configuration',
            'Days overdue to flag as NPA, PAR-30/60/90 thresholds, '
                'auto-classification of overdue buckets.',
            _Priority.p2,
          ),
        ),
        _ActionRow(
          title: 'Holiday Calendar & Hours',
          subtitle: 'Working days, holidays, EMI shift rules',
          icon: Icons.calendar_month_rounded,
          color: Colors.cyan,
          priority: _Priority.p2,
          onTap: () => _showComingSoon(
            context,
            'Holiday Calendar',
            'Branch holidays (auto-shift EMI to next working day), '
                'working days per branch, business hours.',
            _Priority.p2,
          ),
        ),
        _ActionRow(
          title: 'Receipt & Document Templates',
          subtitle: 'PDF receipt header, footer, terms',
          icon: Icons.description_outlined,
          color: Colors.deepPurple,
          priority: _Priority.p2,
          onTap: () => _showComingSoon(
            context,
            'Receipt Templates',
            'Custom PDF receipt and statement templates with '
                'header/footer, terms, signature placeholder.',
            _Priority.p2,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SECTION 3: INTEGRATIONS (Exec Admin only)
// ═══════════════════════════════════════════════════════════════════════
class _IntegrationsSection extends StatelessWidget {
  final WidgetRef ref;
  const _IntegrationsSection({required this.ref});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Integrations',
      subtitle: 'Third-party services and APIs',
      icon: Icons.extension_rounded,
      children: [
        _ActionRow(
          title: 'SMS Gateway',
          subtitle: 'MSG91 / Twilio for OTP and reminders',
          icon: Icons.sms_outlined,
          color: Colors.green,
          priority: _Priority.p1,
          onTap: () => _showComingSoon(
            context,
            'SMS Gateway',
            'Configure SMS provider (MSG91, Twilio, etc.), API key, '
                'sender ID, default templates.',
            _Priority.p1,
          ),
        ),
        _ActionRow(
          title: 'Email / SMTP',
          subtitle: 'Receipts, statements, alerts via email',
          icon: Icons.email_outlined,
          color: Colors.blue,
          priority: _Priority.p1,
          onTap: () => _showComingSoon(
            context,
            'Email / SMTP',
            'SMTP host/port/credentials or Resend/SendGrid API key, '
                'sender address, reply-to.',
            _Priority.p1,
          ),
        ),
        _ActionRow(
          title: 'WhatsApp Business',
          subtitle: 'Send approved templates to customers',
          icon: Icons.chat_bubble_outline_rounded,
          color: Colors.lightGreen,
          priority: _Priority.p2,
          onTap: () => _showComingSoon(
            context,
            'WhatsApp Business API',
            'Configure WhatsApp Business API token, phone number ID, '
                'approved templates.',
            _Priority.p2,
          ),
        ),
        _ActionRow(
          title: 'Notification Templates',
          subtitle: 'EMI reminder, receipt, overdue, welcome',
          icon: Icons.text_snippet_outlined,
          color: Colors.orange,
          priority: _Priority.p1,
          onTap: () => _showComingSoon(
            context,
            'Notification Templates',
            'Editable templates with placeholders like {customer_name}, '
                '{amount}, {due_date}. Schedule reminders by days before due.',
            _Priority.p1,
          ),
        ),
        _ActionRow(
          title: 'Payment Gateway',
          subtitle: 'UPI ID, Razorpay, bank transfer details',
          icon: Icons.payment_rounded,
          color: Colors.deepPurple,
          priority: _Priority.p2,
          onTap: () => _showComingSoon(
            context,
            'Payment Gateway',
            'Organization UPI ID, Razorpay/PhonePe API keys, bank '
                'account for direct transfers, allowed payment modes.',
            _Priority.p2,
          ),
        ),
        _ActionRow(
          title: 'AI Chatbot Config',
          subtitle: 'NVIDIA NIM API key & model',
          icon: Icons.psychology_outlined,
          color: Colors.indigo,
          onTap: () => _showAIChatConfigDialog(context, ref),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SECTION 4: SECURITY & COMPLIANCE
// ═══════════════════════════════════════════════════════════════════════
class _SecuritySection extends StatelessWidget {
  final WidgetRef ref;
  final bool isExecAdmin;
  const _SecuritySection({required this.ref, required this.isExecAdmin});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Security & Compliance',
      subtitle: 'Access control, audit, and data protection',
      icon: Icons.shield_outlined,
      children: [
        if (isExecAdmin) ...[
          _ActionRow(
            title: 'Password Policy',
            subtitle: 'Min length, complexity, expiry',
            icon: Icons.password_rounded,
            color: Colors.red,
            priority: _Priority.p2,
            onTap: () => _showComingSoon(
              context,
              'Password Policy',
              'Min length, require uppercase/digit/special char, '
                  'expiry days, password history.',
              _Priority.p2,
            ),
          ),
          _ActionRow(
            title: 'Session Policy',
            subtitle: 'Auto-logout, login attempt lockout',
            icon: Icons.timer_outlined,
            color: Colors.orange,
            priority: _Priority.p2,
            onTap: () => _showComingSoon(
              context,
              'Session Policy',
              'Session timeout (auto-logout after N min idle), '
                  'login lockout after X failed attempts.',
              _Priority.p2,
            ),
          ),
          _ActionRow(
            title: 'Two-Factor Authentication',
            subtitle: 'Enforce 2FA for admins and managers',
            icon: Icons.verified_user_outlined,
            color: Colors.green,
            priority: _Priority.p2,
            onTap: () => _showComingSoon(
              context,
              '2FA Enforcement',
              'Require 2FA for admin and manager roles. TOTP via '
                  'Google Authenticator or SMS-based OTP.',
              _Priority.p2,
            ),
          ),
          _ActionRow(
            title: 'Data Backup & Export',
            subtitle: 'Scheduled backups, full data export',
            icon: Icons.cloud_download_outlined,
            color: Colors.blue,
            priority: _Priority.p1,
            onTap: () => _showComingSoon(
              context,
              'Data Backup & Export',
              'Scheduled automatic backup (daily/weekly), full export '
                  'with date range filters (PDF/Excel/CSV per entity).',
              _Priority.p1,
            ),
          ),
          _ActionRow(
            title: 'Audit Log Retention',
            subtitle: 'How long to keep activity logs',
            icon: Icons.archive_outlined,
            color: Colors.brown,
            priority: _Priority.p2,
            onTap: () => _showComingSoon(
              context,
              'Audit Log Retention',
              'Set retention period (e.g., 7 years for compliance). '
                  'Archived logs moved to cold storage.',
              _Priority.p2,
            ),
          ),
        ],
        _ActionRow(
          title: 'Activity Logs',
          subtitle: 'View system changes and user actions',
          icon: Icons.history_rounded,
          color: AppColors.primary,
          onTap: () => context.push('/settings/logs'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SECTION 5: SUBSCRIPTION (read-only for exec admin)
// ═══════════════════════════════════════════════════════════════════════
class _SubscriptionSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Subscription',
      subtitle: 'Plan, usage, and billing (managed by Super Admin)',
      icon: Icons.workspace_premium_rounded,
      children: [
        _ActionRow(
          title: 'Current Plan & Usage',
          subtitle: 'Members, loans, storage, limits',
          icon: Icons.bar_chart_rounded,
          color: Colors.amber.shade800,
          priority: _Priority.p2,
          onTap: () => _showComingSoon(
            context,
            'Subscription Info',
            'Read-only view: current plan, usage stats (members, '
                'loan count, storage), limit warnings, contact link '
                'to Super Admin for upgrade.',
            _Priority.p2,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SECTION 6: SUPPORT
// ═══════════════════════════════════════════════════════════════════════
class _SupportSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Support',
      subtitle: 'Help, feedback, and legal',
      icon: Icons.help_outline_rounded,
      children: [
        _ActionRow(
          title: 'Help Center',
          subtitle: 'FAQs and user guides',
          icon: Icons.library_books_outlined,
          color: Colors.teal,
          priority: _Priority.p2,
          onTap: () => _showComingSoon(
            context,
            'Help Center',
            'In-app FAQ, video walkthroughs, searchable docs.',
            _Priority.p2,
          ),
        ),
        _ActionRow(
          title: 'Report an Issue',
          subtitle: 'Bug reports and technical support',
          icon: Icons.bug_report_outlined,
          color: Colors.orange,
          priority: _Priority.p2,
          onTap: () => _showComingSoon(
            context,
            'Report an Issue',
            'Submit bug report with screenshot + device info; opens '
                'a ticket visible to Super Admin.',
            _Priority.p2,
          ),
        ),
        _ActionRow(
          title: 'Terms of Service',
          subtitle: 'View terms and conditions',
          icon: Icons.gavel_rounded,
          color: Colors.blueGrey,
          priority: _Priority.p2,
          onTap: () => _showComingSoon(
            context,
            'Terms of Service',
            'Display ToS in a webview / markdown reader.',
            _Priority.p2,
          ),
        ),
        _ActionRow(
          title: 'Privacy Policy',
          subtitle: 'How we handle your data',
          icon: Icons.privacy_tip_outlined,
          color: Colors.blueGrey,
          priority: _Priority.p2,
          onTap: () => _showComingSoon(
            context,
            'Privacy Policy',
            'Display Privacy Policy in a webview / markdown reader.',
            _Priority.p2,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// DANGER ZONE
// ═══════════════════════════════════════════════════════════════════════
class _DangerSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SectionCard(
      title: 'Danger Zone',
      subtitle: 'Account actions',
      icon: Icons.warning_amber_rounded,
      children: [
        _ActionRow(
          title: 'Sign Out',
          subtitle: 'Exit your current session safely',
          icon: Icons.logout_rounded,
          color: Colors.red,
          onTap: () => _confirmSignOut(context, ref),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// HEADER & FOOTER
// ═══════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final ThemeData theme;
  final dynamic user;
  const _Header({required this.theme, required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
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
          user?.email ?? 'Customize your experience',
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 15),
        ).animate().fadeIn(delay: 50.ms),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  final WidgetRef ref;
  const _Footer({required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        '${ref.watch(brandProvider).name} v1.0.4-stable',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// DIALOGS
// ═══════════════════════════════════════════════════════════════════════
void _showBrandingDialog(BuildContext context, WidgetRef ref) {
  final brand = ref.read(brandProvider);
  final nameController = TextEditingController(text: brand.name);
  final logoController = TextEditingController(text: brand.logoUrl ?? '');
  final colorController =
      TextEditingController(text: brand.primaryColor ?? '#0066FF');

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Branding Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Brand Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: logoController,
              decoration: const InputDecoration(
                labelText: 'Logo URL (Network Image)',
                hintText: 'https://...',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: colorController,
              decoration: const InputDecoration(
                labelText: 'Primary Color (Hex)',
                hintText: '#0066FF',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Applies system-wide across all users in your organization.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            ref.read(brandProvider.notifier).updateBrand(
                  name: nameController.text.trim(),
                  logoUrl: logoController.text.trim(),
                  // primaryColor: colorController.text.trim(), // wire when notifier supports
                );
            Navigator.pop(ctx);
          },
          child: const Text('Apply'),
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
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

void _confirmSignOut(BuildContext context, WidgetRef ref) {
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

/// Generic placeholder for un-built features. Shows priority + description
/// so the team knows what's expected.
void _showComingSoon(
  BuildContext context,
  String title,
  String description,
  _Priority priority,
) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              Tooltip(
                message: priority.tooltip,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: priority.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    priority.label,
                    style: TextStyle(
                      color: priority.color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(description, style: const TextStyle(fontSize: 15, height: 1.5)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.construction_rounded,
                    size: 18, color: Colors.amber),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Coming soon — this section is on the roadmap.',
                    style: TextStyle(fontSize: 13),
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

// ═══════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Widget> children;
  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.children,
  });

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
                      AppColors.primary.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 8),
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
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

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

class _ActionRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final _Priority? priority;

  const _ActionRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.priority,
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                      if (priority != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: priority!.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            priority!.label,
                            style: TextStyle(
                              color: priority!.color,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
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
