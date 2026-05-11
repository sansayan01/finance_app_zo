import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/staff_providers.dart';
import '../../data/providers/collection_providers.dart';
import '../widgets/wallet_card.dart';
import '../widgets/target_progress_ring.dart';
import '../widgets/sync_status_bar.dart';
import '../widgets/gps_status_chip.dart';
import '../widgets/today_agenda_list.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class StaffHomeDashboard extends ConsumerStatefulWidget {
  const StaffHomeDashboard({super.key});

  @override
  ConsumerState<StaffHomeDashboard> createState() => _StaffHomeDashboardState();
}

class _StaffHomeDashboardState extends ConsumerState<StaffHomeDashboard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final profileAsync = ref.watch(staffProfileProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A14) : const Color(0xFFF5F5F5),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(staffProfileProvider);
          ref.invalidate(staffWalletProvider);
          ref.invalidate(staffStreakProvider);
          ref.invalidate(todayTargetProvider);
          ref.invalidate(todayDueEmisProvider);
          ref.invalidate(todayCollectionsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(theme, profileAsync),
              const SizedBox(height: 20),

              // Sync status
              SyncStatusBar(
                status: SyncStatus.synced,
                lastSyncAt: DateTime.now().subtract(const Duration(minutes: 5)),
                onSyncTap: () => _manualSync(),
              ),
              const SizedBox(height: 24),

              // Target progress ring + streak
              _buildTargetSection(theme),
              const SizedBox(height: 24),

              // Wallet card
              _buildWalletSection(theme),
              const SizedBox(height: 24),

              // Today's agenda
              _buildAgendaSection(theme),
              const SizedBox(height: 24),

              // Quick actions
              _buildQuickActions(theme),
              const SizedBox(height: 24),

              // Stats summary
              _buildStatsSummary(theme),
            ],
          ),
        ),
      ),

      // Floating action button for quick collection
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.push('/staff/collections');
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Quick Collect',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, AsyncValue profileAsync) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    return Row(
      children: [
        // Avatar and greeting
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withOpacity(0.8),
                AppColors.primaryDark.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              profileAsync.when(
                data: (profile) => _getInitials(profile?.fullName ?? 'A'),
                loading: () => 'A',
                error: (_, __) => 'A',
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              profileAsync.when(
                data: (profile) => Text(
                  profile?.fullName ?? 'Agent',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                loading: () => Text(
                  'Loading...',
                  style: theme.textTheme.titleMedium,
                ),
                error: (_, __) => Text(
                  'Agent',
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),
        // GPS chip
        const GpsStatusChip(status: GpsStatus.active, accuracy: 15),
      ],
    );
  }

  Widget _buildTargetSection(ThemeData theme) {
    final targetAsync = ref.watch(todayTargetProvider);
    final streakAsync = ref.watch(staffStreakProvider);

    return targetAsync.when(
      data: (target) {
        if (target == null) return const SizedBox.shrink();

        return streakAsync.when(
          data: (streak) => Row(
            children: [
              // Progress ring
              TargetProgressRing(
                target: target,
                streak: streak,
                size: 160,
                onTap: () => context.push('/staff/targets'),
              ),
              const SizedBox(width: 20),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Target',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildStatRow(
                      theme,
                      'Collected',
                      '₹${(target.achievedAmount / 1000).toStringAsFixed(1)}K',
                      Colors.greenAccent,
                    ),
                    const SizedBox(height: 6),
                    _buildStatRow(
                      theme,
                      'Remaining',
                      '₹${(target.remainingAmount / 1000).toStringAsFixed(1)}K',
                      AppColors.primary,
                    ),
                    const SizedBox(height: 6),
                    _buildStatRow(
                      theme,
                      'Collections',
                      '${target.achievedCount}',
                      AppColors.primary,
                    ),
                    if (streak?.hasActiveStreak == true) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.withOpacity(0.8),
                              Colors.deepOrange.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              streak!.streakEmoji,
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${streak.currentStreak} days',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildStatRow(ThemeData theme, String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildWalletSection(ThemeData theme) {
    final walletAsync = ref.watch(staffWalletProvider);

    return walletAsync.when(
      data: (wallet) {
        if (wallet == null) return const SizedBox.shrink();
        return WalletCard(
          wallet: wallet,
          onDeposit: () => _showDepositSheet(wallet.cashInHand),
        );
      },
      loading: () => Container(
        height: 150,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildAgendaSection(ThemeData theme) {
    final emisAsync = ref.watch(todayDueEmisProvider);
    final profileAsync = ref.watch(staffProfileProvider);

    return emisAsync.when(
      data: (emis) {
        return profileAsync.when(
          data: (profile) => TodayAgendaList(
            emis: emis,
            staffId: profile?.id,
            onRefresh: () {
              ref.invalidate(todayDueEmisProvider);
            },
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildQuickActions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.history_rounded,
                label: 'History',
                color: AppColors.primary,
                onTap: () => context.push('/staff/history'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.warning_amber_rounded,
                label: 'Overdue',
                color: Colors.orangeAccent,
                onTap: () => context.push('/staff/overdue'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.map_outlined,
                label: 'Map',
                color: Colors.greenAccent,
                onTap: () => context.push('/staff/map'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                color: Colors.purpleAccent,
                onTap: () => context.push('/staff/profile'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1A1A2E)
              : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSummary(ThemeData theme) {
    final statsAsync = ref.watch(todayCollectionStatsProvider);

    return statsAsync.when(
      data: (stats) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today\'s Summary',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryItem(
                      theme,
                      'Total',
                      '₹${(stats['total_collected'] ?? 0).toStringAsFixed(0)}',
                      AppColors.primary,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: theme.dividerColor.withOpacity(0.2),
                  ),
                  Expanded(
                    child: _buildSummaryItem(
                      theme,
                      'Cash',
                      '₹${(stats['cash_collected'] ?? 0).toStringAsFixed(0)}',
                      Colors.greenAccent,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: theme.dividerColor.withOpacity(0.2),
                  ),
                  Expanded(
                    child: _buildSummaryItem(
                      theme,
                      'Digital',
                      '₹${(stats['digital_collected'] ?? 0).toStringAsFixed(0)}',
                      Colors.purpleAccent,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: theme.dividerColor.withOpacity(0.2),
                  ),
                  Expanded(
                    child: _buildSummaryItem(
                      theme,
                      'Count',
                      '${stats['collection_count'] ?? 0}',
                      Colors.orangeAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        height: 100,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSummaryItem(ThemeData theme, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  void _manualSync() {
    // Force refresh all data
    ref.invalidate(staffProfileProvider);
    ref.invalidate(staffWalletProvider);
    ref.invalidate(todayTargetProvider);
    ref.invalidate(todayDueEmisProvider);
    ref.invalidate(todayCollectionsProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Syncing data...'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showDepositSheet(double cashInHand) {
    final theme = Theme.of(context);
    final amountController = TextEditingController();
    String selectedMode = 'bank';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Deposit to Bank',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Available: ₹${cashInHand.toStringAsFixed(0)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  hintText: '0',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: ['bank', 'upi'].map((mode) {
                  final isSelected = selectedMode == mode;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: mode == 'bank' ? 8 : 0,
                      ),
                      child: GestureDetector(
                        onTap: () => setModalState(() => selectedMode = mode),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              mode.toUpperCase(),
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: isSelected
                                    ? Colors.white
                                    : theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text);
                    if (amount == null || amount <= 0 || amount > cashInHand) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Invalid amount'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Record deposit
                    final profile = await ref.read(staffProfileProvider.future);
                    if (profile != null) {
                      final repo = ref.read(staffRepositoryProvider);
                      await repo.recordDeposit(
                        staffId: profile.id,
                        amount: amount,
                        depositMode: selectedMode,
                      );
                    }

                    if (mounted) {
                      Navigator.pop(ctx);
                      ref.invalidate(staffWalletProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '₹${amount.toStringAsFixed(0)} deposited successfully',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Confirm Deposit',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
