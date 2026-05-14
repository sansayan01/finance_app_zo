import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/haptic_service.dart';

/// Setup Wizard for new organizations
/// Steps:
/// 1. Organization Details (mandatory) - brand name, logo, address, GST
/// 2. First Branch (mandatory)
/// 3. First Branch Manager (mandatory) - assign to branch
/// 4. First Collection Agent (skippable) - assign to branch
/// 5. First Customer (skippable) - assign to branch
class SetupWizardPage extends ConsumerStatefulWidget {
  const SetupWizardPage({super.key});

  @override
  ConsumerState<SetupWizardPage> createState() => _SetupWizardPageState();
}

class _SetupWizardPageState extends ConsumerState<SetupWizardPage> {
  int _currentStep = 0;
  bool _isLoading = false;
  String? _error;
  static const String _stepKey = 'wizard_current_step';
  
  // Created IDs for reference
  String? _createdBranchId;
  String? _createdBranchManagerId;
  String? _createdCollectionAgentId;
  String? _createdCustomerId;
  
  // List of branches for selection
  List<Map<String, dynamic>> _branches = [];

  // ============================================
  // STEP 1: Organization Details
  // ============================================
  final _orgDisplayNameCtrl = TextEditingController();
  final _orgAddressCtrl = TextEditingController();
  final _orgCityCtrl = TextEditingController();
  final _orgStateCtrl = TextEditingController();
  final _orgPincodeCtrl = TextEditingController();
  final _orgGstCtrl = TextEditingController();
  final _orgPhoneCtrl = TextEditingController();
  final _orgEmailCtrl = TextEditingController();
  Uint8List? _orgLogoBytes;
  bool _logoChanged = false;

  // ============================================
  // STEP 2: First Branch (mandatory)
  // ============================================
  final _branchNameCtrl = TextEditingController();
  final _branchCodeCtrl = TextEditingController();
  final _branchZoneCtrl = TextEditingController();
  final _branchDistrictCtrl = TextEditingController();
  final _branchAddressCtrl = TextEditingController();

  // ============================================
  // STEP 3: First Branch Manager (mandatory)
  // ============================================
  final _managerNameCtrl = TextEditingController();
  final _managerPhoneCtrl = TextEditingController();
  final _managerEmailCtrl = TextEditingController();
  final _managerEmployeeIdCtrl = TextEditingController();
  final _managerZoneCtrl = TextEditingController();
  final _managerAddressCtrl = TextEditingController();
  String? _selectedManagerBranchId;

  // ============================================
  // STEP 4: First Collection Agent (skippable)
  // ============================================
  final _agentNameCtrl = TextEditingController();
  final _agentPhoneCtrl = TextEditingController();
  final _agentEmailCtrl = TextEditingController();
  final _agentEmployeeIdCtrl = TextEditingController();
  final _agentZoneCtrl = TextEditingController();
  final _agentAddressCtrl = TextEditingController();
  String? _selectedAgentBranchId;

  // ============================================
  // STEP 5: First Customer (skippable)
  // ============================================
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _customerAadharCtrl = TextEditingController();
  final _customerPanCtrl = TextEditingController();
  String? _selectedCustomerBranchId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final authUser = ref.read(supabaseClientProvider).auth.currentUser;
      final orgName = authUser?.userMetadata?['org_name'] as String?;
      if (orgName != null && orgName.isNotEmpty) {
        _orgDisplayNameCtrl.text = orgName;
      }

      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      if (prefs.getBool('wizard_completed') == true) {
        setState(() => _currentStep = 5);
        return;
      }

      final savedStep = prefs.getInt(_stepKey);
      if (savedStep != null && savedStep > 0 && savedStep < 5) {
        final resume = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Resume Setup?'),
            content: Text('You left off at step ${savedStep + 1}. Would you like to resume from where you stopped?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Start Over'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Resume'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (resume == true) {
          setState(() => _currentStep = savedStep);
        } else {
          await prefs.remove(_stepKey);
        }
      }
    });
  }

  @override
  void dispose() {
    _orgDisplayNameCtrl.dispose();
    _orgAddressCtrl.dispose();
    _orgCityCtrl.dispose();
    _orgStateCtrl.dispose();
    _orgPincodeCtrl.dispose();
    _orgGstCtrl.dispose();
    _orgPhoneCtrl.dispose();
    _orgEmailCtrl.dispose();
    _branchNameCtrl.dispose();
    _branchCodeCtrl.dispose();
    _branchZoneCtrl.dispose();
    _branchDistrictCtrl.dispose();
    _branchAddressCtrl.dispose();
    _managerNameCtrl.dispose();
    _managerPhoneCtrl.dispose();
    _managerEmailCtrl.dispose();
    _managerEmployeeIdCtrl.dispose();
    _managerZoneCtrl.dispose();
    _managerAddressCtrl.dispose();
    _agentNameCtrl.dispose();
    _agentPhoneCtrl.dispose();
    _agentEmailCtrl.dispose();
    _agentEmployeeIdCtrl.dispose();
    _agentZoneCtrl.dispose();
    _agentAddressCtrl.dispose();
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _customerAadharCtrl.dispose();
    _customerPanCtrl.dispose();
    super.dispose();
  }

  // ============================================
  // STEP 1: Save Organization Details
  // ============================================
  Future<void> _saveOrganizationDetails() async {
    if (_orgDisplayNameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter organization display name');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final authUser = client.auth.currentUser;
      String? orgId = ref.read(currentOrgIdProvider);

      // Create organization if doesn't exist
      if (orgId == null) {
        final orgName = authUser?.userMetadata?['org_name'] as String? ?? 'My Organization';
        final slug = orgName
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            .replaceAll(RegExp(r'^-|-$'), '');
        final trialEnd = DateTime.now().add(const Duration(days: 14)).toIso8601String();

        final orgResponse = await client.from('organizations').insert({
          'name': orgName,
          'display_name': _orgDisplayNameCtrl.text.trim(),
          'slug': slug,
          'status': 'trial',
          'trial_ends_at': trialEnd,
          'max_branches': 2,
          'max_staff': 5,
          'max_members': 100,
          'address': _orgAddressCtrl.text.trim(),
          'city': _orgCityCtrl.text.trim(),
          'state': _orgStateCtrl.text.trim(),
          'pincode': _orgPincodeCtrl.text.trim(),
          'gst_number': _orgGstCtrl.text.trim().isNotEmpty ? _orgGstCtrl.text.trim() : null,
          'phone': _orgPhoneCtrl.text.trim(),
          'email': _orgEmailCtrl.text.trim(),
          'brand_color': '#1976D2', // Default brand color
          'created_by': authUser?.id,
        }).select('id').single();
        orgId = orgResponse['id'].toString();

        // Update user profile
        if (authUser != null) {
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
      } else {
        // Update existing organization
        await client.from('organizations').update({
          'display_name': _orgDisplayNameCtrl.text.trim(),
          'address': _orgAddressCtrl.text.trim(),
          'city': _orgCityCtrl.text.trim(),
          'state': _orgStateCtrl.text.trim(),
          'pincode': _orgPincodeCtrl.text.trim(),
          'gst_number': _orgGstCtrl.text.trim().isNotEmpty ? _orgGstCtrl.text.trim() : null,
          'phone': _orgPhoneCtrl.text.trim(),
          'email': _orgEmailCtrl.text.trim(),
        }).eq('id', orgId);
      }

      // Upload logo if selected
      if (_orgLogoBytes != null) {
        final isPng = _orgLogoBytes!.length > 4 &&
            _orgLogoBytes![0] == 0x89 && _orgLogoBytes![1] == 0x50 &&
            _orgLogoBytes![2] == 0x4E && _orgLogoBytes![3] == 0x47;
        final ext = isPng ? 'png' : 'jpg';
        final mime = isPng ? 'image/png' : 'image/jpeg';
        final logoFileName = 'org_$orgId/logo.$ext';

        await client.storage.from('brand-assets').uploadBinary(
          logoFileName,
          _orgLogoBytes!,
          fileOptions: FileOptions(contentType: mime, upsert: true),
        );

        final logoUrl = client.storage.from('brand-assets').getPublicUrl(logoFileName);
        await client.from('organizations').update({
          'logo_url': logoUrl,
        }).eq('id', orgId);

        if (!mounted) return;
        setState(() => _logoChanged = true);
      }

      await ref.read(authProvider.notifier).refreshCurrentUser();
      await _saveStep(1);
      if (!mounted) return;
      setState(() => _currentStep = 1);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================
  // STEP 2: Create First Branch
  // ============================================
  Future<void> _createBranch() async {
    if (_branchNameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter branch name');
      return;
    }
    if (_branchCodeCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter branch code');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final orgId = ref.read(currentOrgIdProvider);
      if (orgId == null) throw Exception('Organization not found');

      final code = _branchCodeCtrl.text.trim().toUpperCase();

      // Check if branch with this code already exists (from a partial run)
      final existing = await client.from('branches')
          .select('id, name')
          .eq('org_id', orgId)
          .eq('code', code)
          .maybeSingle();

      String branchName;
      if (existing != null) {
        _createdBranchId = existing['id'].toString();
        branchName = existing['name'] as String;
      } else {
        final res = await client.from('branches').insert({
          'org_id': orgId,
          'name': _branchNameCtrl.text.trim(),
          'code': code,
          'city': _branchZoneCtrl.text.trim(),
          'state': _branchDistrictCtrl.text.trim(),
          'address': _branchAddressCtrl.text.trim(),
          'status': 'active',
        }).select('id, name').single();
        
        _createdBranchId = res['id'].toString();
        branchName = res['name'] as String;
      }
      
      // Add to branches list for selection
      if (!mounted) return;
      setState(() {
        _branches = [
          {'id': _createdBranchId, 'name': branchName},
        ];
        _selectedManagerBranchId = _createdBranchId;
        _selectedAgentBranchId = _createdBranchId;
        _selectedCustomerBranchId = _createdBranchId;
      });
      
      await _saveStep(2);
      if (!mounted) return;
      setState(() => _currentStep = 2);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================
  // STEP 3: Create First Branch Manager
  // ============================================
  Future<void> _createBranchManager() async {
    if (_managerNameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter manager name');
      return;
    }
    if (_managerPhoneCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter manager phone');
      return;
    }
    if (_selectedManagerBranchId == null) {
      setState(() => _error = 'Please select a branch');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final orgId = ref.read(currentOrgIdProvider);
      if (orgId == null) throw Exception('Organization not found');

      // Check if manager already exists (reuse on retry)
      final existing = await client.from('profiles')
          .select('id')
          .eq('org_id', orgId)
          .eq('role', 'manager')
          .maybeSingle();
      if (existing != null) {
        _createdBranchManagerId = existing['id'].toString();
        await _saveStep(3);
        if (!mounted) return;
        setState(() => _currentStep = 3);
        return;
      }

      final managerCode = 'BM${DateTime.now().millisecondsSinceEpoch.toString().substring(5, 10)}';
      
      final res = await client.from('profiles').insert({
        'org_id': orgId,
        'full_name': _managerNameCtrl.text.trim(),
        'phone': _managerPhoneCtrl.text.trim(),
        'email': _managerEmailCtrl.text.trim().isNotEmpty ? _managerEmailCtrl.text.trim() : null,
        'role': 'manager',
        'branch_id': _selectedManagerBranchId,
        'status': 'active',
        'staff_code': managerCode,
        'employee_id': _managerEmployeeIdCtrl.text.trim().isNotEmpty ? _managerEmployeeIdCtrl.text.trim() : null,
        'assigned_zone': _managerZoneCtrl.text.trim().isNotEmpty ? _managerZoneCtrl.text.trim() : null,
      }).select('id').single();
      
      _createdBranchManagerId = res['id'].toString();
      await _saveStep(3);
      if (!mounted) return;
      setState(() => _currentStep = 3);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================
  // STEP 4: Create First Collection Agent
  // ============================================
  Future<void> _createCollectionAgent() async {
    if (_agentNameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter agent name');
      return;
    }
    if (_agentPhoneCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter agent phone');
      return;
    }
    if (_selectedAgentBranchId == null) {
      setState(() => _error = 'Please select a branch');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final orgId = ref.read(currentOrgIdProvider);
      if (orgId == null) throw Exception('Organization not found');

      // Check if agent already exists (reuse on retry)
      final existing = await client.from('profiles')
          .select('id')
          .eq('org_id', orgId)
          .eq('role', 'collectionAgent')
          .maybeSingle();
      if (existing != null) {
        _createdCollectionAgentId = existing['id'].toString();
        await _saveStep(4);
        if (!mounted) return;
        setState(() => _currentStep = 4);
        return;
      }

      final agentCode = 'CA${DateTime.now().millisecondsSinceEpoch.toString().substring(5, 10)}';
      
      final res = await client.from('profiles').insert({
        'org_id': orgId,
        'full_name': _agentNameCtrl.text.trim(),
        'phone': _agentPhoneCtrl.text.trim(),
        'email': _agentEmailCtrl.text.trim().isNotEmpty ? _agentEmailCtrl.text.trim() : null,
        'role': 'collectionAgent',
        'branch_id': _selectedAgentBranchId,
        'status': 'active',
        'staff_code': agentCode,
        'employee_id': _agentEmployeeIdCtrl.text.trim().isNotEmpty ? _agentEmployeeIdCtrl.text.trim() : null,
        'assigned_zone': _agentZoneCtrl.text.trim().isNotEmpty ? _agentZoneCtrl.text.trim() : null,
      }).select('id').single();
      
      _createdCollectionAgentId = res['id'].toString();
      await _saveStep(4);
      if (!mounted) return;
      setState(() => _currentStep = 4);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================
  // STEP 5: Create First Customer
  // ============================================
  Future<void> _createCustomer() async {
    if (_customerNameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter customer name');
      return;
    }
    if (_customerPhoneCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter customer phone');
      return;
    }
    if (_selectedCustomerBranchId == null) {
      setState(() => _error = 'Please select a branch');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final orgId = ref.read(currentOrgIdProvider);
      if (orgId == null) throw Exception('Organization not found');

      // Check if customer already exists (reuse on retry)
      final existing = await client.from('members')
          .select('id')
          .eq('org_id', orgId)
          .eq('full_name', _customerNameCtrl.text.trim())
          .maybeSingle();
      if (existing != null) {
        _createdCustomerId = existing['id'].toString();
        await _saveStep(5);
        if (!mounted) return;
        setState(() => _currentStep = 5);
        return;
      }

      final customerId = 'C${DateTime.now().millisecondsSinceEpoch.toString().substring(4, 10)}';
      
      final res = await client.from('members').insert({
        'org_id': orgId,
        'full_name': _customerNameCtrl.text.trim(),
        'phone': _customerPhoneCtrl.text.trim(),
        'member_id': customerId,
        'branch_id': _selectedCustomerBranchId,
        'kyc_status': 'pending',
        'status': 'active',
        'pan': _customerPanCtrl.text.trim().isNotEmpty ? _customerPanCtrl.text.trim().toUpperCase() : null,
        'aadhar': _customerAadharCtrl.text.trim().isNotEmpty ? _customerAadharCtrl.text.trim() : null,
      }).select('id').single();
      
      _createdCustomerId = res['id'].toString();
      await _saveStep(5);
      if (!mounted) return;
      setState(() => _currentStep = 5);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================
  // HELPER: Pick & Compress Logo Image
  // Auto-compresses to ~5KB, max upload 1MB
  // ============================================
  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 30,
    );

    if (pickedFile == null) return;

    final rawBytes = await pickedFile.readAsBytes();

    final compressed = await _compressLogo(rawBytes);

    if (mounted) {
      setState(() => _orgLogoBytes = compressed);
      final originalKb = (rawBytes.length / 1024).toStringAsFixed(1);
      final compressedKb = (compressed.length / 1024).toStringAsFixed(1);
      final pct = rawBytes.isNotEmpty ? ((1 - compressed.length / rawBytes.length) * 100).toStringAsFixed(0) : '0';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$originalKb KB → $compressedKb KB ($pct% reduction)'), backgroundColor: Colors.green, duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<Uint8List> _compressLogo(Uint8List raw) async {
    try {
      final codec = await ui.instantiateImageCodec(raw, targetWidth: 256, targetHeight: 256);
      final frame = await codec.getNextFrame();
      final resized = frame.image;

      final pngData = await resized.toByteData(format: ui.ImageByteFormat.png);
      
      resized.dispose();
      codec.dispose();
      
      return pngData?.buffer.asUint8List() ?? raw;
    } catch (_) {
      return raw;
    }
  }

  Future<void> _saveStep(int step) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_stepKey, step);
  }

  void _skipStep() {
    setState(() {
      _error = null;
      _currentStep++;
    });
  }

  void _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stepKey);
    await prefs.setBool('wizard_completed', true);
    ref.invalidate(setupCompleteProvider);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalSteps = 5;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Wizard'),
        leading: Container(), // Remove back button
        actions: [],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgressBar(totalSteps, theme),
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              // Step content
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildCurrentStep(theme, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(int total, ThemeData theme) {
    final stepLabels = [
      'Organization',
      'Branch',
      'Manager',
      'Agent',
      'Customer',
    ];
    final mandatorySteps = [true, true, true, false, false];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress indicator
        Row(
          children: List.generate(total, (i) {
            final isActive = i == _currentStep;
            final isDone = i < _currentStep;
            
            return Expanded(
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? Colors.green
                          : isActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                      border: Border.all(
                        color: isActive ? theme.colorScheme.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check, size: 18, color: Colors.white)
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: isActive ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  if (i < total - 1)
                    Expanded(
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: i < _currentStep 
                              ? Colors.green 
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        // Step labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(total, (i) {
            final isActive = i == _currentStep;
            final isSkippable = !mandatorySteps[i];
            
            return Expanded(
              child: Column(
                children: [
                  Text(
                    stepLabels[i],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (isSkippable && isActive)
                    Text(
                      'Optional',
                      style: TextStyle(
                        fontSize: 8,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCurrentStep(ThemeData theme, bool isDark) {
    switch (_currentStep) {
      case 0:
        return _buildOrgStep(theme, isDark);
      case 1:
        return _buildBranchStep(theme, isDark);
      case 2:
        return _buildManagerStep(theme, isDark);
      case 3:
        return _buildAgentStep(theme, isDark);
      case 4:
        return _buildCustomerStep(theme, isDark);
      case 5:
        return _buildDoneStep(theme, isDark);
      default:
        return const SizedBox();
    }
  }

  // ============================================
  // STEP 1: Organization Details
  // ============================================
  Widget _buildOrgStep(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Setup Your Organization',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Configure your organization branding and details. This will be reflected across the app.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),

        // Logo Upload Section
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickLogo,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.surfaceContainerHighest,
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: _orgLogoBytes != null
                      ? ClipOval(
                          child: Image.memory(
                            _orgLogoBytes!,
                            fit: BoxFit.cover,
                            width: 116,
                            height: 116,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.business,
                              size: 40,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add Logo',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                ),
              ).animate().scale(
                begin: const Offset(0.8, 0.8),
                duration: 400.ms,
              ),
              const SizedBox(height: 8),
              Text(
                'Brand Logo (will change app icon)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (_orgLogoBytes != null)
                TextButton(
                  onPressed: _pickLogo,
                  child: const Text('Change Logo'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Organization Details Form
        TextField(
          controller: _orgDisplayNameCtrl,
          decoration: const InputDecoration(
            labelText: 'Organization Display Name *',
            hintText: 'e.g., ABC Micro Finance',
            helperText: 'This name will appear in the app',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _orgAddressCtrl,
          decoration: const InputDecoration(
            labelText: 'Address',
            hintText: 'Street address',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _orgCityCtrl,
                decoration: const InputDecoration(
                  labelText: 'City',
                  hintText: 'e.g., Mumbai',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _orgPincodeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Pincode',
                  hintText: '400001',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _orgStateCtrl,
                decoration: const InputDecoration(
                  labelText: 'State',
                  hintText: 'Maharashtra',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _orgGstCtrl,
                decoration: const InputDecoration(
                  labelText: 'GST Number (optional)',
                  hintText: 'GSTIN',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _orgPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: '+91 9876543210',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _orgEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'info@example.com',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _buildActionButton(
          'Save & Continue',
          _saveOrganizationDetails,
          isMandatory: true,
        ),
      ],
    );
  }

  // ============================================
  // STEP 2: Create First Branch (mandatory)
  // ============================================
  Widget _buildBranchStep(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'MANDATORY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Create Your First Branch',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Set up your main branch office. You can add more branches later.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _branchNameCtrl,
          decoration: const InputDecoration(
            labelText: 'Branch Name *',
            hintText: 'e.g., Main Branch',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _branchCodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Branch Code *',
                  hintText: 'BR001',
                  helperText: 'Unique identifier',
                ),
              ),
            ),
            const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _branchZoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    hintText: 'Mumbai',
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _branchDistrictCtrl,
          decoration: const InputDecoration(
            labelText: 'District',
            hintText: 'Mumbai',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _branchAddressCtrl,
          decoration: const InputDecoration(
            labelText: 'Branch Address',
            hintText: 'Full address',
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 32),
        _buildActionButton(
          'Create Branch & Continue',
          _createBranch,
          isMandatory: true,
        ),
      ],
    );
  }

  // ============================================
  // STEP 3: Create First Branch Manager (mandatory)
  // ============================================
  Widget _buildManagerStep(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'MANDATORY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Add First Branch Manager',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Create the first branch manager who will manage branch operations.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _managerNameCtrl,
          decoration: const InputDecoration(
            labelText: 'Full Name *',
            hintText: 'e.g., Rajesh Kumar',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _managerPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone *',
                  hintText: '+91 9876543210',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _managerEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  hintText: 'rajesh@example.com',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _managerEmployeeIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Employee ID',
                  hintText: 'Internal reference #',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _managerZoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Assigned Zone / Area',
                  hintText: 'e.g. North Sector',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _managerAddressCtrl,
          decoration: const InputDecoration(
            labelText: 'Residential Address',
            hintText: 'Enter complete address',
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        // Branch Selection
        DropdownButtonFormField<String>(
          initialValue: _selectedManagerBranchId,
          decoration: const InputDecoration(
            labelText: 'Assign to Branch *',
          ),
          items: _branches.map((b) {
            return DropdownMenuItem(
              value: b['id'] as String,
              child: Text(b['name'] as String),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedManagerBranchId = v),
        ),
        const SizedBox(height: 32),
        _buildActionButton(
          'Create Manager & Continue',
          _createBranchManager,
          isMandatory: true,
        ),
      ],
    );
  }

  // ============================================
  // STEP 4: Create First Collection Agent (skippable)
  // ============================================
  Widget _buildAgentStep(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'OPTIONAL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Add First Collection Agent',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Create a collection agent for field operations. You can skip this and add later.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _agentNameCtrl,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            hintText: 'e.g., Suresh Patel',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _agentPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: '+91 9876543211',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _agentEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  hintText: 'suresh@example.com',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _agentEmployeeIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Employee ID',
                  hintText: 'Internal reference #',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _agentZoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Assigned Zone / Area',
                  hintText: 'e.g. North Sector',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _agentAddressCtrl,
          decoration: const InputDecoration(
            labelText: 'Residential Address',
            hintText: 'Enter complete address',
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        // Branch Selection
        DropdownButtonFormField<String>(
          initialValue: _selectedAgentBranchId,
          decoration: const InputDecoration(
            labelText: 'Assign to Branch',
          ),
          items: _branches.map((b) {
            return DropdownMenuItem(
              value: b['id'] as String,
              child: Text(b['name'] as String),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedAgentBranchId = v),
        ),
        const SizedBox(height: 32),
        _buildActionButton(
          'Create Agent & Continue',
          _createCollectionAgent,
          isMandatory: false,
          skipLabel: 'Skip this step',
          onSkip: _skipStep,
        ),
      ],
    );
  }

  // ============================================
  // STEP 5: Create First Customer (skippable)
  // ============================================
  Widget _buildCustomerStep(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'OPTIONAL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Add First Customer',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Onboard your first customer to see how the system works. You can skip and add later.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _customerNameCtrl,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            hintText: 'e.g., Priya Sharma',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _customerPhoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone',
            hintText: '+91 9876543212',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customerAadharCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Aadhar Number',
                  hintText: 'XXXX XXXX XXXX',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _customerPanCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'PAN Number',
                  hintText: 'ABCDE1234F',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Branch Selection
        DropdownButtonFormField<String>(
          initialValue: _selectedCustomerBranchId,
          decoration: const InputDecoration(
            labelText: 'Assign to Branch',
          ),
          items: _branches.map((b) {
            return DropdownMenuItem(
              value: b['id'] as String,
              child: Text(b['name'] as String),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedCustomerBranchId = v),
        ),
        const SizedBox(height: 32),
        _buildActionButton(
          'Create Customer & Finish',
          _createCustomer,
          isMandatory: false,
          skipLabel: 'Skip & Finish',
          onSkip: _skipStep,
        ),
      ],
    );
  }

  // ============================================
  // DONE STEP
  // ============================================
  Widget _buildDoneStep(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.shade50,
          ),
          child: const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 60,
          ),
        ).animate().scale(
          begin: const Offset(0.5, 0.5),
          duration: 400.ms,
          curve: Curves.elasticOut,
        ),
        const SizedBox(height: 24),
        Text(
          'Setup Complete!',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 12),
        Text(
          'Your organization is ready to use.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 300.ms),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              if (_logoChanged) _doneItem(Icons.image, 'Brand logo updated'),
              if (_createdBranchId != null) _doneItem(Icons.business, 'Branch created'),
              if (_createdBranchManagerId != null) _doneItem(Icons.person, 'Branch manager added'),
              if (_createdCollectionAgentId != null) _doneItem(Icons.badge, 'Collection agent added'),
              if (_createdCustomerId != null) _doneItem(Icons.people, 'Customer onboarded'),
            ],
          ),
        ).animate().fadeIn(delay: 400.ms),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _finish,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Go to Dashboard',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ).animate().fadeIn(delay: 500.ms),
      ],
    );
  }

  Widget _doneItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    VoidCallback onPressed, {
    bool isMandatory = true,
    String? skipLabel,
    VoidCallback? onSkip,
  }) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : () {
              HapticService.medium();
              onPressed();
            },
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(label),
          ),
        ),
        if (!isMandatory && onSkip != null) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isLoading ? null : onSkip,
            child: Text(skipLabel ?? 'Skip this step'),
          ),
        ],
      ],
    );
  }
}
