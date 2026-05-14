import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/providers/branch_manager_providers.dart';

class PendingApprovalsPage extends ConsumerWidget {
  const PendingApprovalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchId = ref.watch(currentUserBranchIdProvider);
    final approvalsAsync = branchId != null
        ? ref.watch(pendingApprovalsProvider(branchId))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Approvals'),
      ),
      body: approvalsAsync == null
          ? const Center(child: Text('No branch assigned'))
          : approvalsAsync.when(
              data: (approvals) => approvals.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                          SizedBox(height: 16),
                          Text('All caught up! No pending approvals.'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: approvals.length,
                      itemBuilder: (context, index) {
                        final approval = approvals[index];
                        return _buildApprovalCard(context, ref, approval)
                            .animate()
                            .fadeIn(duration: 300.ms, delay: Duration(milliseconds: index * 50))
                            .slideY(begin: 0.1, end: 0);
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
    );
  }

  Widget _buildApprovalCard(BuildContext context, WidgetRef ref, Map<String, dynamic> approval) {
    final theme = Theme.of(context);
    final type = approval['type'] as String? ?? 'Unknown';
    final createdAt = DateTime.tryParse(approval['created_at'] ?? '') ?? DateTime.now();
    final requestedBy = approval['requested_by_user']?['name'] ?? 'Unknown';
    final memberName = approval['member']?['name'] ?? 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getTypeColor(type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    type.toUpperCase(),
                    style: TextStyle(
                      color: _getTypeColor(type),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTimeAgo(createdAt),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _getApprovalTitle(type, memberName),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Requested by: $requestedBy',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(context, ref, approval['id']),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveRequest(context, ref, approval['id']),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'loan':
        return Colors.blue;
      case 'withdrawal':
        return Colors.orange;
      case 'kyc':
        return Colors.purple;
      case 'member':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getApprovalTitle(String type, String memberName) {
    switch (type.toLowerCase()) {
      case 'loan':
        return 'New Loan Request - $memberName';
      case 'withdrawal':
        return 'Withdrawal Request - $memberName';
      case 'kyc':
        return 'KYC Verification - $memberName';
      case 'member':
        return 'New Member Registration - $memberName';
      default:
        return 'Approval Request - $memberName';
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _approveRequest(BuildContext context, WidgetRef ref, String approvalId) async {
    final user = ref.read(authProvider).user;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(approvalActionsProvider.notifier).approve(
        approvalId,
        user?.id ?? '',
      );
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Request approved successfully')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showRejectDialog(BuildContext context, WidgetRef ref, String approvalId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason',
            hintText: 'Enter the reason for rejection',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason')),
                );
                return;
              }

              final user = ref.read(authProvider).user;
              try {
                await ref.read(approvalActionsProvider.notifier).reject(
                  approvalId,
                  user?.id ?? '',
                  controller.text,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Request rejected')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}
