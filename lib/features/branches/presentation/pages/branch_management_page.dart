import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/layout.dart';
import '../../../../core/providers/org_provider.dart';
import '../../data/providers/branch_providers.dart';
import '../../models/branch_model.dart';

class BranchManagementPage extends ConsumerStatefulWidget {
  const BranchManagementPage({super.key});

  @override
  ConsumerState<BranchManagementPage> createState() =>
      _BranchManagementPageState();
}

class _BranchManagementPageState extends ConsumerState<BranchManagementPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final branchesAsync = ref.watch(branchesProvider);
    final orgAsync = ref.watch(currentOrgProvider);

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
          child: Column(
            children: [
              _buildAppBar(context, isDark, orgAsync),
              Expanded(
                child: branchesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text('Error loading branches',
                            style: TextStyle(color: AppColors.error)),
                        const SizedBox(height: 8),
                        Text('$e',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  data: (branches) => branches.isEmpty
                      ? _buildEmptyState(isDark)
                      : _buildBranchesList(branches, isDark),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: orgAsync.when(
        data: (org) {
          final maxBranches = org?['max_branches'] ?? 10;
          final currentCount = branchesAsync.valueOrNull?.length ?? 0;
          final canAdd = currentCount < maxBranches;

          return Padding(
            padding: kFabSafeAreaPadding,
            child: FloatingActionButton.extended(
              onPressed: canAdd
                  ? () => _showBranchDialog(context)
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Branch limit reached ($maxBranches). Contact support to increase your limit.'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    },
              backgroundColor: canAdd ? AppColors.primary : Colors.grey,
              icon: const Icon(Icons.add_business_rounded, color: Colors.white),
              label: Text(
                'Add Branch',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ).animate().scale(delay: 300.ms),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark,
      AsyncValue<Map<String, dynamic>?> orgAsync) {
    final branchesAsync = ref.watch(branchesProvider);
    final branchCount = branchesAsync.valueOrNull?.length ?? 0;
    final maxBranches = orgAsync.valueOrNull?['max_branches'] ?? 5;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Branch Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '$branchCount / $maxBranches branches',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.business_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  '$branchCount',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.2),
                  AppColors.accent.withValues(alpha: 0.2)
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.business_rounded,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          Text(
            'No Branches Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first branch to start organizing\nyour staff and members by location.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showBranchDialog(context),
            icon: const Icon(Icons.add_business_rounded, color: Colors.white),
            label: const Text('Create Branch',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildBranchesList(List<BranchModel> branches, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: branches.length,
      itemBuilder: (context, index) {
        final branch = branches[index];
        return _buildBranchCard(branch, isDark, index);
      },
    );
  }

  Widget _buildBranchCard(BranchModel branch, bool isDark, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1F2E).withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: branch.isActive
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showBranchDetails(branch),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: branch.isActive
                              ? [AppColors.primary, AppColors.accent]
                              : [Colors.grey.shade400, Colors.grey.shade500],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          branch.code.substring(0,
                              branch.code.length > 3 ? 3 : branch.code.length),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            branch.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  branch.city ?? 'No location',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: branch.isActive
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        branch.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: branch.isActive
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
                if (branch.managerName != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_outline_rounded,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Manager: ${branch.managerName}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildQuickAction(
                      icon: Icons.edit_outlined,
                      label: 'Edit',
                      onTap: () => _showBranchDialog(context, branch: branch),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildQuickAction(
                      icon: Icons.people_outline_rounded,
                      label: 'Staff',
                      onTap: () =>
                          context.push('/admin/branches/${branch.id}/staff'),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildQuickAction(
                      icon: Icons.person_add_outlined,
                      label: 'Add User',
                      onTap: () => _showAddUserDialog(branch),
                      isDark: isDark,
                    ),
                    const Spacer(),
                    _buildQuickAction(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                      onTap: () => _confirmDelete(branch),
                      isDark: isDark,
                      isDestructive: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: (index * 50).ms)
        .slideX(begin: 0.1, end: 0);
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppColors.error : AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }

  void _showBranchDialog(BuildContext context, {BranchModel? branch}) {
    showDialog(
      context: context,
      builder: (ctx) => BranchFormDialog(
        branch: branch,
        onSave: (data) async {
          final notifier = ref.read(branchNotifierProvider.notifier);
          if (branch != null) {
            final result = await notifier.updateBranch(branch.id, data);
            if (result == null) {
              final errorState = ref.read(branchNotifierProvider);
              final errorMsg = errorState.error?.toString() ?? 'Update failed';
              throw Exception(errorMsg);
            }
          } else {
            final result = await notifier.createBranch(
              name: data['name'],
              code: data['code'],
              address: data['address'],
              city: data['city'],
              addressState: data['state'],
              pincode: data['pincode'],
              phone: data['phone'],
              email: data['email'],
              managerId: data['manager_id'],
            );
            if (result == null) {
              final errorState = ref.read(branchNotifierProvider);
              final errorMsg = errorState.error?.toString() ?? 'Creation failed';
              throw Exception(errorMsg);
            }
          }
        },
      ),
    );
  }

  void _showBranchDetails(BranchModel branch) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BranchDetailSheet(branch: branch),
    );
  }

  void _showAddUserDialog(BranchModel branch) {
    context.push('/admin/users/new?branch_id=${branch.id}');
  }

  Future<void> _confirmDelete(BranchModel branch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Branch?'),
        content: Text(
            'Are you sure you want to delete "${branch.name}"? This will unassign all staff and members from this branch.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final notifier = ref.read(branchNotifierProvider.notifier);
      await notifier.deleteBranch(branch.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${branch.name} deleted successfully'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }
}

// Branch Form Dialog
class BranchFormDialog extends StatefulWidget {
  final BranchModel? branch;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const BranchFormDialog({super.key, this.branch, required this.onSave});

  @override
  State<BranchFormDialog> createState() => _BranchFormDialogState();
}

class _BranchFormDialogState extends State<BranchFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String? _selectedManagerId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.branch != null) {
      _nameCtrl.text = widget.branch!.name;
      _codeCtrl.text = widget.branch!.code;
      _addressCtrl.text = widget.branch!.address ?? '';
      _cityCtrl.text = widget.branch!.city ?? '';
      _stateCtrl.text = widget.branch!.state ?? '';
      _pincodeCtrl.text = widget.branch!.pincode ?? '';
      _phoneCtrl.text = widget.branch!.phone ?? '';
      _emailCtrl.text = widget.branch!.email ?? '';
      _selectedManagerId = widget.branch!.managerId;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEdit = widget.branch != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 450,
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1A1F2E), const Color(0xFF0F1115)]
                : [Colors.white, const Color(0xFFF8F9FB)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.accent]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isEdit
                            ? Icons.edit_rounded
                            : Icons.add_business_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        isEdit ? 'Edit Branch' : 'Create New Branch',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: isDark ? Colors.white54 : Colors.black54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildTextField(
                    _nameCtrl, 'Branch Name', Icons.business_rounded, isDark,
                    required: true),
                const SizedBox(height: 16),
                _buildTextField(
                    _codeCtrl, 'Branch Code', Icons.tag_rounded, isDark,
                    required: true, hint: 'e.g., BR001'),
                const SizedBox(height: 16),
                _buildTextField(_addressCtrl, 'Address',
                    Icons.location_on_outlined, isDark,
                    autofillHints: const [AutofillHints.streetAddressLine1]),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _buildTextField(_cityCtrl, 'City',
                            Icons.location_city_rounded, isDark,
                            autofillHints: const [AutofillHints.addressCity])),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildTextField(
                            _stateCtrl, 'State', Icons.map_outlined, isDark,
                            autofillHints: const [AutofillHints.addressState])),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _buildTextField(_pincodeCtrl, 'Pincode',
                            Icons.pin_drop_rounded, isDark,
                            autofillHints: const [AutofillHints.postalCode])),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildTextField(
                            _phoneCtrl, 'Phone', Icons.phone_rounded, isDark,
                            autofillHints: const [AutofillHints.telephoneNumber])),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(
                    _emailCtrl, 'Email', Icons.email_outlined, isDark,
                    autofillHints: const [AutofillHints.email]),
                const SizedBox(height: 24),
                _buildManagerDropdown(isDark),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(isEdit ? 'Update Branch' : 'Create Branch',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController ctrl, String label, IconData icon, bool isDark,
      {bool required = false, String? hint, List<String>? autofillHints}) {
    return TextFormField(
      controller: ctrl,
      autofillHints: autofillHints,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: isDark ? const Color(0xFF1F2532) : const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
      validator: required
          ? (v) => v?.trim().isEmpty == true ? 'Required' : null
          : null,
    );
  }

  Widget _buildManagerDropdown(bool isDark) {
    return Consumer(
      builder: (context, ref, _) {
        final managersAsync = ref.watch(potentialManagersProvider);
        return managersAsync.when(
          loading: () => const SizedBox(
              height: 56, child: Center(child: CircularProgressIndicator())),
          error: (_, __) => const SizedBox.shrink(),
          data: (managers) {
            return DropdownButtonFormField<String>(
              initialValue: _selectedManagerId,
              decoration: InputDecoration(
                labelText: 'Branch Manager',
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF1F2532) : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('No manager assigned')),
                ...managers.map((m) => DropdownMenuItem(
                      value: m['id'] as String,
                      child: Text(m['full_name'] ?? 'Unknown'),
                    )),
              ],
              onChanged: (v) => setState(() => _selectedManagerId = v),
            );
          },
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await widget.onSave({
        'name': _nameCtrl.text.trim(),
        'code': _codeCtrl.text.trim().toUpperCase(),
        'address':
            _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
        'pincode':
            _pincodeCtrl.text.trim().isEmpty ? null : _pincodeCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'manager_id': _selectedManagerId,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// Branch Detail Sheet
class BranchDetailSheet extends ConsumerWidget {
  final BranchModel branch;

  const BranchDetailSheet({super.key, required this.branch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statsAsync = ref.watch(branchStatsProvider(branch.id));

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A1F2E), const Color(0xFF0F1115)]
              : [Colors.white, const Color(0xFFF8F9FB)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.accent]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      branch.code.substring(
                          0, branch.code.length > 3 ? 3 : branch.code.length),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        branch.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        branch.city ?? 'No location set',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: statsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (stats) => ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildStatRow(Icons.people_outline_rounded, 'Total Staff',
                      '${stats.totalStaff}', isDark),
                  _buildStatRow(Icons.person_outline_rounded, 'Total Members',
                      '${stats.totalMembers}', isDark),
                  _buildStatRow(
                      Icons.account_balance_wallet_outlined,
                      'Total Savings',
                      '₹${stats.totalSavings.toStringAsFixed(0)}',
                      isDark),
                  _buildStatRow(Icons.trending_up_rounded, 'Active Loans',
                      '₹${stats.activeLoans.toStringAsFixed(0)}', isDark),
                  if (branch.managerName != null) ...[
                    const SizedBox(height: 16),
                    _buildStatRow(Icons.person_outline_rounded, 'Manager',
                        branch.managerName!, isDark),
                  ],
                  if (branch.address != null) ...[
                    const SizedBox(height: 16),
                    _buildStatRow(Icons.location_on_outlined, 'Address',
                        branch.address!, isDark),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    color:
                        isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
