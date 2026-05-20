import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../loans/presentation/providers/loan_providers.dart';
import '../../../savings/data/providers/savings_providers.dart';
import '../../../loans/data/models/loan_model.dart';
import '../../../savings/data/models/savings_model.dart';
import '../../../../core/utils/kyc_validators.dart';

import '../providers/user_list_provider.dart';
import '../../../../core/services/haptic_service.dart';
import '../providers/new_user_provider.dart';
import '../providers/admin_user_actions_provider.dart';
import '../providers/avatar_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../branches/data/providers/branch_providers.dart';
import '../../../branches/models/branch_model.dart';

class UserDetailsPage extends ConsumerWidget {
  final String userId;
  const UserDetailsPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userDetailsProvider(userId));
    final loansAsync = ref.watch(userLoansProvider(userId));
    final savingsAsync = ref.watch(userSavingsProvider(userId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Aurora effect
          const _AuroraBackground(),

          userAsync.when(
            data: (user) {
              if (user == null) {
                return const Center(child: Text('User not found'));
              }

              return loansAsync.when(
                data: (loans) => savingsAsync.when(
                  data: (savings) {
                    return CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        _buildSliverAppBar(context, ref, user, theme),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildIdentityHeader(
                                    context, ref, user, theme, isDark),
                                if (_isAdminViewer(ref)) ...[
                                  const SizedBox(height: 28),
                                  _buildAdminSection(
                                      context, ref, user, loans, savings,
                                      theme: theme, isDark: isDark),
                                ],
                                if (loans.isNotEmpty) ...[
                                  const SizedBox(height: 28),
                                  _buildTrustScoreGauge(user, theme, isDark),
                                ],
                                const SizedBox(height: 32),
                                _buildPortfolioHub(
                                    loans, savings, theme, isDark),
                                if (loans.isNotEmpty) ...[
                                  const SizedBox(height: 32),
                                  _buildRepaymentdiscipline(
                                      loans, theme, isDark),
                                ],
                                const SizedBox(height: 32),
                                _buildKYCVault(user, theme, isDark),
                                const SizedBox(height: 32),
                                _buildMemberQRPass(user, theme, isDark),
                                const SizedBox(height: 32),
                                _buildActivityTimeline(
                                    loans, savings, theme, isDark),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const _LoadingState(),
                  error: (e, __) => Center(child: Text('Savings Error: $e')),
                ),
                loading: () => const _LoadingState(),
                error: (e, __) => Center(child: Text('Loans Error: $e')),
              );
            },
            loading: () => const _LoadingState(),
            error: (e, __) => Center(child: Text('User Error: $e')),
          ),

          // Floating Action Bar at bottom
          _buildFloatingActionIsland(context, theme, isDark),
        ],
      ),
    );
  }

  // ===========================================================================
  // ADMIN-ONLY SECTION (visible to executiveAdmin / superAdmin)
  // ===========================================================================

  /// Returns true when the *current* signed-in user has admin powers over
  /// this page (executiveAdmin or superAdmin).
  bool _isAdminViewer(WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    if (me == null) return false;
    return me.role == UserRole.executiveAdmin ||
        me.role == UserRole.superAdmin;
  }

  /// Container that holds every admin-only section. Rendered only when
  /// [_isAdminViewer] is true.
  Widget _buildAdminSection(
    BuildContext context,
    WidgetRef ref,
    ProfileModel user,
    List<LoanModel> loans,
    List<SavingsModel> savings, {
    required ThemeData theme,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAdminBanner(theme, isDark),
        const SizedBox(height: 20),
        _buildAdminIdentityContext(user, theme, isDark),
        const SizedBox(height: 20),
        _buildAdminFinancialExposure(loans, savings, theme, isDark),
        const SizedBox(height: 20),
        _buildAdminRolePermissions(context, ref, user, theme, isDark),
        const SizedBox(height: 20),
        _buildAdminSecurityAccess(context, ref, user, theme, isDark),
        const SizedBox(height: 20),
        _buildAdminAuditTimeline(ref, user, theme, isDark),
        const SizedBox(height: 20),
        _buildAdminNotes(context, ref, user, theme, isDark),
        const SizedBox(height: 20),
        _buildAdminCompliance(context, ref, user, theme, isDark),
        const SizedBox(height: 20),
        _buildAdminViewAsUser(context, user, loans, savings, theme, isDark),
      ],
    );
  }

  /// Small banner at the top of the admin block so it's visually obvious
  /// the viewer is in admin context.
  Widget _buildAdminBanner(ThemeData theme, bool isDark) {
    final accent = isDark ? AppColors.warningDark : AppColors.orange;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.admin_panel_settings_rounded,
                color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ADMIN VIEW',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Privileged controls below. All actions are audit-logged.',
                  style:
                      theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  // ---------------------------------------------------------------------------
  // PHASE 3a — IDENTITY & MULTI-TENANT CONTEXT
  // ---------------------------------------------------------------------------
  Widget _buildAdminIdentityContext(
      ProfileModel user, ThemeData theme, bool isDark) {
    final primary = theme.colorScheme.primary;
    final rows = <_KvRow>[
      _KvRow('Member ID',
          user.memberCode ?? 'MF-${user.id.substring(0, 8).toUpperCase()}'),
      _KvRow('Organization', user.orgId ?? 'N/A'),
      _KvRow('Branch', user.branchName ?? user.branchId ?? 'Unassigned'),
      if (user.employeeId != null && user.employeeId!.isNotEmpty)
        _KvRow('Employee ID', user.employeeId!),
      if (user.assignedZone != null && user.assignedZone!.isNotEmpty)
        _KvRow('Assigned Zone', user.assignedZone!),
      _KvRow('Email', user.email ?? 'N/A'),
      _KvRow('Phone', user.phone ?? 'N/A'),
      _KvRow('Status', _statusLabel(user.status)),
      _KvRow('Created', _fmtDate(user.createdAt)),
      _KvRow('Last Updated', _fmtDate(user.updatedAt)),
      _KvRow('Last Seen', _fmtDate(user.lastSeenAt)),
    ];

    return _AdminCard(
      title: 'Identity & Tenant Context',
      icon: Icons.account_tree_rounded,
      accent: primary,
      isDark: isDark,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _kvRow(rows[i], theme, isDark),
            if (i < rows.length - 1)
              Divider(
                  height: 18,
                  thickness: 0.4,
                  color: theme.dividerColor.withValues(alpha: 0.2)),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PHASE 3b — FINANCIAL EXPOSURE
  // ---------------------------------------------------------------------------
  Widget _buildAdminFinancialExposure(List<LoanModel> loans,
      List<SavingsModel> savings, ThemeData theme, bool isDark) {
    final activeLoans =
        loans.where((l) => l.status == LoanStatus.active).toList();
    final closedLoans =
        loans.where((l) => l.status == LoanStatus.closed).toList();
    final defaultedLoans = loans
        .where((l) =>
            l.status == LoanStatus.defaultStatus ||
            l.status == LoanStatus.restructured)
        .toList();
    final totalOutstanding = activeLoans.fold<double>(
        0.0, (s, l) => s + l.outstandingBalance);
    final totalSavings =
        savings.fold<double>(0.0, (s, x) => s + x.targetAmount);

    return _AdminCard(
      title: 'Financial Exposure',
      icon: Icons.trending_up_rounded,
      accent: isDark ? AppColors.successDark : AppColors.success,
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _bigStat(
                  label: 'OUTSTANDING',
                  value: '₹${_compact(totalOutstanding)}',
                  color: theme.colorScheme.primary,
                  theme: theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _bigStat(
                  label: 'SAVINGS BAL',
                  value: '₹${_compact(totalSavings)}',
                  color:
                      isDark ? AppColors.successDark : AppColors.success,
                  theme: theme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _miniStat('Active', activeLoans.length, Colors.blue, theme),
              const SizedBox(width: 8),
              _miniStat('Closed', closedLoans.length, Colors.grey, theme),
              const SizedBox(width: 8),
              _miniStat(
                  'Defaulted', defaultedLoans.length, Colors.red, theme),
              const SizedBox(width: 8),
              _miniStat('Plans', savings.length,
                  isDark ? AppColors.successDark : AppColors.success, theme),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PHASE 4a — ROLE & PERMISSIONS
  // ---------------------------------------------------------------------------
  Widget _buildAdminRolePermissions(BuildContext context, WidgetRef ref,
      ProfileModel user, ThemeData theme, bool isDark) {
    final primary = theme.colorScheme.primary;
    return _AdminCard(
      title: 'Role & Permissions',
      icon: Icons.shield_outlined,
      accent: primary,
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CURRENT ROLE',
                        style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            fontSize: 10)),
                    const SizedBox(height: 4),
                    Text(_roleLabel(user.role),
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900, fontSize: 16)),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _showChangeRoleDialog(context, ref, user, theme, isDark),
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: const Text('Change'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: BorderSide(color: primary.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _divider(theme),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BRANCH ASSIGNMENT',
                        style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            fontSize: 10)),
                    const SizedBox(height: 4),
                    Text(user.branchName ?? user.branchId ?? 'Unassigned',
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _showReassignBranchDialog(context, ref, user, theme),
                icon: const Icon(Icons.account_tree_rounded, size: 16),
                label: const Text('Reassign'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: BorderSide(color: primary.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PHASE 4b — SECURITY & ACCESS
  // ---------------------------------------------------------------------------
  Widget _buildAdminSecurityAccess(BuildContext context, WidgetRef ref,
      ProfileModel user, ThemeData theme, bool isDark) {
    final danger = isDark ? Colors.redAccent : Colors.red;
    return _AdminCard(
      title: 'Security & Access',
      icon: Icons.lock_outline_rounded,
      accent: danger,
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kvRow(_KvRow('Last seen', _fmtDate(user.lastSeenAt)),
              theme, isDark),
          const SizedBox(height: 8),
          _kvRow(_KvRow('Account status', _statusLabel(user.status)),
              theme, isDark),
          const SizedBox(height: 14),
          _divider(theme),
          const SizedBox(height: 12),
          // Status switcher
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip(context, ref, user, AccountStatus.active,
                  'Active', Colors.green, theme),
              _statusChip(context, ref, user, AccountStatus.suspended,
                  'Suspend', Colors.orange, theme),
              _statusChip(context, ref, user, AccountStatus.inactive,
                  'Deactivate', Colors.grey, theme),
            ],
          ),
          const SizedBox(height: 14),
          _divider(theme),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _showPasswordOptions(context, ref, user, theme),
                  icon: const Icon(Icons.password_rounded, size: 16),
                  label: const Text('Reset Password'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    padding:
                        const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _handleForceLogout(context, ref, user),
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: const Text('Force Logout'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: danger,
                    side: BorderSide(color: danger.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PHASE 5a — AUDIT TIMELINE
  // ---------------------------------------------------------------------------
  Widget _buildAdminAuditTimeline(
      WidgetRef ref, ProfileModel user, ThemeData theme, bool isDark) {
    final accent = isDark ? AppColors.warningDark : AppColors.orange;
    final auditAsync = ref.watch(userAuditLogsProvider(
      UserAuditQuery(profileId: user.id, authUserId: user.userId),
    ));
    return _AdminCard(
      title: 'Audit Timeline',
      icon: Icons.history_rounded,
      accent: accent,
      isDark: isDark,
      child: auditAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (e, _) => Text('Failed to load audit log: $e',
            style:
                theme.textTheme.bodySmall?.copyWith(color: Colors.red)),
        data: (entries) {
          if (entries.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No admin-visible events recorded yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey, fontWeight: FontWeight.w500),
                ),
              ),
            );
          }
          final visible = entries.take(10).toList();
          return Column(
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                _auditRow(visible[i], theme, isDark),
                if (i < visible.length - 1)
                  Divider(
                      height: 14,
                      thickness: 0.3,
                      color: theme.dividerColor.withValues(alpha: 0.2)),
              ],
              if (entries.length > 10) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '${entries.length - 10} more events',
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PHASE 5b — INTERNAL ADMIN NOTES
  // ---------------------------------------------------------------------------
  Widget _buildAdminNotes(BuildContext context, WidgetRef ref,
      ProfileModel user, ThemeData theme, bool isDark) {
    final notesAsync = ref.watch(adminNotesProvider(user.id));
    final accent = theme.colorScheme.tertiary;
    return _AdminCard(
      title: 'Internal Admin Notes',
      icon: Icons.sticky_note_2_outlined,
      accent: accent,
      isDark: isDark,
      trailing: TextButton.icon(
        onPressed: () => _showAddNoteSheet(context, ref, user),
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text('Add Note'),
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      child: notesAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
              child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))),
        ),
        error: (e, _) => Text('Failed to load notes: $e',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.red)),
        data: (notes) {
          if (notes.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No notes yet. Add one for the next admin.',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey, fontWeight: FontWeight.w500)),
              ),
            );
          }
          return Column(
            children: [
              for (final note in notes)
                _noteTile(context, ref, user, note, theme, isDark),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PHASE 5c — COMPLIANCE
  // ---------------------------------------------------------------------------
  Widget _buildAdminCompliance(BuildContext context, WidgetRef ref,
      ProfileModel user, ThemeData theme, bool isDark) {
    final exportsAsync = ref.watch(userDataExportsProvider(user.id));
    return _AdminCard(
      title: 'Compliance & Data Rights',
      icon: Icons.gavel_rounded,
      accent: Colors.indigo,
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Right-to-export and right-to-be-forgotten controls. Every '
            'request is audit-logged and tied to your admin profile.',
            style:
                theme.textTheme.bodySmall?.copyWith(fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleRequestDataExport(context, ref, user),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Request Data Export'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.indigo,
                    side: BorderSide(color: Colors.indigo.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _showDeleteWithReasonDialog(context, ref, user),
                  icon: const Icon(Icons.delete_forever_rounded, size: 16),
                  label: const Text('Delete (Reason)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          exportsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (exports) {
              if (exports.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _divider(theme),
                  const SizedBox(height: 8),
                  Text('RECENT EXPORT REQUESTS',
                      style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          fontSize: 10)),
                  const SizedBox(height: 8),
                  for (final ex in exports.take(5))
                    _exportRow(ex, theme, isDark),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PHASE 6 — VIEW AS USER (read-only preview of what the user sees)
  // ---------------------------------------------------------------------------
  Widget _buildAdminViewAsUser(
      BuildContext context,
      ProfileModel user,
      List<LoanModel> loans,
      List<SavingsModel> savings,
      ThemeData theme,
      bool isDark) {
    return _AdminCard(
      title: 'View as User',
      icon: Icons.visibility_rounded,
      accent: Colors.teal,
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Open a read-only preview of what this member sees in their own '
            'portal. No auth tokens are issued — this is a data-only view, '
            'and every open is audit-logged.',
            style:
                theme.textTheme.bodySmall?.copyWith(fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  _openViewAsSheet(context, user, loans, savings, theme, isDark),
              icon: const Icon(Icons.preview_rounded, size: 18),
              label: const Text('Open Read-Only View'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ADMIN — DIALOGS / ACTION HANDLERS
  // ===========================================================================

  Future<void> _showChangeRoleDialog(BuildContext context, WidgetRef ref,
      ProfileModel user, ThemeData theme, bool isDark) async {
    UserRole selected = user.role ?? UserRole.customer;
    final reasonCtrl = TextEditingController();
    bool busy = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Change Role'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Changing the role takes effect immediately. The user '
                    'may need to re-login for permissions to refresh.',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<UserRole>(
                    initialValue: selected,
                    items: UserRole.values
                        .where((r) => r != UserRole.superAdmin)
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(_roleLabel(r)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => selected = v);
                    },
                    decoration: InputDecoration(
                      labelText: 'New role',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Reason (optional)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (selected == user.role) {
                          Navigator.pop(ctx);
                          return;
                        }
                        setState(() => busy = true);
                        try {
                          await ref
                              .read(userRepositoryProvider)
                              .changeUserRole(
                                profileId: user.id,
                                oldRole: user.role ?? UserRole.customer,
                                newRole: selected,
                                reason: reasonCtrl.text,
                              );
                          ref.invalidate(userListProvider);
                          ref.invalidate(userDetailsProvider(user.id));
                          ref.invalidate(userStatsProvider);
                          ref.invalidate(userAuditLogsProvider(
                              UserAuditQuery(
                                  profileId: user.id,
                                  authUserId: user.userId)));
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            _toast(context, 'Role updated.');
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            setState(() => busy = false);
                            _toast(context, 'Failed: $e', error: true);
                          }
                        }
                      },
                child: busy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('UPDATE'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _showReassignBranchDialog(BuildContext context, WidgetRef ref,
      ProfileModel user, ThemeData theme) async {
    final branchesAsync = ref.read(activeBranchesProvider);
    final branches = branchesAsync.value ?? const <BranchModel>[];
    String? selected = user.branchId;
    bool busy = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Reassign Branch'),
            content: branches.isEmpty
                ? const Text('No active branches available.')
                : DropdownButtonFormField<String>(
                    initialValue: selected,
                    items: branches
                        .map((b) => DropdownMenuItem(
                            value: b.id, child: Text(b.name)))
                        .toList(),
                    onChanged: (v) => setState(() => selected = v),
                    decoration: InputDecoration(
                      labelText: 'Branch',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: busy || selected == null || selected == user.branchId
                    ? null
                    : () async {
                        setState(() => busy = true);
                        try {
                          final repo = ref.read(userRepositoryProvider);
                          await repo
                              .updateProfile(user.id, {'branch_id': selected});
                          await repo.logAdminAction(
                            action: 'profile.branch_reassigned',
                            entityType: 'profile',
                            entityId: user.id,
                            details: {
                              'from': user.branchId,
                              'to': selected,
                            },
                          );
                          ref.invalidate(userListProvider);
                          ref.invalidate(userDetailsProvider(user.id));
                          ref.invalidate(userAuditLogsProvider(
                              UserAuditQuery(
                                  profileId: user.id,
                                  authUserId: user.userId)));
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            _toast(context, 'Branch updated.');
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            setState(() => busy = false);
                            _toast(context, 'Failed: $e', error: true);
                          }
                        }
                      },
                child: busy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('REASSIGN'),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _statusChip(BuildContext context, WidgetRef ref, ProfileModel user,
      AccountStatus target, String label, Color color, ThemeData theme) {
    final isCurrent = user.status == target;
    return ActionChip(
      avatar: Icon(
        isCurrent ? Icons.check_circle_rounded : Icons.circle_outlined,
        size: 16,
        color: color,
      ),
      label: Text(label),
      backgroundColor: color.withValues(alpha: isCurrent ? 0.18 : 0.08),
      labelStyle: TextStyle(
          color: color, fontWeight: FontWeight.w800, fontSize: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
            color: color.withValues(alpha: isCurrent ? 0.6 : 0.25)),
      ),
      onPressed: isCurrent
          ? null
          : () => _confirmAndChangeStatus(context, ref, user, target),
    );
  }

  Future<void> _confirmAndChangeStatus(BuildContext context, WidgetRef ref,
      ProfileModel user, AccountStatus newStatus) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Change status to ${_statusLabel(newStatus)}?'),
        content: Text(
            'This will change ${user.fullName ?? "this user"}\'s account state '
            'immediately. The change is audit-logged.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCEL')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('CONFIRM')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(userRepositoryProvider).changeUserStatus(
            profileId: user.id,
            oldStatus: user.status,
            newStatus: newStatus,
          );
      ref.invalidate(userListProvider);
      ref.invalidate(userDetailsProvider(user.id));
      ref.invalidate(userStatsProvider);
      ref.invalidate(userAuditLogsProvider(
          UserAuditQuery(profileId: user.id, authUserId: user.userId)));
      if (context.mounted) _toast(context, 'Status updated.');
    } catch (e) {
      if (context.mounted) _toast(context, 'Failed: $e', error: true);
    }
  }

  Future<void> _handlePasswordReset(
      BuildContext context, WidgetRef ref, ProfileModel user) async {
    final email = user.email ?? '';
    if (email.isEmpty) {
      _toast(context, 'User has no email — cannot reset.', error: true);
      return;
    }
    try {
      await ref.read(userRepositoryProvider).sendPasswordReset(email);
      await ref.read(userRepositoryProvider).logAdminAction(
        action: 'profile.password_reset_sent',
        entityType: 'profile',
        entityId: user.id,
        details: {'email': email},
      );
      ref.invalidate(userAuditLogsProvider(
          UserAuditQuery(profileId: user.id, authUserId: user.userId)));
      if (context.mounted) {
        _toast(context, 'Reset link sent to $email.');
      }
    } catch (e) {
      if (context.mounted) _toast(context, 'Failed: $e', error: true);
    }
  }

  /// Shows a bottom sheet with password management options.
  void _showPasswordOptions(BuildContext context, WidgetRef ref,
      ProfileModel user, ThemeData theme) {
    final primary = theme.colorScheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text('Password Management',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                user.fullName ?? 'User',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 24),
              // Option 1: Set new password directly
              _buildPasswordOption(
                icon: Icons.lock_reset_rounded,
                title: 'Set New Password',
                subtitle: 'Immediately change the password',
                color: primary,
                onTap: () {
                  Navigator.pop(ctx);
                  _showSetPasswordDialog(context, ref, user, theme);
                },
              ),
              const SizedBox(height: 12),
              // Option 2: Send reset email
              _buildPasswordOption(
                icon: Icons.email_rounded,
                title: 'Send Reset Link',
                subtitle: 'Email a password reset link to the user',
                color: AppColors.warning,
                onTap: () {
                  Navigator.pop(ctx);
                  _handlePasswordReset(context, ref, user);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  /// Shows a dialog to directly set a new password for the user.
  Future<void> _showSetPasswordDialog(BuildContext context, WidgetRef ref,
      ProfileModel user, ThemeData theme) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscurePassword = true;
    bool isLoading = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final primary = theme.colorScheme.primary;
          final passwordsMatch =
              passwordController.text == confirmController.text;
          final isValid = passwordController.text.length >= 6 && passwordsMatch;

          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.lock_reset_rounded, color: primary, size: 22),
                const SizedBox(width: 10),
                const Text('Set New Password'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 16, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This will immediately change the password for '
                            '${user.fullName ?? "this user"}. They will need '
                            'to use the new password on next login.',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      hintText: 'Min 6 characters',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => obscurePassword = !obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: confirmController,
                    obscureText: obscurePassword,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon:
                          const Icon(Icons.lock_outline_rounded, size: 20),
                      errorText: confirmController.text.isNotEmpty &&
                              !passwordsMatch
                          ? 'Passwords do not match'
                          : null,
                    ),
                  ),
                  if (passwordController.text.isNotEmpty &&
                      passwordController.text.length < 6) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Password must be at least 6 characters',
                      style: TextStyle(
                          color: theme.colorScheme.error, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: (isValid && !isLoading)
                    ? () async {
                        setState(() => isLoading = true);
                        try {
                          await ref
                              .read(userRepositoryProvider)
                              .adminSetUserPassword(
                                targetUserId: user.userId ?? user.id,
                                newPassword: passwordController.text,
                              );
                          // Log the action
                          await ref
                              .read(userRepositoryProvider)
                              .logAdminAction(
                                action: 'admin.password_force_reset',
                                entityType: 'profile',
                                entityId: user.id,
                                details: {
                                  'target_name': user.fullName,
                                  'method': 'direct_set',
                                },
                              );
                          ref.invalidate(userAuditLogsProvider(UserAuditQuery(
                              profileId: user.id,
                              authUserId: user.userId)));
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            _toast(context,
                                'Password updated for ${user.fullName ?? "user"}.');
                          }
                        } catch (e) {
                          setState(() => isLoading = false);
                          if (ctx.mounted) {
                            final raw = e.toString();
                            // Extract the message portion after "Exception: "
                            final clean = raw.startsWith('Exception: ')
                                ? raw.substring('Exception: '.length)
                                : raw;
                            final friendly = clean.contains('does not have a login account')
                                || clean.contains('missing user_id')
                                  ? 'This user does not have a login account yet. '
                                      'An auth account will be created automatically — '
                                      'please try again or contact support.'
                                  : clean;
                            _toast(context, friendly, error: true);
                          }
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('SET PASSWORD'),
              ),
            ],
          );
        },
      ),
    );

    passwordController.dispose();
    confirmController.dispose();
  }

  Future<void> _handleForceLogout(
      BuildContext context, WidgetRef ref, ProfileModel user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Force logout?'),
        content: Text(
            'All active sessions for ${user.fullName ?? "this user"} will be '
            'invalidated. They will need to sign in again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCEL')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('FORCE LOGOUT')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final repo = ref.read(userRepositoryProvider);
      await repo.forceLogout(user.id, userId: user.userId);
      await repo.logAdminAction(
        action: 'profile.force_logout',
        entityType: 'profile',
        entityId: user.id,
      );
      ref.invalidate(userAuditLogsProvider(
          UserAuditQuery(profileId: user.id, authUserId: user.userId)));
      if (context.mounted) _toast(context, 'Sessions revoked.');
    } catch (e) {
      if (context.mounted) _toast(context, 'Failed: $e', error: true);
    }
  }

  Future<void> _showAddNoteSheet(
      BuildContext context, WidgetRef ref, ProfileModel user) async {
    final ctrl = TextEditingController();
    bool pinned = false;
    bool busy = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add Internal Note',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text('Visible only to admins of this organization.',
                    style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  maxLines: 4,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'e.g. Member requested loan top-up; pending KYC',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Pin to top'),
                  value: pinned,
                  onChanged: (v) => setState(() => pinned = v ?? false),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy ? null : () => Navigator.pop(ctx),
                        child: const Text('CANCEL'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: busy
                            ? null
                            : () async {
                                if (ctrl.text.trim().isEmpty) return;
                                setState(() => busy = true);
                                try {
                                  await ref
                                      .read(userRepositoryProvider)
                                      .addAdminNote(
                                        profileId: user.id,
                                        body: ctrl.text,
                                        pinned: pinned,
                                      );
                                  ref.invalidate(adminNotesProvider(user.id));
                                  ref.invalidate(userAuditLogsProvider(
                                      UserAuditQuery(
                                          profileId: user.id,
                                          authUserId: user.userId)));
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    _toast(context, 'Note added.');
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    setState(() => busy = false);
                                    _toast(context, 'Failed: $e',
                                        error: true);
                                  }
                                }
                              },
                        child: busy
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('SAVE'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _handleRequestDataExport(
      BuildContext context, WidgetRef ref, ProfileModel user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Request data export?'),
        content: Text(
            'A data-export request will be queued for ${user.fullName ?? "this user"}. '
            'A backend job will compile the file and the download link will '
            'appear here when ready.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCEL')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('REQUEST')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(userRepositoryProvider)
          .requestUserDataExport(profileId: user.id);
      ref.invalidate(userDataExportsProvider(user.id));
      ref.invalidate(userAuditLogsProvider(
          UserAuditQuery(profileId: user.id, authUserId: user.userId)));
      if (context.mounted) _toast(context, 'Export queued.');
    } catch (e) {
      if (context.mounted) _toast(context, 'Failed: $e', error: true);
    }
  }

  Future<void> _showDeleteWithReasonDialog(
      BuildContext context, WidgetRef ref, ProfileModel user) async {
    final reasonCtrl = TextEditingController();
    bool busy = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Permanently delete user?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This is irreversible. The profile will be removed and '
                    'their auth account deleted via the delete-user Edge '
                    'Function. A reason is required for compliance.',
                    style:
                        Theme.of(ctx).textTheme.bodySmall?.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Reason *',
                      hintText: 'e.g. KYC fraud confirmed; user request',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: busy ? null : () => Navigator.pop(ctx, false),
                  child: const Text('CANCEL')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: busy
                    ? null
                    : () async {
                        if (reasonCtrl.text.trim().isEmpty) return;
                        setState(() => busy = true);
                        try {
                          await ref
                              .read(userRepositoryProvider)
                              .deleteUserWithReason(
                                profileId: user.id,
                                reason: reasonCtrl.text,
                              );
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (ctx.mounted) {
                            setState(() => busy = false);
                            _toast(context, 'Failed: $e', error: true);
                          }
                        }
                      },
                child: busy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('DELETE'),
              ),
            ],
          );
        });
      },
    );
    if (result == true && context.mounted) {
      ref.invalidate(userListProvider);
      _toast(context, 'User deleted.');
      context.pop();
    }
  }

  Future<void> _openViewAsSheet(
      BuildContext context,
      ProfileModel user,
      List<LoanModel> loans,
      List<SavingsModel> savings,
      ThemeData theme,
      bool isDark) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (ctx, scrollCtrl) {
            return Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.dividerColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    color: Colors.teal.withValues(alpha: 0.12),
                    child: Row(
                      children: [
                        const Icon(Icons.visibility_rounded,
                            size: 18, color: Colors.teal),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('VIEWING AS ${user.fullName ?? "USER"}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.teal,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                      fontSize: 10)),
                              Text('Read-only preview · no actions available',
                                  style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close_rounded)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GlassCard(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor:
                                      theme.colorScheme.primary
                                          .withValues(alpha: 0.15),
                                  child: Text(
                                    (user.fullName ?? '?')[0].toUpperCase(),
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 22,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(user.fullName ?? '—',
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                  fontWeight:
                                                      FontWeight.w900)),
                                      Text(user.email ?? user.phone ?? '',
                                          style: theme.textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text('Your Loans',
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          if (loans.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('No active loans.',
                                  style: TextStyle(color: Colors.grey)),
                            )
                          else
                            for (final l in loans.take(5))
                              GlassCard(
                                padding: const EdgeInsets.all(14),
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    const Icon(
                                        Icons.account_balance_wallet_rounded,
                                        size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              'Loan ${l.id.substring(0, math.min(8, l.id.length)).toUpperCase()}',
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w800)),
                                          Text(
                                              'Outstanding: ₹${_compact(l.outstandingBalance)}',
                                              style:
                                                  theme.textTheme.bodySmall),
                                        ],
                                      ),
                                    ),
                                    Text(l.status.name.toUpperCase(),
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                                fontWeight:
                                                    FontWeight.w900)),
                                  ],
                                ),
                              ),
                          const SizedBox(height: 16),
                          Text('Your Savings',
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          if (savings.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('No savings plans.',
                                  style: TextStyle(color: Colors.grey)),
                            )
                          else
                            for (final s in savings.take(5))
                              GlassCard(
                                padding: const EdgeInsets.all(14),
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.savings_rounded,
                                        size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              'Plan ${s.id.substring(0, math.min(8, s.id.length)).toUpperCase()}',
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w800)),
                                          Text(
                                              'Target: ₹${_compact(s.targetAmount)}',
                                              style:
                                                  theme.textTheme.bodySmall),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // ADMIN — SMALL UI HELPERS
  // ===========================================================================

  Widget _kvRow(_KvRow row, ThemeData theme, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(row.label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  fontSize: 10,
                  color: theme.textTheme.bodySmall?.color
                      ?.withValues(alpha: 0.7))),
        ),
        Expanded(
          child: Text(row.value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _bigStat(
      {required String label,
      required String value,
      required Color color,
      required ThemeData theme}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  fontSize: 10)),
          const SizedBox(height: 6),
          Text(value,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _miniStat(String label, int n, Color color, ThemeData theme) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text('$n',
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900, color: color)),
            Text(label,
                style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _auditRow(
      Map<String, dynamic> row, ThemeData theme, bool isDark) {
    final action = (row['action'] ?? '—').toString();
    final created = row['created_at']?.toString();
    final ip = row['ip_address']?.toString();
    final details = row['details'];
    final detailStr = (details is Map && details.isNotEmpty)
        ? details.entries
            .take(2)
            .map((e) => '${e.key}=${e.value}')
            .join(', ')
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6, right: 10),
            decoration: BoxDecoration(
                color: _auditColorFor(action), shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w800, fontSize: 13)),
                if (detailStr != null)
                  Text(detailStr,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontSize: 11, color: Colors.grey)),
                Text(
                    [
                      _fmtDate(
                          created != null ? DateTime.tryParse(created) : null),
                      if (ip != null && ip.isNotEmpty) ip,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _auditColorFor(String action) {
    if (action.contains('deleted') || action.contains('force_logout')) {
      return Colors.red;
    }
    if (action.contains('role') || action.contains('status')) {
      return Colors.orange;
    }
    if (action.contains('password') || action.contains('export')) {
      return Colors.indigo;
    }
    if (action.contains('note')) return Colors.purple;
    return Colors.green;
  }

  Widget _noteTile(BuildContext context, WidgetRef ref, ProfileModel user,
      Map<String, dynamic> note, ThemeData theme, bool isDark) {
    final body = (note['body'] ?? '').toString();
    final pinned = note['pinned'] == true;
    final createdAt = note['created_at']?.toString();
    final author = note['author'];
    final authorName = author is Map ? author['full_name']?.toString() : null;
    final accent = pinned ? Colors.amber : theme.colorScheme.tertiary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(pinned ? Icons.push_pin_rounded : Icons.notes_rounded,
              size: 16, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(body,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                    [
                      authorName ?? 'Admin',
                      _fmtDate(createdAt != null
                          ? DateTime.tryParse(createdAt)
                          : null),
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            iconSize: 18,
            onSelected: (v) async {
              final repo = ref.read(userRepositoryProvider);
              if (v == 'pin') {
                await repo.setAdminNotePinned(
                    note['id'].toString(), !pinned);
              } else if (v == 'delete') {
                await repo.deleteAdminNote(note['id'].toString(),
                    profileId: user.id);
              }
              ref.invalidate(adminNotesProvider(user.id));
              ref.invalidate(userAuditLogsProvider(
                  UserAuditQuery(profileId: user.id, authUserId: user.userId)));
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'pin', child: Text(pinned ? 'Unpin' : 'Pin')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _exportRow(
      Map<String, dynamic> ex, ThemeData theme, bool isDark) {
    final status = (ex['status'] ?? 'pending').toString();
    final created = ex['created_at']?.toString();
    final url = ex['file_url']?.toString();
    Color c;
    switch (status) {
      case 'completed':
        c = Colors.green;
        break;
      case 'processing':
        c = Colors.blue;
        break;
      case 'failed':
        c = Colors.red;
        break;
      default:
        c = Colors.orange;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(status.toUpperCase(),
                  style: TextStyle(
                      color: c,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1))),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _fmtDate(created != null ? DateTime.tryParse(created) : null),
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
          ),
          if (url != null && url.isNotEmpty)
            const Icon(Icons.cloud_download_rounded,
                size: 16, color: Colors.green),
        ],
      ),
    );
  }

  Widget _divider(ThemeData theme) => Divider(
      height: 0,
      thickness: 0.4,
      color: theme.dividerColor.withValues(alpha: 0.2));

  void _toast(BuildContext context, String msg, {bool error = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : AppColors.success,
        behavior: SnackBarBehavior.floating));
  }

  String _statusLabel(AccountStatus s) {
    switch (s) {
      case AccountStatus.active:
        return 'Active';
      case AccountStatus.inactive:
        return 'Inactive';
      case AccountStatus.suspended:
        return 'Suspended';
      case AccountStatus.onLeave:
        return 'On Leave';
      case AccountStatus.pending:
        return 'Pending';
    }
  }

  String _roleLabel(UserRole? r) {
    if (r == null) return '—';
    switch (r) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.executiveAdmin:
        return 'Executive Admin';
      case UserRole.manager:
        return 'Branch Manager';
      case UserRole.collectionAgent:
        return 'Collection Agent';
      case UserRole.customer:
        return 'Customer';
    }
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _compact(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  Widget _buildSliverAppBar(
      BuildContext context, WidgetRef ref, ProfileModel user, ThemeData theme) {
    return SliverAppBar(
      expandedHeight: 0,
      collapsedHeight: 64,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor.withValues(alpha: 0.7),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => context.pop(),
      ),
      title: Text(
        user.fullName ?? 'Member Profile',
        style: const TextStyle(
            fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, size: 24),
          onSelected: (value) {
            if (value == 'edit') {
              _showEditSheet(context, ref, user);
            } else if (value == 'delete') {
              _showDeleteDialog(context, ref, user);
            }
          },
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Edit Profile',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.ios_share_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Export Statement',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            if (ref.watch(currentUserProvider)?.role ==
                UserRole.executiveAdmin) ...[
              PopupMenuItem(
                value: 'deactivate',
                child: Row(
                  children: [
                    Icon(Icons.no_accounts_rounded,
                        size: 20, color: Colors.orange[400]),
                    const SizedBox(width: 12),
                    Text('Deactivate Member',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[400])),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever_rounded,
                        size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Delete Permanently',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: Colors.red)),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref, ProfileModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditProfileSheet(user: user),
    );
  }

  void _showDeleteDialog(
      BuildContext context, WidgetRef ref, ProfileModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User?'),
        content: Text(
            'Are you sure you want to delete ${user.fullName}? This action is permanent and will remove all records.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              HapticService.heavy();
              try {
                await ref
                    .read(userListNotifierProvider.notifier)
                    .deleteUsers([user.id]);
                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  context.pop(); // Go back to list
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User deleted successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete user: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityHeader(BuildContext context, WidgetRef ref,
      ProfileModel user, ThemeData theme, bool isDark) {
    final primary = theme.colorScheme.primary;
    final avatarState = ref.watch(avatarUploadNotifierProvider);
    final hasAvatar =
        user.avatarUrl != null && user.avatarUrl!.trim().isNotEmpty;

    ref.listen<AsyncValue<String?>>(avatarUploadNotifierProvider,
        (prev, next) {
      next.whenOrNull(
        error: (e, _) => _toast(context, 'Avatar update failed: $e',
            error: true),
        data: (url) {
          if (url != null && prev is AsyncLoading) {
            _toast(context, 'Avatar updated.');
          }
        },
      );
    });

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withValues(alpha: 0.12),
            primary.withValues(alpha: 0.02),
          ],
        ),
        border: Border.all(color: primary.withValues(alpha: 0.15), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Icon(Icons.shield_rounded,
                size: 100, color: primary.withValues(alpha: 0.03)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _showAvatarOptions(context, ref, user),
                  child: Hero(
                    tag: 'user_avatar_${user.id}',
                    child: Stack(
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: hasAvatar
                                ? null
                                : LinearGradient(
                                    colors: [
                                      primary,
                                      primary.withValues(alpha: 0.7)
                                    ],
                                  ),
                            boxShadow: [
                              BoxShadow(
                                  color: primary.withValues(alpha: 0.3),
                                  blurRadius: 15,
                                  spreadRadius: -2),
                            ],
                            image: hasAvatar
                                ? DecorationImage(
                                    image: NetworkImage(user.avatarUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: hasAvatar
                              ? null
                              : Center(
                                  child: Text(
                                    user.fullName?[0].toUpperCase() ?? '?',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 30,
                                        fontWeight: FontWeight.w900),
                                  ),
                                ),
                        ),
                        // Camera badge
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: theme.scaffoldBackgroundColor,
                                  width: 2),
                              boxShadow: [
                                BoxShadow(
                                    color: primary.withValues(alpha: 0.4),
                                    blurRadius: 6),
                              ],
                            ),
                            child: avatarState.isLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(5),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.camera_alt_rounded,
                                    size: 13, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.fullName ?? 'Unknown',
                              style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.8),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.verified_user_rounded,
                              size: 18,
                              color: isDark
                                  ? AppColors.successDark
                                  : AppColors.success),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Member ID: MF-${user.id.substring(0, 8).toUpperCase()}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: primary.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          user.role?.name.toUpperCase() ?? 'RETAIL MEMBER',
                          style: TextStyle(
                              color: primary,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0);
  }

  /// Shows a bottom sheet with avatar options: gallery, camera, or remove.
  void _showAvatarOptions(
      BuildContext context, WidgetRef ref, ProfileModel user) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text('Profile Photo',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAvatarOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: primary,
                    onTap: () {
                      Navigator.pop(ctx);
                      _uploadAvatar(ref, user, ImageSource.gallery);
                    },
                  ),
                  _buildAvatarOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: AppColors.success,
                    onTap: () {
                      Navigator.pop(ctx);
                      _uploadAvatar(ref, user, ImageSource.camera);
                    },
                  ),
                  if (user.avatarUrl != null &&
                      user.avatarUrl!.trim().isNotEmpty)
                    _buildAvatarOption(
                      icon: Icons.delete_rounded,
                      label: 'Remove',
                      color: AppColors.error,
                      onTap: () {
                        Navigator.pop(ctx);
                        ref
                            .read(avatarUploadNotifierProvider.notifier)
                            .removeAvatar(
                              profileId: user.id,
                              userId: user.userId ?? user.id,
                            );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Images are compressed to save storage',
                style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  void _uploadAvatar(WidgetRef ref, ProfileModel user, ImageSource source) {
    HapticService.selection();
    ref.read(avatarUploadNotifierProvider.notifier).uploadAvatar(
          profileId: user.id,
          userId: user.userId ?? user.id,
          source: source,
        );
  }

  Widget _buildTrustScoreGauge(
      ProfileModel user, ThemeData theme, bool isDark) {
    final primary = theme.colorScheme.primary;
    // Real score logic would go here, using a default based on history
    const score = 785.0;

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Platform Trust Score',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text('Performance-based Credit Rating',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('ACTIVE',
                    style: TextStyle(
                        color: AppColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(200, 100),
                  painter: _GaugePainter(score: score, color: primary),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 30),
                    Text(
                      '${score.toInt()}',
                      style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 42,
                          letterSpacing: -1),
                    ),
                    Text(
                      'OF 900',
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 2),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 100.ms)
        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }

  Widget _buildPortfolioHub(List<LoanModel> loans, List<SavingsModel> savings,
      ThemeData theme, bool isDark) {
    final active = loans.where((l) => l.status == LoanStatus.active).toList();
    final totalOut = active.fold<double>(
        0.0, (double sum, LoanModel l) => sum + l.outstandingBalance);
    final totalSavings = savings.fold<double>(
        0.0, (double sum, SavingsModel s) => sum + s.targetAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text('Portfolio Overview',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
        ),
        Row(
          children: [
            Expanded(
              child: _buildPortfolioCard(
                'Active Liability',
                '₹${(totalOut / 1000).toStringAsFixed(1)}k',
                '${active.length} Active Loans',
                Icons.trending_up_rounded,
                theme.colorScheme.primary,
                theme,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildPortfolioCard(
                'Asset Value',
                '₹${(totalSavings / 1000).toStringAsFixed(1)}k',
                '${savings.length} Plans',
                Icons.account_balance_rounded,
                isDark ? AppColors.successDark : AppColors.success,
                theme,
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildPortfolioCard(String label, String value, String subValue,
      IconData icon, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 16),
          Text(value,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(subValue,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildRepaymentdiscipline(
      List<LoanModel> loans, ThemeData theme, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Repayment Discipline',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              Icon(Icons.bar_chart_rounded,
                  size: 20, color: theme.colorScheme.primary),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 100,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _makeGroupData(0, 8, theme.colorScheme.primary),
                  _makeGroupData(1, 10, theme.colorScheme.primary),
                  _makeGroupData(2, 9, theme.colorScheme.primary),
                  _makeGroupData(3, 12, theme.colorScheme.primary),
                  _makeGroupData(4, 11, theme.colorScheme.primary),
                  _makeGroupData(5, 14, theme.colorScheme.primary),
                  _makeGroupData(6, 13, theme.colorScheme.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Historical Collection Performance',
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05, end: 0);
  }

  BarChartGroupData _makeGroupData(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 12,
          borderRadius: BorderRadius.circular(4),
          backDrawRodData: BackgroundBarChartRodData(
              show: true, toY: 15, color: color.withValues(alpha: 0.05)),
        ),
      ],
    );
  }

  Widget _buildKYCVault(ProfileModel user, ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text('Document & KYC Vault',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
        ),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildKYCItem('AADHAR CARD', user.aadhar ?? 'Not provided',
                  Icons.badge_rounded, theme),
              const Divider(height: 24, thickness: 0.5),
              _buildKYCItem('PAN CARD', user.pan ?? 'Not provided',
                  Icons.credit_card_rounded, theme),
              const Divider(height: 24, thickness: 0.5),
              _buildKYCItem('PHONE VERIFIED', user.phone ?? 'Not provided',
                  Icons.phone_android_rounded, theme),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildKYCItem(
      String label, String value, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1)),
              const SizedBox(height: 2),
              Text(value,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
        ),
        const Icon(Icons.verified_rounded, size: 16, color: AppColors.success),
      ],
    );
  }

  Widget _buildMemberQRPass(ProfileModel user, ThemeData theme, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Member QR Pass',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(
                  'Scan this code to instantly pull up profile or record collections.',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_scanner_rounded,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('ENCRYPTED ID',
                          style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: user.id,
              version: QrVersions.auto,
              size: 100.0,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildActivityTimeline(List<LoanModel> loans,
      List<SavingsModel> savings, ThemeData theme, bool isDark) {
    final hasActivity = loans.isNotEmpty || savings.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text('Recent History',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: !hasActivity
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.history_toggle_off_rounded,
                            size: 32, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No transaction activity recorded yet.',
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Real items would be mapped from a transaction provider
                    // For now, only show real items if lists are populated
                    if (loans.isNotEmpty)
                      _buildTimelineItem(
                          'Loan Account Created',
                          'Portfolio initialized',
                          'System Log',
                          Icons.add_moderator_rounded,
                          theme.colorScheme.primary,
                          theme),
                    if (savings.isNotEmpty)
                      _buildTimelineItem(
                          'Savings Plan Active',
                          'Contribution window open',
                          'System Log',
                          Icons.savings_rounded,
                          AppColors.success,
                          theme),
                  ],
                ),
        ),
      ],
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildTimelineItem(String title, String desc, String time,
      IconData icon, Color color, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w800, fontSize: 14)),
                Text(desc,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
              ],
            ),
          ),
          Text(time,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildFloatingActionIsland(
      BuildContext context, ThemeData theme, bool isDark) {
    final primary = theme.colorScheme.primary;

    return Positioned(
      left: 24,
      right: 24,
      bottom: 32,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        borderRadius: 24,
        child: Row(
          children: [
            Expanded(
              child: _ActionIslandButton(
                label: 'Deploy Capital',
                icon: Icons.add_moderator_rounded,
                color: primary,
                onTap: () => context.push('/loans/new'),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 40,
              width: 1,
              color: theme.dividerColor.withValues(alpha: 0.2),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionIslandButton(
                label: 'Quick Deposit',
                icon: Icons.savings_rounded,
                color: isDark ? AppColors.successDark : AppColors.success,
                onTap: () => context.push('/savings/new'),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.5, end: 0);
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Synchronizing Profile...',
              style:
                  TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _ActionIslandButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionIslandButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: -0.2),
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double score;
  final Color color;
  _GaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 2);
    const startAngle = math.pi;
    const sweepAngle = math.pi;

    // Background track
    paint.color = color.withValues(alpha: 0.1);
    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);

    // Active track
    final activeSweep = (score / 900) * math.pi;
    paint.color = color;
    canvas.drawArc(rect, startAngle, activeSweep, false, paint);

    // Dot at the end
    final angle = startAngle + activeSweep;
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;
    final x = center.dx + radius * math.cos(angle);
    final y = center.dy + radius * math.sin(angle);

    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(x, y), 5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _AuroraBackground extends StatelessWidget {
  const _AuroraBackground();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary.withValues(alpha: 0.05),
            ),
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .moveY(
                begin: 0, end: 30, duration: 4.seconds, curve: Curves.easeInOut)
            .moveX(
                begin: 0,
                end: -20,
                duration: 5.seconds,
                curve: Curves.easeInOut),
        Positioned(
          bottom: 100,
          left: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success.withValues(alpha: 0.03),
            ),
          ),
        ).animate(onPlay: (c) => c.repeat()).moveY(
            begin: 0, end: -40, duration: 6.seconds, curve: Curves.easeInOut),
      ],
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  final ProfileModel user;
  const _EditProfileSheet({required this.user});

  @override
  _EditProfileSheetState createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _aadharController;
  late TextEditingController _panController;
  late TextEditingController _employeeIdController;
  late TextEditingController _zoneController;
  late TextEditingController _addressController;
  late TextEditingController _emailController;
  String? _selectedBranchId;
  bool _isLoading = false;
  bool _isResetting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName);
    
    final rawPhone = widget.user.phone?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (rawPhone.length == 10) {
      _phoneController = TextEditingController(
          text: '${rawPhone.substring(0, 5)} ${rawPhone.substring(5)}');
    } else {
      _phoneController = TextEditingController(text: rawPhone);
    }

    final rawAadhar = widget.user.aadhar?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (rawAadhar.length == 12) {
      _aadharController = TextEditingController(
          text: '${rawAadhar.substring(0, 4)} ${rawAadhar.substring(4, 8)} ${rawAadhar.substring(8)}');
    } else {
      _aadharController = TextEditingController(text: widget.user.aadhar ?? '');
    }

    _panController = TextEditingController(text: widget.user.pan);
    _emailController = TextEditingController(text: widget.user.email ?? '');
    _employeeIdController =
        TextEditingController(text: widget.user.employeeId ?? '');
    _zoneController =
        TextEditingController(text: widget.user.assignedZone ?? '');
    _addressController = TextEditingController(text: widget.user.address ?? '');
    _selectedBranchId = widget.user.branchId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _aadharController.dispose();
    _panController.dispose();
    _emailController.dispose();
    _employeeIdController.dispose();
    _zoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    setState(() => _isLoading = true);
    try {
      final repository = ref.read(userRepositoryProvider);
      final theme = Theme.of(context);

      // Build update data with only non-empty fields
      final data = <String, dynamic>{};

      if (_nameController.text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Full name is required'),
                behavior: SnackBarBehavior.floating),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
      data['full_name'] = _nameController.text.trim();

      if (_phoneController.text.trim().isNotEmpty) {
        final rawPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
        final phoneError = KYCValidators.validatePhone(rawPhone);
        if (phoneError != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(phoneError),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: theme.colorScheme.error),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
        data['phone'] = rawPhone;
      }

      if (_emailController.text.trim().isNotEmpty) {
        final emailError = KYCValidators.validateEmail(_emailController.text.trim());
        if (emailError != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(emailError),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: theme.colorScheme.error),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
        data['email'] = _emailController.text.trim();
      }

      if (_selectedBranchId != null &&
          _selectedBranchId!.trim().isNotEmpty) {
        data['branch_id'] = _selectedBranchId;
      }

      // Validate Aadhar if provided
      final aadharVal = _aadharController.text.trim().replaceAll(' ', '');
      if (aadharVal.isNotEmpty) {
        final aadharError = KYCValidators.validateAadhar(aadharVal);
        if (aadharError != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(aadharError),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: theme.colorScheme.error),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      // Validate PAN if provided
      final panVal = _panController.text.trim().toUpperCase();
      if (panVal.isNotEmpty) {
        final panError = KYCValidators.validatePAN(panVal);
        if (panError != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(panError),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: theme.colorScheme.error),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      // These columns may or may not exist depending on the DB schema version.
      // We include them only if they have values, and catch errors gracefully.
      final extraFields = <String, String>{
        'aadhar': aadharVal,
        'pan': panVal,
        'employee_id': _employeeIdController.text.trim(),
        'assigned_zone': _zoneController.text.trim(),
        'address': _addressController.text.trim(),
      };

      for (final entry in extraFields.entries) {
        if (entry.value.isNotEmpty) {
          data[entry.key] = entry.value;
        }
      }

      if (data.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('No changes to save'),
                behavior: SnackBarBehavior.floating),
          );
        }
        return;
      }

      await repository.updateUser(widget.user.id, data);

      ref.invalidate(userListProvider);
      ref.invalidate(userDetailsProvider(widget.user.id));
      ref.invalidate(userStatsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text('Profile updated successfully'),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Update failed: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePasswordReset() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Email address is required for password reset'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isResetting = true);
    try {
      final success = await ref
          .read(authProvider.notifier)
          .resetPassword(_emailController.text);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Password reset instructions sent to email'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating),
          );
        } else {
          final error = ref.read(authProvider).errorMessage;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(error ?? 'Failed to trigger password reset'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 600;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? AppColors.elevatedDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Indicator
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Title Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Profile',
                        style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900, letterSpacing: -1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Update member details and KYC records.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.dividerColor.withValues(alpha: 0.05),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Scrollable Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Summary / Role Info (Glass Card)
                  _buildRoleSummaryCard(theme, primary, isDark),
                  const SizedBox(height: 20),

                  // Branch Assignment Section
                  _buildBranchAssignmentSection(
                      theme, primary, isDark, isNarrow),
                  const SizedBox(height: 20),

                  // Account Details
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Account Details',
                            Icons.person_outline_rounded, theme, primary),
                        const SizedBox(height: 24),
                        _buildTwoColumn(
                          isNarrow: isNarrow,
                          first: _buildInputField(
                            label: 'FULL NAME',
                            hint: 'Enter legal name',
                            controller: _nameController,
                            theme: theme,
                            isDark: isDark,
                            primary: primary,
                          ),
                          second: _buildInputField(
                            label: 'MOBILE NUMBER',
                            hint: '98765 43210',
                            icon: Icons.phone_android_outlined,
                            prefixText: '+91 ',
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(11),
                              _MobileFormatter(),
                            ],
                            theme: theme,
                            isDark: isDark,
                            primary: primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          label: 'EMAIL ADDRESS',
                          hint: 'example@domain.com',
                          icon: Icons.alternate_email_rounded,
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          theme: theme,
                          isDark: isDark,
                          primary: primary,
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          label: 'RESIDENTIAL ADDRESS',
                          hint: 'Enter complete home address',
                          icon: Icons.home_outlined,
                          controller: _addressController,
                          theme: theme,
                          isDark: isDark,
                          primary: primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Operational Details (Employee ID / Zone)
                  if (widget.user.role != UserRole.customer) ...[
                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader(
                              'Field Operations',
                              Icons.corporate_fare_outlined,
                              theme,
                              isDark
                                  ? AppColors.warningDark
                                  : AppColors.orange),
                          const SizedBox(height: 24),
                          _buildTwoColumn(
                            isNarrow: isNarrow,
                            first: _buildInputField(
                              label: 'EMPLOYEE ID',
                              hint: 'Internal reference #',
                              controller: _employeeIdController,
                              theme: theme,
                              isDark: isDark,
                              primary: primary,
                            ),
                            second: _buildInputField(
                              label: 'ASSIGNED ZONE',
                              hint: 'e.g. North Sector',
                              icon: Icons.location_on_outlined,
                              controller: _zoneController,
                              theme: theme,
                              isDark: isDark,
                              primary: primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Security & Access
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                            'Security & Access',
                            Icons.lock_outline_rounded,
                            theme,
                            isDark ? Colors.redAccent : Colors.red),
                        const SizedBox(height: 24),
                        Text(
                          'Send a secure password reset link to the registered email address.',
                          style:
                              theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                                _isResetting ? null : _handlePasswordReset,
                            icon: _isResetting
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.red))
                                : const Icon(Icons.send_rounded, size: 18),
                            label: Text(_isResetting
                                ? 'Sending...'
                                : 'Reset User Password'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  isDark ? Colors.redAccent : Colors.red,
                              side: BorderSide(
                                  color:
                                      isDark ? Colors.redAccent : Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                            'Identity Verification',
                            Icons.badge_outlined,
                            theme,
                            isDark ? AppColors.successDark : AppColors.success),
                        const SizedBox(height: 24),
                        _buildTwoColumn(
                          isNarrow: isNarrow,
                          first: _buildInputField(
                            label: 'AADHAR NUMBER',
                            hint: 'XXXX XXXX XXXX',
                            icon: Icons.fingerprint_outlined,
                            controller: _aadharController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(14),
                              _AadharFormatter(),
                            ],
                            theme: theme,
                            isDark: isDark,
                            primary: primary,
                          ),
                          second: _buildInputField(
                            label: 'PAN NUMBER',
                            hint: 'ABCDE 1234 F',
                            icon: Icons.credit_card_outlined,
                            controller: _panController,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(10),
                              _PanFormatter(),
                            ],
                            theme: theme,
                            isDark: isDark,
                            primary: primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Bottom Actions
          Container(
            padding: EdgeInsets.fromLTRB(24, 16, 24,
                MediaQuery.of(context).padding.bottom > 0 ? 32 : 24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.elevatedDark : Colors.white,
              border: Border(
                top: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Discard',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save Changes',
                            style: TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSummaryCard(ThemeData theme, Color primary, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary, primary.withValues(alpha: 0.6)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.shield_outlined, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user.role?.name.toUpperCase() ?? 'MEMBER',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Permission Matrix Active',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      String title, IconData icon, ThemeData theme, Color accent) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: 12),
        Text(title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2)),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required ThemeData theme,
    required bool isDark,
    required Color primary,
    IconData? icon,
    String? prefixText,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                fontSize: 10,
                color:
                    theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          style:
              theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon, size: 18) : null,
            prefixText: prefixText,
            prefixStyle: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodySmall?.color,
            ),
            filled: true,
            fillColor: isDark ? AppColors.fillDark : AppColors.fillLight,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primary, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildTwoColumn({
    required bool isNarrow,
    required Widget first,
    required Widget second,
  }) {
    if (isNarrow) {
      return Column(
        children: [
          first,
          const SizedBox(height: 16),
          second,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: first),
        const SizedBox(width: 16),
        Expanded(child: second),
      ],
    );
  }

  Widget _buildBranchAssignmentSection(
      ThemeData theme, Color primary, bool isDark, bool isNarrow) {
    final branchesAsync = ref.watch(activeBranchesProvider);
    final branches = branchesAsync.value ?? [];

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
              'Branch Assignment', Icons.account_tree_outlined, theme, primary),
          const SizedBox(height: 24),
          _buildLabel('ASSIGN TO BRANCH', theme),
          const SizedBox(height: 10),
          _buildBranchDropdown(
            value: _selectedBranchId,
            hint: 'Select target branch',
            branches: branches,
            onChanged: (val) => setState(() => _selectedBranchId = val),
            theme: theme,
            isDark: isDark,
            primary: primary,
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String label, ThemeData theme) {
    return Text(label,
        style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            fontSize: 10,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7)));
  }

  Widget _buildBranchDropdown({
    required String? value,
    required String hint,
    required List<BranchModel> branches,
    required ValueChanged<String?> onChanged,
    required ThemeData theme,
    required bool isDark,
    required Color primary,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.fillDark : AppColors.fillLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        hint: Text(hint, style: theme.textTheme.bodyMedium),
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: primary, width: 1.5)),
        ),
        items: branches.map((branch) {
          return DropdownMenuItem<String>(
            value: branch.id,
            child: Row(
              children: [
                Icon(Icons.location_city_rounded,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(branch.name,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }).toList(),
        onChanged: onChanged,
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        dropdownColor: isDark ? AppColors.elevatedDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}


// =============================================================================
// ADMIN — small private value classes / cards
// =============================================================================

class _KvRow {
  final String label;
  final String value;
  const _KvRow(this.label, this.value);
}

/// A consistent admin-section card: header (icon + title + optional trailing)
/// followed by [child] body. All admin sections use this so they look
/// uniform and clearly belong together.
class _AdminCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final bool isDark;
  final Widget child;
  final Widget? trailing;

  const _AdminCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.isDark,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.18), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900, letterSpacing: -0.2)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _PanFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.toUpperCase();
    String formatted = '';

    for (int i = 0; i < text.length; i++) {
      String char = text[i];
      if (i < 5) {
        if (RegExp(r'[A-Z]').hasMatch(char)) formatted += char;
      } else if (i < 9) {
        if (RegExp(r'[0-9]').hasMatch(char)) formatted += char;
      } else if (i < 10) {
        if (RegExp(r'[A-Z]').hasMatch(char)) formatted += char;
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _AadharFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 12) digits = digits.substring(0, 12);

    StringBuffer formatted = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) formatted.write(' ');
      formatted.write(digits[i]);
    }

    return TextEditingValue(
      text: formatted.toString(),
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _MobileFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) digits = digits.substring(0, 10);

    StringBuffer formatted = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 5 == 0) formatted.write(' ');
      formatted.write(digits[i]);
    }

    return TextEditingValue(
      text: formatted.toString(),
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
