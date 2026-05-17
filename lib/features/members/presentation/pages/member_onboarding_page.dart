import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../providers/onboarding_provider.dart';

class MemberOnboardingPage extends ConsumerStatefulWidget {
  const MemberOnboardingPage({super.key});

  @override
  ConsumerState<MemberOnboardingPage> createState() =>
      _MemberOnboardingPageState();
}

class _MemberOnboardingPageState extends ConsumerState<MemberOnboardingPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _businessTypeController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _shopNameController.dispose();
    _businessTypeController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Member Onboarding',
            style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildStepIndicator(primary),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(theme, state),
                _buildStep2(theme, state),
                _buildStep3(theme, state),
              ],
            ),
          ),
          _buildBottomNav(state, primary),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(Color primary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isActive ? primary : primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep1(ThemeData theme, OnboardingState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
              'Personal Details', 'Basic information about the member'),
          const SizedBox(height: 32),
          _buildInputField(
            label: 'FULL NAME',
            hint: 'Enter member\'s legal name',
            controller: _nameController,
            onChanged: (v) =>
                ref.read(onboardingProvider.notifier).updateFullName(v),
            theme: theme,
          ),
          const SizedBox(height: 24),
          _buildInputField(
            label: 'PHONE NUMBER',
            hint: '+91 XXXXXXXXXX',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            onChanged: (v) =>
                ref.read(onboardingProvider.notifier).updatePhone(v),
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(ThemeData theme, OnboardingState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
              'Business Profile', 'Details about their shop or venture'),
          const SizedBox(height: 32),
          _buildInputField(
            label: 'SHOP NAME',
            hint: 'e.g. Sharma General Store',
            controller: _shopNameController,
            onChanged: (v) =>
                ref.read(onboardingProvider.notifier).updateShopName(v),
            theme: theme,
          ),
          const SizedBox(height: 24),
          _buildInputField(
            label: 'BUSINESS TYPE',
            hint: 'e.g. Retail, Grocery, Service',
            controller: _businessTypeController,
            onChanged: (v) =>
                ref.read(onboardingProvider.notifier).updateBusinessType(v),
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildStep3(ThemeData theme, OnboardingState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
              'Field Intelligence', 'Capture proof of location and business'),
          const SizedBox(height: 32),
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.location_on_rounded,
                    size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text('GPS COORDINATES',
                    style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                if (state.latitude != null)
                  Text(
                      '${state.latitude!.toStringAsFixed(6)}, ${state.longitude!.toStringAsFixed(6)}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900))
                else
                  Text('NOT CAPTURED', style: theme.textTheme.bodySmall),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(onboardingProvider.notifier).captureLocation(),
                    icon: const Icon(Icons.gps_fixed_rounded),
                    label: const Text('Capture Live Location'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Placeholder for Photo Capture
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.dividerColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.1), width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_rounded,
                    size: 40, color: theme.dividerColor.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text('Capture Shop Photo', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: TextStyle(
                fontSize: 16,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.6))),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required Function(String) onChanged,
    required ThemeData theme,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.color
                    ?.withValues(alpha: 0.5))),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: keyboardType,
          style: const TextStyle(fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: theme.dividerColor.withValues(alpha: 0.05),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(20),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav(OnboardingState state, Color primary) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
            top: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            IconButton(
              onPressed: _prevStep,
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              style: IconButton.styleFrom(
                backgroundColor:
                    Theme.of(context).dividerColor.withValues(alpha: 0.05),
                padding: const EdgeInsets.all(16),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: state.isLoading
                  ? null
                  : (_currentStep < 2 ? _nextStep : _submit),
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentStep < 2 ? primary : AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: state.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      _currentStep < 2 ? 'CONTINUE' : 'FINALIZE REGISTRATION',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final success = await ref.read(onboardingProvider.notifier).submit();
    if (success && mounted) {
      _showSuccessDialog();
    } else if (mounted) {
      final error = ref.read(onboardingProvider).error;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error ?? 'Submission failed')));
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 80, color: AppColors.success),
            const SizedBox(height: 24),
            const Text('Member Registered!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            const Text(
                'KYC is now under review. You can now start collections for this member.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.pop();
                },
                child: const Text('BACK TO DASHBOARD'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
