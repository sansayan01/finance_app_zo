import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/haptic_service.dart';
import '../../data/providers/super_admin_providers.dart';

class OrganizationsManagementPage extends ConsumerStatefulWidget {
  const OrganizationsManagementPage({super.key});

  @override
  ConsumerState<OrganizationsManagementPage> createState() =>
      _OrganizationsManagementPageState();
}

class _OrganizationsManagementPageState
    extends ConsumerState<OrganizationsManagementPage> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _search = '';
  String _statusFilter = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _search = value);
    });
  }

  void _onStatusFilter(String status) {
    HapticService.selection();
    setState(() => _statusFilter = status);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final orgs = ref.watch(allOrganizationsProvider({
      'limit': 50,
      'offset': 0,
      'search': _search.isEmpty ? null : _search,
      'status': _statusFilter.isEmpty ? null : _statusFilter,
    }));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(allOrganizationsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                // ── Header ──────────────────────────────
                _buildHeader(context, isDark),
                const SizedBox(height: 20),

                // ── Search & Filter ─────────────────────
                _buildSearchAndFilter(context, isDark),
                const SizedBox(height: 20),

                // ── Org List ────────────────────────────
                orgs.when(
                  data: (list) {
                    if (list.isEmpty) {
                      return _buildEmptyState(context, isDark);
                    }
                    return Column(
                      children: list.asMap().entries.map((entry) {
                        final i = entry.key;
                        final org = entry.value;
                        return _buildOrgCard(context, org, i, isDark);
                      }).toList(),
                    );
                  },
                  loading: () => _buildLoadingState(isDark),
                  error: (e, _) => _buildErrorState(context, '$e', isDark),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, isDark),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Organizations',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage all organizations',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  // ── Search & Filter ─────────────────────────────────────
  Widget _buildSearchAndFilter(BuildContext context, bool isDark) {
    final filters = [
      ('', 'All'),
      ('active', 'Active'),
      ('suspended', 'Suspended'),
      ('inactive', 'Inactive'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search field
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1A1F2E).withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.3),
            ),
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearch,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'Search organizations...',
              hintStyle: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
              prefixIcon: Icon(Icons.search_rounded,
                  size: 20,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Filter chips
        Row(
          children: filters.map((f) {
            final isActive = _statusFilter == f.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _onStatusFilter(f.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                        : isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    f.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? AppColors.primary
                          : isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  // ── Org Card ────────────────────────────────────────────
  Widget _buildOrgCard(
      BuildContext context, Map<String, dynamic> org, int index, bool isDark) {
    final name = org['name'] as String? ?? 'Unknown';
    final slug = org['slug'] as String? ?? '';
    final status = org['status'] as String? ?? 'active';
    final plan = org['plan'] as String? ?? 'free';
    return GestureDetector(
      onTap: () => context.push('/super-admin/organizations/${org['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1A1F2E).withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Org icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.2),
                    AppColors.accent.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.business_rounded,
                  color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 14),

            // Org info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color:
                          isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    slug,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Status + Plan
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _statusBadge(status, isDark),
                const SizedBox(height: 6),
                _planBadge(plan, isDark),
              ],
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: (200 + 60 * index).ms)
        .slideY(begin: 0.05, end: 0);
  }

  Widget _statusBadge(String status, bool isDark) {
    final (color, label) = switch (status) {
      'active' => (AppColors.success, 'Active'),
      'suspended' => (AppColors.warning, 'Suspended'),
      'inactive' => (Colors.grey, 'Inactive'),
      _ => (AppColors.success, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _planBadge(String plan, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: isDark ? 0.1 : 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        plan.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
        ),
      ),
    );
  }

  // ── Create Dialog ───────────────────────────────────────
  void _showCreateDialog(BuildContext context, bool isDark) {
    final nameCtrl = TextEditingController();
    final slugCtrl = TextEditingController();
    String selectedPlan = 'free';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Create Organization',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 20),

              // Name field
              _dialogField('Organization Name', nameCtrl, isDark,
                  onChanged: (v) {
                slugCtrl.text = v
                    .toLowerCase()
                    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
                    .replaceAll(RegExp(r'^-|-$'), '');
              }),
              const SizedBox(height: 12),

              // Slug field
              _dialogField('Slug', slugCtrl, isDark),
              const SizedBox(height: 12),

              // Plan selector
              Text(
                'Plan',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: ['free', 'basic', 'pro', 'enterprise'].map((plan) {
                  final isSelected = selectedPlan == plan;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setSheetState(() => selectedPlan = plan),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                    .withValues(alpha: isDark ? 0.2 : 0.1)
                                : isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.3)
                                  : isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.grey.shade200,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              plan[0].toUpperCase() + plan.substring(1),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppColors.primary
                                    : isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Create button
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    HapticService.selection();
                    final orgName = nameCtrl.text.trim();
                    Navigator.pop(ctx);
                    final messenger = ScaffoldMessenger.of(context);
                    await ref
                        .read(superAdminActionsProvider.notifier)
                        .createOrganization(
                          name: orgName,
                          slug: slugCtrl.text.trim(),
                          plan: selectedPlan,
                        );
                    ref.invalidate(allOrganizationsProvider);
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                              'Organization "$orgName" created'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'Create Organization',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
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

  Widget _dialogField(String label, TextEditingController ctrl, bool isDark,
      {ValueChanged<String>? onChanged}) {
    return TextField(
      controller: ctrl,
      onChanged: onChanged,
      style: TextStyle(
        fontSize: 14,
        color: isDark ? Colors.white : const Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.shade50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  // ── States ──────────────────────────────────────────────
  Widget _buildLoadingState(bool isDark) {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 100,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1A1F2E).withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1F2E).withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.3),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.business_center_rounded,
                size: 48,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No organizations found',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _search.isNotEmpty
                  ? 'Try a different search term'
                  : 'Create your first organization',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1F2E).withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Center(
        child: Text(
          'Failed to load organizations: $error',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}
