import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';

class SecurityCompliancePage extends ConsumerWidget {
  const SecurityCompliancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Security & Compliance'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data Shield & Auditing',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn(),
              const SizedBox(height: 4),
              Text(
                'Enforce strict regulatory policies, manage user locks, and inspect system audit logs.',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
              ).animate().fadeIn(delay: 50.ms),
              const SizedBox(height: 24),

              // ─── 1. FUNCTIONAL AUDIT LOG CARD ────────────────────────
              _buildFunctionalAuditCard(context, theme, isDark)
                  .animate(delay: 100.ms)
                  .fadeIn()
                  .slideY(begin: 0.05, end: 0),
              const SizedBox(height: 24),

              // ─── 2. COMPLIANCE ROADMAP HEADER ────────────────────────
              Text(
                'SECURITY POLICIES',
                style: theme.textTheme.labelMedium?.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ).animate(delay: 130.ms).fadeIn(),
              const SizedBox(height: 8),

              // ─── 3. ROADMAP POLICIES ─────────────────────────────────
              _buildTappablePolicyCard(
                theme: theme,
                title: 'Data Backup & Export',
                subtitle: 'Cloud backup to Google Drive',
                description: 'Connect your Google Drive account and back up your organization data as a restorable JSON snapshot. Includes full record content and a metadata manifest.',
                priority: 'P1',
                icon: Icons.cloud_upload_outlined,
                color: Colors.blue,
                onTap: () => context.push('/settings/data-backup'),
              ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.05, end: 0),
              const SizedBox(height: 16),

              _buildTappablePolicyCard(
                theme: theme,
                title: 'Password Complexity',
                subtitle: 'Enforce strong structural password rules',
                description: 'Set rules for minimum lengths, special symbols, uppercase, numeric checks, password recycle buffers, and quarterly forced updates.',
                priority: 'P2',
                icon: Icons.password_rounded,
                color: Colors.red,
                onTap: () => context.push('/settings/password-rules'),
              ).animate(delay: 180.ms).fadeIn().slideY(begin: 0.05, end: 0),
              const SizedBox(height: 16),

              _buildTappablePolicyCard(
                theme: theme,
                title: 'Auto-Logout & Locks',
                subtitle: 'Session time-out configuration',
                description: 'Terminate inactive application scopes automatically after N minutes of idle states. Configure maximum login retry buffers before lockouts.',
                priority: 'P2',
                icon: Icons.timer_outlined,
                color: Colors.orange,
                onTap: () => context.push('/settings/session-locks'),
              ).animate(delay: 210.ms).fadeIn().slideY(begin: 0.05, end: 0),
              const SizedBox(height: 16),

              _buildTappablePolicyCard(
                theme: theme,
                title: 'Two-Factor Authentication',
                subtitle: 'Enforce MFA across admin levels',
                description: 'Mandate time-based TOTP generators (Google Authenticator) or SMS-based OTP structures for Branch Managers and executive staff nodes.',
                priority: 'P2',
                icon: Icons.verified_user_outlined,
                color: Colors.green,
                onTap: () => context.push('/settings/two-factor-auth'),
              ).animate(delay: 240.ms).fadeIn().slideY(begin: 0.05, end: 0),
              const SizedBox(height: 16),

              _buildTappablePolicyCard(
                theme: theme,
                title: 'Audit Log Retention',
                subtitle: 'Compliance retention period parameters',
                description: 'Establish logs lifetime (e.g. 7 years). Automatically flags older database audit rows to be compiled and zipped into encrypted archives.',
                priority: 'P2',
                icon: Icons.archive_outlined,
                color: Colors.brown,
                onTap: () => context.push('/settings/audit-retention'),
              ).animate(delay: 270.ms).fadeIn().slideY(begin: 0.05, end: 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFunctionalAuditCard(BuildContext context, ThemeData theme, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.history_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System Activity Logs',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Live operations & database audit stream',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Track system actions, staff edits, loan disbursements, and database structural triggers in real-time. For compliance, these logs are cryptographically sealed.',
            style: TextStyle(fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/settings/logs'),
              icon: const Icon(Icons.analytics_outlined),
              label: const Text(
                'Open Activity Logs',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTappablePolicyCard({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required String description,
    required String priority,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (priority == 'P1' ? Colors.orange : Colors.grey).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            priority,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: priority == 'P1' ? Colors.orange : Colors.blueGrey,
                            ),
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
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 13, height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
