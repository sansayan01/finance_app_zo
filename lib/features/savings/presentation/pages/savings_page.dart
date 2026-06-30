// ignore_for_file: deprecated_member_use
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  final void Function(String savingId)? onSavingTap;
  final bool showCreateButton;

  const SavingsPage({
    super.key,
    this.onSavingTap,
    this.showCreateButton = true,
  });

  @override
  ConsumerState<SavingsPage> createState() => _SavingsPageState();
}

class _SavingsPageState extends ConsumerState<SavingsPage> {
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
      floating: true,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            color: (isDark 
                ? const Color(0xFF0A0A0C) 
                : const Color(0xFFF2F2F7)).withOpacity(0.7),
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'VAULT OVERVIEW',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: theme.colorScheme.primary.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'Savings Hub',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
      actions: [
        if (widget.showCreateButton)
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: GestureDetector(
                onTap: () => context.push('/savings/new'),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(
            children: [
              // Main hero card — gradient strip with amount
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Shield icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.15)),
                      ),
                      child: const Icon(Icons.shield_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    // Amount
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'TOTAL SAVED',
                            style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w900,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            AppFormatters.formatCurrency(totalSaved),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Progress ring
                    SizedBox(
                      width: 42,
                      height: 42,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 42,
                            height: 42,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 3,
                              backgroundColor:
                                  Colors.white.withOpacity(0.15),
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Bento metric pills row
              Row(
                children: [
                  _buildBentoPill(
                      '${savings.length}', 'PLANS', Icons.savings_outlined,
                      theme),
                  const SizedBox(width: 8),
                  _buildBentoPill(
                      '${avgRate.toStringAsFixed(1)}%', 'AVG YIELD',
                      Icons.trending_up_rounded, theme),
                  const SizedBox(width: 8),
                  _buildBentoPill(
                      AppFormatters.formatCompactCurrency(totalTarget),
                      'GOAL',
                      Icons.flag_outlined, theme),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: ShimmerCard(height: 100)),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildBentoPill(
      String value, String label, IconData icon, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.015),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 13,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: -0.3,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(ThemeData theme, bool isDark) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _FilterDelegate(
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: (isDark 
                  ? const Color(0xFF0A0A0C) 
                  : const Color(0xFFF2F2F7)).withOpacity(0.7),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.04)
                            : Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.06)
                                : Colors.black.withOpacity(0.04),
                            width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded,
                              size: 16,
                              color: theme.colorScheme.onSurface.withOpacity(0.4)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              onChanged: (value) =>
                                  setState(() => _searchQuery = value),
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search by member name...',
                                hintStyle: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface.withOpacity(0.3)),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.close_rounded,
                                            size: 16,
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.4)),
                                        onPressed: () {
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _buildFilterPill('All Vaults', 0, theme),
                        const SizedBox(width: 6),
                        _buildFilterPill('Active Plans', 1, theme),
                        const SizedBox(width: 6),
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: !isSelected
              ? (isDark
                  ? Colors.white.withOpacity(0.04)
                  : Colors.black.withOpacity(0.03))
              : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : theme.dividerColor.withOpacity(0.05),
              width: 0.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : theme.colorScheme.onSurface.withOpacity(0.6),
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 11,
            letterSpacing: 0.1,
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final saving = filtered[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (widget.onSavingTap != null) {
                        widget.onSavingTap!(saving.id);
                      } else {
                        context.push('/savings/${saving.id}');
                      }
                    },
                    child: _CompactSavingCard(saving: saving),
                  ),
                ).animate().fadeIn(delay: (50 * index).ms).slideY(begin: 0.05);
              },
              childCount: filtered.length,
            ),
          ),
        );
      },
      loading: () => SliverPadding(
        padding: const EdgeInsets.all(20),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: ShimmerCard(height: 56)),
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withOpacity(0.05),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.1),
                width: 1.5,
              ),
            ),
            child: Icon(Icons.savings_outlined,
                size: 64, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text('No Savings Found',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('Your financial future starts with a single deposit.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5))),
        ],
      ),
    );
  }
}

class _CompactSavingCard extends StatelessWidget {
  final SavingsModel saving;
  const _CompactSavingCard({required this.saving});

  Widget _buildStatusBadge(String status, ThemeData theme) {
    final isMatured = status == 'completed';
    final isDark = theme.brightness == Brightness.dark;
    final color = isMatured 
        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669)) 
        : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Text(
        isMatured ? 'MATURED' : 'ACTIVE',
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final progress = (saving.targetAmount > 0)
        ? (saving.currentAmount / saving.targetAmount).clamp(0.0, 1.0)
        : 0.0;

    final initial = saving.memberName.trim().isNotEmpty
        ? saving.memberName.trim()[0].toUpperCase()
        : '?';

    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 14,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          primary.withOpacity(0.15),
                          primary.withOpacity(0.05),
                        ],
                      ),
                      border: Border.all(
                        color: primary.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: primary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          saving.memberName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: -0.2,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${saving.collectionType.toUpperCase()} • Due ${AppFormatters.formatDate(saving.maturityDate)}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppFormatters.formatCurrency(saving.currentAmount),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: -0.3,
                          color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildStatusBadge(saving.status, theme),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 2.5,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: theme.colorScheme.onSurface.withOpacity(0.04),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                ),
              ),
            ),
          ],
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
  double get maxExtent => 88;
  @override
  double get minExtent => 88;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}
