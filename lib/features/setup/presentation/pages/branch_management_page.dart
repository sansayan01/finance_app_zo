import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../../providers/supabase_provider.dart';

final branchListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  final orgId = ref.read(currentOrgIdOrThrowProvider);
  final branches = await client.from('branches').select('id, name, code, zone, district, status, created_at, manager_id, staff_profiles!branches_manager_id(full_name)').eq('org_id', orgId).order('created_at', ascending: false);
  final staff = await client.from('staff_profiles').select('id, full_name, role').eq('org_id', orgId).inFilter('role', ['branch_manager', 'manager']).eq('status', 'active');
  return {
    'branches': List<Map<String, dynamic>>.from(branches),
    'staff': List<Map<String, dynamic>>.from(staff),
  } as List<Map<String, dynamic>>;
});

class BranchManagementPage extends ConsumerStatefulWidget {
  const BranchManagementPage({super.key});

  @override
  ConsumerState<BranchManagementPage> createState() => _BranchManagementPageState();
}

class _BranchManagementPageState extends ConsumerState<BranchManagementPage> {
  bool _showForm = false;
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _zoneCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String? _selectedManagerId;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _zoneCtrl.dispose();
    _districtCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _createBranch() async {
    if (_nameCtrl.text.trim().isEmpty || _codeCtrl.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final orgId = ref.read(currentOrgIdOrThrowProvider);
      await client.from('branches').insert({
        'org_id': orgId,
        'name': _nameCtrl.text.trim(),
        'code': _codeCtrl.text.trim().toUpperCase(),
        'zone': _zoneCtrl.text.trim(),
        'district': _districtCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'manager_id': _selectedManagerId,
        'status': 'active',
      });
      ref.invalidate(branchListProvider);
      _nameCtrl.clear();
      _codeCtrl.clear();
      _zoneCtrl.clear();
      _districtCtrl.clear();
      _addressCtrl.clear();
      _selectedManagerId = null;
      setState(() => _showForm = false);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(branchListProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: isDark ? [const Color(0xFF0F1115), const Color(0xFF1A1F2E)] : [const Color(0xFFF8F9FB), const Color(0xFFEEF2FF)],
          ),
        ),
        child: SafeArea(
          child: branchesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (data) {
              final branches = data;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                children: [
                  _buildTopBar(context, isDark),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Branches (${branches.length})', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      if (!_showForm)
                        ElevatedButton.icon(
                          onPressed: () => setState(() => _showForm = true),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Branch'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                    ],
                  ),
                  if (_showForm) _buildCreateForm(isDark),
                  const SizedBox(height: 16),
                  if (branches.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.business_rounded, size: 64, color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('No branches yet', style: TextStyle(fontSize: 16, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
                            const SizedBox(height: 8),
                            TextButton(onPressed: () => setState(() => _showForm = true), child: const Text('Create your first branch')),
                          ],
                        ),
                      ),
                    ),
                  ...branches.asMap().entries.map((e) => _buildBranchCard(e.value, isDark)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isDark) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.2)),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
        const SizedBox(width: 12),
        Text('Branch Management', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
      ],
    );
  }

  Widget _buildCreateForm(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2E).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.add_business_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('New Branch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 16),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Branch Name', hintText: 'e.g. Main Branch'), style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: _codeCtrl, decoration: const InputDecoration(labelText: 'Branch Code', hintText: 'e.g. MAIN01'), style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _zoneCtrl, decoration: const InputDecoration(labelText: 'Zone/Area', hintText: 'e.g. North'), style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)))),
            ],
          ),
          const SizedBox(height: 12),
          TextField(controller: _districtCtrl, decoration: const InputDecoration(labelText: 'District', hintText: 'e.g. Chennai'), style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A))),
          const SizedBox(height: 12),
          TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Address (optional)'), style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)), maxLines: 2),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _showForm = false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _createBranch,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  child: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create Branch'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBranchCard(Map<String, dynamic> branch, bool isDark) {
    final status = branch['status'] as String? ?? 'active';
    final isActive = status == 'active';
    final mgr = branch['staff_profiles'] as Map?;
    final mgrName = mgr?['full_name'] as String?;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2E).withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.2), AppColors.accent.withValues(alpha: 0.1)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.business_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(branch['name'] as String? ?? '', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text('${branch['code']}  •  ${branch['zone']}  •  ${mgrName ?? 'No manager'}', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? AppColors.success.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(isActive ? 'Active' : 'Inactive', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isActive ? AppColors.success : Colors.grey)),
          ),
        ],
      ),
    );
  }
}
