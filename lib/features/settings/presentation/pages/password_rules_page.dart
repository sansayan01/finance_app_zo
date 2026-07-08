import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/providers/security_policies_providers.dart';

class PasswordRulesPage extends ConsumerStatefulWidget {
  const PasswordRulesPage({super.key});

  @override
  ConsumerState<PasswordRulesPage> createState() => _PasswordRulesPageState();
}

class _PasswordRulesPageState extends ConsumerState<PasswordRulesPage> {
  bool _saving = false;
  bool _initialized = false;

  int _minLength = 8;
  bool _requireUppercase = true;
  bool _requireLowercase = true;
  bool _requireNumbers = true;
  bool _requireSpecial = true;
  int _maxAgeDays = 90;
  int _recycleBuffer = 5;
  int _maxLoginRetries = 5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncPolicies = ref.watch(securityPoliciesProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Password Rules'),
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
                  'Password Rules',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ).animate().fadeIn(),
                const SizedBox(height: 4),
                Text(
                  'Set minimum complexity, expiry, and recycle rules for user passwords.',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
                ).animate().fadeIn(delay: 50.ms),
                const SizedBox(height: 24),

                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSliderTile(
                        label: 'Minimum Length',
                        value: _minLength.toDouble(),
                        min: 4,
                        max: 24,
                        divisions: 20,
                        suffix: '$_minLength characters',
                        onChanged: (v) => setState(() => _minLength = v.round()),
                      ),
                      const SizedBox(height: 8),
                      _buildToggleTile(
                        title: 'Require Uppercase Letters',
                        subtitle: 'A-Z characters mandatory',
                        value: _requireUppercase,
                        onChanged: (v) => setState(() => _requireUppercase = v),
                      ),
                      _buildToggleTile(
                        title: 'Require Lowercase Letters',
                        subtitle: 'a-z characters mandatory',
                        value: _requireLowercase,
                        onChanged: (v) => setState(() => _requireLowercase = v),
                      ),
                      _buildToggleTile(
                        title: 'Require Numbers',
                        subtitle: '0-9 digits mandatory',
                        value: _requireNumbers,
                        onChanged: (v) => setState(() => _requireNumbers = v),
                      ),
                      _buildToggleTile(
                        title: 'Require Special Characters',
                        subtitle: '!@#\$%^&*() symbols mandatory',
                        value: _requireSpecial,
                        onChanged: (v) => setState(() => _requireSpecial = v),
                      ),
                      const SizedBox(height: 8),
                      _buildSliderTile(
                        label: 'Password Expiry',
                        value: _maxAgeDays.toDouble(),
                        min: 30,
                        max: 365,
                        divisions: 11,
                        suffix: '$_maxAgeDays days',
                        onChanged: (v) => setState(() => _maxAgeDays = v.round()),
                      ),
                      _buildSliderTile(
                        label: 'Recycle Buffer',
                        value: _recycleBuffer.toDouble(),
                        min: 0,
                        max: 20,
                        divisions: 20,
                        suffix: '$_recycleBuffer previous passwords',
                        onChanged: (v) =>
                            setState(() => _recycleBuffer = v.round()),
                      ),
                      const SizedBox(height: 8),
                      _buildSliderTile(
                        label: 'Max Login Retries',
                        value: _maxLoginRetries.toDouble(),
                        min: 3,
                        max: 15,
                        divisions: 12,
                        suffix: '$_maxLoginRetries attempts',
                        onChanged: (v) =>
                            setState(() => _maxLoginRetries = v.round()),
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
    final pw =
        (policies['password'] as Map?)?.cast<String, dynamic>() ?? {};
    _minLength = _parseInt(pw['min_length'], 8);
    _requireUppercase = pw['require_uppercase'] ?? true;
    _requireLowercase = pw['require_lowercase'] ?? true;
    _requireNumbers = pw['require_numbers'] ?? true;
    _requireSpecial = pw['require_special'] ?? true;
    _maxAgeDays = _parseInt(pw['max_age_days'], 90);
    _recycleBuffer = _parseInt(pw['recycle_buffer'], 5);
    _maxLoginRetries = _parseInt(pw['max_login_retries'], 5);
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
          _saving ? 'Saving...' : 'Save Password Rules',
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
      await service.savePasswordRules(
        minLength: _minLength,
        requireUppercase: _requireUppercase,
        requireLowercase: _requireLowercase,
        requireNumbers: _requireNumbers,
        requireSpecial: _requireSpecial,
        maxAgeDays: _maxAgeDays,
        recycleBuffer: _recycleBuffer,
        maxLoginRetries: _maxLoginRetries,
      );
      ref.invalidate(securityPoliciesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text('Password rules saved')),
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

  Widget _buildSliderTile({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                suffix,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppColors.primary,
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withValues(alpha: 0.1),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
