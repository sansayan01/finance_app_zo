import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/savings_model.dart';
import '../../data/providers/savings_providers.dart';

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
                  if (value % 3 != 0) return const SizedBox.shrink();
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
          minY: 0,
          maxY: saving.targetAmount * 1.2,
          lineBarsData: [
            // Target Line (Straight)
            LineChartBarData(
              spots: [
                const FlSpot(0, 0),
                FlSpot(12, saving.targetAmount),
              ],
              isCurved: false,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              barWidth: 2,
              dashArray: [5, 5],
              dotData: const FlDotData(show: false),
            ),
            // Current Progress Line (Curved)
            LineChartBarData(
              spots: [
                const FlSpot(0, 0),
                FlSpot(6, saving.currentAmount),
              ],
              isCurved: true,
              color: AppColors.success,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
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
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: (value) {
                  if (value == 'edit') {
                    context.push('/savings/${saving.id}/edit');
                  }
                  if (value == 'delete') _showDeleteDialog();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit Vault')),
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Record Deposit'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixText: '₹ ',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text) ?? 0;
              final navigator = Navigator.of(dialogContext);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              if (amount > 0) {
                await ref
                    .read(savingsRepositoryProvider)
                    .recordDeposit(widget.savingId, amount);

                if (!mounted) return;
                ref.invalidate(savingDetailProvider(widget.savingId));
                ref.invalidate(savingTransactionsProvider(widget.savingId));
                ref.invalidate(allSavingsProvider);
                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Deposit Confirmed',
                                style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                              Text(
                                '₹${amount.toStringAsFixed(0)} added to vault.',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    margin: const EdgeInsets.all(16),
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            },
            child: const Text('Confirm'),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildActionButton('Deposit', Icons.add_rounded, AppColors.success,
              () => _showDepositDialog(saving)),
          _buildActionButton('Statement', Icons.description_rounded,
              theme.colorScheme.onSurface, () {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Generating statement...')));
          }),
          _buildActionButton(
              'Withdraw', Icons.outbound_rounded, theme.colorScheme.onSurface,
              () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Withdrawal feature coming soon')));
          }),
          _buildActionButton('Close', Icons.lock_outline_rounded, Colors.red,
              () => _showDeleteDialog()),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                  ? color.withValues(alpha: 0.15)
                  : color.withValues(alpha: 0.1),
              border:
                  Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 30),
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
    final transactionsAsync =
        ref.watch(savingTransactionsProvider(widget.savingId));

    return transactionsAsync.when(
      data: (transactions) {
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
          children: transactions
              .map((t) => _buildTransactionItem(
                    t.description ?? _capitalize(t.type.name),
                    AppFormatters.formatDate(t.createdAt),
                    t.amount,
                    t.type.name.contains('Deposit') ||
                        t.type.name.contains('Interest'),
                    theme,
                  ))
              .toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }

  String _capitalize(String s) =>
      s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;

  Widget _buildTransactionItem(String title, String date, double amount,
      bool isCredit, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
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
            '${isCredit ? '+' : '-'} ₹$amount',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: isCredit ? AppColors.success : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
