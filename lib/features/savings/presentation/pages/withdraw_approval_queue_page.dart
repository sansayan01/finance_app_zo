import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/savings_repository.dart';

class WithdrawApprovalQueuePage extends ConsumerStatefulWidget {
  const WithdrawApprovalQueuePage({super.key});

  @override
  ConsumerState<WithdrawApprovalQueuePage> createState() =>
      _WithdrawApprovalQueuePageState();
}

class _WithdrawApprovalQueuePageState
    extends ConsumerState<WithdrawApprovalQueuePage> {
  int _activeFilter = 0; // 0=Pending, 1=Approved, 2=Rejected, 3=All

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text(
          'Withdrawal Requests',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter tabs
          _buildFilterTabs(theme),
          // List
          Expanded(
            child: _buildApprovalList(user, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(ThemeData theme) {
    final labels = ['Pending', 'Approved', 'Rejected', 'All'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isSelected = _activeFilter == i;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _activeFilter = i),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.dividerColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? Colors.white
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildApprovalList(dynamic user, ThemeData theme) {
    if (user == null) return const Center(child: Text('Not authenticated'));

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchApprovals(user),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final approvals = snapshot.data ?? [];
        if (approvals.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_rounded,
                    size: 48,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                const SizedBox(height: 12),
                Text(
                  'No withdrawal requests',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: approvals.length,
          itemBuilder: (ctx, i) => _buildApprovalCard(approvals[i], theme),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchApprovals(dynamic user) async {
    final client = ref.read(supabaseClientProvider);

    final statusFilter = _activeFilter == 0
        ? 'pending'
        : _activeFilter == 1
            ? 'approved'
            : _activeFilter == 2
                ? 'rejected'
                : null;

    var query = client
        .from('pending_approvals')
        .select(
            '*, members:member_id(full_name, phone), profiles:requested_by(full_name)')
        .eq('org_id', user.orgId!)
        .eq('type', 'withdrawal');

    if (statusFilter != null) {
      query = query.eq('status', statusFilter);
    }

    if (user.role == 'branchManager' && user.branchId != null) {
      query = query.eq('branch_id', user.branchId);
    }

    final result = await query.order('created_at', ascending: false);
    return (result as List).cast<Map<String, dynamic>>();
  }

  Widget _buildApprovalCard(Map<String, dynamic> approval, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final status = approval['status'] as String? ?? 'pending';
    final member =
        approval['members'] as Map<String, dynamic>?;
    final requestedBy =
        approval['profiles'] as Map<String, dynamic>?;
    final createdAt = DateTime.tryParse(approval['created_at'] ?? '');
    final notes = approval['notes'] as String? ?? '';

    // Parse metadata from notes
    final amount = _extractDouble(notes, 'amount') ?? 0;
    final penaltyAmount = _extractDouble(notes, 'penalty_amount') ?? 0;
    final paymentMode = _extractString(notes, 'payment_mode') ?? 'cash';

    final statusColor = status == 'pending'
        ? Colors.orange
        : status == 'approved'
            ? AppColors.success
            : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.1),
                child: Text(
                  (member?['full_name'] as String? ?? 'M')[0].toUpperCase(),
                  style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member?['full_name'] as String? ?? 'Unknown',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(
                      'Requested by ${requestedBy?['full_name'] as String? ?? 'Staff'}',
                      style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Amount details
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface
                  .withValues(alpha: isDark ? 0.05 : 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _buildDetailRow(theme, 'Withdrawal',
                    '₹${amount.toStringAsFixed(0)}'),
                if (penaltyAmount > 0)
                  _buildDetailRow(theme, 'Penalty',
                      '-₹${penaltyAmount.toStringAsFixed(0)}',
                      valueColor: Colors.orange),
                _buildDetailRow(theme, 'Payment Mode',
                    paymentMode.toUpperCase(),
                    isBold: true),
                if (createdAt != null)
                  _buildDetailRow(
                      theme, 'Requested', _formatTimeAgo(createdAt)),
              ],
            ),
          ),

          // Action buttons (only for pending)
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectRequest(approval['id']),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _approveRequest(approval['id']),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 50 * 0));
  }

  Widget _buildDetailRow(ThemeData theme, String label, String value,
      {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          Text(value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                color: valueColor ?? theme.colorScheme.onSurface,
              )),
        ],
      ),
    );
  }

  Future<void> _approveRequest(String approvalId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      final repo = SavingsRepository(
          ref.read(supabaseClientProvider), user.orgId!);
      await repo.processWithdrawalApproval(
        approvalId: approvalId,
        reviewedById: user.id,
        approve: true,
      );

      if (!mounted) return;
      setState(() {});
      messenger.showSnackBar(SnackBar(
        content: const Text('Withdrawal approved'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Future<void> _rejectRequest(String approvalId) async {
    final reasonController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
            24, 12, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Rejection Reason',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Enter reason for rejection...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, reasonController.text),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Reject Request',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );

    if (result == null || result.isEmpty) return;

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      final repo = SavingsRepository(
          ref.read(supabaseClientProvider), user.orgId!);
      await repo.processWithdrawalApproval(
        approvalId: approvalId,
        reviewedById: user.id,
        approve: false,
        rejectionReason: result,
      );

      if (!mounted) return;
      setState(() {});
      messenger.showSnackBar(SnackBar(
        content: const Text('Withdrawal rejected'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM yyyy').format(dt);
  }

  double? _extractDouble(String text, String key) {
    final regex = RegExp('$key:\\s*([\\d.]+)');
    final match = regex.firstMatch(text);
    return match != null ? double.tryParse(match.group(1)!) : null;
  }

  String? _extractString(String text, String key) {
    final regex = RegExp('$key:\\s*([^,}]+)');
    final match = regex.firstMatch(text);
    return match?.group(1)?.trim();
  }
}
