import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../payments/data/models/today_payment_model.dart';
import '../../../payments/data/providers/payment_providers.dart' show TodayPaymentData;
import '../../../payments/data/utils/payment_export.dart';
import '../../../loans/presentation/widgets/collection_sheet.dart';
import '../../../savings/data/models/savings_model.dart';
import '../../../loans/data/models/loan_model.dart';
import '../../../../core/widgets/premium_calendar_sheet.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../data/providers/branch_payment_providers.dart';
import '../../../payments/data/services/auto_collection_service.dart';
import '../../../staff/data/providers/collection_providers.dart';

class BranchTodayPaymentsPage extends ConsumerStatefulWidget {
  const BranchTodayPaymentsPage({super.key});

  @override
  ConsumerState<BranchTodayPaymentsPage> createState() =>
      _BranchTodayPaymentsPageState();
}

class _BranchTodayPaymentsPageState
    extends ConsumerState<BranchTodayPaymentsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showSearch = false;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final newScrolled = _scrollController.offset > 80;
    if (newScrolled != _isScrolled) {
      setState(() => _isScrolled = newScrolled);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
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

  Future<void> _pickDate() async {
    final filters = ref.read(branchPaymentFilterProvider);
    final picked = await PremiumCalendarSheet.show(
      context: context,
      initialDate: filters.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      ref.read(branchPaymentFilterProvider.notifier).setDate(picked);
    }
  }

  void _showSortSheet() {
    final filters = ref.read(branchPaymentFilterProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Sort By',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            ...PaymentSortBy.values.map((sort) => ListTile(
                  title: Text(sort.label),
                  trailing: filters.sortBy == sort
                      ? Icon(Icons.check_circle, color: AppColors.primary)
                      : null,
                  onTap: () {
                    ref
                        .read(branchPaymentFilterProvider.notifier)
                        .setSortBy(sort);
                    Navigator.pop(ctx);
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet() {
    final filters = ref.read(branchPaymentFilterProvider);
    final user = ref.read(currentUserProvider);
    final branchId = user?.branchId;
    if (branchId == null) return;

    final agentsAsync = ref.watch(branchPaymentAgentsProvider(branchId));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Filters',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  TextButton(
                    onPressed: () {
                      ref
                          .read(branchPaymentFilterProvider.notifier)
                          .resetFilters();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Agent',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              agentsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (agents) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All Agents'),
                      selected: filters.agentId == null,
                      onSelected: (_) {
                        ref
                            .read(branchPaymentFilterProvider.notifier)
                            .setAgent(null);
                      },
                      selectedColor:
                          AppColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.primary,
                    ),
                    ...agents.map((a) => FilterChip(
                          label: Text(a['name']!),
                          selected: filters.agentId == a['id'],
                          onSelected: (_) {
                            ref
                                .read(branchPaymentFilterProvider.notifier)
                                .setAgent(a['id']);
                          },
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          checkmarkColor: AppColors.primary,
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Apply Filters',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShareSheet(TodayPaymentData data) {
    final filters = ref.read(branchPaymentFilterProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Export & Share',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.share_rounded,
                    color: AppColors.primary, size: 20),
              ),
              title: const Text('Share Summary'),
              subtitle: const Text('Share text summary via any app'),
              onTap: () async {
                Navigator.pop(ctx);
                final text = PaymentExport.generateSummaryText(
                    data, filters.dateLabel);
                await SharePlus.instance.share(
                  ShareParams(
                    text: text,
                    subject: 'Payments - ${filters.dateLabel}',
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.table_chart_rounded,
                    color: AppColors.success, size: 20),
              ),
              title: const Text('Export CSV'),
              subtitle: const Text('Download payment data as CSV file'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await PaymentExport.shareCsv(
                      data.allPayments, filters.dateLabel);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Export failed: $e'),
                      backgroundColor: Colors.redAccent,
                    ));
                  }
                }
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.copy_rounded,
                    color: AppColors.info, size: 20),
              ),
              title: const Text('Copy Summary'),
              subtitle: const Text('Copy summary to clipboard'),
              onTap: () async {
                Navigator.pop(ctx);
                final text = PaymentExport.generateSummaryText(
                    data, filters.dateLabel);
                await Clipboard.setData(ClipboardData(text: text));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Summary copied to clipboard'),
                    backgroundColor: AppColors.success,
                  ));
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _sendReminder(TodayPayment payment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Send Reminder'),
        content: Text('Send payment reminder to ${payment.memberName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Reminder sent to ${payment.memberName}'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSavingsCollection(TodayPayment payment) async {
    final client = ref.read(supabaseClientProvider);
    final planId = payment.id.endsWith('_today')
        ? payment.id.substring(0, payment.id.length - 6)
        : payment.id;
    try {
      final response = await client
          .from('savings_plans')
          .select('*, members:member_id(full_name, phone)')
          .eq('id', planId)
          .maybeSingle();
      if (response != null && mounted) {
        final plan = SavingsModel.fromJson(response);
        Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => CollectionSheet.savings(savingsPlan: plan),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load savings plan: $e')),
        );
      }
    }
  }

  Future<void> _openEmiCollection(TodayPayment payment) async {
    if (payment.loanId == null) return;
    try {
      final client = ref.read(supabaseClientProvider);
      final response = await client
          .from('loans')
          .select('*, members:customer_id(full_name, phone)')
          .eq('id', payment.loanId!)
          .maybeSingle();
      if (response != null && mounted) {
        final loan = LoanModel.fromJson(response);
        Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => CollectionSheet(loan: loan),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load loan: $e')),
        );
      }
    }
  }

  void _showQuickCollect(TodayPayment payment) {
    if (payment.type == PaymentType.savings) {
      _openSavingsCollection(payment);
    } else if (payment.type == PaymentType.emi && payment.loanId != null) {
      _openEmiCollection(payment);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to collect — missing payment data')),
      );
    }
  }

  Future<void> _performAutoCollection(TodayPayment payment) async {
    final client = ref.read(supabaseClientProvider);
    final user = ref.read(currentUserProvider);
    final branchId = user?.branchId;
    if (user == null || user.orgId == null || branchId == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text('Processing collection for ${payment.memberName}...'),
          ],
        ),
        duration: const Duration(days: 1),
      ),
    );

    try {
      final profile = await client
          .from('profiles')
          .select('id, full_name')
          .eq('user_id', user.id)
          .maybeSingle();
      final staffId = profile?['id'] as String?;
      if (staffId == null) throw Exception('Staff profile not found');
      final staffName = profile?['full_name']?.toString() ?? 'Branch Manager';

      if (payment.type == PaymentType.savings) {
        final userRole = user.role?.name ?? 'manager';
        await AutoCollectionService.autoCollectSavings(
          client: client,
          orgId: user.orgId!,
          staffId: staffId,
          staffName: staffName,
          staffRole: userRole,
          payment: payment,
        );
      } else {
        await AutoCollectionService.autoCollectEmi(
          client: client,
          orgId: user.orgId!,
          staffId: staffId,
          payment: payment,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-collected \u20b9${payment.amountExpected.toStringAsFixed(0)} cash for ${payment.memberName}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-collect failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      ref.invalidate(branchTodayPaymentsProvider(branchId));
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final branchId = user?.branchId;
    final filters = ref.watch(branchPaymentFilterProvider);

    ref.watch(branchAutoRefreshTimerProvider);

    if (branchId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Today's Payments")),
        body:
            const Center(child: Text('No branch assigned to your profile.')),
      );
    }

    final paymentsAsync =
        ref.watch(branchTodayPaymentsProvider(branchId));

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : const Color(0xFFF5F6FA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: _isScrolled
            ? (isDark
                ? AppColors.surfaceDark.withValues(alpha: 0.88)
                : AppColors.surfaceLight.withValues(alpha: 0.88))
            : Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: _isScrolled
            ? ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    color: (isDark ? AppColors.surfaceDark : AppColors.surfaceLight)
                        .withValues(alpha: 0.72),
                  ),
                ),
              )
            : null,
        leading: _showSearch
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _clearSearch,
              )
            : null,
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search customer, phone, loan...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 18,
                              color: isDark ? Colors.white54 : Colors.black45),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                ),
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black),
              )
            : GestureDetector(
                onTap: _pickDate,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      filters.isToday
                          ? "Today's Payments"
                          : 'Payments - ${filters.dateLabel}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color:
                            isDark ? Colors.white54 : Colors.black54),
                  ],
                ),
              ),
        actions: [
          if (!_showSearch) ...[
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () => setState(() => _showSearch = true),
            ),
            IconButton(
              icon: Icon(
                Icons.filter_list_rounded,
                color: filters.agentId != null ? AppColors.primary : null,
              ),
              onPressed: _showFilterSheet,
            ),
            PopupMenuButton(
              icon: const Icon(Icons.more_vert_rounded),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  child: ListTile(
                    leading: Icon(
                      filters.autoRefresh
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      size: 20,
                    ),
                    title: Text(filters.autoRefresh
                        ? 'Pause Auto-refresh'
                        : 'Enable Auto-refresh'),
                    dense: true,
                  ),
                  onTap: () => ref
                      .read(branchPaymentFilterProvider.notifier)
                      .toggleAutoRefresh(),
                ),
                PopupMenuItem(
                  child: const ListTile(
                    leading: Icon(Icons.sort_rounded, size: 20),
                    title: Text('Sort'),
                    dense: true,
                  ),
                  onTap: () => Future.delayed(
                      Duration.zero, () => _showSortSheet()),
                ),
                PopupMenuItem(
                  child: const ListTile(
                    leading: Icon(Icons.refresh_rounded, size: 20),
                    title: Text('Refresh'),
                    dense: true,
                  ),
                  onTap: () => ref.invalidate(
                      branchTodayPaymentsProvider(branchId)),
                ),
              ],
            ),
          ],
        ],
      ),
      body: paymentsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline,
                      size: 48, color: AppColors.error),
                ),
                const SizedBox(height: 16),
                Text('Something went wrong',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight)),
                const SizedBox(height: 8),
                Text('$e',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(
                      branchTodayPaymentsProvider(branchId)),
                  icon:
                      const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          final summary = data.summary;
          final pending = data.pendingPayments;
          final collected = data.collectedPayments;
          final overdue = data.overduePayments;

          return CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Scrollable compact hero header
              SliverToBoxAdapter(
                child: _HeroHeader(
                  summary: summary,
                  isDark: isDark,
                ),
              ),

              // Active Filters
              if (filters.agentId != null)
                SliverToBoxAdapter(
                  child: _buildActiveFilters(filters, isDark),
                ),

              // ── Tab Bar ──
              SliverToBoxAdapter(
                child: _PremiumTabBar(
                  controller: _tabController,
                  pendingCount: pending.length,
                  overdueCount: overdue.length,
                  collectedCount: collected.length,
                  isDark: isDark,
                ),
              ),

              // ── Tab Content ──
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPaymentList(pending, overdue, isDark,
                        'No pending payments', Icons.schedule_rounded),
                    _buildPaymentList(overdue, overdue, isDark,
                        'No overdue payments',
                        Icons.warning_amber_rounded),
                    _buildPaymentList(collected, overdue, isDark,
                        'No collections yet',
                        Icons.check_circle_outline_rounded),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: paymentsAsync.maybeWhen(
        data: (data) => FloatingActionButton.extended(
          onPressed: () => _showShareSheet(data),
          icon: const Icon(Icons.ios_share_rounded, size: 20),
          label: const Text('Export',
              style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        orElse: () => null,
      ),
    );
  }



  Widget _buildActiveFilters(
      BranchPaymentFilterState filters, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_rounded,
              size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Filtered by: Agent',
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500),
            ),
          ),
          GestureDetector(
            onTap: () => ref
                .read(branchPaymentFilterProvider.notifier)
                .resetFilters(),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Clear',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentList(List<TodayPayment> payments, List<TodayPayment> overduePayments, bool isDark,
      String emptyMessage, IconData emptyIcon) {
    if (payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: (isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight)
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(emptyIcon,
                  size: 48,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight),
            ),
            const SizedBox(height: 16),
            Text(emptyMessage,
                style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    final user = ref.read(currentUserProvider);
    final branchId = user?.branchId ?? '';

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(branchTodayPaymentsProvider(branchId));
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: payments.length,
        itemBuilder: (context, index) {
          final p = payments[index];
          final onCallFn = p.memberPhone != null
              ? () => _makePhoneCall(p.memberPhone!)
              : null;
          void onRemindFn() => _sendReminder(p);
          final onCollectFn = !p.isCollected
              ? () {
                  final hasOverdues = p.isOverdue || overduePayments.any((o) => o.memberId == p.memberId && p.memberId != null);
                  if (hasOverdues) {
                    _showQuickCollect(p);
                  } else {
                    _performAutoCollection(p);
                  }
                }
              : null;

          final card = _PaymentCard(
            payment: p,
            isDark: isDark,
            onCall: onCallFn,
            onRemind: onRemindFn,
            onTap: () => _showPaymentDetails(p),
            onCollect: onCollectFn,
          );

          if (p.isCollected) {
            return card;
          }

          return Dismissible(
            key: ValueKey('pay_${p.id}'),
            direction: DismissDirection.horizontal,
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                if (onCollectFn != null) {
                  HapticFeedback.mediumImpact();
                  onCollectFn();
                }
              } else if (direction == DismissDirection.endToStart) {
                if (onCallFn != null) {
                  HapticFeedback.lightImpact();
                  onCallFn();
                } else {
                  HapticFeedback.lightImpact();
                  onRemindFn();
                }
              }
              return false;
            },
            background: onCollectFn != null
                ? const _SwipeBackground(
                    icon: Icons.payment_rounded,
                    label: 'Collect',
                    color: AppColors.success,
                    align: Alignment.centerLeft,
                  )
                : null,
            secondaryBackground: _SwipeBackground(
              icon: onCallFn != null ? Icons.call_rounded : Icons.notifications_active_rounded,
              label: onCallFn != null ? 'Call' : 'Remind',
              color: onCallFn != null ? AppColors.success : AppColors.warning,
              align: Alignment.centerRight,
            ),
            child: card,
          );
        },
      ),
    );
  }

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not launch phone dialer'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  void _showPaymentDetails(TodayPayment payment) {
    final currencyFormat =
        NumberFormat.currency(symbol: '\u20b9', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: payment.typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(payment.typeIcon,
                        color: payment.typeColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(payment.memberName,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: payment.statusColor
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(payment.statusLabel,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: payment.statusColor)),
                        ),
                      ],
                    ),
                  ),
                  Text(currencyFormat.format(payment.amountExpected),
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: payment.statusColor)),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _DetailRow('Type', payment.typeLabel),
                    if (payment.loanNumber != null)
                      _DetailRow('Loan Number', payment.loanNumber!),
                    if (payment.emiNumber != null)
                      _DetailRow(
                          'EMI Number', '#${payment.emiNumber}'),
                    if (payment.planName != null)
                      _DetailRow('Savings Plan', payment.planName!),
                    _DetailRow(
                        'Due Date', dateFormat.format(payment.dueDate)),
                    if (payment.isOverdue)
                      _DetailRow('Overdue', payment.overdueLabel,
                          valueColor: Colors.red),
                    if (payment.penaltyAmount > 0)
                      _DetailRow('Penalty',
                          currencyFormat.format(payment.penaltyAmount),
                          valueColor: Colors.red),
                    if (payment.memberPhone != null)
                      _DetailRow('Phone', payment.memberPhone!),
                    if (payment.paymentMode != null)
                      _DetailRow('Payment Mode',
                          payment.paymentMode!.toUpperCase()),
                    if (payment.collectedAt != null)
                      _DetailRow(
                          'Collected At',
                          DateFormat('dd MMM yyyy, hh:mm a')
                              .format(payment.collectedAt!)),
                    if (payment.remarks != null &&
                        payment.remarks!.isNotEmpty)
                      _DetailRow('Remarks', payment.remarks!),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (payment.memberPhone != null)
                    _DetailActionButton(
                      icon: Icons.call_rounded,
                      color: AppColors.success,
                      onTap: () {
                        Navigator.pop(ctx);
                        _makePhoneCall(payment.memberPhone!);
                      },
                    ),
                  if (payment.memberPhone != null &&
                      !payment.isCollected)
                    const SizedBox(width: 14),
                  if (!payment.isCollected) ...[
                    _DetailActionButton(
                      icon: Icons.notifications_active_rounded,
                      color: AppColors.warning,
                      onTap: () {
                        Navigator.pop(ctx);
                        _sendReminder(payment);
                      },
                    ),
                    const SizedBox(width: 14),
                    _DetailActionButton(
                      icon: Icons.payment_rounded,
                      color: AppColors.primary,
                      onTap: () {
                        Navigator.pop(ctx);
                        _showQuickCollect(payment);
                      },
                    ),
                  ],
                  if (payment.isCollected && payment.collectionId != null) ...[
                    const SizedBox(width: 14),
                    _DetailActionButton(
                      icon: Icons.delete_outline_rounded,
                      color: AppColors.error,
                      onTap: () {
                        Navigator.pop(ctx);
                        _confirmDeleteCollection(payment);
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteCollection(TodayPayment payment) {
    final currencyFormat = NumberFormat.currency(symbol: '\u20b9', decimalDigits: 0);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 10),
            Text('Delete Collection', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          'Delete the ₹${currencyFormat.format(payment.amountCollected ?? payment.amountExpected)} collection from ${payment.memberName}?\n\nThis will revert the EMI status and restore the loan outstanding balance.',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Delete'),
            onPressed: () async {
              Navigator.pop(ctx);
              await _performDeleteCollection(payment);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteCollection(TodayPayment payment) async {
    if (payment.collectionId == null) return;

    try {
      final repository = ref.read(collectionRepositoryProvider);
      await repository.deleteCollection(payment.collectionId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Collection deleted. Loan balance restored by ₹${payment.amountCollected?.toInt() ?? payment.amountExpected.toInt()}.',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        ref.invalidate(branchTodayPaymentsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}

// ─── Stat Card ───
class _DetailActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DetailActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}



// ─── Detail Row ───
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? Colors.grey.shade900)),
          ),
        ],
      ),
    );
  }
}

// ─── Payment Card ───
class _SwipeBackground extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Alignment align;

  const _SwipeBackground({
    required this.icon,
    required this.label,
    required this.color,
    required this.align,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: align,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: align == Alignment.centerRight
            ? [
                Text(label,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(width: 6),
                Icon(icon, color: color, size: 18),
              ]
            : [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w800, fontSize: 13)),
              ],
      ),
    );
  }
}

// ─── Payment Card ───
class _PaymentCard extends StatelessWidget {
  final TodayPayment payment;
  final bool isDark;
  final VoidCallback? onCall;
  final VoidCallback onRemind;
  final VoidCallback onTap;
  final VoidCallback? onCollect;

  const _PaymentCard({
    required this.payment,
    required this.isDark,
    this.onCall,
    required this.onRemind,
    required this.onTap,
    this.onCollect,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\u20b9', decimalDigits: 0);
    final timeFormat = DateFormat('dd MMM, hh:mm a');
    final dateFormat = DateFormat('dd MMM yyyy');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: payment.statusColor.withValues(alpha: isDark ? 0.15 : 0.08),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : Colors.grey.shade100)
                  .withValues(alpha: isDark ? 0.25 : 0.45),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _PaymentAvatar(
                type: payment.type,
                label: payment.memberName,
                color: payment.typeColor,
                isCollected: payment.isCollected,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            payment.memberName,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: -0.2,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              currencyFormat.format(payment.amountExpected),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14.5,
                                letterSpacing: -0.4,
                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              ),
                            ),
                            if (payment.penaltyAmount > 0) ...[
                              const SizedBox(width: 3),
                              Text(
                                '+${currencyFormat.format(payment.penaltyAmount)}',
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${payment.typeLabel}'
                                '${payment.loanNumber != null ? ' \u00b7 ${payment.loanNumber}' : ''}'
                                '${payment.emiNumber != null ? ' #${payment.emiNumber}' : ''}'
                                '${payment.planName != null ? ' \u00b7 ${payment.planName}' : ''}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    payment.isCollected
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.schedule_rounded,
                                    size: 10,
                                    color: payment.isOverdue
                                        ? AppColors.error
                                        : (payment.isCollected
                                            ? AppColors.success
                                            : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)),
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      payment.isCollected && payment.collectedAt != null
                                          ? 'Collected ${timeFormat.format(payment.collectedAt!)}'
                                          : 'Due ${dateFormat.format(payment.dueDate)}',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: payment.isOverdue
                                            ? AppColors.error
                                            : (payment.isCollected
                                                ? AppColors.success
                                                : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!payment.isCollected)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (onCall != null)
                                _ActionCircle(
                                  icon: Icons.call_rounded,
                                  color: AppColors.success,
                                  onTap: () { HapticFeedback.lightImpact(); onCall!(); },
                                ),
                              if (onCall != null) const SizedBox(width: 5),
                              _ActionCircle(
                                icon: Icons.notifications_active_rounded,
                                color: AppColors.warning,
                                onTap: () { HapticFeedback.lightImpact(); onRemind(); },
                              ),
                              if (onCollect != null) ...[
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () { HapticFeedback.mediumImpact(); onCollect!(); },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: AppColors.successGradient),
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.success.withValues(alpha: 0.2),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1.5),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.payment_rounded, size: 10, color: Colors.white),
                                        SizedBox(width: 3),
                                        Text(
                                          'Collect',
                                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          )
                        else
                          _StatusPill(status: payment.status, type: payment.type),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentAvatar extends StatelessWidget {
  final PaymentType type;
  final String label;
  final Color color;
  final bool isCollected;

  const _PaymentAvatar({
    required this.type,
    required this.label,
    required this.color,
    required this.isCollected,
  });

  @override
  Widget build(BuildContext context) {
    final initial = label.isNotEmpty ? label[0].toUpperCase() : '?';
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: isCollected ? 0.08 : 0.18),
            color.withValues(alpha: isCollected ? 0.02 : 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: isCollected ? 0.05 : 0.12),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: color.withValues(alpha: isCollected ? 0.5 : 0.85),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final PaymentStatus status;
  final PaymentType type;
  const _StatusPill({required this.status, required this.type});

  Color get _color {
    switch (status) {
      case PaymentStatus.collected:
        return AppColors.success;
      case PaymentStatus.overdue:
        return AppColors.error;
      case PaymentStatus.pending:
        return type == PaymentType.emi ? AppColors.warning : AppColors.mint;
    }
  }

  String get _label {
    switch (status) {
      case PaymentStatus.collected:
        return 'Done';
      case PaymentStatus.overdue:
        return 'Overdue';
      case PaymentStatus.pending:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (status == PaymentStatus.pending || status == PaymentStatus.overdue) {
      return const SizedBox.shrink();
    }
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCircle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCircle({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ─── Premium Redesigned Bento Header Widgets ───

class _HeroHeader extends StatelessWidget {
  final TodayPaymentSummary summary;
  final bool isDark;

  const _HeroHeader({
    required this.summary,
    required this.isDark,
  });

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '\u20b9${(amount / 1000).toStringAsFixed(0)}k';
    } else if (amount >= 1000) {
      return '\u20b9${(amount / 1000).toStringAsFixed(1)}k';
    } else {
      return '\u20b9${amount.toInt()}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\u20b9', decimalDigits: 0);
    final double progress = summary.countDue > 0
        ? summary.countCollected / summary.countDue
        : 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [
                        Color(0xFF050B18),
                        Color(0xFF0F172A),
                      ]
                    : const [
                        Color(0xFF0F172A),
                        Color(0xFF1E3A5F),
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.1),
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress row: label + % done
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL DUE TODAY',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${(progress * 100).toInt()}% Done',
                          style: const TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 60,
                          height: 4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              backgroundColor: Colors.white.withValues(alpha: 0.12),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Large Amount
                Text(
                  currencyFormat.format(summary.totalDue),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 16),
                // Stats Row below amount
                Row(
                  children: [
                    Expanded(child: _MiniStatBadge(
                      label: 'Done',
                      count: summary.countCollected,
                      amountString: _formatAmount(summary.totalCollected),
                      color: const Color(0xFF34D399),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _MiniStatBadge(
                      label: 'Pending',
                      count: summary.countPending,
                      amountString: _formatAmount(summary.totalPending),
                      color: const Color(0xFFFBBF24),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _MiniStatBadge(
                      label: 'Overdue',
                      count: summary.countOverdue,
                      amountString: _formatAmount(summary.totalOverdue),
                      color: const Color(0xFFF87171),
                    )),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStatBadge extends StatelessWidget {
  final String label;
  final int count;
  final String amountString;
  final Color color;

  const _MiniStatBadge({
    required this.label,
    required this.count,
    required this.amountString,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 7.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                amountString,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                '($count)',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumTabBar extends StatelessWidget {
  final TabController controller;
  final int pendingCount;
  final int overdueCount;
  final int collectedCount;
  final bool isDark;

  const _PremiumTabBar({
    required this.controller,
    required this.pendingCount,
    required this.overdueCount,
    required this.collectedCount,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.grey.shade100)
                .withValues(alpha: isDark ? 0.2 : 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
        indicatorSize: TabBarIndicatorSize.tab,
        labelPadding: EdgeInsets.zero,
        tabs: [
          _TabPill(
            label: 'Pending',
            count: pendingCount,
            index: 0,
            controller: controller,
            activeColor: AppColors.primary,
          ),
          _TabPill(
            label: 'Overdue',
            count: overdueCount,
            index: 1,
            controller: controller,
            activeColor: AppColors.error,
          ),
          _TabPill(
            label: 'Collected',
            count: collectedCount,
            index: 2,
            controller: controller,
            activeColor: AppColors.success,
          ),
        ],
      ),
    );
  }
}

class _TabPill extends AnimatedWidget {
  final String label;
  final int count;
  final int index;
  final TabController controller;
  final Color activeColor;

  const _TabPill({
    required this.label,
    required this.count,
    required this.index,
    required this.controller,
    required this.activeColor,
  }) : super(listenable: controller);

  @override
  Widget build(BuildContext context) {
    final bool isSelected = controller.index == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? activeColor : Colors.transparent,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : (isDark
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppColors.primary : Colors.grey.shade700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

