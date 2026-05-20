import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SetupWizardPage extends ConsumerStatefulWidget {
  const SetupWizardPage({super.key});

  @override
  ConsumerState<SetupWizardPage> createState() => _SetupWizardPageState();
}

class _SetupWizardPageState extends ConsumerState<SetupWizardPage> {
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Step 1: Organization Details
  final _orgFormKey = GlobalKey<FormState>();
  final _orgAddressController = TextEditingController();
  final _orgCityController = TextEditingController();
  final _orgStateController = TextEditingController();
  final _orgPincodeController = TextEditingController();
  final _orgPhoneController = TextEditingController();
  final _orgEmailController = TextEditingController();
  final _orgGstController = TextEditingController();

  // Step 2: Owner Details
  final _ownerFormKey = GlobalKey<FormState>();
  final _ownerPhoneController = TextEditingController();
  final _ownerAddressController = TextEditingController();
  final _ownerCityController = TextEditingController();
  final _ownerStateController = TextEditingController();
  final _ownerPincodeController = TextEditingController();
  final _ownerAadharController = TextEditingController();
  final _ownerPanController = TextEditingController();

  // Step 3: First Branch
  final _branchFormKey = GlobalKey<FormState>();
  final _branchNameController = TextEditingController();
  final _branchCodeController = TextEditingController();
  final _branchAddressController = TextEditingController();
  final _branchCityController = TextEditingController();
  final _branchStateController = TextEditingController();
  final _branchPincodeController = TextEditingController();
  final _branchPhoneController = TextEditingController();
  final _branchEmailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _prefillFromProfile();
  }

  void _prefillFromProfile() {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _ownerPhoneController.text = user.phone ?? '';
      _ownerAddressController.text = user.address ?? '';
      _ownerCityController.text = user.city ?? '';
      _ownerStateController.text = user.state ?? '';
      _ownerPincodeController.text = user.pincode ?? '';
      _orgEmailController.text = user.email ?? '';
      _orgPhoneController.text = user.phone ?? '';
    }
  }

  @override
  void dispose() {
    _orgAddressController.dispose();
    _orgCityController.dispose();
    _orgStateController.dispose();
    _orgPincodeController.dispose();
    _orgPhoneController.dispose();
    _orgEmailController.dispose();
    _orgGstController.dispose();
    _ownerPhoneController.dispose();
    _ownerAddressController.dispose();
    _ownerCityController.dispose();
    _ownerStateController.dispose();
    _ownerPincodeController.dispose();
    _ownerAadharController.dispose();
    _ownerPanController.dispose();
    _branchNameController.dispose();
    _branchCodeController.dispose();
    _branchAddressController.dispose();
    _branchCityController.dispose();
    _branchStateController.dispose();
    _branchPincodeController.dispose();
    _branchPhoneController.dispose();
    _branchEmailController.dispose();
    super.dispose();
  }

  void _nextStep() {
    bool isValid = false;
    switch (_currentStep) {
      case 0:
        isValid = _orgFormKey.currentState?.validate() ?? false;
        break;
      case 1:
        isValid = _ownerFormKey.currentState?.validate() ?? false;
        break;
      case 2:
        isValid = _branchFormKey.currentState?.validate() ?? false;
        break;
    }

    if (isValid) {
      if (_currentStep < 2) {
        setState(() => _currentStep++);
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _submit();
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null || user.orgId == null) {
        throw Exception('User or organization not found');
      }

      final client = Supabase.instance.client;
      final orgId = user.orgId!;
      final userId = user.id;

      // Step 1: Update organization details
      await client.from('organizations').update({
        'address': _orgAddressController.text.trim(),
        'city': _orgCityController.text.trim(),
        'state': _orgStateController.text.trim(),
        'pincode': _orgPincodeController.text.trim(),
        'phone': _orgPhoneController.text.trim(),
        'email': _orgEmailController.text.trim(),
        'gst_number': _orgGstController.text.trim().isEmpty
            ? null
            : _orgGstController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orgId);

      // Step 2: Update owner profile
      await client.from('profiles').update({
        'phone': _ownerPhoneController.text.trim(),
        'address': _ownerAddressController.text.trim(),
        'city': _ownerCityController.text.trim(),
        'state': _ownerStateController.text.trim(),
        'pincode': _ownerPincodeController.text.trim(),
        'aadhar': _ownerAadharController.text.trim().isEmpty
            ? null
            : _ownerAadharController.text.trim(),
        'pan': _ownerPanController.text.trim().isEmpty
            ? null
            : _ownerPanController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);

      // Step 3: Create first branch
      await client.from('branches').insert({
        'org_id': orgId,
        'name': _branchNameController.text.trim(),
        'code': _branchCodeController.text.trim().toUpperCase(),
        'address': _branchAddressController.text.trim(),
        'city': _branchCityController.text.trim(),
        'state': _branchStateController.text.trim(),
        'pincode': _branchPincodeController.text.trim(),
        'phone': _branchPhoneController.text.trim(),
        'email': _branchEmailController.text.trim().isEmpty
            ? null
            : _branchEmailController.text.trim(),
        'status': 'active',
      });

      // Refresh user data
      await ref.read(authProvider.notifier).refreshCurrentUser();

      if (mounted) {
        // Show success and navigate
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Organization setup complete!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Setup failed: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final user = ref.watch(currentUserProvider);
    final orgName = user?.orgName ?? 'Your Organization';

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1219) : const Color(0xFFF8F9FC),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(theme, isDark, primary, orgName),

            // Progress indicator
            _buildProgressIndicator(primary, isDark),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildOrgDetailsStep(theme, isDark, primary),
                  _buildOwnerDetailsStep(theme, isDark, primary),
                  _buildBranchStep(theme, isDark, primary),
                ],
              ),
            ),

            // Navigation buttons
            _buildNavigationButtons(primary, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      ThemeData theme, bool isDark, Color primary, String orgName) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Column(
        children: [
          // Logo
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary, primary.withValues(alpha: 0.7)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.business_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            'Welcome to $orgName',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Complete the setup to get started',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(Color primary, bool isDark) {
    final steps = ['Organization', 'Your Details', 'First Branch'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index <= _currentStep;
          final isCurrent = index == _currentStep;

          return Expanded(
            child: Row(
              children: [
                // Circle
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isActive
                        ? primary
                        : (isDark ? Colors.white12 : Colors.grey.shade200),
                    shape: BoxShape.circle,
                    border: isCurrent
                        ? Border.all(color: primary, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: isActive && !isCurrent
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive
                                  ? Colors.white
                                  : (isDark ? Colors.white38 : Colors.black38),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
                // Line
                if (index < 2)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isActive
                          ? primary
                          : (isDark ? Colors.white12 : Colors.grey.shade200),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepTitle(ThemeData theme, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.brightness == Brightness.dark
                  ? Colors.white54
                  : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          counterText: '',
        ),
        validator: validator ??
            (required
                ? (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '$label is required';
                    }
                    return null;
                  }
                : null),
      ),
    );
  }

  Widget _buildOrgDetailsStep(ThemeData theme, bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _orgFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepTitle(
              theme,
              'Organization Details',
              'Tell us about your organization',
            ),
            _buildInputField(
              controller: _orgAddressController,
              label: 'Address',
              icon: Icons.location_on_outlined,
            ),
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    controller: _orgCityController,
                    label: 'City',
                    icon: Icons.location_city_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInputField(
                    controller: _orgStateController,
                    label: 'State',
                    icon: Icons.map_outlined,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    controller: _orgPincodeController,
                    label: 'Pincode',
                    icon: Icons.pin_outlined,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Pincode is required';
                      }
                      if (value.length != 6) return 'Enter valid 6-digit pincode';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInputField(
                    controller: _orgPhoneController,
                    label: 'Phone',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Phone is required';
                      }
                      if (value.length != 10) return 'Enter valid 10-digit phone';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            _buildInputField(
              controller: _orgEmailController,
              label: 'Organization Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email is required';
                }
                if (!value.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            _buildInputField(
              controller: _orgGstController,
              label: 'GST Number (Optional)',
              icon: Icons.receipt_long_outlined,
              required: false,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerDetailsStep(ThemeData theme, bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _ownerFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepTitle(
              theme,
              'Your Details',
              'Complete your personal information',
            ),
            _buildInputField(
              controller: _ownerPhoneController,
              label: 'Phone',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Phone is required';
                }
                if (value.length != 10) return 'Enter valid 10-digit phone';
                return null;
              },
            ),
            _buildInputField(
              controller: _ownerAddressController,
              label: 'Address',
              icon: Icons.home_outlined,
            ),
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    controller: _ownerCityController,
                    label: 'City',
                    icon: Icons.location_city_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInputField(
                    controller: _ownerStateController,
                    label: 'State',
                    icon: Icons.map_outlined,
                  ),
                ),
              ],
            ),
            _buildInputField(
              controller: _ownerPincodeController,
              label: 'Pincode',
              icon: Icons.pin_outlined,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Pincode is required';
                }
                if (value.length != 6) return 'Enter valid 6-digit pincode';
                return null;
              },
            ),
            _buildInputField(
              controller: _ownerAadharController,
              label: 'Aadhar Number (Optional)',
              icon: Icons.badge_outlined,
              keyboardType: TextInputType.number,
              maxLength: 12,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              required: false,
            ),
            _buildInputField(
              controller: _ownerPanController,
              label: 'PAN Number (Optional)',
              icon: Icons.credit_card_outlined,
              maxLength: 10,
              required: false,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchStep(ThemeData theme, bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _branchFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepTitle(
              theme,
              'First Branch',
              'Create your first branch to start operations',
            ),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildInputField(
                    controller: _branchNameController,
                    label: 'Branch Name',
                    icon: Icons.store_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInputField(
                    controller: _branchCodeController,
                    label: 'Code',
                    icon: Icons.tag_outlined,
                    maxLength: 10,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Code is required';
                      }
                      if (value.trim().length < 2) return 'Min 2 chars';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            _buildInputField(
              controller: _branchAddressController,
              label: 'Branch Address',
              icon: Icons.location_on_outlined,
            ),
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    controller: _branchCityController,
                    label: 'City',
                    icon: Icons.location_city_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInputField(
                    controller: _branchStateController,
                    label: 'State',
                    icon: Icons.map_outlined,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    controller: _branchPincodeController,
                    label: 'Pincode',
                    icon: Icons.pin_outlined,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Pincode is required';
                      }
                      if (value.length != 6) return 'Enter valid 6-digit pincode';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInputField(
                    controller: _branchPhoneController,
                    label: 'Phone',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Phone is required';
                      }
                      if (value.length != 10) return 'Enter valid 10-digit phone';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            _buildInputField(
              controller: _branchEmailController,
              label: 'Branch Email (Optional)',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              required: false,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(Color primary, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1219) : const Color(0xFFF8F9FC),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _prevStep,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: _currentStep == 0 ? 1 : 1,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _nextStep,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(
                      _currentStep == 2
                          ? Icons.check_circle_rounded
                          : Icons.arrow_forward_rounded,
                      size: 18,
                    ),
              label: Text(
                _isSubmitting
                    ? 'Setting up...'
                    : (_currentStep == 2 ? 'Complete Setup' : 'Continue'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
