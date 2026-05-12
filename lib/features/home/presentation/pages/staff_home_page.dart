import '../../../../core/widgets/shimmer_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/services/offline_queue_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../loans/presentation/providers/loan_providers.dart'
    hide loansRepositoryProvider;
import '../../../loans/presentation/widgets/collection_sheet.dart';

import '../../../loans/data/models/emi_schedule_model.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../providers/staff_providers.dart';
import '../../../savings/data/providers/savings_providers.dart';

class StaffHomePage extends ConsumerWidget {
  const StaffHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(staffTodaysDuesProvider);
          ref.invalidate(staffTodayStatsProvider);
          ref.invalidate(staffRecentActivityProvider);
          ref.invalidate(offlineQueueCountProvider);
          ref.invalidate(staffWalletProvider);
        },
        displacement: 20,
        color: theme.colorScheme.primary,
        backgroundColor: theme.cardColor,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, ref),
              const SizedBox(height: 24),
              _buildWalletCard(context, ref),
              const SizedBox(height: 24),
              _buildMissionCard(context, ref),
              const SizedBox(height: 24),
              _buildDueList(context, ref),
              const SizedBox(height: 24),
              _buildQuickActions(context, ref),
              const SizedBox(height: 24),
              _buildRecentActivity(context, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletCard(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final walletAsync = ref.watch(staffWalletProvider);
    final isDark = theme.brightness == Brightness.dark;

    return walletAsync.when(
      data: (wallet) => GlassCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cash in Hand',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodySmall?.color
                          ?.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    AppFormatters.formatCurrency(wallet.cashInHand),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'SAFE',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Branch limit: ₹50k',
                  style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
                ),
              ],
            ),
          ],
        ),
      ),
      loading: () => ShimmerCard(height: 90),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final now = DateTime.now();
    final hour = now.hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    final queueAsync = ref.watch(offlineQueueCountProvider);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color:
                      theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?.fullName ?? 'Agent',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (queueAsync.valueOrNull != null && queueAsync.valueOrNull! > 0)
          GestureDetector(
            onTap: () => _showOfflineQueue(context, ref),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.orange.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.offline_bolt_rounded,
                      size: 16, color: AppColors.orange),
                  const SizedBox(width: 6),
                  Text(
                    '${queueAsync.valueOrNull} pending',
                    style: TextStyle(
                      color: AppColors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(width: 12),
        _buildGPSStatusChip(context),
      ],
    );
  }

  Widget _buildGPSStatusChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'GPS ACTIVE',
            style: TextStyle(
              color: AppColors.success,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionCard(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statsAsync = ref.watch(staffTodayStatsProvider);
    final primary = theme.colorScheme.primary;

    return statsAsync.when(
      data: (stats) {
        return GlassCard(
          elevated: true,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Today\'s Mission',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: stats.progress >= 1
                          ? AppColors.success.withValues(alpha: 0.12)
                          : primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      stats.progress >= 1 ? 'Completed' : 'In Progress',
                      style: TextStyle(
                        color:
                            stats.progress >= 1 ? AppColors.success : primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _MissionStat(
                      label: 'Target',
                      value: AppFormatters.formatCompactCurrency(stats.target),
                      icon: Icons.flag_outlined,
                      color: primary,
                      theme: theme,
                    ),
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: theme.dividerColor.withValues(alpha: 0.2),
                  ),
                  Expanded(
                    child: _MissionStat(
                      label: 'Collected',
                      value:
                          AppFormatters.formatCompactCurrency(stats.collected),
                      icon: Icons.check_circle_outline,
                      color: AppColors.success,
                      theme: theme,
                    ),
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: theme.dividerColor.withValues(alpha: 0.2),
                  ),
                  Expanded(
                    child: _MissionStat(
                      label: 'Remaining',
                      value:
                          AppFormatters.formatCompactCurrency(stats.remaining),
                      icon: Icons.timelapse_outlined,
                      color: AppColors.orange,
                      theme: theme,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: stats.progress,
                  minHeight: 8,
                  backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    stats.progress >= 1 ? AppColors.success : primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${stats.collectedCount} of ${stats.totalDues} dues collected',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
            ],
          ),
        );
      },
      loading: () => ShimmerCard(height: 200),
      error: (_, __) => GlassCard(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text('Unable to load mission data',
              style: theme.textTheme.bodySmall),
        ),
      ),
    );
  }

  Widget _buildDueList(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final duesAsync = ref.watch(staffTodaysDuesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Collection Route',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        duesAsync.when(
          data: (dues) {
            if (dues.isEmpty) {
              return GlassCard(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.done_all_rounded,
                          size: 48,
                          color: theme.textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text('All caught up!',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('No collections due today.',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              );
            }

            final emis = dues.where((d) => d.type == 'emi').toList();
            final savings = dues.where((d) => d.type == 'savings').toList();

            return DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: theme.dividerColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                      unselectedLabelStyle:
                          const TextStyle(fontWeight: FontWeight.w500),
                      indicator: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: theme.textTheme.bodySmall?.color,
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(text: 'EMI Due (${emis.length})'),
                        Tab(text: 'Savings (${savings.length})'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: emis.length > savings.length
                        ? emis.length * 80.0
                        : savings.length * 80.0,
                    child: TabBarView(
                      children: [
                        _buildDueListItems(context, ref, emis),
                        _buildDueListItems(context, ref, savings),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Column(
            children: [
              ShimmerCard(height: 80),
              SizedBox(height: 12),
              ShimmerCard(height: 80),
            ],
          ),
          error: (_, __) => GlassCard(
            padding: const EdgeInsets.all(24),
            child: Center(
              child:
                  Text('Unable to load dues', style: theme.textTheme.bodySmall),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDueListItems(
      BuildContext context, WidgetRef ref, List<StaffDueItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Text('None due', style: Theme.of(context).textTheme.bodySmall),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _DueListTile(
          item: item,
          onCollect: () => _onCollect(context, ref, item),
        );
      },
    );
  }

  void _onCollect(BuildContext context, WidgetRef ref, StaffDueItem item) {
    if (item.type == 'emi') {
      _showEmiCollectionSheet(context, ref, item);
    } else {
      _showSavingsDepositSheet(context, ref, item);
    }
  }

  void _showEmiCollectionSheet(
      BuildContext context, WidgetRef ref, StaffDueItem item) {
    if (item.loanId == null) return;

    // Fetch loan and EMI details, then show collection sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, child) {
            final loanAsync = ref.watch(loanDetailProvider(item.loanId!));
            final emiAsync = ref.watch(emiScheduleProvider(item.loanId!));

            return loanAsync.when(
              data: (loan) {
                if (loan == null) {
                  return _buildErrorSheet(context, 'Loan not found');
                }
                return emiAsync.when(
                  data: (emis) {
                    final emi = emis.firstWhere(
                      (e) => e.id == item.id,
                      orElse: () => emis.isNotEmpty
                          ? emis.firstWhere(
                              (e) => e.emiNumber == item.emiNumber,
                              orElse: () => emis.first,
                            )
                          : EMIScheduleModel(
                              id: item.id,
                              loanId: item.loanId!,
                              emiNumber: item.emiNumber ?? 1,
                              dueDate: item.dueDate ?? DateTime.now(),
                              emiAmount: item.amount,
                              principal: 0,
                              interest: 0,
                              balanceAfter: 0,
                              status: EMIStatus.upcoming,
                              penaltyAmount: 0,
                              penaltyPaid: false,
                              createdAt: DateTime.now(),
                            ),
                    );
                    return CollectionSheet(loan: loan, emi: emi);
                  },
                  loading: () => _buildLoadingSheet(context),
                  error: (_, __) => _buildErrorSheet(context, 'EMI not found'),
                );
              },
              loading: () => _buildLoadingSheet(context),
              error: (_, __) => _buildErrorSheet(context, 'Loan not found'),
            );
          },
        );
      },
    );
  }

  void _showSavingsDepositSheet(
      BuildContext context, WidgetRef ref, StaffDueItem item) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final amountController = TextEditingController(
      text: item.amount > 0 ? item.amount.toStringAsFixed(0) : '',
    );
    String selectedPaymentMode = 'Cash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 20,
                right: 20,
                top: 24,
              ),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 40,
                    spreadRadius: 10,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.savings_rounded,
                            color: AppColors.success),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Record Deposit',
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            Text(
                              '${item.memberName} \u2022 ${item.planName ?? 'Regular Savings'}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildLabel('DEPOSIT AMOUNT', theme),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w900, color: primary),
                    decoration: InputDecoration(
                      prefixText: '\u20B9 ',
                      prefixStyle: theme.textTheme.headlineSmall?.copyWith(
                          color: primary, fontWeight: FontWeight.w900),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      contentPadding: const EdgeInsets.all(20),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Amount Presets
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [100, 500, 1000, 2000, 5000].map((amt) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text('\u20B9$amt'),
                            onPressed: () {
                              amountController.text = amt.toString();
                              HapticFeedback.selectionClick();
                            },
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            backgroundColor: primary.withValues(alpha: 0.05),
                            side: BorderSide.none,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildLabel('PAYMENT MODE', theme),
                  const SizedBox(height: 12),
                  Row(
                    children: ['Cash', 'UPI', 'Bank Transfer'].map((mode) {
                      final isSelected = selectedPaymentMode == mode;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: () {
                              setState(() => selectedPaymentMode = mode);
                              HapticFeedback.lightImpact();
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primary
                                    : theme.colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      isSelected ? primary : Colors.transparent,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  mode,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : theme.colorScheme.onSurface,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final amount =
                                  double.tryParse(amountController.text) ?? 0;
                              if (amount <= 0) return;

                              setState(
                                  () => isSubmitting = true); // Visual only

                              try {
                                final repo =
                                    ref.read(savingsRepositoryProvider);
                                await repo.recordDeposit(
                                  item.savingsId!,
                                  amount,
                                );
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  _showSuccessFeedback(
                                      context,
                                      'Deposit Recorded',
                                      '₹$amount received via $selectedPaymentMode');
                                }
                                ref.invalidate(staffTodaysDuesProvider);
                                ref.invalidate(staffTodayStatsProvider);
                                ref.invalidate(staffRecentActivityProvider);
                              } catch (e) {
                                // Offline fallback
                                final queue = OfflineQueueService();
                                await queue.enqueueTransaction({
                                  'type': 'savingsDeposit',
                                  'savings_id': item.savingsId,
                                  'amount': amount,
                                  'payment_mode': selectedPaymentMode,
                                  'member_name': item.memberName,
                                  'timestamp': DateTime.now().toIso8601String(),
                                });
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  _showSuccessFeedback(context, 'Saved Offline',
                                      'Will sync automatically when online.');
                                }
                                ref.invalidate(offlineQueueCountProvider);
                              }
                              if (context.mounted) {
                                setState(() => isSubmitting = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        elevation: 8,
                        shadowColor: AppColors.success.withValues(alpha: 0.4),
                      ),
                      child: isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_outline_rounded),
                                const SizedBox(width: 12),
                                Text(
                                    'Confirm \u20B9${amountController.text} Deposit',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18)),
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

  void _showSuccessFeedback(
      BuildContext context, String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(message, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildLabel(String label, ThemeData theme) {
    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildLoadingSheet(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorSheet(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Center(child: Text(message)),
    );
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.person_add_rounded,
                label: 'Onboard',
                color: AppColors.success,
                onTap: () => context.push('/members/onboarding'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.payments_rounded,
                label: 'Collection',
                color: AppColors.primary,
                onTap: () => context.push('/loans'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.account_balance_rounded,
                label: 'My Vault',
                color: AppColors.orange,
                onTap: () => _showVaultDetails(context, ref),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showVaultDetails(BuildContext context, WidgetRef ref) {
    // Show a bottom sheet with cash denomination tracking or deposit QR
    final theme = Theme.of(context);
    final wallet = ref.read(staffWalletProvider).valueOrNull;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Text('Cash Vault', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 32),
            _buildVaultInfoRow('Cash in Hand', AppFormatters.formatCurrency(wallet?.cashInHand ?? 0), AppColors.success, theme),
            const SizedBox(height: 16),
            _buildVaultInfoRow('Digital Today', AppFormatters.formatCurrency(wallet?.totalDigitalCollected ?? 0), AppColors.primary, theme),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),
            const Text('Handover to Branch', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text('Generate this QR for the Branch Manager to scan and confirm your cash deposit.', 
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6))),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.qr_code_2_rounded, size: 200, color: Colors.black.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('DONE'),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildVaultInfoRow(String label, String value, Color color, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }

  Widget _buildRecentActivity(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activityAsync = ref.watch(staffRecentActivityProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            GestureDetector(
              onTap: () => context.push('/transactions'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'View All',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.orange,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        activityAsync.when(
          data: (transactions) {
            if (transactions.isEmpty) {
              return GlassCard(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text('No activity yet today',
                      style: theme.textTheme.bodySmall),
                ),
              );
            }
            return Column(
              children: transactions.take(5).map((t) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TransactionListTile(transaction: t, theme: theme),
                );
              }).toList(),
            );
          },
          loading: () => Column(
            children: [
              ShimmerCard(height: 60),
              SizedBox(width: 8),
              ShimmerCard(height: 60),
            ],
          ),
          error: (_, __) => GlassCard(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text('Unable to load activity',
                  style: theme.textTheme.bodySmall),
            ),
          ),
        ),
      ],
    );
  }

  void _showOfflineQueue(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Offline Queue',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Text('Pending transactions will sync automatically.',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MissionStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final ThemeData theme;

  const _MissionStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(value,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(fontSize: 10)),
      ],
    );
  }
}

class _DueListTile extends StatelessWidget {
  final StaffDueItem item;
  final VoidCallback onCollect;

  const _DueListTile({required this.item, required this.onCollect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmi = item.type == 'emi';
    final color = isEmi ? AppColors.primary : AppColors.success;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.15),
                  color.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isEmi ? Icons.account_balance_outlined : Icons.savings_outlined,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.memberName,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isEmi
                      ? 'Loan ${item.loanNumber ?? ''} \u2022 EMI #${item.emiNumber ?? ''}'
                      : item.planName ?? 'Recurring Deposit',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppFormatters.formatCurrency(item.amount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onCollect,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.9),
                        color.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'COLLECT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.12),
              color.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionListTile extends StatelessWidget {
  final TransactionModel transaction;
  final ThemeData theme;

  const _TransactionListTile({
    required this.transaction,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isDeposit = transaction.type == TransactionType.emiPayment ||
        transaction.type == TransactionType.savingsDeposit;
    final color = isDeposit ? AppColors.success : AppColors.error;
    final icon =
        isDeposit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;

    String title;
    switch (transaction.type) {
      case TransactionType.emiPayment:
        title = 'EMI Payment';
        break;
      case TransactionType.loanDisbursement:
        title = 'Loan Disbursement';
        break;
      case TransactionType.savingsDeposit:
        title = 'Savings Deposit';
        break;
      case TransactionType.savingsWithdrawal:
        title = 'Savings Withdrawal';
        break;
      case TransactionType.penalty:
        title = 'Penalty';
        break;
      default:
        title = transaction.description ?? 'Transaction';
    }

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                transaction.memberName,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
        Text(
          '${isDeposit ? '+' : '-'} ${AppFormatters.formatCompactCurrency(transaction.amount)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
