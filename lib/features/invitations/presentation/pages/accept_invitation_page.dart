import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/providers/invitation_providers.dart';
import '../data/models/org_invitation_model.dart';

class AcceptInvitationPage extends ConsumerStatefulWidget {
  final String token;

  const AcceptInvitationPage({super.key, required this.token});

  @override
  ConsumerState<AcceptInvitationPage> createState() => _AcceptInvitationPageState();
}

class _AcceptInvitationPageState extends ConsumerState<AcceptInvitationPage> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final invitationAsync = ref.watch(invitationByTokenProvider(widget.token));

    return Scaffold(
      body: invitationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(error: e.toString()),
        data: (invitation) {
          if (invitation == null) {
            return const _ErrorState(error: 'Invitation not found');
          }

          if (!invitation.isPending || invitation.isExpired) {
            return _InvalidInvitation(invitation: invitation);
          }

          return _InvitationForm(
            invitation: invitation,
            nameController: _nameController,
            passwordController: _passwordController,
            obscurePassword: _obscurePassword,
            isLoading: _isLoading,
            onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
            onAccept: _acceptInvitation,
          );
        },
      ),
    );
  }

  Future<void> _acceptInvitation() async {
    setState(() => _isLoading = true);

    final notifier = ref.read(invitationNotifierProvider.notifier);
    final result = await notifier.acceptInvitation(
      token: widget.token,
      fullName: _nameController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (result != null && mounted) {
      final action = result['action'] as String?;
      if (action == 'signup') {
        // User needs to sign up
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign up to complete invitation')),
        );
        context.go('/auth');
      } else if (action == 'login') {
        // User already exists, logged in
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation accepted! Welcome to the team.'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/');
      } else if (result['error'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] as String),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _InvitationForm extends StatelessWidget {
  final OrgInvitationModel invitation;
  final TextEditingController nameController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isLoading;
  final VoidCallback onTogglePassword;
  final VoidCallback onAccept;

  const _InvitationForm({
    required this.invitation,
    required this.nameController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isLoading,
    required this.onTogglePassword,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Icon(
                  Icons.business,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  'You\'re Invited!',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Join ${invitation.orgId} as ${invitation.roleDisplay}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Invitation details card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.email, color: Colors.grey[600], size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                invitation.email,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Icon(Icons.badge, color: Colors.grey[600], size: 20),
                            const SizedBox(width: 12),
                            Text(
                              'Role: ${invitation.roleDisplay}',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        if (invitation.personalMessage != null) ...[
                          const Divider(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.message, color: Colors.grey[600], size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  invitation.personalMessage!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Name input (for new users)
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Password input (for new users)
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Create Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: onTogglePassword,
                      icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                // Accept button
                ElevatedButton(
                  onPressed: isLoading ? null : onAccept,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Accept Invitation'),
                ),
                const SizedBox(height: 16),

                // Already have account
                TextButton(
                  onPressed: () => context.go('/auth'),
                  child: const Text('Already have an account? Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;

  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Invalid Invitation',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/auth'),
              child: const Text('Go to Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvalidInvitation extends StatelessWidget {
  final OrgInvitationModel invitation;

  const _InvalidInvitation({required this.invitation});

  @override
  Widget build(BuildContext context) {
    final message = invitation.isAccepted
        ? 'This invitation has already been accepted.'
        : invitation.isRevoked
            ? 'This invitation has been revoked.'
            : 'This invitation has expired.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              invitation.isAccepted ? Icons.check_circle : Icons.cancel,
              size: 64,
              color: invitation.isAccepted ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              invitation.isAccepted ? 'Already Accepted' : 'Invitation Invalid',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/auth'),
              child: const Text('Go to Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}
