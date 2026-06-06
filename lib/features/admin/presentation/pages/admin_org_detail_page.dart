import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/utils/error_formatter.dart';
import '../../../../features/settings/data/models/activity_log_model.dart';
import '../../../../features/settings/data/repositories/activity_log_repository.dart';

final adminOrgDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, orgId) async {
  final client = ref.read(supabaseClientProvider);
  // Filter out soft-deleted organizations from the read path.
  return client
      .from('organizations')
      .select()
      .eq('id', orgId)
      .isFilter('deleted_at', null)
      .maybeSingle();
});

/// Reactive list of all *active* (non-deleted, non-suspended) orgs.
/// Re-fetches when `currentOrgProvider` emits.
final adminOrgListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  final response = await client
      .from('organizations')
      .select()
      .isFilter('deleted_at', null)
      .order('created_at', ascending: false);
  return (response as List).cast<Map<String, dynamic>>();
});

class AdminOrgDetailPage extends ConsumerWidget {
  final String orgId;
  const AdminOrgDetailPage({super.key, required this.orgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(adminOrgDetailProvider(orgId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
          child: detailAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (org) {
              if (org == null) return const Center(child: Text('Not found'));
              return _buildContent(context, ref, org, isDark);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref,
      Map<String, dynamic> org, bool isDark) {
    final status = org['status'] as String? ?? 'unknown';
    final isActive = status == 'active';
    final statusColor = isActive ? AppColors.success : AppColors.warning;
    final name = org['name'] as String? ?? '';

    return Column(
      children: [
        _buildAppBar(context, name, isDark),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              _buildHeaderCard(org, status, statusColor, isDark),
              const SizedBox(height: 20),
              _buildInfoSection(org, isDark),
              const SizedBox(height: 20),
              _buildLimitsCard(org, isDark),
              const SizedBox(height: 24),
              _buildDangerZone(context, ref, org['id'], isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context, String name, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: isDark ? Colors.white : const Color(0xFF0F172A)),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text('Organization',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A))),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildHeaderCard(
      Map<String, dynamic> org, String status, Color statusColor, bool isDark) {
    final name = org['name'] as String? ?? '';
    final slug = org['slug'] as String? ?? '';
    final created = org['created_at'] as String? ?? '';
    final dateStr = created.length >= 10 ? created.substring(0, 10) : '';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF1A1F2E).withValues(alpha: 0.9),
                  const Color(0xFF222731).withValues(alpha: 0.6)
                ]
              : [
                  Colors.white.withValues(alpha: 0.9),
                  Colors.white.withValues(alpha: 0.6)
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient:
                  LinearGradient(colors: [AppColors.primary, AppColors.accent]),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6))
              ],
            ),
            child: const Icon(Icons.business_rounded,
                color: Colors.white, size: 34),
          ),
          const SizedBox(height: 16),
          Text(name,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : const Color(0xFF0F172A))),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: statusColor)),
                const SizedBox(width: 6),
                Text(status[0].toUpperCase() + status.substring(1),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                        letterSpacing: 0.3)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('$slug  •  Created $dateStr',
              style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildInfoSection(Map<String, dynamic> org, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1F2E).withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Organization Info',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 16),
          _infoTile(Icons.alternate_email_rounded, 'Slug',
              org['slug'] as String? ?? '', isDark),
          _infoTile(Icons.calendar_today_rounded, 'Created',
              _formatDate(org['created_at'] as String?), isDark),
          _infoTile(Icons.update_rounded, 'Updated',
              _formatDate(org['updated_at'] as String?), isDark),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 200.ms)
        .slideY(begin: 0.05, end: 0);
  }

  Widget _buildLimitsCard(Map<String, dynamic> org, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1F2E).withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed_rounded, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text('Plan Limits',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _limitChip(
                      Icons.business_rounded,
                      'Branches',
                      '${org['max_branches'] ?? 5}',
                      AppColors.primary,
                      isDark)),
              const SizedBox(width: 12),
              Expanded(
                  child: _limitChip(Icons.people_rounded, 'Staff',
                      '${org['max_staff'] ?? 20}', AppColors.success, isDark)),
              const SizedBox(width: 12),
              Expanded(
                  child: _limitChip(
                      Icons.person_rounded,
                      'Members',
                      '${org['max_members'] ?? 500}',
                      AppColors.warning,
                      isDark)),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 300.ms)
        .slideY(begin: 0.05, end: 0);
  }

  Widget _limitChip(
      IconData icon, String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A))),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value, bool isDark) {
    if (value.isEmpty || value == 'null') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
          const SizedBox(width: 12),
          SizedBox(
              width: 80,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade600))),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF0F172A)))),
        ],
      ),
    );
  }

  Widget _buildDangerZone(
      BuildContext context, WidgetRef ref, String id, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: isDark ? 0.06 : 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 18, color: AppColors.error),
              const SizedBox(width: 8),
              Text('Danger Zone',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _suspendOrg(context, ref, id),
              icon: const Icon(Icons.pause_rounded, size: 18),
              label: const Text('Suspend Organization'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warning,
                side:
                    BorderSide(color: AppColors.warning.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _deleteOrg(context, ref, id),
              icon: const Icon(Icons.delete_rounded, size: 18),
              label: const Text('Delete Organization'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 400.ms);
  }

  String _formatDate(String? date) {
    return AppFormatters.parseIsoDate(date);
  }

  /// Suspend the organization. Revokes access for all members of the org
  /// (via the `suspend_organization` RPC) and refreshes the detail screen.
  Future<void> _suspendOrg(
      BuildContext context, WidgetRef ref, String id) async {
    final reason = await _showReasonDialog(
      context,
      title: 'Suspend Organization',
      description:
          'Suspended organizations will immediately lose access. '
          'All members will be signed out.',
      actionLabel: 'Suspend',
      actionColor: AppColors.warning,
    );
    if (reason == null) return;

    try {
      final client = Supabase.instance.client;
      await client.rpc('suspend_organization', params: {
        'p_org_id': id,
        'p_reason': reason,
      });

      // Refresh detail provider so the new status shows up.
      ref.invalidate(adminOrgDetailProvider(id));
      ref.invalidate(adminOrgListProvider);

      // Audit log (best-effort).
      try {
        await ActivityLogRepository(client).log(
          action: 'Organization Suspended',
          details: 'Suspended org $id. Reason: $reason',
          type: ActivityType.securityAlert,
        );
      } catch (_) {}

      if (context.mounted) {
        showSuccessSnackBar(context, 'Organization suspended');
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, e,
            fallback: 'Failed to suspend organization');
      }
    }
  }

  /// Soft-delete the organization. After this, the org is hidden from
  /// every list, members are detached from it, and the slug becomes
  /// available for re-use after the 30-day grace period.
  Future<void> _deleteOrg(
      BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Organization?'),
        content: const Text(
            'This will soft-delete the organization, sign out all members, '
            'and free the slug for re-use after 30 days. This can be '
            'restored from the audit log within the grace period.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(fontWeight: FontWeight.w600))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(
                      color: AppColors.error, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final reason = await _showReasonDialog(
      context,
      title: 'Reason for deletion',
      description:
          'This is required for audit. The organization record is kept for 30 days.',
      actionLabel: 'Delete',
      actionColor: AppColors.error,
    );
    if (reason == null) return;

    try {
      final client = Supabase.instance.client;
      await client.rpc('soft_delete_organization', params: {
        'p_org_id': id,
        'p_reason': reason,
      });

      ref.invalidate(adminOrgDetailProvider(id));
      ref.invalidate(adminOrgListProvider);

      try {
        await ActivityLogRepository(client).log(
          action: 'Organization Deleted',
          details: 'Soft-deleted org $id. Reason: $reason',
          type: ActivityType.securityAlert,
        );
      } catch (_) {}

      if (context.mounted) {
        // Force sign-out: the deleted org's members can no longer auth into
        // any tenant-scoped data. The acting super admin stays signed in.
        showSuccessSnackBar(
            context, 'Organization deleted. Members have been signed out.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, e,
            fallback: 'Failed to delete organization');
      }
    }
  }

  /// Generic reason-capture dialog used by Suspend / Delete.
  /// Returns the entered reason, or null if the user cancelled.
  Future<String?> _showReasonDialog(
    BuildContext context, {
    required String title,
    required String description,
    required String actionLabel,
    required Color actionColor,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description,
                  style: TextStyle(
                      color: Theme.of(ctx)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7))),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Required for audit log',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop<String?>(ctx, null),
                child: const Text('Cancel',
                    style: TextStyle(fontWeight: FontWeight.w600))),
            TextButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isEmpty) return;
                  Navigator.pop<String?>(ctx, text);
                },
                child: Text(actionLabel,
                    style: TextStyle(
                        color: actionColor, fontWeight: FontWeight.w700))),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }
}
