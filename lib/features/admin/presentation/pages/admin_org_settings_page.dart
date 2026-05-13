import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../branches/presentation/pages/branch_management_page.dart';

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
  final _primaryColorCtrl = TextEditingController();
  final _accentColorCtrl = TextEditingController();
  
  String? _logoUrl;
  File? _selectedLogo;
  bool _isSaving = false;
  bool _isLoading = true;
  bool _isUploadingLogo = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _branchesCtrl.dispose();
    _staffCtrl.dispose();
    _membersCtrl.dispose();
    _primaryColorCtrl.dispose();
    _accentColorCtrl.dispose();
    super.dispose();
  }

  void _initForm(Map<String, dynamic> org) {
    if (_isLoading) {
      _nameCtrl.text = org['name'] as String? ?? '';
      _slugCtrl.text = org['slug'] as String? ?? '';
      _branchesCtrl.text = '${org['max_branches'] ?? 5}';
      _staffCtrl.text = '${org['max_staff'] ?? 20}';
      _membersCtrl.text = '${org['max_members'] ?? 500}';
      _logoUrl = org['logo_url'] as String?;
      _primaryColorCtrl.text = org['primary_color'] as String? ?? '#6366F1';
      _accentColorCtrl.text = org['accent_color'] as String? ?? '#8B5CF6';
      _isLoading = false;
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() => _selectedLogo = File(pickedFile.path));
      await _uploadLogo();
    }
  }

  Future<void> _uploadLogo() async {
    if (_selectedLogo == null) return;

    setState(() => _isUploadingLogo = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final orgId = ref.read(currentOrgIdOrThrowProvider);
      final fileName = 'org_logos/$orgId-${DateTime.now().millisecondsSinceEpoch}.png';

      await client.storage.from('organization-assets').upload(fileName, _selectedLogo!);
      
      final publicUrl = client.storage.from('organization-assets').getPublicUrl(fileName);
      
      await client.from('organizations').update({
        'logo_url': publicUrl,
      }).eq('id', orgId);

      setState(() => _logoUrl = publicUrl);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Logo uploaded successfully'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error uploading logo: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
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
        'primary_color': _primaryColorCtrl.text,
        'accent_color': _accentColorCtrl.text,
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
                        _buildLogoSection(isDark),
                        const SizedBox(height: 20),
                        _buildBrandingSection(isDark),
                        const SizedBox(height: 20),
                        _buildQuickActions(isDark),
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

  Widget _buildLogoSection(bool isDark) {
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
                child: const Icon(Icons.image_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Organization Logo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  Text('Upload your brand logo (512x512 recommended)', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: GestureDetector(
              onTap: _isUploadingLogo ? null : _pickLogo,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1F2532) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 2),
                  image: _selectedLogo != null
                      ? DecorationImage(image: FileImage(_selectedLogo!), fit: BoxFit.cover)
                      : _logoUrl != null
                          ? DecorationImage(image: NetworkImage(_logoUrl!), fit: BoxFit.cover)
                          : null,
                ),
                child: _isUploadingLogo
                    ? const Center(child: CircularProgressIndicator())
                    : _selectedLogo == null && _logoUrl == null
                        ? Icon(Icons.add_photo_alternate_rounded, size: 40, color: AppColors.primary.withValues(alpha: 0.5))
                        : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Tap to upload logo',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
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
                  gradient: LinearGradient(colors: [AppColors.warning, AppColors.orange]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.palette_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Brand Colors', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  Text('Customize your brand appearance', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Primary Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: _parseColor(_primaryColorCtrl.text),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _primaryColorCtrl,
                            decoration: InputDecoration(
                              hintText: '#6366F1',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1F2532) : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            style: TextStyle(fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Accent Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: _parseColor(_accentColorCtrl.text),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _accentColorCtrl,
                            decoration: InputDecoration(
                              hintText: '#8B5CF6',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1F2532) : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            style: TextStyle(fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 150.ms);
  }

  Widget _buildQuickActions(bool isDark) {
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
                  gradient: LinearGradient(colors: [AppColors.success, AppColors.teal]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.settings_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  Text('Manage organization settings', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildActionTile(Icons.business_rounded, 'Manage Branches', 'Create and manage branch offices', isDark, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const BranchManagementPage()));
          }),
          const SizedBox(height: 12),
          _buildActionTile(Icons.people_rounded, 'Manage Users', 'Create admins, managers, and staff', isDark, () {
            context.push('/admin/users');
          }),
          const SizedBox(height: 12),
          _buildActionTile(Icons.security_rounded, 'Security Settings', 'Configure access controls', isDark, () {}),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildActionTile(IconData icon, String title, String subtitle, bool isDark, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
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
                  gradient: LinearGradient(colors: [AppColors.error, AppColors.pink]),
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
    ).animate().fadeIn(duration: 400.ms, delay: 250.ms);
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
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
