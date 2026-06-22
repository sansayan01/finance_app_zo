import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/glass_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/data/models/user_model.dart';

/// Provider to fetch the complete user profile from the profiles table.
final userProfileProvider = FutureProvider.autoDispose<ProfileModel?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final client = Supabase.instance.client;
  final response = await client
      .from('profiles')
      .select()
      .eq('user_id', user.id)
      .maybeSingle();
  if (response == null) return null;
  return ProfileModel.fromJson(response);
});

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _fatherNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _aadharController;
  late TextEditingController _panController;
  late TextEditingController _employeeIdController;
  late TextEditingController _zoneController;

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSaving = false;
  bool _isChangingPassword = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _fatherNameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();
    _aadharController = TextEditingController();
    _panController = TextEditingController();
    _employeeIdController = TextEditingController();
    _zoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fatherNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _aadharController.dispose();
    _panController.dispose();
    _employeeIdController.dispose();
    _zoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _initializeFields(ProfileModel profile) {
    if (_initialized) return;
    _nameController.text = profile.fullName ?? '';
    _fatherNameController.text = profile.fatherName ?? '';
    _phoneController.text = profile.phone ?? '';
    _emailController.text = profile.email ?? '';
    _addressController.text = profile.address ?? '';
    _aadharController.text = profile.aadhar ?? '';
    _panController.text = profile.pan ?? '';
    _employeeIdController.text = profile.employeeId ?? '';
    _zoneController.text = profile.assignedZone ?? '';
    _initialized = true;
  }

  Future<void> _handleUpdateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final success = await ref.read(authProvider.notifier).updateProfile(
          fullName: _nameController.text.trim(),
          fatherName: _fatherNameController.text.trim().isNotEmpty
              ? _fatherNameController.text.trim()
              : null,
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          address: _addressController.text.trim().isNotEmpty
              ? _addressController.text.trim()
              : null,
          pan: _panController.text.trim().isNotEmpty
              ? _panController.text.trim()
              : null,
          aadhar: _aadharController.text.trim().isNotEmpty
              ? _aadharController.text.trim()
              : null,
          employeeId: _employeeIdController.text.trim().isNotEmpty
              ? _employeeIdController.text.trim()
              : null,
          assignedZone: _zoneController.text.trim().isNotEmpty
              ? _zoneController.text.trim()
              : null,
        );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ref.invalidate(userProfileProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: AppColors.success),
        );
      }
    }
  }

  Future<void> _handleChangePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Passwords do not match'),
            backgroundColor: Colors.red),
      );
      return;
    }
    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Password must be at least 6 characters'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isChangingPassword = true);
    final success = await ref.read(authProvider.notifier).changePassword(
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
        );
    if (mounted) {
      setState(() => _isChangingPassword = false);
      if (success) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Password changed successfully'),
              backgroundColor: AppColors.success),
        );
      } else {
        final error =
            ref.read(authProvider).errorMessage ?? 'Failed to change password';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || name.trim().isEmpty) return '?';
    if (parts.length >= 2) {
      final first = parts[0];
      final last = parts[parts.length - 1];
      if (first.isNotEmpty && last.isNotEmpty) {
        return '${first[0]}${last[0]}'.toUpperCase();
      }
    }
    return name.trim()[0].toUpperCase();
  }

  String _getRoleDisplayName(UserRole? role) {
    if (role == null) return 'USER';
    switch (role) {
      case UserRole.superAdmin:
        return 'SUPER ADMIN';
      case UserRole.executiveAdmin:
        return 'EXECUTIVE ADMIN';
      case UserRole.manager:
        return 'BRANCH MANAGER';
      case UserRole.collectionAgent:
        return 'COLLECTION AGENT';
      case UserRole.customer:
        return 'CUSTOMER';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final isStaff = user?.role == UserRole.manager ||
        user?.role == UserRole.collectionAgent;

    return profileAsync.when(
      data: (profile) {
        if (profile != null) {
          _initializeFields(profile);
        }
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: AuroraBackground(
            child: SafeArea(
              bottom: false,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // App Bar
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 16,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          onPressed: () => context.pop(),
                        ),
                      ),
                    ),
                    title: Text(
                      'Security Profile',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    centerTitle: true,
                  ),

                  // Header / Avatar Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Column(
                        children: [
                          // Glowing Ring Avatar
                          Center(
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: AppColors.premiumGradient,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.35),
                                        blurRadius: 24,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 54,
                                    backgroundColor: isDark ? const Color(0xFF0F1115) : Colors.white,
                                    child: CircleAvatar(
                                      radius: 50,
                                      backgroundColor: isDark ? const Color(0xFF141416) : Colors.grey[100],
                                      child: Text(
                                        _getInitials(profile?.fullName ?? user?.fullName ?? ''),
                                        style: theme.textTheme.headlineMedium?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primary,
                                          letterSpacing: -1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Custom camera badge overlay
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF0F1115) : Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                          const SizedBox(height: 16),

                          // Name and Role Badges
                          Text(
                            profile?.fullName ?? user?.fullName ?? 'User Profile',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _getRoleDisplayName(profile?.role ?? user?.role),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Org/Branch Cards
                          if (profile?.branchName != null || profile?.orgId != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (profile?.branchName != null) ...[
                                    Icon(
                                      Icons.storefront_rounded,
                                      size: 14,
                                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      profile!.branchName!,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  if (profile?.branchName != null && profile?.orgId != null)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                      child: Container(
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.3),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  if (profile?.orgId != null) ...[
                                    Icon(
                                      Icons.business_rounded,
                                      size: 14,
                                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'MFI Node ID: ${profile!.orgId!.substring(0, 8)}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Main Form
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Card 1: Personal Details
                            GlassCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle(theme, 'Personal Identity', Icons.person_outline),
                                  const SizedBox(height: 20),
                                  _ProfileTextField(
                                    label: 'Full Name',
                                    controller: _nameController,
                                    icon: Icons.badge_outlined,
                                    isDark: isDark,
                                    isRequired: true,
                                    autofillHints: const [AutofillHints.name],
                                  ),
                                  const SizedBox(height: 16),
                                  _ProfileTextField(
                                    label: "Father's Name",
                                    controller: _fatherNameController,
                                    icon: Icons.people_outline_rounded,
                                    isDark: isDark,
                                    autofillHints: const [AutofillHints.name],
                                  ),
                                  const SizedBox(height: 16),
                                  _ProfileTextField(
                                    label: 'Email Address',
                                    controller: _emailController,
                                    icon: Icons.email_outlined,
                                    isDark: isDark,
                                    isRequired: true,
                                    keyboardType: TextInputType.emailAddress,
                                    autofillHints: const [AutofillHints.email],
                                  ),
                                  const SizedBox(height: 16),
                                  _ProfileTextField(
                                    label: 'Phone Number',
                                    controller: _phoneController,
                                    icon: Icons.phone_outlined,
                                    isDark: isDark,
                                    isRequired: true,
                                    keyboardType: TextInputType.phone,
                                    autofillHints: const [AutofillHints.telephoneNumber],
                                  ),
                                  const SizedBox(height: 16),
                                  _ProfileTextField(
                                    label: 'Residential Address',
                                    controller: _addressController,
                                    icon: Icons.home_outlined,
                                    isDark: isDark,
                                    autofillHints: const [AutofillHints.streetAddressLine1],
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04, end: 0),
                            
                            const SizedBox(height: 16),

                            // Card 2: Field Ops (For staff/managers only)
                            if (isStaff) ...[
                              GlassCard(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionTitle(theme, 'Field Operations', Icons.corporate_fare_outlined),
                                    const SizedBox(height: 20),
                                    _ProfileTextField(
                                      label: 'Employee ID / Staff Code',
                                      controller: _employeeIdController,
                                      icon: Icons.badge_outlined,
                                      isDark: isDark,
                                    ),
                                    const SizedBox(height: 16),
                                    _ProfileTextField(
                                      label: 'Assigned Zone / Area',
                                      controller: _zoneController,
                                      icon: Icons.location_on_outlined,
                                      isDark: isDark,
                                    ),
                                  ],
                                ),
                              ).animate().fadeIn(delay: 80.ms, duration: 400.ms).slideY(begin: 0.04, end: 0),
                              const SizedBox(height: 16),
                            ],

                            // Card 3: ID Verification
                            GlassCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle(theme, 'Government Identifiers', Icons.domain_verification_outlined),
                                  const SizedBox(height: 20),
                                  _ProfileTextField(
                                    label: 'Aadhar Number (12 Digit)',
                                    controller: _aadharController,
                                    icon: Icons.fingerprint_outlined,
                                    isDark: isDark,
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      if (v != null && v.isNotEmpty && v.length != 12) {
                                        return 'Aadhar must be exactly 12 digits';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  _ProfileTextField(
                                    label: 'PAN Number (10 Alphanumeric)',
                                    controller: _panController,
                                    icon: Icons.credit_card_outlined,
                                    isDark: isDark,
                                    validator: (v) {
                                      if (v != null && v.isNotEmpty && v.length != 10) {
                                        return 'PAN must be exactly 10 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  GlassButton(
                                    label: 'Save Changes',
                                    width: double.infinity,
                                    isLoading: _isSaving,
                                    onTap: _handleUpdateProfile,
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(delay: 120.ms, duration: 400.ms).slideY(begin: 0.04, end: 0),

                            const SizedBox(height: 16),

                            // Card 4: Change Password / Security
                            GlassCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle(theme, 'Change Credentials', Icons.lock_outline),
                                  const SizedBox(height: 20),
                                  _ProfileTextField(
                                    label: 'Current Password',
                                    controller: _currentPasswordController,
                                    icon: Icons.lock_open_rounded,
                                    isDark: isDark,
                                    isPassword: true,
                                    autofillHints: const [AutofillHints.password],
                                  ),
                                  const SizedBox(height: 16),
                                  _ProfileTextField(
                                    label: 'New Password',
                                    controller: _newPasswordController,
                                    icon: Icons.vpn_key_outlined,
                                    isDark: isDark,
                                    isPassword: true,
                                    autofillHints: const [AutofillHints.newPassword],
                                  ),
                                  const SizedBox(height: 16),
                                  _ProfileTextField(
                                    label: 'Confirm New Password',
                                    controller: _confirmPasswordController,
                                    icon: Icons.check_circle_outline_rounded,
                                    isDark: isDark,
                                    isPassword: true,
                                    autofillHints: const [AutofillHints.newPassword],
                                  ),
                                  const SizedBox(height: 24),
                                  GlassButton(
                                    label: 'Update Security Credentials',
                                    width: double.infinity,
                                    color: Colors.orange,
                                    isLoading: _isChangingPassword,
                                    onTap: _handleChangePassword,
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(delay: 160.ms, duration: 400.ms).slideY(begin: 0.04, end: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: AuroraBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Decrypting secure node keys...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: AuroraBackground(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to read profile details',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.redAccent.withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(userProfileProvider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Retry Connection'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool isDark;
  final bool isPassword;
  final TextInputType? keyboardType;
  final List<String>? autofillHints;
  final String? Function(String?)? validator;
  final bool isRequired;

  const _ProfileTextField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.isDark,
    this.isPassword = false,
    this.keyboardType,
    this.autofillHints,
    this.validator,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              size: 18,
              color: isDark 
                  ? Colors.white.withValues(alpha: 0.4) 
                  : Colors.black.withValues(alpha: 0.4),
            ),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF141416)
                : Colors.black.withValues(alpha: 0.02),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Colors.redAccent,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Colors.redAccent,
                width: 1.5,
              ),
            ),
            errorStyle: const TextStyle(
              color: Colors.redAccent,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          validator: validator ?? (isRequired ? (v) => v == null || v.isEmpty ? 'Required' : null : null),
        ),
      ],
    );
  }
}
