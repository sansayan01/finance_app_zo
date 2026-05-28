// ignore_for_file: deprecated_member_use
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../data/models/savings_model.dart';
import '../../data/providers/savings_providers.dart';
import '../../../home/data/providers/dashboard_providers.dart';

class SavingsPage extends ConsumerStatefulWidget {
  const SavingsPage({super.key});

  @override
  ConsumerState<SavingsPage> createState() => _SavingsPageState();
}

class _SavingsPageState extends ConsumerState<SavingsPage>
    with SingleTickerProviderStateMixin {
  int _activeFilter = 0; // 0: All, 1: Active, 2: Matured
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.invalidate(savingsProvider);
      ref.invalidate(savingsSummaryProvider);
      ref.invalidate(pendingDepositsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final savingsAsync = ref.watch(savingsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF2F2F7),
      body: AuroraBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(savingsProvider);
            ref.invalidate(savingsSummaryProvider);
            ref.invalidate(pendingDepositsProvider);
          },
          displacement: 20,
          color: theme.colorScheme.primary,
          backgroundColor: theme.cardColor,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              _buildAppBar(context, theme, isDark),
              SliverToBoxAdapter(
                  child: _buildWealthSummary(savingsAsync, theme, isDark)),
              _buildFilters(theme, isDark),
              _buildSavingsList(savingsAsync, theme, isDark),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, ThemeData theme, bool isDark) {
    return SliverAppBar(
      expandedHeight: 140,
      floating: true,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(),
        titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        centerTitle: false,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VAULT OVERVIEW',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            Text(
              'Savings Hub',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
      actions: [

        Padding(
          padding: const EdgeInsets.only(right: 16, top: 12),
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: IconButton(
              onPressed: () => context.push('/savings/new'),
              icon: const Icon(Icons.add_rounded, size: 28),
              color: Colors.white,
              tooltip: 'New Savings Plan',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWealthSummary(AsyncValue<List<SavingsModel>> savingsAsync,
      ThemeData theme, bool isDark) {
    return savingsAsync.when(
      data: (savings) {
        final totalSaved = savings.fold(0.0, (sum, s) => sum + s.currentAmount);
        final totalTarget = savings.fold(0.0, (sum, s) => sum + s.targetAmount);
        final progress =
            (totalTarget > 0 ? totalSaved / totalTarget : 0.0).clamp(0.0, 1.0);
        final avgRate = savings.isEmpty
            ? 0.0
            : (savings.fold(0.0, (sum, s) => sum + s.interestRate) /
                savings.length);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -60,
                        right: -40,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -80,
                        left: -40,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                          child: const SizedBox(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('CUMULATIVE WEALTH',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                                letterSpacing: 2,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white
                                                    .withValues(alpha: 0.7))),
                                    const SizedBox(height: 8),
                                    Text(
                                      AppFormatters.formatCurrency(totalSaved),
                                      style: theme.textTheme.displaySmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.2)),
                                  ),
                                  child: const Icon(Icons.shield_rounded,
                                      color: Colors.white, size: 28),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildGlobalMetric(
                                    'GOAL',
                                    AppFormatters.formatCompactCurrency(
                                        totalTarget),
                                    theme,
                                    color: Colors.white,
                                    labelColor:
                                        Colors.white.withValues(alpha: 0.7)),
                                _buildGlobalMetric('AVG YIELD',
                                    '${avgRate.toStringAsFixed(1)}%', theme,
                                    color: Colors.white,
                                    labelColor:
                                        Colors.white.withValues(alpha: 0.7)),
                                _buildGlobalMetric(
                                    'PLANS', savings.length.toString(), theme,
                                    color: Colors.white,
                                    labelColor:
                                        Colors.white.withValues(alpha: 0.7)),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                    '${(progress * 100).toStringAsFixed(1)}% ACHIEVED',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white)),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 8,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.2),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Padding(
          padding: EdgeInsets.all(24), child: ShimmerCard(height: 220)),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildGlobalMetric(String label, String value, ThemeData theme,
      {Color? color, Color? labelColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: labelColor ??
                    theme.colorScheme.onSurface.withValues(alpha: 0.4))),
        const SizedBox(height: 4),
        Text(value,
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900, color: color, fontSize: 16)),
      ],
    );
  }

  Widget _buildFilters(ThemeData theme, bool isDark) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _FilterDelegate(
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.03)),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded,
                              size: 20,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              onChanged: (value) =>
                                  setState(() => _searchQuery = value),
                              decoration: InputDecoration(
                                hintText: 'Search by member name...',
                                hintStyle: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.3)),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        _buildFilterPill('All Vaults', 0, theme),
                        const SizedBox(width: 12),
                        _buildFilterPill('Active Plans', 1, theme),
                        const SizedBox(width: 12),
                        _buildFilterPill('Matured', 2, theme),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPill(String label, int index, ThemeData theme) {
    final isSelected = _activeFilter == index;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _activeFilter = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: !isSelected
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03))
              : null,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : theme.dividerColor.withValues(alpha: 0.1)),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 13,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildSavingsList(AsyncValue<List<SavingsModel>> savingsAsync,
      ThemeData theme, bool isDark) {
    return savingsAsync.when(
      data: (savings) {
        final filtered = savings.where((s) {
          final matchesFilter = (_activeFilter == 0) ||
              (_activeFilter == 1 && s.status == 'active') ||
              (_activeFilter == 2 && s.status == 'completed');
          final matchesSearch =
              s.memberName.toLowerCase().contains(_searchQuery.toLowerCase());
          return matchesFilter && matchesSearch;
        }).toList();

        if (filtered.isEmpty) {
          return SliverFillRemaining(child: _buildEmptyState(theme));
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final saving = filtered[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.push('/savings/${saving.id}');
                    },
                    child: _PremiumSavingCard(saving: saving),
                  ),
                );
              },
              childCount: filtered.length,
            ),
          ),
        );
      },
      loading: () => SliverPadding(
        padding: const EdgeInsets.all(24),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: ShimmerCard(height: 160)),
            childCount: 3,
          ),
        ),
      ),
      error: (e, _) =>
          SliverFillRemaining(child: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  blurRadius: 32,
                  spreadRadius: 8,
                )
              ],
            ),
            child: Icon(Icons.savings_outlined,
                size: 80, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 24),
          Text('No Savings Found',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Your financial future starts with a single deposit.',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
        ],
      ),
    );
  }

}

class _PremiumSavingCard extends StatelessWidget {
  final SavingsModel saving;
  const _PremiumSavingCard({required this.saving});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (saving.targetAmount > 0)
        ? (saving.currentAmount / saving.targetAmount).clamp(0.0, 1.0)
        : 0.0;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      elevated: true,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(saving.memberName,
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    Text(
                      'VAULT ID: ${saving.id.length >= 8 ? saving.id.substring(0, 8).toUpperCase() : saving.id.toUpperCase()}',
                      style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4)),
                    ),
                  ],
                ),
              ),
              _buildMaturityBadge(saving, theme),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniMetric('ACCUMULATED',
                  AppFormatters.formatCurrency(saving.currentAmount), theme),
              _buildMiniMetric(
                  saving.collectionType.toUpperCase(),
                  AppFormatters.formatCompactCurrency(saving.monthlyDeposit),
                  theme,
                  color: theme.colorScheme.primary),
              _buildMiniMetric('YIELD', '${saving.interestRate}%', theme,
                  color: AppColors.success),
            ],
          ),
          const SizedBox(height: 20),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('PROGRESS',
                      style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.3))),
                  Text('${(progress * 100).toInt()}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppColors.success)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: const LinearGradient(
                            colors: AppColors.successGradient),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.event_available_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text(
                'Maturity: ${AppFormatters.formatDate(saving.maturityDate)}',
                style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, ThemeData theme,
      {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
        Text(value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }



  Widget _buildMaturityBadge(SavingsModel saving, ThemeData theme) {
    final isMatured = saving.status == 'completed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: isMatured
            ? const LinearGradient(colors: AppColors.successGradient)
            : AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: (isMatured ? AppColors.success : AppColors.primary)
                .withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Text(
        isMatured ? 'MATURED' : 'ACTIVE',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _FilterDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _FilterDelegate({required this.child});

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      SizedBox.expand(child: child);

  @override
  double get maxExtent => 140;
  @override
  double get minExtent => 140;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}



