import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SetupWizardPage extends ConsumerStatefulWidget {
  const SetupWizardPage({super.key});

  @override
  ConsumerState<SetupWizardPage> createState() => _SetupWizardPageState();
}

class _SetupWizardPageState extends ConsumerState<SetupWizardPage> {
  int _currentStep = 0;
  bool _isLoading = false;
  String? _createdBranchId;
  String? _createdStaffId;
  String? _createdMemberId;

  // Step 1: Branch
  final _branchNameCtrl = TextEditingController();
  final _branchCodeCtrl = TextEditingController();
  final _branchZoneCtrl = TextEditingController();
  final _branchDistrictCtrl = TextEditingController();

  // Step 2: Staff
  final _staffNameCtrl = TextEditingController();
  final _staffPhoneCtrl = TextEditingController();
  final _staffEmailCtrl = TextEditingController();
  String _staffRole = 'collector';

  // Step 3: Member
  final _memberNameCtrl = TextEditingController();
  final _memberPhoneCtrl = TextEditingController();

  @override
  void dispose() {
    _branchNameCtrl.dispose();
    _branchCodeCtrl.dispose();
    _branchZoneCtrl.dispose();
    _branchDistrictCtrl.dispose();
    _staffNameCtrl.dispose();
    _staffPhoneCtrl.dispose();
    _staffEmailCtrl.dispose();
    _memberNameCtrl.dispose();
    _memberPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _createBranch() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('Starting branch creation...');
      final client = ref.read(supabaseClientProvider);
      final authUser = client.auth.currentUser;
      String? orgId = ref.read(currentOrgIdProvider);

      if (orgId == null) {
        debugPrint('No orgId found, creating new organization...');
        final orgName = authUser?.userMetadata?['org_name'] as String? ?? 'My Organization';
        final slug = orgName
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            .replaceAll(RegExp(r'^-|-$'), '');
        final trialEnd = DateTime.now().add(const Duration(days: 14)).toIso8601String();

        final orgResponse = await client.from('organizations').insert({
          'name': orgName,
          'slug': slug,
          'status': 'trial',
          'trial_ends_at': trialEnd,
          'max_branches': 2,
          'max_staff': 5,
          'max_members': 100,
          'created_by': authUser?.id,
        }).select('id').single();
        orgId = orgResponse['id'].toString();
        debugPrint('Organization created: $orgId');

        if (authUser != null) {
          debugPrint('Updating user profile with org_id...');
          final fullName = authUser.userMetadata?['full_name'] as String? ?? '';
          final email = authUser.email ?? '';
          await client.from('profiles').upsert({
            'user_id': authUser.id,
            'full_name': fullName,
            'email': email,
            'role': 'executiveAdmin',
            'org_id': orgId,
          });
        }
      }

      debugPrint('Inserting branch for org $orgId...');
      final res = await client.from('branches').insert({
        'org_id': orgId,
        'name': _branchNameCtrl.text.trim(),
        'code': _branchCodeCtrl.text.trim().toUpperCase(),
        'zone': _branchZoneCtrl.text.trim(),
        'district': _branchDistrictCtrl.text.trim(),
        'status': 'active',
      }).select('id').single();
      _createdBranchId = res['id'].toString();
      debugPrint('Branch created: $_createdBranchId');

      debugPrint('Refreshing user session...');
      await ref.read(authProvider.notifier).refreshCurrentUser();

      setState(() => _currentStep = 1);
    } catch (e) {
      debugPrint('Setup error in _createBranch: $e');
      _showError(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createStaff() async {
    final orgId = ref.read(currentOrgIdProvider);
    if (orgId == null || _createdBranchId == null) return;
    setState(() => _isLoading = true);
    try {
      debugPrint('Starting staff creation for org $orgId and branch $_createdBranchId...');
      final client = ref.read(supabaseClientProvider);
      final staffCode = 'STF${DateTime.now().millisecondsSinceEpoch.toString().substring(5, 10)}';
      final res = await client.from('staff_profiles').insert({
        'org_id': orgId,
        'staff_code': staffCode,
        'full_name': _staffNameCtrl.text.trim(),
        'phone': _staffPhoneCtrl.text.trim(),
        'email': _staffEmailCtrl.text.trim().isEmpty ? null : _staffEmailCtrl.text.trim(),
        'role': _staffRole,
        'branch_id': _createdBranchId,
        'status': 'active',
      }).select('id').single();
      _createdStaffId = res['id'].toString();
      debugPrint('Staff profile created: $_createdStaffId');
      setState(() => _currentStep = 2);
    } catch (e) {
      debugPrint('Setup error in _createStaff: $e');
      _showError(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createMember() async {
    final orgId = ref.read(currentOrgIdProvider);
    if (orgId == null) return;
    setState(() => _isLoading = true);
    try {
      debugPrint('Starting member onboarding for org $orgId...');
      final client = ref.read(supabaseClientProvider);
      final memberId = 'M${DateTime.now().millisecondsSinceEpoch.toString().substring(4, 10)}';
      final res = await client.from('members').insert({
        'org_id': orgId,
        'full_name': _memberNameCtrl.text.trim(),
        'phone': _memberPhoneCtrl.text.trim(),
        'member_id': memberId,
        'kyc_status': 'verified',
        'area': _branchZoneCtrl.text.trim(),
      }).select('id').single();
      _createdMemberId = res['id'].toString();
      debugPrint('Member created: $_createdMemberId');
      setState(() => _currentStep = 3);
    } catch (e) {
      debugPrint('Setup error in _createMember: $e');
      _showError(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _skipStep() {
    setState(() => _currentStep++);
  }

  void _finish() {
    context.go('/');
  }

  void _showError(dynamic e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalSteps = 4;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Up Your Organization'),
        leading: Container(),
        actions: [
          TextButton(
            onPressed: _finish,
            child: const Text('Skip All'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgressBar(totalSteps),
              const SizedBox(height: 32),
              if (_currentStep == 0) _buildBranchStep(theme),
              if (_currentStep == 1) _buildStaffStep(theme),
              if (_currentStep == 2) _buildMemberStep(theme),
              if (_currentStep == 3) _buildDoneStep(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(int total) {
    final labels = ['Branch', 'Staff', 'Member', 'Done'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(total, (i) {
            final isActive = i == _currentStep;
            final isDone = i < _currentStep;
            return Expanded(
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? Colors.green
                          : isActive
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade300,
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : Text('${i + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              )),
                    ),
                  ),
                  if (i < total - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i < _currentStep ? Colors.green : Colors.grey.shade300,
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(total, (i) {
            return Text(
              labels[i],
              style: TextStyle(
                fontSize: 11,
                fontWeight: i == _currentStep ? FontWeight.w600 : FontWeight.w400,
                color: i == _currentStep
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildBranchStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Create Your First Branch', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Set up your main branch office.', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
        const SizedBox(height: 24),
        TextField(controller: _branchNameCtrl, decoration: const InputDecoration(labelText: 'Branch Name', hintText: 'e.g. Main Branch')),
        const SizedBox(height: 16),
        TextField(controller: _branchCodeCtrl, decoration: const InputDecoration(labelText: 'Branch Code', hintText: 'e.g. MAIN01')),
        const SizedBox(height: 16),
        TextField(controller: _branchZoneCtrl, decoration: const InputDecoration(labelText: 'Zone/Area', hintText: 'e.g. North Zone')),
        const SizedBox(height: 16),
        TextField(controller: _branchDistrictCtrl, decoration: const InputDecoration(labelText: 'District', hintText: 'e.g. Chennai')),
        const SizedBox(height: 32),
        _buildActionButton('Create Branch & Continue', _createBranch),
        _buildSkipButton(),
      ],
    );
  }

  Widget _buildStaffStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add Your First Staff Member', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Create a staff profile for your team.', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
        const SizedBox(height: 24),
        TextField(controller: _staffNameCtrl, decoration: const InputDecoration(labelText: 'Full Name', hintText: 'e.g. Rajesh Kumar')),
        const SizedBox(height: 16),
        TextField(controller: _staffPhoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', hintText: 'e.g. 9876543210')),
        const SizedBox(height: 16),
        TextField(controller: _staffEmailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email (optional)', hintText: 'e.g. rajesh@mfi.com')),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _staffRole,
          decoration: const InputDecoration(labelText: 'Role'),
          items: const [
            DropdownMenuItem(value: 'collector', child: Text('Field Collector')),
            DropdownMenuItem(value: 'supervisor', child: Text('Supervisor')),
            DropdownMenuItem(value: 'branch_manager', child: Text('Branch Manager')),
          ],
          onChanged: (v) => setState(() => _staffRole = v ?? 'collector'),
        ),
        const SizedBox(height: 32),
        _buildActionButton('Add Staff & Continue', _createStaff),
        _buildSkipButton(),
      ],
    );
  }

  Widget _buildMemberStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add a Sample Member', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Onboard your first customer to see how it works.', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
        const SizedBox(height: 24),
        TextField(controller: _memberNameCtrl, decoration: const InputDecoration(labelText: 'Member Name', hintText: 'e.g. Priya Sharma')),
        const SizedBox(height: 16),
        TextField(controller: _memberPhoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', hintText: 'e.g. 9876543211')),
        const SizedBox(height: 32),
        _buildActionButton('Add Member & Finish', _createMember),
        _buildSkipButton(),
      ],
    );
  }

  Widget _buildDoneStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.shade50,
          ),
          child: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        ),
        const SizedBox(height: 24),
        Text('You\'re All Set!', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text(
          'Your organization is ready to go.',
          style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        if (_createdBranchId != null) _doneItem(Icons.business, 'Branch created'),
        if (_createdStaffId != null) _doneItem(Icons.person, 'Staff member added'),
        if (_createdMemberId != null) _doneItem(Icons.people, 'Member onboarded'),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _finish,
            child: const Text('Go to Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _doneItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        child: _isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(label),
      ),
    );
  }

  Widget _buildSkipButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: _skipStep,
          child: const Text('Skip this step'),
        ),
      ),
    );
  }
}
