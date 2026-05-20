import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../features/transactions/data/models/transaction_model.dart';
import '../../data/models/savings_model.dart';
import '../../data/providers/savings_providers.dart';
import '../../../home/data/providers/dashboard_providers.dart'
    show pendingDepositsProvider;

class SavingDetailPage extends ConsumerStatefulWidget {
  final String savingId;
  const SavingDetailPage({super.key, required this.savingId});

  @override
  ConsumerState<SavingDetailPage> createState() => _SavingDetailPageState();
}

class _SavingDetailPageState extends ConsumerState<SavingDetailPage> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() => _scrollOffset = _scrollController.offset);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
      appBar: savingAsync.when(
        data: (saving) => saving != null ? _buildAppBar(theme, saving) : null,
        loading: () => null,
        error: (_, __) => null,
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
    final blurAlpha = (_scrollOffset / 100).clamp(0.0, 1.0);
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
                  }
                },
                itemBuilder: (context) => [
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
                ],
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
              await ref
                  .read(savingsRepositoryProvider)
                  .deleteSavingPlan(widget.savingId);

              if (!mounted) return;
              ref.invalidate(allSavingsProvider);
              ref.invalidate(savingsSummaryProvider);
              ref.invalidate(pendingDepositsProvider);
              navigator.pop(); // Pop dialog
              if (mounted) {
                Navigator.of(this.context).pop(); // Pop page
              }
            },
            child: const Text('Close Account',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDepositDialog(SavingsModel saving) {
    final controller =
        TextEditingController(text: saving.monthlyDeposit.toString());
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isSubmitting = false;
        bool isSuccess = false;
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: isSuccess 
                  ? null 
                  : const Text('Record Deposit', style: TextStyle(fontWeight: FontWeight.w800)),
              content: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isSuccess
                    ? Padding(
                        key: const ValueKey('success'),
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 64),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Deposit Successful',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₹${controller.text} added to vault.',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                      )
                    : TextField(
                        key: const ValueKey('input'),
                        controller: controller,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        ),
                      ),
              ),
              actions: isSuccess
                  ? []
                  : [
                      TextButton(
                          onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                          child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final amount = double.tryParse(controller.text) ?? 0;
                                if (amount <= 0) return;

                                setState(() => isSubmitting = true);

                                try {
                                  await ref
                                      .read(savingsRepositoryProvider)
                                      .recordDeposit(widget.savingId, amount);

                                  HapticFeedback.heavyImpact();
                                  
                                  setState(() {
                                    isSubmitting = false;
                                    isSuccess = true;
                                  });

                                  // Wait for user to see the success message
                                  await Future.delayed(const Duration(milliseconds: 1800));

                                  if (!mounted) return;
                                  ref.invalidate(savingDetailProvider(widget.savingId));
                                  ref.invalidate(savingTransactionsProvider(widget.savingId));
                                  ref.invalidate(allSavingsProvider);
                                  ref.invalidate(savingsSummaryProvider);
                                  ref.invalidate(pendingDepositsProvider);
                                  
                                  if (dialogContext.mounted) {
                                    Navigator.of(dialogContext).pop();
                                  }
                                } catch (e) {
                                  setState(() => isSubmitting = false);
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20, 
                                height: 20, 
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                              )
                            : const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
            );
          },
        );
      },
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
