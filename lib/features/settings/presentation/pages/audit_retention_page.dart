import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/providers/security_policies_providers.dart';

class AuditRetentionPage extends ConsumerStatefulWidget {
  const AuditRetentionPage({super.key});

  @override
  ConsumerState<AuditRetentionPage> createState() =>
      _AuditRetentionPageState();
}

class _AuditRetentionPageState extends ConsumerState<AuditRetentionPage> {
  bool _saving = false;
  bool _initialized = false;

  int _retentionDays = 2555;
  bool _autoArchive = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncPolicies = ref.watch(securityPoliciesProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Audit Log Retention'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: asyncPolicies.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load\n\n$e')),
        data: (policies) {
          _hydrate(policies);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audit Retention',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ).animate().fadeIn(),
                const SizedBox(height: 4),
                Text(
                  'Control how long audit logs are kept and when they archive.',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
                ).animate().fadeIn(delay: 50.ms),
                const SizedBox(height: 24),

                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: _retentionDays,
                        items: const [
                          DropdownMenuItem(
                              value: 365, child: Text('1 Year')),
                          DropdownMenuItem(
                              value: 1095, child: Text('3 Years')),
                          DropdownMenuItem(
                              value: 1825, child: Text('5 Years')),
                          DropdownMenuItem(
                              value: 2555, child: Text('7 Years')),
                          DropdownMenuItem(
                              value: 3650, child: Text('10 Years')),
                          DropdownMenuItem(
                              value: 0, child: Text('Indefinite')),
                        ],
                        onChanged: (v) =>
                            setState(() => _retentionDays = v ?? 2555),
                        decoration: const InputDecoration(
                          labelText: 'Retention Period',
                          helperText:
                              'Logs older than this period will be archived',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildToggleTile(
                        title: 'Auto-Archive Old Logs',
                        subtitle:
                            'Compress and move expired logs to cold storage',
                        value: _autoArchive,
                        onChanged: (v) =>
                            setState(() => _autoArchive = v),
                      ),
                    ],
                  ),
                ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.04, end: 0),

                const SizedBox(height: 28),
                _buildSaveButton().animate(delay: 200.ms).fadeIn(),
              ],
            ),
          );
        },
      ),
    );
  }

  void _hydrate(Map<String, dynamic> policies) {
    if (_initialized) return;
    final audit =
        (policies['audit_retention'] as Map?)?.cast<String, dynamic>() ?? {};
    _retentionDays = _parseInt(audit['retention_days'], 2555);
    _autoArchive = audit['auto_archive'] ?? true;
    _initialized = true;
  }

  int _parseInt(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return fallback;
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _saving ? null : _save,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : const Icon(Icons.save_rounded),
        label: Text(
          _saving ? 'Saving...' : 'Save Retention Settings',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final service = ref.read(securityPoliciesServiceProvider);
      await service.saveAuditRetention(
        retentionDays: _retentionDays,
        autoArchive: _autoArchive,
      );
      ref.invalidate(securityPoliciesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text('Audit retention settings saved')),
          ]),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(alpha: 0.6))),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeTrackColor: AppColors.primary,
        ),
      ],
    );
  }
}
