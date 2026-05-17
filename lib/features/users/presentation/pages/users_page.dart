import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../loans/presentation/providers/loan_providers.dart';
import '../providers/user_list_provider.dart';
import '../../../../core/services/haptic_service.dart';

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  String _searchQuery = '';
  UserRole? _filterRole;
  final Set<String> _selectedUsers = {};
  bool _isSelectionMode = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final canCreate = currentUser?.role == UserRole.executiveAdmin ||
        currentUser?.role == UserRole.manager;

    final usersAsync = ref.watch(userListProvider);
    final statsAsync = ref.watch(userStatsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: _isSelectionMode
          ? null
          : (canCreate
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    await context.push('/users/new');
                    ref.invalidate(userListProvider);
                    ref.invalidate(userStatsProvider);
                  },
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  icon: const Icon(Icons.person_add_alt_1_rounded,
                      size: 22, color: Colors.white),
                  label: const Text('Add User',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: -0.3,
                          color: Colors.white)),
                ).animate().scale(
                  delay: 500.ms, duration: 400.ms, curve: Curves.easeOutBack)
              : null),
      body: Stack(
        children: [
          const _AuroraBackground(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(userListProvider);
                ref.invalidate(userStatsProvider);
              },
              displacement: 20,
              color: primary,
              backgroundColor: theme.cardColor,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  _buildSliverAppBar(theme, isDark),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          _buildHeader(theme),
                          const SizedBox(height: 28),
                          _buildStatsCarousel(
                              statsAsync, theme, isDark, primary),
                          const SizedBox(height: 32),
                          _buildSearchAndFilters(theme, primary),
                          const SizedBox(height: 16),
                          _buildRoleFilterChips(theme, primary),
                          const SizedBox(height: 24),
                          // Debug banner
                          _buildDebugBanner(usersAsync, theme),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  usersAsync.when(
                    data: (users) {
                      final filteredUsers = users.where((u) {
                        final matchesSearch = u.fullName
                                ?.toLowerCase()
                                .contains(_searchQuery.toLowerCase()) ??
                            true;
                        final matchesRole =
                            _filterRole == null || u.role == _filterRole;
                        return matchesSearch && matchesRole;
                      }).toList();

                      if (filteredUsers.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyState(theme),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final user = filteredUsers[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _UserListItem(
                                  user: user,
                                  isSelectionMode: _isSelectionMode,
                                  isSelected: _selectedUsers.contains(user.id),
                                  onLongPress: () {
                                    if (currentUser?.role !=
                                        UserRole.executiveAdmin) {
                                      return;
                                    }
                                    HapticService.medium();
                                    setState(() {
                                      _isSelectionMode = true;
                                      _selectedUsers.add(user.id);
                                    });
                                  },
                                  onTap: () {
                                    HapticService.selection();
                                    if (_isSelectionMode) {
                                      setState(() {
                                        if (_selectedUsers.contains(user.id)) {
                                          _selectedUsers.remove(user.id);
                                          if (_selectedUsers.isEmpty) {
                                            _isSelectionMode = false;
                                          }
                                        } else {
                                          _selectedUsers.add(user.id);
                                        }
                                      });
                                    } else {
                                      context.push('/users/${user.id}');
                                    }
                                  },
                                )
                                    .animate()
                                    .fadeIn(
                                        duration: 400.ms,
                                        delay: (index * 30).ms)
                                    .slideY(
                                        begin: 0.1,
                                        end: 0,
                                        curve: Curves.easeOutQuad),
                              );
                            },
                            childCount: filteredUsers.length,
                          ),
                        ),
                      );
                    },
                    loading: () => const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator())),
                    error: (e, __) => SliverFillRemaining(
                        child: Center(child: Text('Error: $e'))),
                  ),
                ],
              ),
            ),
          ),
          if (_isSelectionMode) _buildSelectionActions(theme, primary),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(ThemeData theme, bool isDark) {
    return SliverAppBar(
      expandedHeight: 0,
      collapsedHeight: 64,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
        ),
      ),
      leading: _isSelectionMode
          ? IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() {
                _isSelectionMode = false;
                _selectedUsers.clear();
              }),
            )
          : null,
      title: _isSelectionMode
          ? Text('${_selectedUsers.length} Selected',
              style: const TextStyle(fontWeight: FontWeight.w900))
          : null,
      actions: [
        if (!_isSelectionMode)
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 22),
            onPressed: () {
              // Advanced Sort/Filter
            },
          ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMMAND CENTER',
          style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontSize: 10,
              color: theme.colorScheme.primary),
        ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0),
        const SizedBox(height: 4),
        Text(
          'User Hub',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
            fontSize: 34,
          ),
        ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.05, end: 0),
      ],
    );
  }

  Widget _buildStatsCarousel(
      AsyncValue statsAsync, ThemeData theme, bool isDark, Color primary) {
    return statsAsync
        .when(
          data: (stats) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _StatCard(
                  label: 'Total',
                  value: stats['total'].toString(),
                  icon: Icons.people_rounded,
                  color: primary,
                  isSelected: _filterRole == null,
                  onTap: () => setState(() => _filterRole = null),
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Admins',
                  value: stats['admins'].toString(),
                  icon: Icons.shield_rounded,
                  color: isDark ? AppColors.accentDark : AppColors.accent,
                  isSelected: _filterRole == UserRole.executiveAdmin,
                  onTap: () =>
                      setState(() => _filterRole = UserRole.executiveAdmin),
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Managers',
                  value: stats['managers'].toString(),
                  icon: Icons.manage_accounts_rounded,
                  color: theme.colorScheme.secondary,
                  isSelected: _filterRole == UserRole.manager,
                  onTap: () => setState(() => _filterRole = UserRole.manager),
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Staff',
                  value: stats['staff'].toString(),
                  icon: Icons.support_agent_rounded,
                  color: isDark ? AppColors.warningDark : AppColors.orange,
                  isSelected: _filterRole == UserRole.collectionAgent,
                  onTap: () =>
                      setState(() => _filterRole = UserRole.collectionAgent),
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Members',
                  value: stats['members'].toString(),
                  icon: Icons.groups_rounded,
                  color: isDark ? AppColors.successDark : AppColors.success,
                  isSelected: _filterRole == UserRole.customer,
                  onTap: () => setState(() => _filterRole = UserRole.customer),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
          loading: () => const SizedBox(
              height: 100, child: Center(child: CircularProgressIndicator())),
          error: (_, __) => const Text('Error loading stats'),
        )
        .animate()
        .fadeIn(delay: 200.ms)
        .slideY(begin: 0.1, end: 0);
  }

  Widget _buildSearchAndFilters(ThemeData theme, Color primary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded,
              size: 22, color: theme.textTheme.bodySmall?.color),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search by name, phone or ID...',
                hintStyle: theme.textTheme.bodySmall?.copyWith(fontSize: 15),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => setState(() => _searchQuery = ''),
            ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildRoleFilterChips(ThemeData theme, Color primary) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'All Roles',
            isSelected: _filterRole == null,
            onTap: () {
              HapticService.selection();
              setState(() => _filterRole = null);
            },
            primary: primary,
          ),
          const SizedBox(width: 8),
          ...UserRole.values.map((role) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterChip(
                  label: role.name[0].toUpperCase() + role.name.substring(1),
                  isSelected: _filterRole == role,
                  onTap: () {
                    HapticService.selection();
                    setState(() => _filterRole = role);
                  },
                  primary: primary,
                ),
              )),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildSelectionActions(ThemeData theme, Color primary) {
    return Positioned(
      left: 24,
      right: 24,
      bottom: 32,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 24,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _SelectionAction(
                icon: Icons.message_rounded, label: 'Notify', onTap: () {}),
            _SelectionAction(
                icon: Icons.delete_rounded,
                label: 'Delete',
                onTap: () => _showDeleteConfirmation(theme),
                color: Colors.red),
            _SelectionAction(
                icon: Icons.verified_user_rounded,
                label: 'Verify',
                onTap: () {},
                color: AppColors.success),
            _SelectionAction(
                icon: Icons.ios_share_rounded, label: 'Export', onTap: () {}),
          ],
        ),
      ),
    ).animate().slideY(begin: 1, end: 0, curve: Curves.easeOutBack);
  }

  void _showDeleteConfirmation(ThemeData theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Users'),
        content: Text(
            'Are you sure you want to delete ${_selectedUsers.length} user(s)? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              HapticService.heavy();
              Navigator.pop(ctx);
              await ref
                  .read(userListNotifierProvider.notifier)
                  .deleteUsers(_selectedUsers.toList());
              ref.invalidate(userListProvider);
              ref.invalidate(userStatsProvider);
              setState(() {
                _selectedUsers.clear();
                _isSelectionMode = false;
              });
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_rounded,
              size: 64,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.2)),
          const SizedBox(height: 20),
          Text('No matching users found',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Try adjusting your search or filters.',
              style: theme.textTheme.bodySmall),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildDebugBanner(
      AsyncValue<List<ProfileModel>> usersAsync, ThemeData theme) {
    return usersAsync.when(
      data: (users) {
        final customerCount =
            users.where((u) => u.role == UserRole.customer).length;
        final profileCount = users.where((u) => u.userId != null).length;
        final memberCount = users.where((u) => u.userId == null).length;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bug_report_rounded,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('DEBUG: User Data',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                        fontSize: 12,
                      )),
                ],
              ),
              const SizedBox(height: 8),
              Text('Total fetched: ${users.length}',
                  style: theme.textTheme.bodySmall),
              Text('• Profiles (with auth): $profileCount',
                  style: theme.textTheme.bodySmall),
              Text('• Members (no auth): $memberCount',
                  style: theme.textTheme.bodySmall),
              Text('• Customers: $customerCount',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: customerCount == 0
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  )),
              if (users.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('First user role: ${users.first.role?.name ?? "null"}',
                    style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('Error: $e',
            style: TextStyle(
              color: theme.colorScheme.error,
              fontSize: 12,
            )),
      ),
    );
  }
}

class _UserListItem extends ConsumerWidget {
  final ProfileModel user;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _UserListItem({
    required this.user,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final loansAsync = ref.watch(userLoansProvider(user.id));

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            borderColor: isSelected ? primary : null,
            child: Row(
              children: [
                Hero(
                  tag: 'user_avatar_${user.id}',
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          primary.withValues(alpha: 0.8),
                          primary.withValues(alpha: 0.4)
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            user.fullName?[0].toUpperCase() ?? '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18),
                          ),
                        ),
                        if (user.role == UserRole.customer)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: theme.scaffoldBackgroundColor,
                                    width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName ?? 'Unknown User',
                        style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w900, letterSpacing: -0.2),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.phone_rounded,
                              size: 10,
                              color: theme.textTheme.bodySmall?.color),
                          const SizedBox(width: 4),
                          Text(
                            user.phone ?? 'No contact',
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      loansAsync.when(
                        data: (loans) {
                          final active = loans
                              .where((l) => l.status == LoanStatus.active)
                              .length;
                          if (active == 0) return const SizedBox.shrink();
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$active ACTIVE LOANS',
                              style: const TextStyle(
                                  color: AppColors.orange,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900),
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                if (!isSelectionMode)
                  Row(
                    children: [
                      _buildQuickAction(Icons.call_rounded,
                          () => _launchCaller(user.phone), theme),
                      const SizedBox(width: 8),
                      _buildQuickAction(Icons.chat_bubble_rounded,
                          () => _launchWhatsApp(user.phone), theme),
                    ],
                  )
                else
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => onTap(),
                    shape: const CircleBorder(),
                    activeColor: primary,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, VoidCallback onTap, ThemeData theme) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: theme.colorScheme.primary),
      ),
    );
  }

  void _launchCaller(String? phone) async {
    if (phone == null) return;
    final Uri url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  void _launchWhatsApp(String? phone) async {
    if (phone == null) return;
    final Uri url = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color primary;

  const _FilterChip(
      {required this.label,
      required this.isSelected,
      required this.onTap,
      required this.primary});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? primary : primary.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : primary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SelectionAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _SelectionAction(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    final primary = color ?? Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: primary),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: primary, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: 300.ms,
        width: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.3)
                  : Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 12),
            Text(value,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900, fontSize: 20)),
            Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontSize: 10, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _AuroraBackground extends StatelessWidget {
  const _AuroraBackground();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Stack(
      children: [
        Positioned(
          top: -150,
          right: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary.withValues(alpha: 0.05),
            ),
          ),
        ).animate(onPlay: (c) => c.repeat()).moveY(
            begin: 0, end: 50, duration: 8.seconds, curve: Curves.easeInOut),
        Positioned(
          bottom: -100,
          left: -50,
          child: Container(
            width: 350,
            height: 350,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success.withValues(alpha: 0.03),
            ),
          ),
        ).animate(onPlay: (c) => c.repeat()).moveY(
            begin: 0, end: -30, duration: 7.seconds, curve: Curves.easeInOut),
      ],
    );
  }
}
