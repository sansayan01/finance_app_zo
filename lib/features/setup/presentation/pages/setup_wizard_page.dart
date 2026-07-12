import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/providers/setup_provider.dart';

class SetupWizardPage extends ConsumerStatefulWidget {
  const SetupWizardPage({super.key});

  @override
  ConsumerState<SetupWizardPage> createState() => _SetupWizardPageState();
}

class _SetupWizardPageState extends ConsumerState<SetupWizardPage> {
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _prefillFromProfile();
    _maybeRedirectIfAlreadyDone();
  }

  Future<void> _maybeRedirectIfAlreadyDone() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    final isComplete = ref.read(setupCompleteProvider).valueOrNull ?? true;
    if (isComplete) {
      context.go('/');
    }
  }

  // Step 1: Organization (3 fields)
  final _orgFormKey = GlobalKey<FormState>();
  final _orgNameController = TextEditingController();
  final _orgCityController = TextEditingController();
  final _orgPhoneController = TextEditingController();

  // Step 2: First Branch (2 fields)
  final _branchFormKey = GlobalKey<FormState>();
  final _branchNameController = TextEditingController();
  final _branchCodeController = TextEditingController();

  void _prefillFromProfile() async {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _orgPhoneController.text = user.phone ?? '';

      // Fetch org name + city from organizations table
      if (user.orgId != null) {
        try {
          final res = await Supabase.instance.client
              .from('organizations')
              .select('name, city')
              .eq('id', user.orgId!)
              .single();
          _orgNameController.text = res['name'] ?? '';
          _orgCityController.text = res['city'] ?? '';
          if (mounted) setState(() {});
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _orgNameController.dispose();
    _orgCityController.dispose();
    _orgPhoneController.dispose();
    _branchNameController.dispose();
    _branchCodeController.dispose();
    super.dispose();
  }

  void _nextStep() {
    bool isValid = false;
    switch (_currentStep) {
      case 0:
        isValid = _orgFormKey.currentState?.validate() ?? false;
        break;
      case 1:
        isValid = _branchFormKey.currentState?.validate() ?? false;
        break;
    }

    if (isValid) {
      if (_currentStep < 1) {
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

      // Step 1: Update organization (name, city, phone only)
      final orgUpdates = <String, dynamic>{
        if (_orgNameController.text.trim().isNotEmpty)
          'name': _orgNameController.text.trim(),
        if (_orgCityController.text.trim().isNotEmpty)
          'city': _orgCityController.text.trim(),
        if (_orgPhoneController.text.trim().isNotEmpty)
          'phone': _orgPhoneController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (orgUpdates.length > 1) {
        // More than just updated_at
        await client.from('organizations').update(orgUpdates).eq('id', orgId);
      }

      // Step 2: Create first branch (idempotent via RPC)
      await client.rpc('upsert_default_branch', params: {
        'p_org_id': orgId,
        'p_name': _branchNameController.text.trim(),
        'p_code': _branchCodeController.text.trim(),
        'p_address': '',
        'p_city': '',
        'p_state': '',
        'p_pincode': '',
        'p_phone': '',
        'p_email': null,
      });

      // Step 3: Mark org setup complete
      await client.rpc('complete_org_setup', params: {'p_org_id': orgId});

      // Refresh user data + invalidate setup provider so router sees true
      await ref.read(authProvider.notifier).refreshCurrentUser();
      ref.invalidate(setupCompleteProvider);
      await ref.read(setupCompleteProvider.future);

      if (mounted) {
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

    final orgName = _orgNameController.text.isNotEmpty
        ? _orgNameController.text
        : 'Your Organization';

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1219) : const Color(0xFFF8F9FC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme, isDark, primary, orgName),
            _buildProgressIndicator(primary, isDark),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildOrgDetailsStep(theme, isDark, primary),
                  _buildBranchStep(theme, isDark, primary),
                ],
              ),
            ),
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
            'Quick setup — just 2 steps!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(Color primary, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: List.generate(2, (index) {
          final isActive = index <= _currentStep;
          final isCurrent = index == _currentStep;

          return Expanded(
            child: Row(
              children: [
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
                if (index < 1)
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
    List<String>? autofillHints,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        autofillHints: autofillHints,
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

  // ── Step 1: Organization (Name + City + Phone) ──

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
              'Organization',
              'Basic details about your organization',
            ),
            _buildInputField(
              controller: _orgNameController,
              label: 'Organization Name',
              icon: Icons.business_outlined,
            ),
            _buildInputField(
              controller: _orgCityController,
              label: 'City',
              icon: Icons.location_city_outlined,
              autofillHints: const [AutofillHints.addressCity],
            ),
            _buildInputField(
              controller: _orgPhoneController,
              label: 'Phone',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofillHints: const [AutofillHints.telephoneNumber],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Phone is required';
                }
                if (value.length != 10) return 'Enter valid 10-digit phone';
                return null;
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Step 2: First Branch (Name + Code) ──

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
                        return 'Required';
                      }
                      if (value.trim().length < 2) return 'Min 2 chars';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Navigation buttons ──

  Widget _buildNavigationButtons(Color primary, bool isDark) {
    final isLastStep = _currentStep == 1;

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
          if (_currentStep > 0) ...[
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
            const SizedBox(width: 12),
          ],
          Expanded(
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
                      isLastStep
                          ? Icons.check_circle_rounded
                          : Icons.arrow_forward_rounded,
                      size: 18,
                    ),
              label: Text(
                _isSubmitting
                    ? 'Setting up...'
                    : (isLastStep ? 'Complete Setup' : 'Continue'),
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
