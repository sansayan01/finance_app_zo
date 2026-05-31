import 'dart:io';
import 'dart:ui';
import '../../../../core/utils/file_download.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/payment_mode_chips.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/branding_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/transactions/data/models/transaction_model.dart';
import '../../../../providers/supabase_provider.dart';
import '../../data/models/savings_model.dart';
import '../../data/providers/savings_providers.dart';
import '../../data/services/savings_statement_models.dart';
import '../../data/services/savings_statement_pdf_service.dart';
import '../../data/services/savings_statement_excel_service.dart';
import '../../data/services/savings_statement_csv_service.dart';
import '../../../home/data/providers/dashboard_providers.dart'
    show pendingDepositsProvider, recentTransactionsProvider,
        dashboardTransactionsProvider, todayStatsProvider;

class SavingDetailPage extends ConsumerStatefulWidget {
  final String savingId;
  const SavingDetailPage({super.key, required this.savingId});

  @override
  ConsumerState<SavingDetailPage> createState() => _SavingDetailPageState();
}

class _SavingDetailPageState extends ConsumerState<SavingDetailPage> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0);

  // Dialog state variables (persist across StatefulBuilder rebuilds)
  int _depositInstallmentCount = 1;
  String _depositSelectedMode = 'cash';
  bool _depositIsSubmitting = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      _scrollOffset.value = _scrollController.offset;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final savingAsync = ref.watch(savingDetailProvider(widget.savingId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF2F2F7),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ValueListenableBuilder<double>(
          valueListenable: _scrollOffset,
          builder: (context, offset, _) {
            return savingAsync.when(
              data: (saving) =>
                  saving != null ? _buildAppBar(theme, saving) : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            );
          },
        ),
      ),
      body: savingAsync.when(
        data: (saving) {
          if (saving == null) {
            return const Center(child: Text('Savings Plan Not Found'));
          }
          return AuroraBackground(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(savingDetailProvider(widget.savingId));
                ref.invalidate(savingTransactionsProvider(widget.savingId));
              },
              displacement: 20,
              color: theme.colorScheme.primary,
              backgroundColor: theme.cardColor,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(
                      child: SizedBox(
                          height: MediaQuery.of(context).padding.top + 60)),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildCurrentBalance(saving, theme),
                        const SizedBox(height: 32),
                        _buildVaultCard(saving, theme),
                        const SizedBox(height: 32),
                        _buildPrimaryActionRow(saving, theme),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(40)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.5 : 0.05),
                            blurRadius: 30,
                            offset: const Offset(0, -10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
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
                            const SizedBox(height: 32),
                            _buildSectionHeader('Vault Intelligence', theme),
                            const SizedBox(height: 16),
                            _buildIntelligenceCard(saving, theme),
                            const SizedBox(height: 40),
                            _buildSectionHeader('Yield Projection', theme),
                            const SizedBox(height: 16),
                            _buildYieldChart(saving, theme),
                            const SizedBox(height: 40),
                            _buildSectionHeader('Deposit History', theme),
                            const SizedBox(height: 16),
                            _buildTransactionList(theme),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildYieldChart(SavingsModel saving, ThemeData theme) {
    final totalDays = saving.maturityDate.difference(saving.createdAt).inDays;
    double planDurationMonths = totalDays / 30.0;
    if (planDurationMonths <= 0) planDurationMonths = 12.0;

    double interval = 3.0;
    if (planDurationMonths <= 6) {
      interval = 1.0;
    } else if (planDurationMonths <= 12) {
      interval = 3.0;
    } else if (planDurationMonths <= 24) {
      interval = 6.0;
    } else {
      interval = 12.0;
    }

    final transactionsAsync = ref.watch(savingTransactionsProvider(saving.id));
    final List<FlSpot> currentProgressSpots = [];

    // Start with (0, 0)
    currentProgressSpots.add(const FlSpot(0, 0));

    transactionsAsync.maybeWhen(
      data: (txList) {
        if (txList.isNotEmpty) {
          // Sort transactions by date ascending
          final sortedTxs = List<TransactionModel>.from(txList)
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

          double accumulated = 0;
          for (final tx in sortedTxs) {
            final days = tx.createdAt.difference(saving.createdAt).inDays;
            double monthFraction = days / 30.0;
            if (monthFraction < 0) monthFraction = 0;
            if (monthFraction > planDurationMonths) monthFraction = planDurationMonths;

            if (tx.type == TransactionType.savingsWithdrawal) {
              accumulated -= tx.amount;
            } else {
              accumulated += tx.amount;
            }
            if (accumulated < 0) accumulated = 0;

            currentProgressSpots.add(FlSpot(monthFraction, accumulated));
          }

          // Make sure the line extends to the current date/balance
          final currentDays = DateTime.now().difference(saving.createdAt).inDays;
          double currentMonthFraction = currentDays / 30.0;
          if (currentMonthFraction < 0) currentMonthFraction = 0;
          if (currentMonthFraction > planDurationMonths) currentMonthFraction = planDurationMonths;

          if (currentProgressSpots.last.x < currentMonthFraction) {
            currentProgressSpots.add(FlSpot(currentMonthFraction, saving.currentAmount));
          }
        } else {
          // Fallback to basic line if no transaction records are found
          final currentDays = DateTime.now().difference(saving.createdAt).inDays;
          double currentMonthFraction = currentDays / 30.0;
          if (currentMonthFraction < 0) currentMonthFraction = 0;
          if (currentMonthFraction > planDurationMonths) currentMonthFraction = planDurationMonths;
          if (currentMonthFraction == 0) currentMonthFraction = 0.5;

          currentProgressSpots.add(FlSpot(currentMonthFraction, saving.currentAmount));
        }
      },
      orElse: () {
        // Fallback when loading/error
        final currentDays = DateTime.now().difference(saving.createdAt).inDays;
        double currentMonthFraction = currentDays / 30.0;
        if (currentMonthFraction < 0) currentMonthFraction = 0;
        if (currentMonthFraction > planDurationMonths) currentMonthFraction = planDurationMonths;
        if (currentMonthFraction == 0) currentMonthFraction = 0.5;

        currentProgressSpots.add(FlSpot(currentMonthFraction, saving.currentAmount));
      },
    );

    return Container(
      height: 260,
      padding: const EdgeInsets.only(top: 32, right: 24, left: 16, bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: planDurationMonths,
          minY: 0,
          maxY: saving.targetAmount * 1.2,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => theme.cardColor,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    'M${spot.x.toStringAsFixed(1)}: ${AppFormatters.formatCurrency(spot.y)}',
                    theme.textTheme.bodySmall!.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval:
                saving.targetAmount > 0 ? (saving.targetAmount / 4) : 1000,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: theme.dividerColor.withValues(alpha: 0.5),
                strokeWidth: 1,
                dashArray: [5, 5],
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value % interval != 0 && value != planDurationMonths.toInt()) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('M${value.toInt()}',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.4))),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Text(AppFormatters.formatCompactCurrency(value),
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4)));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            // Target Line (Straight)
            LineChartBarData(
              spots: [
                const FlSpot(0, 0),
                FlSpot(planDurationMonths, saving.targetAmount),
              ],
              isCurved: false,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              barWidth: 2,
              dashArray: [5, 5],
              dotData: const FlDotData(show: false),
            ),
            // Current Progress Line (Curved)
            LineChartBarData(
              spots: currentProgressSpots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: AppColors.success,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final isLast = index == currentProgressSpots.length - 1;
                  return FlDotCirclePainter(
                    radius: isLast ? 5 : 3,
                    color: AppColors.success,
                    strokeWidth: 2,
                    strokeColor: theme.scaffoldBackgroundColor,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.success.withValues(alpha: 0.3),
                    AppColors.success.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1);
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, SavingsModel saving) {
    final blurAlpha = (_scrollOffset.value / 100).clamp(0.0, 1.0);
    final isPaused = saving.status.toLowerCase() == 'paused';
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        child: BackdropFilter(
          filter:
              ImageFilter.blur(sigmaX: 15 * blurAlpha, sigmaY: 15 * blurAlpha),
          child: AppBar(
            backgroundColor: theme.scaffoldBackgroundColor
                .withValues(alpha: 0.7 * blurAlpha),
            elevation: 0,
            titleSpacing: 0,
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    saving.planName.isNotEmpty
                        ? saving.planName
                        : 'Savings Vault',
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(saving.status, theme),
              ],
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.description_rounded),
                tooltip: 'Statement',
                onPressed: () => _generateStatement(saving),
              ),
              IconButton(
                icon: const Icon(Icons.ios_share_rounded),
                tooltip: 'Share vault summary',
                onPressed: () => _shareVaultSummary(saving),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      context.push('/savings/${saving.id}/edit');
                      break;
                    case 'pause':
                      _setStatus(saving, 'paused');
                      break;
                    case 'resume':
                      _setStatus(saving, 'active');
                      break;
                    case 'share':
                      _shareVaultSummary(saving);
                      break;
                    case 'delete':
                      _showDeleteDialog();
                      break;
                    case 'delete_permanent':
                      _showHardDeleteDialog();
                      break;
                  }
                },
                itemBuilder: (context) {
                  final isExecAdmin = ref.read(currentUserProvider)?.role ==
                      UserRole.executiveAdmin;
                  return [
                    const PopupMenuItem(value: 'edit', child: Text('Edit Vault')),
                    PopupMenuItem(
                      value: isPaused ? 'resume' : 'pause',
                      child: Row(
                        children: [
                          Icon(
                            isPaused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(isPaused ? 'Resume Vault' : 'Pause Vault'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.ios_share_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Share Summary'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Text('Close Account',
                            style: TextStyle(color: Colors.red))),
                    if (isExecAdmin)
                      const PopupMenuItem(
                        value: 'delete_permanent',
                        child: Row(
                          children: [
                            Icon(Icons.delete_forever_rounded,
                                size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete Permanently',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, ThemeData theme) {
    final s = status.toLowerCase();
    late final Color color;
    late final String label;
    switch (s) {
      case 'paused':
        color = Colors.orange;
        label = 'PAUSED';
        break;
      case 'matured':
      case 'completed':
        color = theme.colorScheme.primary;
        label = 'MATURED';
        break;
      case 'closed':
      case 'cancelled':
      case 'withdrawn':
        color = Colors.red;
        label = 'CLOSED';
        break;
      case 'active':
      default:
        color = AppColors.success;
        label = 'ACTIVE';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
          color: color,
        ),
      ),
    );
  }

  Future<void> _setStatus(SavingsModel saving, String newStatus) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(savingsRepositoryProvider)
          .setSavingStatus(saving.id, newStatus);
      if (!mounted) return;
      ref.invalidate(savingDetailProvider(saving.id));
      ref.invalidate(allSavingsProvider);
      ref.invalidate(savingsSummaryProvider);
      ref.invalidate(pendingDepositsProvider);
      HapticFeedback.lightImpact();
      messenger.showSnackBar(
        SnackBar(
          content: Text(newStatus == 'paused'
              ? 'Vault paused. Contributions are on hold.'
              : 'Vault resumed.'),
          backgroundColor:
              newStatus == 'paused' ? Colors.orange : AppColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _shareVaultSummary(SavingsModel saving) {
    final progress =
        (saving.currentAmount / saving.targetAmount * 100).clamp(0, 100);
    final daysLeft = saving.maturityDate.difference(DateTime.now()).inDays;
    final buffer = StringBuffer()
      ..writeln('🏦 Savings Vault Summary')
      ..writeln('━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('Plan: ${saving.planName}')
      ..writeln('Member: ${saving.memberName}')
      ..writeln('Status: ${_capitalize(saving.status)}')
      ..writeln('')
      ..writeln(
          '💰 Current Balance : ${AppFormatters.formatCurrency(saving.currentAmount)}')
      ..writeln(
          '🎯 Target Amount   : ${AppFormatters.formatCurrency(saving.targetAmount)}')
      ..writeln('📈 Progress        : ${progress.toStringAsFixed(1)}%')
      ..writeln('💎 Annual Yield    : ${saving.interestRate}%')
      ..writeln(
          '🗓️  Maturity Date   : ${AppFormatters.formatDate(saving.maturityDate)}')
      ..writeln('⏳ Days Remaining  : $daysLeft days')
      ..writeln(
          '💸 ${_capitalize(saving.collectionType)} Deposit : ${AppFormatters.formatCurrency(saving.monthlyDeposit)}')
      ..writeln('')
      ..writeln('Shared from MicroFlow Pro');

    SharePlus.instance.share(
      ShareParams(
        text: buffer.toString(),
        subject: 'Savings Vault: ${saving.planName}',
      ),
    );
  }

  Future<void> _generateStatement(SavingsModel saving) async {
    final options = await showModalBottomSheet<_SavingsStatementOptions>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _SavingsStatementOptionsSheet(),
    );
    if (options == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Generating statement…'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      final memberId = saving.memberId;

      final plansFuture = ref.read(memberSavingsProvider(memberId).future);
      final txnsFuture = ref.read(transactionsRepositoryProvider).getMemberSavingsTransactions(
        memberId: memberId,
        periodEnd: options.periodEnd,
      );
      final memberResponseFuture = ref.read(supabaseClientProvider)
          .from('members')
          .select('phone, member_id')
          .eq('id', memberId)
          .maybeSingle();

      final orgRaw = await ref.read(currentOrgProvider.future);
      final brandingState = ref.read(brandingProvider);
      final logoBytes = brandingState.value != null
          ? ref.read(brandingProvider.notifier).cachedLogoBytes
          : null;

      final org = SavingsStatementOrgInfo(
        name: (orgRaw?['display_name'] ?? orgRaw?['name'] ?? 'MicroFlow Pro').toString(),
        address: orgRaw?['address'] as String?,
        city: orgRaw?['city'] as String?,
        state: orgRaw?['state'] as String?,
        pincode: orgRaw?['pincode'] as String?,
        phone: orgRaw?['phone'] as String?,
        email: orgRaw?['email'] as String?,
        gstNumber: orgRaw?['gst_number'] as String?,
        logoBytes: logoBytes,
      );

      final results = await Future.wait<dynamic>([plansFuture, txnsFuture, memberResponseFuture]);
      final plans = results[0] as List<SavingsModel>;
      final txns = results[1] as List<TransactionModel>;
      final memberResponse = results[2] as Map<String, dynamic>?;

      final phone = memberResponse?['phone'] as String? ?? '';
      final humanReadableMemberId = memberResponse?['member_id'] as String? ?? '';

      final customer = SavingsStatementCustomer(
        id: memberId,
        memberId: humanReadableMemberId.isNotEmpty ? humanReadableMemberId : memberId,
        fullName: saving.memberName,
        phone: phone,
      );

      double totalOpeningBalance = 0;
      double totalDeposits = 0;
      double totalWithdrawals = 0;

      final planBlocks = plans.map((p) {
        double openingBalance = 0;
        final deposits = <SavingsStatementTx>[];
        final withdrawals = <SavingsStatementTx>[];

        for (final t in txns) {
          if (t.savingsId == p.id) {
            final date = t.collectedAt ?? t.createdAt;
            final isBeforePeriod = date.isBefore(options.periodStart);

            if (isBeforePeriod) {
              if (t.type == TransactionType.savingsDeposit) {
                openingBalance += t.amount;
              } else if (t.type == TransactionType.savingsWithdrawal) {
                openingBalance -= t.amount;
              }
            } else {
              final stx = SavingsStatementTx(
                date: date,
                amount: t.amount,
                description: t.description ?? '${t.type.name} transaction',
                paymentMode: t.paymentMode?.name,
                collectedByName: t.collectedByName,
              );
              if (t.type == TransactionType.savingsDeposit) {
                deposits.add(stx);
                totalDeposits += t.amount;
              } else if (t.type == TransactionType.savingsWithdrawal) {
                withdrawals.add(stx);
                totalWithdrawals += t.amount;
              }
            }
          }
        }

        final planClosingBalance = openingBalance +
            deposits.fold<double>(0, (sum, t) => sum + t.amount) -
            withdrawals.fold<double>(0, (sum, t) => sum + t.amount);

        totalOpeningBalance += openingBalance;

        return SavingsStatementPlanBlock(
          planId: p.id,
          planName: p.planName,
          status: p.status,
          targetAmount: p.targetAmount,
          currentAmount: p.currentAmount,
          openingBalance: openingBalance,
          closingBalance: planClosingBalance,
          interestRate: p.interestRate,
          maturityDate: p.maturityDate,
          collectionType: p.collectionType,
          monthlyDeposit: p.monthlyDeposit,
          maturityAmount: p.maturityAmount,
          nextDueDate: p.nextDueDate,
          totalInstallments: p.totalInstallments,
          paidInstallments: deposits.length,
          deposits: deposits,
          withdrawals: withdrawals,
        );
      }).toList();

      final activePlans = plans.where((p) => p.status == 'active').length;
      final closingBalance = totalOpeningBalance + totalDeposits - totalWithdrawals;
      final interestEarned = planBlocks.fold<double>(0, (sum, p) => sum + p.interestAccrued);

      final portfolio = SavingsStatementPortfolioSummary(
        openingBalance: totalOpeningBalance,
        totalDeposits: totalDeposits,
        totalWithdrawals: totalWithdrawals,
        interestEarned: interestEarned,
        closingBalance: closingBalance,
        activePlans: activePlans,
        totalPlans: plans.length,
      );

      final statementData = SavingsStatementData(
        customer: customer,
        periodStart: options.periodStart,
        periodEnd: options.periodEnd,
        plans: planBlocks,
        portfolio: portfolio,
      );

      final now = DateTime.now();
      final statementRef =
          'SAV-STMT-${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      Uint8List bytes;
      String ext;
      String mimeType;

      switch (options.format) {
        case SavingsFormat.pdf:
          bytes = await SavingsStatementPdfService.build(
            data: statementData,
            org: org,
            statementRef: statementRef,
            generatedByName: ref.read(currentUserProvider)?.fullName,
          );
          ext = 'pdf';
          mimeType = 'application/pdf';
        case SavingsFormat.excel:
          bytes = SavingsStatementExcelService.build(
            data: statementData,
            orgName: org.name,
            statementRef: statementRef,
          );
          ext = 'xlsx';
          mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        case SavingsFormat.csv:
          bytes = SavingsStatementCsvService.build(
            data: statementData,
            orgName: org.name,
            statementRef: statementRef,
          );
          ext = 'csv';
          mimeType = 'text/csv';
      }

      final filename = 'savings_statement_${saving.memberId}.$ext';

      if (kIsWeb) {
        downloadFileForWeb(bytes, filename, mimeType);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            subject: 'Savings Statement - ${saving.memberName}',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate statement: $e')),
        );
      }
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Savings Vault?'),
        content: const Text(
            'Are you sure you want to close this account? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(this.context);
              navigator.pop(); // Pop dialog first so user sees feedback
              try {
                await ref
                    .read(savingsRepositoryProvider)
                    .closeSavingPlan(widget.savingId);

                if (!mounted) return;
                ref.invalidate(allSavingsProvider);
                ref.invalidate(savingsSummaryProvider);
                ref.invalidate(pendingDepositsProvider);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Savings vault closed')),
                );
                if (mounted) {
                  Navigator.of(this.context).pop(); // Pop page
                }
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Failed to close vault: $e'),
                    backgroundColor: Theme.of(this.context).colorScheme.error,
                  ),
                );
              }
            },
            child: const Text('Close Account',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showHardDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded,
            color: Colors.red, size: 36),
        title: const Text('Delete Permanently?'),
        content: const Text(
          'This will permanently delete this RD/savings vault AND all of its '
          'collection records and transactions. This action cannot be undone '
          'and may affect financial reports.\n\nProceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(this.context);
              navigator.pop();
              try {
                await ref
                    .read(savingsRepositoryProvider)
                    .deleteSavingPlanCascade(widget.savingId);

                if (!mounted) return;
                ref.invalidate(allSavingsProvider);
                ref.invalidate(savingsSummaryProvider);
                ref.invalidate(pendingDepositsProvider);
                ref.invalidate(recentTransactionsProvider);
                ref.invalidate(dashboardTransactionsProvider);
                ref.invalidate(todayStatsProvider);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Vault deleted permanently')),
                );
                if (mounted) {
                  Navigator.of(this.context).pop();
                }
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Delete failed: $e'),
                    backgroundColor: Theme.of(this.context).colorScheme.error,
                  ),
                );
              }
            },
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
  }

  void _showDepositDialog(SavingsModel saving) {
    final perInstallmentAmount = saving.monthlyDeposit;
    final currencyFormat =
        NumberFormat.currency(symbol: '\u20b9', decimalDigits: 0);

    // Reset dialog state
    _depositInstallmentCount = 1;
    _depositSelectedMode = 'cash';
    _depositIsSubmitting = false;

    final now = DateTime.now();
    // Strip time so we compare dates only (nextDueDate is midnight, now has time)
    final todayDate = DateTime(now.year, now.month, now.day);
    int overdueCount = 0;
    if (saving.nextDueDate != null && saving.nextDueDate!.isBefore(todayDate)) {
      switch (saving.collectionType.toLowerCase()) {
        case 'daily':
          overdueCount = now.difference(saving.nextDueDate!).inDays;
          break;
        case 'weekly':
          overdueCount =
              (now.difference(saving.nextDueDate!).inDays / 7).floor();
          break;
        case 'monthly':
        default:
          overdueCount = (now.year - saving.nextDueDate!.year) * 12 +
              (now.month - saving.nextDueDate!.month);
          if (overdueCount < 0) overdueCount = 0;
          break;
      }
    }
    final hasCurrent = overdueCount >= 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          double totalAmount() =>
              _depositInstallmentCount * perInstallmentAmount;

          int overdueToPay() =>
              _depositInstallmentCount < overdueCount
                  ? _depositInstallmentCount
                  : overdueCount;
          int remainingAfterOverdue() =>
              _depositInstallmentCount - overdueToPay();
          int currentToPay() =>
              remainingAfterOverdue() > 0 && hasCurrent ? 1 : 0;
          int advanceToPay() =>
              remainingAfterOverdue() - currentToPay();

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom +
                  MediaQuery.of(ctx).padding.bottom +
                  20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: AppColors.successGradient,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.savings_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Record Deposit',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${saving.memberName} \u00b7 ${saving.planName}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Info row
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    children: [
                      if (overdueCount > 0) ...[
                        const Icon(Icons.warning_amber_rounded,
                            size: 16, color: AppColors.error),
                        const SizedBox(width: 6),
                        Text(
                          '$overdueCount overdue',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                            width: 1,
                            height: 14,
                            color: Colors.grey.shade300),
                        const SizedBox(width: 12),
                      ],
                      Text(
                        'Deposit \u20b9${perInstallmentAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const Spacer(),
                      if (saving.nextDueDate != null)
                        Text(
                          'Due ${AppFormatters.formatDate(saving.nextDueDate!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Installment count selector
                const Text('Number of Installments',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _depositInstallmentCount > 1
                            ? () => setSheetState(
                                () => _depositInstallmentCount--)
                            : null,
                        icon: const Icon(
                            Icons.remove_circle_outline_rounded),
                        color: AppColors.primary,
                        disabledColor: Colors.grey.shade300,
                      ),
                      Column(
                        children: [
                          Text(
                            '$_depositInstallmentCount',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            _depositInstallmentCount == 1
                                ? 'installment'
                                : 'installments',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: _depositInstallmentCount < 12
                            ? () => setSheetState(
                                () => _depositInstallmentCount++)
                            : null,
                        icon: const Icon(
                            Icons.add_circle_outline_rounded),
                        color: AppColors.primary,
                        disabledColor: Colors.grey.shade300,
                      ),
                    ],
                  ),
                ),
                if (_depositInstallmentCount > 1) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '$_depositInstallmentCount \u00d7 ${currencyFormat.format(perInstallmentAmount)} = ${currencyFormat.format(totalAmount())}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Read-only total amount
                const Text('Total Amount',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                TextFormField(
                  readOnly: true,
                  controller: TextEditingController(
                      text: totalAmount().toStringAsFixed(0)),
                  keyboardType: TextInputType.none,
                  decoration: InputDecoration(
                    prefixText: '\u20b9 ',
                    prefixStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                      fontSize: 20,
                    ),
                    hintText: 'Amount',
                    filled: true,
                    fillColor: AppColors.success.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.success, width: 2),
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),

                // Distribution breakdown
                if (overdueToPay() > 0 ||
                    currentToPay() > 0 ||
                    advanceToPay() > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        const Text('Deposit Distribution',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                        const SizedBox(height: 10),
                        if (overdueToPay() > 0)
                          _buildDistRow(
                              '${overdueToPay()} Overdue',
                              currencyFormat.format(
                                  overdueToPay() *
                                      perInstallmentAmount),
                              AppColors.error,
                              Icons.warning_amber_rounded),
                        if (currentToPay() > 0)
                          _buildDistRow(
                              '${currentToPay()} Current',
                              currencyFormat.format(
                                  currentToPay() *
                                      perInstallmentAmount),
                              AppColors.warning,
                              Icons.schedule_rounded),
                        if (advanceToPay() > 0)
                          _buildDistRow(
                              '${advanceToPay()} Advance',
                              currencyFormat.format(
                                  advanceToPay() *
                                      perInstallmentAmount),
                              AppColors.info,
                              Icons.trending_up_rounded),
                        const Divider(height: 20),
                        _buildDistRow(
                          'Total',
                          currencyFormat.format(totalAmount()),
                          AppColors.success,
                          null,
                          isTotal: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Payment mode chips
                const Text('Payment Mode',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: PaymentModeChip(
                        icon: Icons.money_rounded,
                        label: 'Cash',
                        isSelected: _depositSelectedMode == 'cash',
                        onTap: () => setSheetState(
                            () => _depositSelectedMode = 'cash'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PaymentModeChip(
                        icon: Icons.qr_code_rounded,
                        label: 'UPI',
                        isSelected: _depositSelectedMode == 'upi',
                        onTap: () => setSheetState(
                            () => _depositSelectedMode = 'upi'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PaymentModeChip(
                        icon: Icons.account_balance_rounded,
                        label: 'Bank',
                        isSelected: _depositSelectedMode == 'bank_transfer',
                        onTap: () => setSheetState(
                            () => _depositSelectedMode = 'bank_transfer'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PaymentModeChip(
                        icon: Icons.receipt_rounded,
                        label: 'Cheque',
                        isSelected: _depositSelectedMode == 'cheque',
                        onTap: () => setSheetState(
                            () => _depositSelectedMode = 'cheque'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _depositIsSubmitting
                            ? null
                            : () async {
                                final amount = totalAmount();
                                if (amount <= 0) return;

                                setSheetState(
                                    () => _depositIsSubmitting = true);
                                HapticFeedback.mediumImpact();

                                try {
                                  final client =
                                      Supabase.instance.client;
                                  final user = ref.read(
                                      currentUserProvider);
                                  if (user == null ||
                                      user.orgId == null) {
                                    throw Exception(
                                        'User not found');
                                  }

                                  final profile = await client
                                      .from('profiles')
                                      .select('id, full_name')
                                      .eq('user_id', user.id)
                                      .maybeSingle();
                                  final staffId =
                                      profile?['id'] as String?;

                                  final now = DateTime.now();
                                  final today = now
                                      .toIso8601String()
                                      .split('T')
                                      .first;

                                  // 1. Record collection log
                                  await client
                                      .from('savings_collections')
                                      .insert({
                                    'org_id': user.orgId!,
                                    'savings_plan_id':
                                        widget.savingId,
                                    'member_id': saving.memberId,
                                    'member_name':
                                        saving.memberName,
                                    'member_phone': '',
                                    'amount_expected':
                                        perInstallmentAmount *
                                            _depositInstallmentCount,
                                    'amount_collected': amount,
                                    'is_partial': false,
                                    'payment_mode': _depositSelectedMode,
                                    'collection_date': today,
                                    'staff_id': staffId,
                                    'sync_status': 'synced',
                                  });

                                  // 2. Advance next_due_date
                                  DateTime nextDue;
                                  switch (saving
                                      .collectionType
                                      .toLowerCase()) {
                                    case 'weekly':
                                      nextDue = now.add(Duration(
                                          days:
                                              7 * _depositInstallmentCount));
                                      break;
                                    case 'monthly':
                                      final targetDay =
                                          saving.nextDueDate
                                                  ?.day ??
                                              now.day;
                                      final targetMonth =
                                          now.month +
                                              _depositInstallmentCount;
                                      final targetYear =
                                          now.year +
                                              ((targetMonth -
                                                      1) ~/
                                                  12);
                                      final adjustedMonth =
                                          ((targetMonth - 1) %
                                                  12) +
                                              1;
                                      final daysInMonth = DateTime(
                                              targetYear,
                                              adjustedMonth + 1,
                                              0)
                                          .day;
                                      nextDue = DateTime(
                                        targetYear,
                                        adjustedMonth,
                                        targetDay > daysInMonth
                                            ? daysInMonth
                                            : targetDay,
                                      );
                                      break;
                                    default: // daily
                                      nextDue = now.add(Duration(
                                          days:
                                              _depositInstallmentCount));
                                  }

                                  // 3. Update savings plan
                                  final currentBalance =
                                      saving.currentAmount;
                                  await client
                                      .from('savings_plans')
                                      .update({
                                    'next_due_date': nextDue
                                        .toIso8601String()
                                        .split('T')
                                        .first,
                                    'current_amount':
                                        currentBalance + amount,
                                    'updated_at':
                                        now.toIso8601String(),
                                  }).eq('id', widget.savingId);

                                  // 4. Transaction record
                                  await client
                                      .from('transactions')
                                      .insert({
                                    'member_id': saving.memberId,
                                    'member_name':
                                        saving.memberName,
                                    'savings_id': widget.savingId,
                                    'amount': amount,
                                    'type':
                                        TransactionType
                                            .savingsDeposit.name,
                                    'payment_mode': _depositSelectedMode,
                                    'description':
                                        _depositInstallmentCount > 1
                                            ? '$_depositInstallmentCount installments deposited via $_depositSelectedMode'
                                            : 'Savings deposit via $_depositSelectedMode',
                                    'org_id': user.orgId!,
                                    'created_at':
                                        now.toIso8601String(),
                                  });

                                  setSheetState(() =>
                                      _depositIsSubmitting = false);
                                  HapticFeedback.heavyImpact();

                                  // 5. Invalidate providers
                                  ref.invalidate(savingDetailProvider(
                                      widget.savingId));
                                  ref.invalidate(
                                      savingTransactionsProvider(
                                          widget.savingId));
                                  ref.invalidate(allSavingsProvider);
                                  ref.invalidate(
                                      savingsSummaryProvider);
                                  ref.invalidate(
                                      pendingDepositsProvider);

                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                  }
                                  if (mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text(
                                        '${_depositInstallmentCount > 1 ? '$_depositInstallmentCount installments \u00b7 ' : ''}\u20b9${amount.toStringAsFixed(0)} deposited to ${saving.memberName}\'s vault',
                                      ),
                                      backgroundColor:
                                          AppColors.success,
                                      behavior:
                                          SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(
                                                  12)),
                                    ));
                                  }
                                } catch (e) {
                                  setSheetState(
                                      () => _depositIsSubmitting = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text(
                                          'Deposit failed: $e'),
                                      backgroundColor:
                                          AppColors.error,
                                    ));
                                  }
                                }
                              },
                        icon: _depositIsSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Icon(
                                Icons.check_circle_rounded,
                                size: 18),
                        label: Text(
                          _depositIsSubmitting
                              ? 'Processing...'
                              : 'Deposit ${currencyFormat.format(totalAmount())}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDistRow(String label, String value, Color color,
      IconData? icon,
      {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 13 : 12,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
              color: isTotal ? Colors.black87 : Colors.grey.shade700,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 14 : 12,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentBalance(SavingsModel saving, ThemeData theme) {
    return Column(
      children: [
        Text(
          'Total Wealth Accumulated',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            letterSpacing: 1.5,
          ),
        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.5),
        const SizedBox(height: 8),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [theme.colorScheme.onSurface, AppColors.success],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            AppFormatters.formatCurrency(saving.currentAmount),
            style: theme.textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -2,
              height: 1,
              color: Colors.white, // White required for ShaderMask
            ),
          ),
        ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.9, 0.9)),
      ],
    );
  }

  Widget _buildVaultCard(SavingsModel saving, ThemeData theme) {
    final progress =
        (saving.currentAmount / saving.targetAmount).clamp(0.0, 1.0);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A1F2C), const Color(0xFF0F1420)]
              : [const Color(0xFFFFFFFF), const Color(0xFFF8F9FA)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: isDark ? 0.2 : 0.1),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : AppColors.success.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success.withValues(alpha: 0.15),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.savings_rounded,
                          color: AppColors.success),
                      Text(
                        'SAVINGS PASS',
                        style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 2,
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TARGET AMOUNT',
                              style: theme.textTheme.labelSmall?.copyWith(
                                  letterSpacing: 1,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.4))),
                          Text(
                              AppFormatters.formatCurrency(saving.targetAmount),
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('ANNUAL YIELD',
                              style: theme.textTheme.labelSmall?.copyWith(
                                  letterSpacing: 1,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.4))),
                          Text('${saving.interestRate}%',
                              style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.success)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor:
                          theme.colorScheme.onSurface.withValues(alpha: 0.05),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.success),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2);
  }

  Widget _buildPrimaryActionRow(SavingsModel saving, ThemeData theme) {
    final isPaused = saving.status.toLowerCase() == 'paused';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildActionButton(
            'Deposit',
            Icons.add_rounded,
            AppColors.success,
            isPaused
                ? () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Vault is paused. Resume it to make deposits.')),
                    )
                : () => _showDepositDialog(saving),
            disabled: isPaused,
          ),
          _buildActionButton(
            'Share',
            Icons.ios_share_rounded,
            theme.colorScheme.onSurface,
            () => _shareVaultSummary(saving),
          ),
          _buildActionButton(
              'Withdraw', Icons.outbound_rounded, theme.colorScheme.onSurface,
              () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Withdrawal feature coming soon')));
          }),
          _buildActionButton(
            isPaused ? 'Resume' : 'Pause',
            isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            isPaused ? AppColors.success : Colors.orange,
            () => _setStatus(saving, isPaused ? 'active' : 'paused'),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onTap,
      {bool disabled = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveColor =
        disabled ? theme.colorScheme.onSurface.withValues(alpha: 0.3) : color;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? effectiveColor.withValues(alpha: 0.15)
                  : effectiveColor.withValues(alpha: 0.1),
              border: Border.all(
                  color: effectiveColor.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: effectiveColor.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: effectiveColor, size: 30),
          ),
          const SizedBox(height: 12),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8))),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Text(
      title,
      style: theme.textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
    );
  }

  Widget _buildIntelligenceCard(SavingsModel saving, ThemeData theme) {
    double monthlyEquivalent = saving.monthlyDeposit;
    final typeStr = saving.collectionType.toLowerCase();
    if (typeStr == 'daily') {
      monthlyEquivalent = saving.monthlyDeposit * 30;
    } else if (typeStr == 'weekly') {
      monthlyEquivalent = saving.monthlyDeposit * 4.33;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          _buildInfoRow('${_capitalize(saving.collectionType)} Deposit',
              AppFormatters.formatCurrency(saving.monthlyDeposit), theme),
          if (typeStr != 'monthly') ...[
            const SizedBox(height: 12),
            _buildInfoRow('Monthly Equivalent',
                AppFormatters.formatCurrency(monthlyEquivalent), theme,
                valueColor: theme.colorScheme.primary),
          ],
          const SizedBox(height: 12),
          _buildInfoRow(
              'Interest Earned',
              AppFormatters.formatCurrency(
                  saving.currentAmount * saving.interestRate / 100),
              theme,
              valueColor: AppColors.success),
          const SizedBox(height: 12),
          _buildInfoRow('Maturity Date',
              AppFormatters.formatDate(saving.maturityDate), theme),
          if (saving.nextDueDate != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
                'Next Installment',
                AppFormatters.formatDate(saving.nextDueDate!),
                theme,
                valueColor: saving.nextDueDate!.isBefore(
                    DateTime(DateTime.now().year, DateTime.now().month,
                        DateTime.now().day))
                    ? AppColors.error
                    : AppColors.primary,
                isBold: true),
          ],
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1)),
          _buildInfoRow(
              'Days Remaining',
              '${saving.maturityDate.difference(DateTime.now()).inDays} Days',
              theme,
              isBold: true),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme,
      {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
        Text(value,
            style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
                color: valueColor)),
      ],
    );
  }

  Widget _buildTransactionList(ThemeData theme) {
    final pageState = ref.watch(savingTxPagerProvider(widget.savingId));
    final transactions = pageState.items;

    if (pageState.error != null && transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Text('Error: ${pageState.error}', style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => ref
                    .read(savingTxPagerProvider(widget.savingId).notifier)
                    .refresh(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (transactions.isEmpty && pageState.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(
            'No transaction history available.',
            style: theme.textTheme.bodySmall,
          ),
        ),
      );
    }

    return Column(
      children: [
        ...transactions.map((t) => _buildTransactionItem(t, theme)),
        const SizedBox(height: 8),
        if (pageState.hasMore)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: pageState.isLoading
                  ? null
                  : () => ref
                      .read(savingTxPagerProvider(widget.savingId).notifier)
                      .loadMore(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                side: BorderSide(color: theme.dividerColor),
              ),
              icon: pageState.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded, size: 18),
              label: Text(pageState.isLoading ? 'Loading…' : 'Load More'),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '— End of history —',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
      ],
    );
  }

  String _capitalize(String s) =>
      s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;

  Widget _buildTransactionItem(TransactionModel tx, ThemeData theme) {
    final isCredit = tx.type != TransactionType.savingsWithdrawal;
    final title = tx.description ?? _capitalize(tx.type.name);
    final date = AppFormatters.formatDate(tx.createdAt);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _showTransactionActionsSheet(tx),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isCredit ? AppColors.success : Colors.red)
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(isCredit ? Icons.add_rounded : Icons.remove_rounded,
                  color: isCredit ? AppColors.success : Colors.red, size: 18),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text(date, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Text(
              '${isCredit ? '+' : '-'} ${AppFormatters.formatCurrency(tx.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isCredit ? AppColors.success : Colors.red,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  void _showTransactionActionsSheet(TransactionModel tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Edit Transaction'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showEditTransactionDialog(tx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: Colors.red),
                title: const Text('Delete Transaction',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _confirmDeleteTransaction(tx);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showEditTransactionDialog(TransactionModel tx) {
    final amountController =
        TextEditingController(text: tx.amount.toStringAsFixed(2));
    final descController = TextEditingController(text: tx.description ?? '');
    DateTime selectedDate = tx.createdAt;
    TransactionType selectedType = tx.type == TransactionType.savingsWithdrawal
        ? TransactionType.savingsWithdrawal
        : TransactionType.savingsDeposit;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(builder: (ctx, setLocalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Edit Transaction',
                style: TextStyle(fontWeight: FontWeight.w800)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<TransactionType>(
                    segments: const [
                      ButtonSegment(
                        value: TransactionType.savingsDeposit,
                        label: Text('Deposit'),
                        icon: Icon(Icons.add_rounded),
                      ),
                      ButtonSegment(
                        value: TransactionType.savingsWithdrawal,
                        label: Text('Withdraw'),
                        icon: Icon(Icons.remove_rounded),
                      ),
                    ],
                    selected: {selectedType},
                    onSelectionChanged: (s) =>
                        setLocalState(() => selectedType = s.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) {
                        setLocalState(() {
                          selectedDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            selectedDate.hour,
                            selectedDate.minute,
                          );
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(AppFormatters.formatDate(selectedDate)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final amt = double.tryParse(amountController.text) ?? 0;
                  if (amt <= 0) return;
                  Navigator.pop(dialogCtx);
                  await _applyTransactionEdit(
                    tx: tx,
                    amount: amt,
                    description: descController.text.trim(),
                    createdAt: selectedDate,
                    type: selectedType,
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _applyTransactionEdit({
    required TransactionModel tx,
    required double amount,
    required String description,
    required DateTime createdAt,
    required TransactionType type,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(transactionsRepositoryProvider).updateTransaction(
            id: tx.id,
            amount: amount,
            description: description.isEmpty ? null : description,
            createdAt: createdAt,
            type: type,
          );
      await ref
          .read(savingsRepositoryProvider)
          .recalculateBalance(widget.savingId);

      if (!mounted) return;
      ref.invalidate(savingDetailProvider(widget.savingId));
      ref.invalidate(savingTransactionsProvider(widget.savingId));
      ref.invalidate(allSavingsProvider);
      ref.invalidate(savingsSummaryProvider);
      ref
          .read(savingTxPagerProvider(widget.savingId).notifier)
          .refresh();

      HapticFeedback.lightImpact();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Transaction updated'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _confirmDeleteTransaction(TransactionModel tx) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Transaction?'),
        content: Text(
            'This will remove "${tx.description ?? _capitalize(tx.type.name)}" of ${AppFormatters.formatCurrency(tx.amount)} and recalculate the vault balance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await _deleteTransaction(tx);
            },
            child:
                const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTransaction(TransactionModel tx) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(transactionsRepositoryProvider)
          .deleteTransaction(tx.id);
      await ref
          .read(savingsRepositoryProvider)
          .recalculateBalance(widget.savingId);

      if (!mounted) return;
      ref.invalidate(savingDetailProvider(widget.savingId));
      ref.invalidate(savingTransactionsProvider(widget.savingId));
      ref.invalidate(allSavingsProvider);
      ref.invalidate(savingsSummaryProvider);
      ref
          .read(savingTxPagerProvider(widget.savingId).notifier)
          .refresh();

      HapticFeedback.mediumImpact();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Transaction deleted'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

class _SavingsStatementOptions {
  final DateTime periodStart;
  final DateTime periodEnd;
  final SavingsFormat format;

  const _SavingsStatementOptions({
    required this.periodStart,
    required this.periodEnd,
    required this.format,
  });
}

enum _RangePreset { thisMonth, last3M, last6M, thisFY, custom }

class _SavingsStatementOptionsSheet extends StatefulWidget {
  const _SavingsStatementOptionsSheet();

  @override
  State<_SavingsStatementOptionsSheet> createState() =>
      _SavingsStatementOptionsSheetState();
}

class _SavingsStatementOptionsSheetState
    extends State<_SavingsStatementOptionsSheet> {
  _RangePreset _preset = _RangePreset.thisFY;
  SavingsFormat _format = SavingsFormat.pdf;
  late DateTime _customStart;
  late DateTime _customEnd;

  @override
  void initState() {
    super.initState();
    _customStart = DateTime(2000);
    _customEnd = DateTime.now();
  }

  (DateTime, DateTime) _resolveRange() {
    final now = DateTime.now();
    switch (_preset) {
      case _RangePreset.thisMonth:
        return (DateTime(now.year, now.month, 1), now);
      case _RangePreset.last3M:
        return (DateTime(now.year, now.month - 3, now.day), now);
      case _RangePreset.last6M:
        return (DateTime(now.year, now.month - 6, now.day), now);
      case _RangePreset.thisFY:
        final fyStartYear = now.month >= 4 ? now.year : now.year - 1;
        return (DateTime(fyStartYear, 4, 1), now);
      case _RangePreset.custom:
        return (_customStart, _customEnd);
    }
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _customStart, end: _customEnd),
    );
    if (picked != null) {
      setState(() {
        _customStart = picked.start;
        _customEnd = picked.end;
        _preset = _RangePreset.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (start, end) = _resolveRange();
    final fmt = DateFormat('dd MMM yyyy');

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Generate Savings Statement',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('Choose the period and format.',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 20),
            Text('PERIOD',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w900,
                  color: theme.textTheme.bodySmall?.color
                      ?.withValues(alpha: 0.6),
                )),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _RangePreset.values.map((p) {
                final selected = _preset == p;
                return GestureDetector(
                  onTap: () async {
                    if (p == _RangePreset.custom) {
                      await _pickCustomRange();
                    } else {
                      setState(() => _preset = p);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _presetLabel(p),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: selected
                            ? Colors.white
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            Text('${fmt.format(start)}  →  ${fmt.format(end)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodySmall?.color
                      ?.withValues(alpha: 0.7),
                )),
            const SizedBox(height: 20),
            Text('FORMAT',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w900,
                  color: theme.textTheme.bodySmall?.color
                      ?.withValues(alpha: 0.6),
                )),
            const SizedBox(height: 8),
            SegmentedButton<SavingsFormat>(
              segments: [
                ButtonSegment(
                  value: SavingsFormat.pdf,
                  label: const Text('PDF'),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                ),
                ButtonSegment(
                  value: SavingsFormat.excel,
                  label: const Text('Excel'),
                  icon: const Icon(Icons.grid_on_rounded, size: 18),
                ),
                ButtonSegment(
                  value: SavingsFormat.csv,
                  label: const Text('CSV'),
                  icon: const Icon(Icons.table_chart_rounded, size: 18),
                ),
              ],
              selected: {_format},
              onSelectionChanged: (s) => setState(() => _format = s.first),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.pop(
                    context,
                    _SavingsStatementOptions(
                      periodStart: start,
                      periodEnd: end,
                      format: _format,
                    ),
                  );
                },
                icon: const Icon(Icons.download_rounded),
                label: const Text('Generate',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _presetLabel(_RangePreset p) {
    switch (p) {
      case _RangePreset.thisMonth:
        return 'This Month';
      case _RangePreset.last3M:
        return 'Last 3 Months';
      case _RangePreset.last6M:
        return 'Last 6 Months';
      case _RangePreset.thisFY:
        return 'This FY';
      case _RangePreset.custom:
        return 'Custom';
    }
  }
}
