import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/providers/security_policies_providers.dart';

class SessionLocksPage extends ConsumerStatefulWidget {
  const SessionLocksPage({super.key});

  @override
  ConsumerState<SessionLocksPage> createState() => _SessionLocksPageState();
}

class _SessionLocksPageState extends ConsumerState<SessionLocksPage> {
  bool _saving = false;
  bool _initialized = false;

  int _autoLogoutMinutes = 15;
  int _maxLoginRetries = 5;
  int _lockoutDurationMinutes = 30;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncPolicies = ref.watch(securityPoliciesProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Auto-Logout & Locks'),
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
                  'Session & Locks',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ).animate().fadeIn(),
                const SizedBox(height: 4),
                Text(
                  'Configure auto-logout timeouts and account lockout rules.',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
                ).animate().fadeIn(delay: 50.ms),
                const SizedBox(height: 24),

                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSliderTile(
                        label: 'Session Timeout',
                        value: _autoLogoutMinutes.toDouble(),
                        min: 5,
                        max: 120,
                        divisions: 23,
                        suffix: '$_autoLogoutMinutes minutes',
                        onChanged: (v) =>
                            setState(() => _autoLogoutMinutes = v.round()),
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
                      _buildSliderTile(
                        label: 'Lockout Duration',
                        value: _lockoutDurationMinutes.toDouble(),
                        min: 5,
                        max: 120,
                        divisions: 23,
                        suffix: '$_lockoutDurationMinutes minutes',
                        onChanged: (v) => setState(
                            () => _lockoutDurationMinutes = v.round()),
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
    final session =
        (policies['session'] as Map?)?.cast<String, dynamic>() ?? {};
    _autoLogoutMinutes = _parseInt(session['auto_logout_minutes'], 15);
    _maxLoginRetries = _parseInt(session['max_login_retries'], 5);
    _lockoutDurationMinutes = _parseInt(session['lockout_duration_minutes'], 30);
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
          _saving ? 'Saving...' : 'Save Session Settings',
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
      await service.saveSessionConfig(
        autoLogoutMinutes: _autoLogoutMinutes,
        maxLoginRetries: _maxLoginRetries,
        lockoutDurationMinutes: _lockoutDurationMinutes,
      );
      ref.invalidate(securityPoliciesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text('Session settings saved')),
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
