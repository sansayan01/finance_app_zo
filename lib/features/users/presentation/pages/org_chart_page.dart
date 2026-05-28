import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../branches/data/providers/branch_providers.dart';
import '../../../branches/models/branch_model.dart';
import '../providers/new_user_provider.dart';

/// `BranchId` → list of profiles (managers + agents) for that branch.
final _branchTeamProvider =
    FutureProvider.family<List<ProfileModel>, String>((ref, branchId) async {
  final repo = ref.watch(userRepositoryProvider);
  return repo.getProfilesPaginated(
    roles: const {UserRole.manager, UserRole.collectionAgent},
    branchId: branchId,
    limit: 200,
    excludeStatuses: const {AccountStatus.suspended, AccountStatus.inactive},
  );
});

/// Hierarchy: Organization → Branches → (Manager, Collection Agents).
class OrgChartPage extends ConsumerWidget {
  const OrgChartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final branchesAsync = ref.watch(branchesProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 20),
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Organisation Hierarchy',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'Reporting structure across all branches',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      onPressed: () {
                        ref.invalidate(branchesProvider);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: branchesAsync.when(
                  data: (branches) {
                    if (branches.isEmpty) {
                      return _buildEmpty(theme);
                    }
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      children: [
                        _OrgRoot()
                            .animate()
                            .fadeIn(duration: 300.ms)
                            .slideY(begin: 0.05, end: 0),
                        const SizedBox(height: 12),
                        ...branches.asMap().entries.map((entry) {
                          final i = entry.key;
                          final branch = entry.value;
                          return _BranchNode(branch: branch)
                              .animate()
                              .fadeIn(
                                  duration: 300.ms, delay: (60 * (i + 1)).ms)
                              .slideX(begin: 0.04, end: 0);
                        }),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_tree_outlined,
              size: 56,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('No branches yet',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Create a branch to see the hierarchy here.',
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _OrgRoot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.business_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Organisation',
                    style: theme.textTheme.bodySmall?.copyWith(
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      color: AppColors.primary,
                    )),
                Text('Executive Admin',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchNode extends ConsumerStatefulWidget {
  final BranchModel branch;
  const _BranchNode({required this.branch});

  @override
  ConsumerState<_BranchNode> createState() => _BranchNodeState();
}

class _BranchNodeState extends ConsumerState<_BranchNode> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teamAsync = ref.watch(_branchTeamProvider(widget.branch.id));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.location_city_rounded,
                      color: AppColors.accent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.branch.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          )),
                      Text(
                        '${widget.branch.code} · ${widget.branch.city ?? "—"}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            teamAsync.when(
              data: (team) {
                final manager =
                    team.where((p) => p.role == UserRole.manager).toList();
                final agents = team
                    .where((p) => p.role == UserRole.collectionAgent)
                    .toList();
                return Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Column(
                    children: [
                      if (manager.isEmpty)
                        _MissingNode(
                          label: 'Branch Manager',
                          hint: 'No manager assigned',
                        )
                      else
                        ...manager.map((m) => _PersonNode(
                              profile: m,
                              role: 'Branch Manager',
                              color: AppColors.accent,
                              icon: Icons.manage_accounts_rounded,
                            )),
                      ...agents.map((m) => _PersonNode(
                            profile: m,
                            role: 'Collection Agent',
                            color: AppColors.orange,
                            icon: Icons.support_agent_rounded,
                          )),
                      if (agents.isEmpty && manager.isNotEmpty)
                        _MissingNode(
                          label: 'Collection Agents',
                          hint: 'No agents assigned to this branch yet',
                        ),
                    ],
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Error: $e',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.error)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PersonNode extends StatelessWidget {
  final ProfileModel profile;
  final String role;
  final Color color;
  final IconData icon;
  const _PersonNode({
    required this.profile,
    required this.role,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: () => context.push('/users/${profile.id}'),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.fullName ?? 'Unknown',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text(role,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontSize: 11, color: color)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: theme.textTheme.bodySmall?.color),
          ],
        ),
      ),
    );
  }
}

class _MissingNode extends StatelessWidget {
  final String label;
  final String hint;
  const _MissingNode({required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.person_off_outlined,
                size: 16, color: theme.textTheme.bodySmall?.color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text(hint,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
