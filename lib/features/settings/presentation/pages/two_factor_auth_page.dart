import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/providers/security_policies_providers.dart';

class TwoFactorAuthPage extends ConsumerStatefulWidget {
  const TwoFactorAuthPage({super.key});

  @override
  ConsumerState<TwoFactorAuthPage> createState() => _TwoFactorAuthPageState();
}

class _TwoFactorAuthPageState extends ConsumerState<TwoFactorAuthPage> {
  bool _saving = false;
  bool _initialized = false;

  bool _enabled = false;
  String _method = 'totp';
  List<String> _enforcedRoles = [];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncPolicies = ref.watch(securityPoliciesProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Two-Factor Authentication'),
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
                  'Two-Factor Auth',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ).animate().fadeIn(),
                const SizedBox(height: 4),
                Text(
                  'Require additional verification for sensitive roles.',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
                ).animate().fadeIn(delay: 50.ms),
                const SizedBox(height: 24),

                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildToggleTile(
                        title: 'Enforce 2FA',
                        subtitle: 'Require MFA for selected roles',
                        value: _enabled,
                        onChanged: (v) => setState(() => _enabled = v),
                      ),
                      if (_enabled) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Authentication Method',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _MethodChip(
                                label: 'Authenticator App',
                                icon: Icons.phone_iphone_rounded,
                                selected: _method == 'totp',
                                onTap: () =>
                                    setState(() => _method = 'totp'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MethodChip(
                                label: 'SMS Code',
                                icon: Icons.sms_rounded,
                                selected: _method == 'sms',
                                onTap: () =>
                                    setState(() => _method = 'sms'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Enforce for Roles',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildRoleCheckbox('Executive Admin', 'executive_admin'),
                        _buildRoleCheckbox('Branch Manager', 'branch_manager'),
                        _buildRoleCheckbox(
                            'Staff / Agent', 'collection_agent'),
                      ],
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
    final tf =
        (policies['two_factor'] as Map?)?.cast<String, dynamic>() ?? {};
    _enabled = tf['enabled'] ?? false;
    _method = tf['method'] ?? 'totp';
    _enforcedRoles = tf['enforced_roles'] != null
        ? List<String>.from(tf['enforced_roles'])
        : [];
    _initialized = true;
  }

  Widget _buildRoleCheckbox(String label, String role) {
    final isSelected = _enforcedRoles.contains(role);
    return CheckboxListTile(
      value: isSelected,
      onChanged: (v) {
        setState(() {
          if (v == true) {
            _enforcedRoles.add(role);
          } else {
            _enforcedRoles.remove(role);
          }
        });
      },
      title: Text(label, style: const TextStyle(fontSize: 14)),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: AppColors.primary,
    );
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
          _saving ? 'Saving...' : 'Save 2FA Settings',
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
      await service.saveTwoFactorConfig(
        enabled: _enabled,
        method: _method,
        enforcedRoles: _enforcedRoles,
      );
      ref.invalidate(securityPoliciesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text('2FA settings saved')),
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

class _MethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _MethodChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : theme.dividerColor.withValues(alpha: 0.5),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: selected
                    ? AppColors.primary
                    : theme.textTheme.bodySmall?.color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? AppColors.primary
                    : theme.textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
