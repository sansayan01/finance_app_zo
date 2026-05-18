import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/constants/layout.dart';
import '../../data/providers/invitation_providers.dart';
import '../../data/models/org_invitation_model.dart';

class ManageInvitationsPage extends ConsumerWidget {
  const ManageInvitationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final invitationsAsync = ref.watch(orgInvitationsProvider);
    final statsAsync = ref.watch(invitationStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Invitations'),
        actions: [
          IconButton(
            onPressed: () => _showInviteDialog(context, ref),
            icon: const Icon(Icons.person_add),
            tooltip: 'Invite Member',
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats cards
          statsAsync.when(
            loading: () => const SizedBox(
                height: 80, child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const SizedBox.shrink(),
            data: (stats) => _StatsRow(stats: stats),
          ),

          // Invitations list
          Expanded(
            child: invitationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error loading invitations: $e'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(orgInvitationsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (invitations) {
                if (invitations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mail_outline,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No invitations yet',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Invite team members to get started',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _showInviteDialog(context, ref),
                          icon: const Icon(Icons.person_add),
                          label: const Text('Invite Member'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: invitations.length,
                  itemBuilder: (context, index) {
                    final invitation = invitations[index];
                    return _InvitationCard(invitation: invitation);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: kFabSafeAreaPadding,
        child: FloatingActionButton.extended(
          onPressed: () => _showInviteDialog(context, ref),
          icon: const Icon(Icons.person_add),
          label: const Text('Invite'),
        ),
      ),
    );
  }

  void _showInviteDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _InviteMemberSheet(),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Map<String, int> stats;

  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _StatCard(
            label: 'Pending',
            value: stats['pending'] ?? 0,
            color: Colors.orange,
          ),
          const SizedBox(width: 12),
          _StatCard(
            label: 'Accepted',
            value: stats['accepted'] ?? 0,
            color: Colors.green,
          ),
          const SizedBox(width: 12),
          _StatCard(
            label: 'Expired',
            value: stats['expired'] ?? 0,
            color: Colors.grey,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvitationCard extends ConsumerWidget {
  final OrgInvitationModel invitation;

  const _InvitationCard({required this.invitation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation.email,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getRoleColor(invitation.role)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              invitation.roleDisplay,
                              style: TextStyle(
                                fontSize: 12,
                                color: _getRoleColor(invitation.role),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(status: invitation.status),
                        ],
                      ),
                    ],
                  ),
                ),
                if (invitation.isPending) _buildActions(context, ref),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  invitation.isPending
                      ? 'Expires ${dateFormat.format(invitation.expiresAt)}'
                      : invitation.isAccepted
                          ? 'Accepted ${invitation.acceptedAt != null ? dateFormat.format(invitation.acceptedAt!) : ''}'
                          : dateFormat.format(invitation.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _resendInvitation(context, ref),
          icon: const Icon(Icons.refresh, size: 20),
          tooltip: 'Resend',
        ),
        IconButton(
          onPressed: () => _revokeInvitation(context, ref),
          icon: const Icon(Icons.close, size: 20, color: Colors.red),
          tooltip: 'Revoke',
        ),
      ],
    );
  }

  Color _getRoleColor(UserRole role) {
    return switch (role) {
      UserRole.superAdmin => Colors.deepPurple,
      UserRole.executiveAdmin => Colors.purple,
      UserRole.manager => Colors.blue,
      UserRole.collectionAgent => Colors.green,
      UserRole.customer => Colors.orange,
    };
  }

  Future<void> _resendInvitation(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(invitationNotifierProvider.notifier);
    final success = await notifier.resendInvitation(invitation.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Invitation resent!' : 'Failed to resend'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _revokeInvitation(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Invitation?'),
        content: Text('Revoke invitation to ${invitation.email}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final notifier = ref.read(invitationNotifierProvider.notifier);
      await notifier.revokeInvitation(invitation.id);
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, text) = switch (status) {
      'pending' => (Colors.orange, 'Pending'),
      'accepted' => (Colors.green, 'Accepted'),
      'expired' => (Colors.grey, 'Expired'),
      'revoked' => (Colors.red, 'Revoked'),
      _ => (Colors.grey, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _InviteMemberSheet extends ConsumerStatefulWidget {
  const _InviteMemberSheet();

  @override
  ConsumerState<_InviteMemberSheet> createState() => _InviteMemberSheetState();
}

class _InviteMemberSheetState extends ConsumerState<_InviteMemberSheet> {
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  UserRole _selectedRole = UserRole.collectionAgent;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Invite Team Member',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Email
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Role
          DropdownButtonFormField<UserRole>(
            initialValue: _selectedRole,
            decoration: const InputDecoration(
              labelText: 'Role',
              prefixIcon: Icon(Icons.badge_outlined),
              border: OutlineInputBorder(),
            ),
            items: UserRole.values
                .where((r) => r != UserRole.superAdmin)
                .map((role) {
              return DropdownMenuItem(
                value: role,
                child:
                    Text(role.name[0].toUpperCase() + role.name.substring(1)),
              );
            }).toList(),
            onChanged: (value) => setState(
                () => _selectedRole = value ?? UserRole.collectionAgent),
          ),
          const SizedBox(height: 16),

          // Optional message
          TextField(
            controller: _messageController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Personal Message (Optional)',
              prefixIcon: Icon(Icons.message_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // Submit
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendInvitation,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_isLoading ? 'Sending...' : 'Send Invitation'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendInvitation() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an email address')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final notifier = ref.read(invitationNotifierProvider.notifier);
    final invitation = await notifier.createInvitation(
      email: _emailController.text.trim(),
      role: _selectedRole.name,
      message: _messageController.text.trim().isEmpty
          ? null
          : _messageController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (invitation != null && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invitation sent to ${invitation.email}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
