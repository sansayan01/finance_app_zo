import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/glass_button.dart';
import '../../../../core/widgets/glass_text_field.dart';
import '../../../../core/widgets/progress_gauge.dart';
import '../../../payments/data/models/today_payment_model.dart';
import '../../../payments/data/providers/payment_providers.dart' show TodayPaymentData;
import '../../../payments/data/utils/payment_export.dart';
import '../../../branch_manager/data/providers/branch_payment_providers.dart';
import '../../../branch_manager/data/providers/branch_scoped_providers.dart';
import '../../data/providers/staff_branch_providers.dart';
import '../../data/providers/staff_providers.dart';
import '../widgets/premium_helpers.dart';

class StaffTodayPaymentsPage extends ConsumerStatefulWidget {
  const StaffTodayPaymentsPage({super.key});

  @override
  ConsumerState<StaffTodayPaymentsPage> createState() =>
      _StaffTodayPaymentsPageState();
}

class _StaffTodayPaymentsPageState
    extends ConsumerState<StaffTodayPaymentsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref.read(branchPaymentFilterProvider.notifier).setSearchQuery(query);
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(branchPaymentFilterProvider.notifier).setSearchQuery('');
    setState(() => _showSearch = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final branchAsync = ref.watch(staffBranchIdProvider);

    if (branchAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payments')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final branchId = branchAsync.valueOrNull;

    if (branchId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payments')),
        body: const Center(child: Text('No branch assigned to your profile.\nContact your admin to assign a branch.')),
      );
    }

    final paymentsAsync = ref.watch(branchTodayPaymentsProvider(branchId));
    final filter = ref.watch(branchPaymentFilterProvider);

    // Auto-refresh timer
    ref.listen<BranchPaymentFilterState>(branchPaymentFilterProvider,
        (prev, next) {
      if (next.autoRefresh && next.isToday) {
        ref.watch(branchAutoRefreshTimerProvider);
      }
    });

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF2F2F7),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(branchTodayPaymentsProvider(branchId));
          ref.invalidate(branchCollectionStatsProvider(branchId));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // App Bar
            _buildAppBar(theme, isDark, filter, branchId),
            // Hero Summary
            SliverToBoxAdapter(
              child: paymentsAsync.when(
                data: (data) => _buildHeroSummary(theme, isDark, data),
                loading: () => _buildHeroLoading(isDark),
                error: (e, _) => _buildErrorWidget(theme, isDark, e),
              ),
            ),
            // Quick Stats Row
            SliverToBoxAdapter(
              child: paymentsAsync.when(
                data: (data) => _buildQuickStats(theme, isDark, data),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
            // Tab Bar
            SliverToBoxAdapter(child: _buildTabBar(theme, isDark)),
            // Search Bar (when visible)
            if (_showSearch)
              SliverToBoxAdapter(
                child: _buildSearchField(theme, isDark),
              ),
            // Date & Sort Controls
            SliverToBoxAdapter(
              child: _buildDateSortRow(theme, isDark, filter, branchId),
            ),
            // Payment Cards
            paymentsAsync.when(
              data: (data) {
                final tabData = _getTabData(data);
                if (tabData.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(theme, isDark, _tabController.index),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  sliver: SliverList.builder(
                    itemCount: tabData.length,
                    itemBuilder: (context, index) {
                      return _buildPaymentCard(
                        context, theme, isDark, tabData[index], index,
                        branchId,
                      );
                    },
                  ),
                );
              },
              loading: () => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: 6,
                  itemBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              error: (e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: _buildErrorWidget(theme, isDark, e),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildQuickCollectFab(theme, isDark, branchId),
    );
  }

  // ── App Bar ──
  Widget _buildAppBar(
      ThemeData theme, bool isDark, BranchPaymentFilterState filter, String branchId) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: isDark
          ? const Color(0xFF0A0A0C).withValues(alpha: 0.85)
          : const Color(0xFFF2F2F7).withValues(alpha: 0.85),
      surfaceTintColor: Colors.transparent,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Collection",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            filter.dateLabel,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        if (!_showSearch)
          IconButton(
            onPressed: () => setState(() => _showSearch = true),
            icon: Icon(Icons.search_rounded,
                color: isDark ? Colors.white70 : Colors.black54),
          ),
        if (_showSearch)
          IconButton(
            onPressed: _clearSearch,
            icon: Icon(Icons.close_rounded,
                color: isDark ? Colors.white70 : Colors.black54),
          ),
        IconButton(
          onPressed: () => _showSortSheet(context, isDark),
          icon: Icon(Icons.sort_rounded,
              color: isDark ? Colors.white70 : Colors.black54),
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded,
              color: isDark ? Colors.white70 : Colors.black54),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) {
            switch (value) {
              case 'export_csv':
                _exportPayments(context, branchId, 'csv');
                break;
              case 'export_pdf':
                _exportPayments(context, branchId, 'pdf');
                break;
              case 'auto_refresh':
                ref
                    .read(branchPaymentFilterProvider.notifier)
                    .toggleAutoRefresh();
                break;
              case 'reset':
                ref
                    .read(branchPaymentFilterProvider.notifier)
                    .resetFilters();
                _searchController.clear();
                setState(() {
                  _showSearch = false;
                  _tabController.index = 0;
                });
                break;
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'export_csv',
              child: Row(children: [
                const Icon(Icons.file_download_outlined, size: 20),
                const SizedBox(width: 12),
                const Text('Export CSV'),
              ]),
            ),
            PopupMenuItem(
              value: 'export_pdf',
              child: Row(children: [
                const Icon(Icons.picture_as_pdf_outlined, size: 20),
                const SizedBox(width: 12),
                const Text('Export PDF'),
              ]),
            ),
            PopupMenuItem(
              value: 'auto_refresh',
              child: Row(children: [
                Icon(
                  filter.autoRefresh
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(filter.autoRefresh
                    ? 'Pause Auto-refresh'
                    : 'Enable Auto-refresh'),
              ]),
            ),
            const PopupMenuItem(
              value: 'reset',
              child: Row(children: [
                Icon(Icons.refresh_rounded, size: 20),
                SizedBox(width: 12),
                Text('Reset Filters'),
              ]),
            ),
          ],
        ),
      ],
      systemOverlayStyle:
          isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
  }

  // ── Hero Summary ──
  Widget _buildHeroSummary(
      ThemeData theme, bool isDark, TodayPaymentData data) {
    final total = data.allPayments.length;
    final collected =
        data.allPayments.where((p) => p.isCollected).length;
    final pending =
        data.allPayments.where((p) => p.isPending).length;
    final overdue =
        data.allPayments.where((p) => p.isOverdue).length;
    final progress = total > 0 ? collected / total : 0.0;
    final totalExpected = data.allPayments.fold<double>(
        0, (sum, p) => sum + p.amountExpected);
    final totalCollected = data.allPayments
        .where((p) => p.isCollected)
        .fold<double>(0, (sum, p) => sum + (p.amountCollected ?? p.amountExpected));
    final f = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                : [const Color(0xFF667EEA), const Color(0xFF764BA2)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Ambient orbs
            Positioned(
              top: -20,
              right: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              bottom: -15,
              left: 40,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            // Content
            Row(
              children: [
                // Progress ring
                ProgressGauge(
                  value: progress,
                  size: 80,
                  strokeWidth: 6,
                  progressColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '$collected/$total',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.format(totalExpected),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Collected: ${f.format(totalCollected)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _miniBadge('$pending', 'Pending',
                              const Color(0xFFFBBF24)),
                          const SizedBox(width: 8),
                          _miniBadge(
                              '$overdue', 'Overdue', const Color(0xFFEF4444)),
                          const SizedBox(width: 8),
                          _miniBadge(
                              '$collected', 'Done', const Color(0xFF34D399)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _miniBadge(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(count,
              style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          Text(label,
              style: TextStyle(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildHeroLoading(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  // ── Quick Stats ──
  Widget _buildQuickStats(
      ThemeData theme, bool isDark, TodayPaymentData data) {
    final emiPayments =
        data.allPayments.where((p) => p.type == PaymentType.emi).toList();
    final savingsPayments =
        data.allPayments.where((p) => p.type == PaymentType.savings).toList();
    final f = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final emiTotal = emiPayments.fold<double>(0, (s, p) => s + p.amountExpected);
    final savingsTotal =
        savingsPayments.fold<double>(0, (s, p) => s + p.amountExpected);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumHelpers.sectionHeader(theme, 'Quick Overview'),
          Row(
            children: [
              Expanded(
                  child: _statChip(theme, isDark, Icons.account_balance_rounded,
                      'EMI', f.format(emiTotal), '${emiPayments.length} dues')),
              const SizedBox(width: 10),
              Expanded(
                  child: _statChip(
                      theme,
                      isDark,
                      Icons.savings_rounded,
                      'Savings',
                      f.format(savingsTotal),
                      '${savingsPayments.length} plans')),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 300.ms);
  }

  Widget _statChip(ThemeData theme, bool isDark, IconData icon, String label,
      String amount, String sub) {
    final color = AppColors.primary;
    return GlassCard(
      backgroundColor: color.withValues(alpha: 0.05),
      borderRadius: 16,
      padding: const EdgeInsets.all(14),
      enableScale: false,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(amount,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87)),
                Text(sub,
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab Bar ──
  Widget _buildTabBar(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        height: 40,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}),
          indicator: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          labelColor: Colors.white,
          unselectedLabelColor:
              isDark ? Colors.white54 : Colors.black54,
          labelStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Overdue'),
            Tab(text: 'Collected'),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 300.ms);
  }

  // ── Search Field ──
  Widget _buildSearchField(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: _onSearchChanged,
        style: TextStyle(
            color: isDark ? Colors.white : Colors.black87, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search member, phone, loan number...',
          hintStyle: TextStyle(
              color: isDark ? Colors.white30 : Colors.black38, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded,
              color: isDark ? Colors.white30 : Colors.black38, size: 20),
          filled: true,
          fillColor: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  // ── Date & Sort Row ──
  Widget _buildDateSortRow(ThemeData theme, bool isDark,
      BranchPaymentFilterState filter, String branchId) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          // Date navigator
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: filter.selectedDate,
                firstDate: DateTime(2024),
                lastDate: DateTime.now().add(const Duration(days: 7)),
              );
              if (picked != null) {
                ref.read(branchPaymentFilterProvider.notifier).setDate(picked);
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    iconSize: 18,
                    onPressed: () {
                      ref.read(branchPaymentFilterProvider.notifier).setDate(
                          filter.selectedDate
                              .subtract(const Duration(days: 1)));
                    },
                    icon: Icon(Icons.chevron_left,
                        color: isDark ? Colors.white54 : Colors.black54),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    filter.isToday
                        ? 'Today'
                        : DateFormat('dd MMM').format(filter.selectedDate),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    iconSize: 18,
                    onPressed: filter.selectedDate.isBefore(
                            DateTime.now().add(const Duration(days: 7)))
                        ? () {
                            ref
                                .read(branchPaymentFilterProvider.notifier)
                                .setDate(filter.selectedDate
                                    .add(const Duration(days: 1)));
                          }
                        : null,
                    icon: Icon(Icons.chevron_right,
                        color: isDark ? Colors.white54 : Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Sort chip
          GestureDetector(
            onTap: () => _showSortSheet(context, isDark),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_vert,
                      size: 16,
                      color: isDark ? Colors.white54 : Colors.black54),
                  const SizedBox(width: 4),
                  Text(
                    _sortLabel(filter.sortBy),
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Payment Card ──
  Widget _buildPaymentCard(BuildContext context, ThemeData theme, bool isDark,
      TodayPayment payment, int index, String branchId) {
    final f = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: () => _showPaymentDetails(context, isDark, payment),
        borderRadius: 16,
        padding: const EdgeInsets.all(14),
        borderColor: _statusBorderColor(payment.status, isDark),
        enableScale: true,
        child: Column(
          children: [
            Row(
              children: [
                // Type icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _typeColor(payment.type)
                        .withValues(alpha: isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    payment.type == PaymentType.emi
                        ? Icons.account_balance_rounded
                        : Icons.savings_rounded,
                    size: 18,
                    color: _typeColor(payment.type),
                  ),
                ),
                const SizedBox(width: 12),
                // Member info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.memberName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (payment.loanNumber != null) ...[
                            Text(
                              payment.loanNumber!,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white38
                                    : Colors.black38,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (payment.planName != null) ...[
                            Text(
                              payment.planName!,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white38
                                    : Colors.black38,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Amount + status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      f.format(payment.amountExpected),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _statusColor(payment.status),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor(payment.status)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _statusLabel(payment.status),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _statusColor(payment.status),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Bottom row: actions
            if (!payment.isCollected) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (payment.memberPhone != null)
                    _actionChip(
                      Icons.phone_rounded,
                      'Call',
                      const Color(0xFF10B981),
                      () => _callMember(payment.memberPhone!),
                    ),
                  const SizedBox(width: 8),
                  _actionChip(
                    Icons.check_circle_outline_rounded,
                    'Collect',
                    AppColors.primary,
                    () => _showQuickCollectSheet(
                        context, isDark, payment, branchId),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(
          delay: Duration(milliseconds: 50 * index.clamp(0, 10)),
          duration: 300.ms,
        ).slideY(begin: 0.03, end: 0);
  }

  Widget _actionChip(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }

  // ── Quick Collect FAB ──
  Widget _buildQuickCollectFab(ThemeData theme, bool isDark, String branchId) {
    return FloatingActionButton.extended(
      onPressed: () => _showQuickCollectSheet(
          context, isDark, null, branchId),
      backgroundColor: AppColors.primary,
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      label: const Text('Quick Collect',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }

  // ── Empty State ──
  Widget _buildEmptyState(ThemeData theme, bool isDark, int tabIndex) {
    final messages = [
      ['No pending payments', 'All payments for this date are collected!'],
      ['No overdue payments', 'Great job! No overdue payments found.'],
      ['No collections yet', 'Start collecting to see results here.'],
    ];
    final icons = [
      Icons.check_circle_outline_rounded,
      Icons.celebration_rounded,
      Icons.hourglass_empty_rounded,
    ];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icons[tabIndex],
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(messages[tabIndex][0],
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            Text(messages[tabIndex][1],
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white38 : Colors.black38)),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95));
  }

  // ── Error Widget ──
  Widget _buildErrorWidget(ThemeData theme, bool isDark, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            Text('Something went wrong',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            Text(error.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : Colors.black38)),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──
  List<TodayPayment> _getTabData(TodayPaymentData data) {
    switch (_tabController.index) {
      case 0:
        return data.payments
            .where((p) => p.status == PaymentStatus.pending)
            .toList();
      case 1:
        return data.payments
            .where((p) => p.status == PaymentStatus.overdue)
            .toList();
      case 2:
        return data.payments
            .where((p) => p.status == PaymentStatus.collected)
            .toList();
      default:
        return data.payments;
    }
  }

  String _statusLabel(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.overdue:
        return 'Overdue';
      case PaymentStatus.collected:
        return 'Collected';
    }
  }

  Color _statusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return const Color(0xFFFBBF24);
      case PaymentStatus.overdue:
        return const Color(0xFFEF4444);
      case PaymentStatus.collected:
        return const Color(0xFF34D399);
    }
  }

  Color _statusBorderColor(PaymentStatus status, bool isDark) {
    switch (status) {
      case PaymentStatus.overdue:
        return const Color(0xFFEF4444).withValues(alpha: 0.2);
      default:
        return isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04);
    }
  }

  Color _typeColor(PaymentType type) {
    switch (type) {
      case PaymentType.emi:
        return const Color(0xFF667EEA);
      case PaymentType.savings:
        return const Color(0xFF10B981);
    }
  }

  String _sortLabel(PaymentSortBy sortBy) {
    switch (sortBy) {
      case PaymentSortBy.statusPriority:
        return 'Status';
      case PaymentSortBy.nameAsc:
        return 'Name A-Z';
      case PaymentSortBy.nameDesc:
        return 'Name Z-A';
      case PaymentSortBy.amountHigh:
        return 'Amount ↓';
      case PaymentSortBy.amountLow:
        return 'Amount ↑';
      case PaymentSortBy.dueDateOldest:
        return 'Oldest';
      case PaymentSortBy.dueDateNewest:
        return 'Newest';
      case PaymentSortBy.branchAsc:
        return 'Branch';
    }
  }

  void _showSortSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2030) : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Sort by',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 16),
              ...PaymentSortBy.values.map((sortBy) {
                final current =
                    ref.read(branchPaymentFilterProvider).sortBy;
                final isSelected = current == sortBy;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: GlassCard(
                    onTap: () {
                      ref
                          .read(branchPaymentFilterProvider.notifier)
                          .setSortBy(sortBy);
                      Navigator.pop(ctx);
                    },
                    borderRadius: 12,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    borderColor: isSelected
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : null,
                    enableScale: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(_sortLabel(sortBy),
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  color: isDark ? Colors.white : Colors.black87)),
                        ),
                        if (isSelected)
                          Icon(Icons.check_rounded, color: AppColors.primary, size: 20),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentDetails(
      BuildContext context, bool isDark, TodayPayment payment) {
    final f = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2030) : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(payment.memberName,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 16),
              _detailRow('Type', payment.type == PaymentType.emi ? 'EMI' : 'Savings', isDark),
              _detailRow('Amount', f.format(payment.amountExpected), isDark),
              if (payment.loanNumber != null)
                _detailRow('Loan #', payment.loanNumber!, isDark),
              if (payment.planName != null)
                _detailRow('Plan', payment.planName!, isDark),
              _detailRow('Status', _statusLabel(payment.status), isDark),
              if (payment.paymentMode != null)
                _detailRow('Mode', payment.paymentMode!, isDark),
              if (payment.collectedAt != null)
                _detailRow('Collected At',
                    DateFormat('dd MMM yyyy, hh:mm a').format(payment.collectedAt!), isDark),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black54)),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87)),
        ],
      ),
    );
  }

  void _callMember(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showQuickCollectSheet(BuildContext context, bool isDark,
      TodayPayment? payment, String branchId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuickCollectSheet(
        payment: payment,
        isDark: isDark,
        onCollected: () {
          ref.invalidate(branchTodayPaymentsProvider(branchId));
          ref.invalidate(branchCollectionStatsProvider(branchId));
        },
      ),
    );
  }

  Future<void> _exportPayments(
      BuildContext context, String branchId, String format) async {
    final data = ref.read(branchTodayPaymentsProvider(branchId));
    final filter = ref.read(branchPaymentFilterProvider);
    data.when(
      data: (paymentData) async {
        await PaymentExport.shareCsv(paymentData.payments, filter.dateLabel);
      },
      loading: () {},
      error: (_, __) {},
    );
  }
}

// ── Quick Collect Bottom Sheet ──
class _QuickCollectSheet extends ConsumerStatefulWidget {
  final TodayPayment? payment;
  final bool isDark;
  final VoidCallback onCollected;

  const _QuickCollectSheet({
    this.payment,
    required this.isDark,
    required this.onCollected,
  });

  @override
  ConsumerState<_QuickCollectSheet> createState() => _QuickCollectSheetState();
}

class _QuickCollectSheetState extends ConsumerState<_QuickCollectSheet> {
  final _amountController = TextEditingController();
  String _paymentMode = 'cash';
  final _remarkController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.payment != null) {
      _amountController.text =
          widget.payment!.amountExpected.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final payment = widget.payment;

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2030) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              payment != null
                  ? 'Collect from ${payment.memberName}'
                  : 'Quick Collect',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            // Amount
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 24,
                  fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: 'Amount',
                labelStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38),
                prefixText: '₹ ',
                prefixStyle: TextStyle(
                    color: AppColors.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Payment mode
            Text('Payment Mode',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 8),
            Row(
              children: ['cash', 'upi', 'bank_transfer', 'cheque'].map((mode) {
                final isActive = _paymentMode == mode;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: GestureDetector(
                      onTap: () => setState(() => _paymentMode = mode),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.primary
                              : isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isActive
                                ? AppColors.primary
                                : isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Text(
                          mode == 'bank_transfer' ? 'Bank' : mode.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? Colors.white
                                : isDark
                                    ? Colors.white70
                                    : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Remark
            GlassTextField(
              controller: _remarkController,
              labelText: 'Remark (optional)',
            ),
            const SizedBox(height: 20),
            // Submit
            GlassButton(
              label: 'Record Collection',
              onTap: _submitting ? null : _submit,
              isPrimary: true,
              isLoading: _submitting,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    setState(() => _submitting = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final profile = await ref.read(staffProfileProvider.future);
      if (profile == null) throw Exception('Staff profile not found');

      await client.from('collections').insert({
        'org_id': profile.orgId,
        'staff_id': profile.id,
        'member_id': widget.payment?.memberId,
        'member_name': widget.payment?.memberName ?? 'Quick Collect',
        'member_phone': widget.payment?.memberPhone,
        'loan_id': widget.payment?.loanId,
        'loan_number': widget.payment?.loanNumber,
        'amount_expected': widget.payment?.amountExpected ?? amount,
        'amount_collected': amount,
        'collection_type':
            widget.payment?.type == PaymentType.savings ? 'savings' : 'emi',
        'payment_mode': _paymentMode,
        'collection_date':
            DateTime.now().toIso8601String().split('T').first,
        'collection_time': DateTime.now().toIso8601String(),
        'remarks': _remarkController.text.isNotEmpty
            ? _remarkController.text
            : null,
        'collector_name': profile.fullName,
        'collector_role': profile.role.displayName,
      });

      widget.onCollected();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '₹${amount.toStringAsFixed(0)} collected successfully'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
