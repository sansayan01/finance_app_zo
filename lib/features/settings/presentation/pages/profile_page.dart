import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/glass_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/constants/enums.dart';

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

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nameController = TextEditingController(text: user?.fullName);
    _fatherNameController = TextEditingController(text: user?.fatherName ?? '');
    _phoneController = TextEditingController(text: user?.phone);
    _emailController = TextEditingController(text: user?.email);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final isStaff = user?.role == UserRole.manager ||
        user?.role == UserRole.collectionAgent;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () => context.pop(),
                ),
                title: Text('Edit Profile',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                centerTitle: true,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GlassCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle(theme, 'Account Details',
                                  Icons.person_outline),
                              const SizedBox(height: 24),
                              _ProfileTextField(
                                  label: 'Full Name',
                                  controller: _nameController,
                                  icon: Icons.badge_outlined,
                                  isDark: isDark),
                              const SizedBox(height: 16),
                              _ProfileTextField(
                                  label: "Father's Name",
                                  controller: _fatherNameController,
                                  icon: Icons.people_outline_rounded,
                                  isDark: isDark),
                              const SizedBox(height: 16),
                              _ProfileTextField(
                                  label: 'Email Address',
                                  controller: _emailController,
                                  icon: Icons.email_outlined,
                                  isDark: isDark,
                                  keyboardType: TextInputType.emailAddress),
                              const SizedBox(height: 16),
                              _ProfileTextField(
                                  label: 'Phone Number',
                                  controller: _phoneController,
                                  icon: Icons.phone_outlined,
                                  isDark: isDark,
                                  keyboardType: TextInputType.phone),
                              const SizedBox(height: 16),
                              _ProfileTextField(
                                  label: 'Residential Address',
                                  controller: _addressController,
                                  icon: Icons.home_outlined,
                                  isDark: isDark),
                            ],
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: 0.05, end: 0),
                        if (isStaff) ...[
                          const SizedBox(height: 20),
                          GlassCard(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle(theme, 'Field Operations',
                                    Icons.corporate_fare_outlined),
                                const SizedBox(height: 24),
                                _ProfileTextField(
                                    label: 'Employee ID',
                                    controller: _employeeIdController,
                                    icon: Icons.badge_outlined,
                                    isDark: isDark),
                                const SizedBox(height: 16),
                                _ProfileTextField(
                                    label: 'Assigned Zone / Area',
                                    controller: _zoneController,
                                    icon: Icons.location_on_outlined,
                                    isDark: isDark),
                              ],
                            ),
                          )
                              .animate()
                              .fadeIn(delay: 100.ms)
                              .slideY(begin: 0.05, end: 0),
                        ],
                        const SizedBox(height: 20),
                        GlassCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle(theme, 'Identity Verification',
                                  Icons.badge_outlined),
                              const SizedBox(height: 24),
                              _ProfileTextField(
                                  label: 'Aadhar Number',
                                  controller: _aadharController,
                                  icon: Icons.fingerprint_outlined,
                                  isDark: isDark,
                                  keyboardType: TextInputType.number),
                              const SizedBox(height: 16),
                              _ProfileTextField(
                                  label: 'PAN Number',
                                  controller: _panController,
                                  icon: Icons.credit_card_outlined,
                                  isDark: isDark),
                              const SizedBox(height: 24),
                              GlassButton(
                                  label: 'Update Profile',
                                  width: double.infinity,
                                  isLoading: _isSaving,
                                  onTap: _handleUpdateProfile),
                            ],
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 150.ms)
                            .slideY(begin: 0.05, end: 0),
                        const SizedBox(height: 24),
                        GlassCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle(
                                  theme, 'Security', Icons.lock_outline),
                              const SizedBox(height: 24),
                              _ProfileTextField(
                                  label: 'Current Password',
                                  controller: _currentPasswordController,
                                  icon: Icons.lock_open_rounded,
                                  isDark: isDark,
                                  isPassword: true),
                              const SizedBox(height: 16),
                              _ProfileTextField(
                                  label: 'New Password',
                                  controller: _newPasswordController,
                                  icon: Icons.vpn_key_outlined,
                                  isDark: isDark,
                                  isPassword: true),
                              const SizedBox(height: 16),
                              _ProfileTextField(
                                  label: 'Confirm New Password',
                                  controller: _confirmPasswordController,
                                  icon: Icons.check_circle_outline_rounded,
                                  isDark: isDark,
                                  isPassword: true),
                              const SizedBox(height: 24),
                              GlassButton(
                                  label: 'Change Password',
                                  width: double.infinity,
                                  color: Colors.orange,
                                  isLoading: _isChangingPassword,
                                  onTap: _handleChangePassword),
                            ],
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 200.ms)
                            .slideY(begin: 0.05, end: 0),
                        const SizedBox(height: 100),
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
  }

  Widget _buildSectionTitle(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
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

  const _ProfileTextField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.isDark,
    this.isPassword = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color:
                    theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7))),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05)),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: isPassword,
            keyboardType: keyboardType,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              prefixIcon: Icon(icon,
                  size: 18, color: AppColors.primary.withValues(alpha: 0.7)),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
        ),
      ],
    );
  }
}
