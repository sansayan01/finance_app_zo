import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/today_payment_model.dart';
import '../../data/providers/payment_providers.dart';
import '../../data/utils/payment_export.dart';

class TodayPaymentsPage extends ConsumerStatefulWidget {
  const TodayPaymentsPage({super.key});

  @override
  ConsumerState<TodayPaymentsPage> createState() => _TodayPaymentsPageState();
}

class _TodayPaymentsPageState extends ConsumerState<TodayPaymentsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  bool _showSearch = false;
  bool _showBranchBreakdown = false;

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
    ref.read(paymentFilterProvider.notifier).setSearchQuery(query);
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(paymentFilterProvider.notifier).setSearchQuery('');
    setState(() => _showSearch = false);
  }

  Future<void> _pickDate() async {
    final filters = ref.read(paymentFilterProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: filters.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      ref.read(paymentFilterProvider.notifier).setDate(picked);
    }
  }

  void _showSortSheet() {
    final filters = ref.read(paymentFilterProvider);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sort By',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            ...PaymentSortBy.values.map((sort) => ListTile(
                  title: Text(sort.label),
                  trailing: filters.sortBy == sort
                      ? Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    ref.read(paymentFilterProvider.notifier).setSortBy(sort);
                    Navigator.pop(ctx);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet() {
    final filters = ref.read(paymentFilterProvider);
    final branchesAsync = ref.read(paymentBranchesProvider);
    final agentsAsync = ref.read(paymentAgentsProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Filters',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  TextButton(
                    onPressed: () {
                      ref.read(paymentFilterProvider.notifier).resetFilters();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Branch filter
              const Text('Branch',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              branchesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (branches) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All Branches'),
                      selected: filters.branchId == null,
                      onSelected: (_) {
                        ref.read(paymentFilterProvider.notifier).setBranch(null);
                      },
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.primary,
                    ),
                    ...branches.map((b) => FilterChip(
                          label: Text(b['name']!),
                          selected: filters.branchId == b['id'],
                          onSelected: (_) {
                            ref
                                .read(paymentFilterProvider.notifier)
                                .setBranch(b['id']);
                          },
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          checkmarkColor: AppColors.primary,
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Agent filter
              const Text('Agent',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
                        ref.read(paymentFilterProvider.notifier).setAgent(null);
                      },
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.primary,
                    ),
                    ...agents.map((a) => FilterChip(
                          label: Text(a['name']!),
                          selected: filters.agentId == a['id'],
                          onSelected: (_) {
                            ref
                                .read(paymentFilterProvider.notifier)
                                .setAgent(a['id']);
                          },
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          checkmarkColor: AppColors.primary,
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Apply button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShareSheet(TodayPaymentData data) {
    final filters = ref.read(paymentFilterProvider);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Export & Share',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
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
              leading: const Icon(Icons.table_chart_rounded),
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
              leading: const Icon(Icons.copy_rounded),
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
                    backgroundColor: Colors.green,
                  ));
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _sendReminder(TodayPayment payment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Reminder'),
        content: Text(
            'Send payment reminder to ${payment.memberName}'
            '${payment.agentName != null ? ' and agent ${payment.agentName}' : ''}?'),
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
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ));
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final paymentsAsync = ref.watch(todayPaymentsProvider);
    final filters = ref.watch(paymentFilterProvider);

    // Start auto-refresh
    ref.watch(autoRefreshTimerProvider);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1219) : const Color(0xFFF8F9FC),
      appBar: AppBar(
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
                ),
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              )
            : Text(filters.isToday
                ? "Today's Payments"
                : 'Payments - ${filters.dateLabel}'),
        backgroundColor: isDark ? const Color(0xFF1A1D2E) : Colors.white,
        elevation: 0,
        leading: _showSearch
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _clearSearch,
              )
            : null,
        actions: [
          if (!_showSearch) ...[
            // Date picker
            IconButton(
              icon: Icon(
                filters.isToday
                    ? Icons.calendar_today_rounded
                    : Icons.event_rounded,
                color: filters.isToday ? null : AppColors.primary,
              ),
              onPressed: _pickDate,
              tooltip: 'Select Date',
            ),
            // Search
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () => setState(() => _showSearch = true),
              tooltip: 'Search',
            ),
            // Filter
            IconButton(
              icon: Icon(
                Icons.filter_list_rounded,
                color: (filters.branchId != null || filters.agentId != null)
                    ? AppColors.primary
                    : null,
              ),
              onPressed: _showFilterSheet,
              tooltip: 'Filters',
            ),
            // Sort
            IconButton(
              icon: const Icon(Icons.sort_rounded),
              onPressed: _showSortSheet,
              tooltip: 'Sort',
            ),
            // More options
            PopupMenuButton(
              icon: const Icon(Icons.more_vert_rounded),
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
                  onTap: () =>
                      ref.read(paymentFilterProvider.notifier).toggleAutoRefresh(),
                ),
                PopupMenuItem(
                  child: const ListTile(
                    leading: Icon(Icons.refresh_rounded, size: 20),
                    title: Text('Refresh Now'),
                    dense: true,
                  ),
                  onTap: () => ref.invalidate(todayPaymentsProvider),
                ),
              ],
            ),
          ],
        ],
      ),
      body: paymentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text('Error: $e', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(todayPaymentsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) {
          final summary = data.summary;
          final pending = data.pendingPayments;
          final collected = data.collectedPayments;
          final overdue = data.overduePayments;

          return Column(
            children: [
              // Progress bar
              _buildProgressBar(summary, isDark),

              // Summary cards
              _buildSummaryCards(summary, isDark),

              // Branch breakdown toggle
              if (data.branchSummaries.length > 1)
                _buildBranchBreakdownToggle(data, isDark),

              // Branch breakdown
              if (_showBranchBreakdown && data.branchSummaries.length > 1)
                _buildBranchBreakdown(data, isDark),

              // Active filters indicator
              if (filters.branchId != null || filters.agentId != null)
                _buildActiveFilters(filters, isDark),

              // Tab bar
              Container(
                color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor:
                      isDark ? Colors.white54 : Colors.black54,
                  indicatorColor: AppColors.primary,
                  tabs: [
                    Tab(text: 'Pending (${pending.length})'),
                    Tab(text: 'Overdue (${overdue.length})'),
                    Tab(text: 'Collected (${collected.length})'),
                  ],
                ),
              ),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPaymentList(pending, isDark, 'No pending payments'),
                    _buildPaymentList(overdue, isDark, 'No overdue payments'),
                    _buildPaymentList(
                        collected, isDark, 'No collections yet'),
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
          icon: const Icon(Icons.share_rounded),
          label: const Text('Export'),
          backgroundColor: AppColors.primary,
        ),
        orElse: () => null,
      ),
    );
  }

  Widget _buildProgressBar(TodayPaymentSummary summary, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Collection Progress',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              Text(
                '${summary.countCollected} of ${summary.countDue} (${summary.completionPercent}%)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: summary.completionPercent >= 80
                      ? Colors.green
                      : summary.completionPercent >= 50
                          ? Colors.orange
                          : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: summary.countDue > 0
                  ? summary.countCollected / summary.countDue
                  : 0,
              backgroundColor:
                  isDark ? Colors.white12 : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                summary.completionPercent >= 80
                    ? Colors.green
                    : summary.completionPercent >= 50
                        ? Colors.orange
                        : Colors.red,
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(TodayPaymentSummary summary, bool isDark) {
    final currencyFormat =
        NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
      child: Row(
        children: [
          _SummaryCard(
            label: 'Total Due',
            value: currencyFormat.format(summary.totalDue),
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.primary,
            subtitle: '${summary.countDue} payments',
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _SummaryCard(
            label: 'Collected',
            value: currencyFormat.format(summary.totalCollected),
            icon: Icons.check_circle_outline,
            color: Colors.green,
            subtitle: '${summary.collectionRate.toStringAsFixed(0)}% rate',
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _SummaryCard(
            label: 'Pending',
            value: currencyFormat.format(summary.totalPending),
            icon: Icons.pending_outlined,
            color: Colors.orange,
            subtitle: '${summary.countPending + summary.countOverdue} left',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildBranchBreakdownToggle(TodayPaymentData data, bool isDark) {
    return GestureDetector(
      onTap: () =>
          setState(() => _showBranchBreakdown = !_showBranchBreakdown),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isDark
            ? const Color(0xFF1A1D2E).withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.8),
        child: Row(
          children: [
            Icon(Icons.business_rounded,
                size: 16, color: isDark ? Colors.white54 : Colors.black54),
            const SizedBox(width: 8),
            Text(
              'Branch-wise Breakdown',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const Spacer(),
            Icon(
              _showBranchBreakdown
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchBreakdown(TodayPaymentData data, bool isDark) {
    final currencyFormat =
        NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final branches = data.branchSummaries;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark
          ? const Color(0xFF0F1219)
          : const Color(0xFFF8F9FC),
      child: Column(
        children: branches.map((branch) {
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        branch.branchName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        '${branch.countCollected}/${branch.countDue} collected',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  currencyFormat.format(branch.totalCollected),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: branch.collectionRate >= 80
                        ? Colors.green
                        : branch.collectionRate >= 50
                            ? Colors.orange
                            : Colors.red,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '/ ${currencyFormat.format(branch.totalDue)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActiveFilters(PaymentFilterState filters, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
      child: Row(
        children: [
          Icon(Icons.filter_alt_rounded,
              size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Filtered by: '
              '${filters.branchId != null ? 'Branch' : ''}'
              '${filters.branchId != null && filters.agentId != null ? ' + ' : ''}'
              '${filters.agentId != null ? 'Agent' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: () =>
                ref.read(paymentFilterProvider.notifier).resetFilters(),
            child: Text(
              'Clear',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentList(
      List<TodayPayment> payments, bool isDark, String emptyMessage) {
    if (payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 56,
                color: isDark ? Colors.white24 : Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(todayPaymentsProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: payments.length,
        itemBuilder: (context, index) {
          return _PaymentCard(
            payment: payments[index],
            isDark: isDark,
            onCall: payments[index].memberPhone != null
                ? () => _makePhoneCall(payments[index].memberPhone!)
                : null,
            onRemind: () => _sendReminder(payments[index]),
            onTap: () => _showPaymentDetails(payments[index]),
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
        NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: payment.statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(payment.typeIcon,
                        color: payment.statusColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment.memberName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: payment.statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            payment.statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: payment.statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    currencyFormat.format(payment.amountExpected),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: payment.statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Details
              _DetailRow('Type', payment.typeLabel),
              if (payment.loanNumber != null)
                _DetailRow('Loan Number', payment.loanNumber!),
              if (payment.emiNumber != null)
                _DetailRow('EMI Number', '#${payment.emiNumber}'),
              _DetailRow('Due Date', dateFormat.format(payment.dueDate)),
              if (payment.isOverdue)
                _DetailRow('Overdue', payment.overdueLabel,
                    valueColor: Colors.red),
              if (payment.penaltyAmount > 0)
                _DetailRow('Penalty', currencyFormat.format(payment.penaltyAmount),
                    valueColor: Colors.red),
              if (payment.branchName != null)
                _DetailRow('Branch', payment.branchName!),
              if (payment.agentName != null)
                _DetailRow('Agent', payment.agentName!),
              if (payment.memberPhone != null)
                _DetailRow('Phone', payment.memberPhone!),
              if (payment.paymentMode != null)
                _DetailRow('Payment Mode', payment.paymentMode!.toUpperCase()),
              if (payment.collectedAt != null)
                _DetailRow('Collected At',
                    DateFormat('dd MMM yyyy, hh:mm a').format(payment.collectedAt!)),
              if (payment.remarks != null && payment.remarks!.isNotEmpty)
                _DetailRow('Remarks', payment.remarks!),

              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  if (payment.memberPhone != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _makePhoneCall(payment.memberPhone!);
                        },
                        icon: const Icon(Icons.call_rounded, size: 18),
                        label: const Text('Call'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ),
                  if (payment.memberPhone != null && !payment.isCollected)
                    const SizedBox(width: 8),
                  if (!payment.isCollected)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _sendReminder(payment);
                        },
                        icon: const Icon(Icons.notifications_active_rounded,
                            size: 18),
                        label: const Text('Remind'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ??
                    (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;
  final bool isDark;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final TodayPayment payment;
  final bool isDark;
  final VoidCallback? onCall;
  final VoidCallback onRemind;
  final VoidCallback onTap;

  const _PaymentCard({
    required this.payment,
    required this.isDark,
    this.onCall,
    required this.onRemind,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final timeFormat = DateFormat('hh:mm a');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: payment.statusColor.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Left icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: payment.statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  payment.typeIcon,
                  color: payment.statusColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // Middle content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            payment.memberName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                payment.statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            payment.statusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: payment.statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Details row
                    Text(
                      '${payment.typeLabel}'
                      '${payment.loanNumber != null ? ' · ${payment.loanNumber}' : ''}'
                      '${payment.emiNumber != null ? ' #${payment.emiNumber}' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Overdue label
                    if (payment.isOverdue) ...[
                      Text(
                        payment.overdueLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],

                    // Branch and agent
                    Row(
                      children: [
                        if (payment.branchName != null) ...[
                          Icon(Icons.store_outlined,
                              size: 12,
                              color:
                                  isDark ? Colors.white38 : Colors.black38),
                          const SizedBox(width: 4),
                          Text(
                            payment.branchName!,
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                        if (payment.agentName != null) ...[
                          Text(' · ',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38)),
                          Icon(Icons.person_outline,
                              size: 12,
                              color:
                                  isDark ? Colors.white38 : Colors.black38),
                          const SizedBox(width: 4),
                          Text(
                            payment.agentName!,
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Action buttons row
                    if (!payment.isCollected) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (onCall != null)
                            _ActionButton(
                              icon: Icons.call_rounded,
                              label: 'Call',
                              color: Colors.green,
                              onTap: onCall!,
                            ),
                          if (onCall != null) const SizedBox(width: 8),
                          _ActionButton(
                            icon: Icons.notifications_active_rounded,
                            label: 'Remind',
                            color: Colors.orange,
                            onTap: onRemind,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Right: amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currencyFormat.format(payment.amountExpected),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: payment.statusColor,
                    ),
                  ),
                  if (payment.penaltyAmount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '+${currencyFormat.format(payment.penaltyAmount)} penalty',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ],
                  if (payment.isCollected &&
                      payment.collectedAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      timeFormat.format(payment.collectedAt!),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                  if (payment.paymentMode != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      payment.paymentMode!.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white24 : Colors.black26,
                        letterSpacing: 0.5,
                      ),
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
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
