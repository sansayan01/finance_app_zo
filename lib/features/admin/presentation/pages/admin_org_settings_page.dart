import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final adminOrgSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  final orgId = ref.read(currentOrgIdOrThrowProvider);
  return client.from('organizations').select().eq('id', orgId).single();
});

class AdminOrgSettingsPage extends ConsumerStatefulWidget {
  const AdminOrgSettingsPage({super.key});

  @override
  ConsumerState<AdminOrgSettingsPage> createState() => _AdminOrgSettingsPageState();
}

class _AdminOrgSettingsPageState extends ConsumerState<AdminOrgSettingsPage> {
  final _nameCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _branchesCtrl = TextEditingController();
  final _staffCtrl = TextEditingController();
  final _membersCtrl = TextEditingController();
  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _branchesCtrl.dispose();
    _staffCtrl.dispose();
    _membersCtrl.dispose();
    super.dispose();
  }

  void _initForm(Map<String, dynamic> org) {
    if (_isLoading) {
      _nameCtrl.text = org['name'] as String? ?? '';
      _slugCtrl.text = org['slug'] as String? ?? '';
      _branchesCtrl.text = '${org['max_branches'] ?? 5}';
      _staffCtrl.text = '${org['max_staff'] ?? 20}';
      _membersCtrl.text = '${org['max_members'] ?? 500}';
      _isLoading = false;
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final orgId = ref.read(currentOrgIdOrThrowProvider);
      await client.from('organizations').update({
        'name': _nameCtrl.text.trim(),
        'slug': _slugCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
        'max_branches': int.tryParse(_branchesCtrl.text) ?? 5,
        'max_staff': int.tryParse(_staffCtrl.text) ?? 20,
        'max_members': int.tryParse(_membersCtrl.text) ?? 500,
      }).eq('id', orgId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Settings saved successfully'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(adminOrgSettingsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0F1115), const Color(0xFF1A1F2E)]
                : [const Color(0xFFF8F9FB), const Color(0xFFEEF2FF)],
          ),
        ),
        child: SafeArea(
          child: settingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (org) {
              _initForm(org);
              return Column(
                children: [
                  _buildAppBar(context, isDark),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      children: [
                        _buildProfileSection(org, isDark),
                        const SizedBox(height: 20),
                        _buildBrandingSection(isDark),
                        const SizedBox(height: 20),
                        _buildLimitsSection(isDark),
                        const SizedBox(height: 32),
                        _buildSaveButton(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(child: Text('Organization Settings', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)))),
          GestureDetector(
            onTap: () async {
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) context.go('/auth');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.logout_rounded, size: 14, color: AppColors.error),
                  const SizedBox(width: 4),
                  Text('Sign Out', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error)),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildProfileSection(Map<String, dynamic> org, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2E).withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.business_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Organization Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  Text('Update your organization details', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildField('Organization Name', _nameCtrl, Icons.business_rounded, isDark),
          const SizedBox(height: 14),
          _buildField('Slug', _slugCtrl, Icons.alternate_email_rounded, isDark, hint: 'Used in URLs: my-mfi'),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildBrandingSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2E).withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.accent, AppColors.pink]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.palette_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Branding', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  Text('Customize your organization appearance', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(child: Text('Brand name, logo, and colors can be updated from the app settings page.', style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700))),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildLimitsSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2E).withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.warning, AppColors.orange]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.speed_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Plan Limits', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  Text('Set maximum limits for your organization', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildLimitField('Max Branches', _branchesCtrl, Icons.business_rounded, isDark)),
              const SizedBox(width: 12),
              Expanded(child: _buildLimitField('Max Staff', _staffCtrl, Icons.people_rounded, isDark)),
              const SizedBox(width: 12),
              Expanded(child: _buildLimitField('Max Members', _membersCtrl, Icons.person_rounded, isDark)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon, bool isDark, {String? hint}) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: isDark ? const Color(0xFF1F2532) : const Color(0xFFF1F5F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
    );
  }

  Widget _buildLimitField(String label, TextEditingController ctrl, IconData icon, bool isDark) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        filled: true,
        fillColor: isDark ? const Color(0xFF1F2532) : const Color(0xFFF1F5F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
      style: TextStyle(fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A)),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isSaving
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }
}
