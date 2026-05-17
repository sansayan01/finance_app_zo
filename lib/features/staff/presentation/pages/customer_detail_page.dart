import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../data/providers/collection_providers.dart';

class CustomerDetailPage extends ConsumerStatefulWidget {
  final String customerId;
  final Map<String, dynamic>? initialData;
  const CustomerDetailPage(
      {super.key, required this.customerId, this.initialData});

  @override
  ConsumerState<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends ConsumerState<CustomerDetailPage>
    with SingleTickerProviderStateMixin {
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    ref.invalidate(customerDetailProvider(widget.customerId));
    ref.invalidate(customerLoansProvider(widget.customerId));
    await Future.delayed(const Duration(milliseconds: 500));
    _refreshController.refreshCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final customerAsync = ref.watch(customerDetailProvider(widget.customerId));

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF8F9FE),
      body: customerAsync.when(
        data: (customer) => _buildContent(context, customer, isDark),
        loading: () => _buildLoadingSkeleton(context, isDark),
        error: (err, _) => _buildError(context, err.toString(), isDark),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, Map<String, dynamic> customer, bool isDark) {
    final theme = Theme.of(context);
    final name = customer['full_name'] ?? customer['member_name'] ?? 'Unknown';
    final phone = customer['phone'] ?? '';
    final memberId = customer['member_id'] ?? customer['memberId'] ?? '';
    final kycStatus = customer['kyc_status'] ?? 'pending';

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          expandedHeight: 240,
          floating: true,
          pinned: true,
          backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_rounded,
                color: isDark ? Colors.white70 : Colors.black87),
          ),
          actions: [
            IconButton(
                onPressed: phone.isNotEmpty
                    ? () => HapticFeedback.selectionClick()
                    : null,
                icon: Icon(Icons.phone_outlined,
                    color: isDark ? Colors.white70 : Colors.black87)),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded,
                  color: isDark ? Colors.white70 : Colors.black87),
              onSelected: (_) {},
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Edit Customer')
                    ])),
              ],
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [const Color(0xFF1A1A2E), const Color(0xFF0A0A0B)]
                      : [
                          AppColors.primary.withValues(alpha: 0.08),
                          Colors.transparent
                        ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.accent]),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 16)
                        ],
                      ),
                      child: Center(
                        child: Text(
                          name
                              .split(' ')
                              .map((e) => e[0])
                              .take(2)
                              .join()
                              .toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(name,
                        style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('ID: $memberId',
                            style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.black54,
                                fontSize: 12)),
                        const SizedBox(width: 10),
                        _buildKycBadge(kycStatus),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05)),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(
                      child: Text('Overview',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12))),
                  Tab(
                      child: Text('Loans',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12))),
                  Tab(
                      child: Text('Savings',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12))),
                  Tab(
                      child: Text('History',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12))),
                ],
              ),
            ),
          ),
        ),
      ],
      body: SmartRefresher(
        controller: _refreshController,
        onRefresh: _onRefresh,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(context, customer, isDark),
            _buildLoansTab(context, customer, isDark),
            _buildSavingsTab(context, customer, isDark),
            _buildHistoryTab(context, customer, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildKycBadge(String status) {
    final verified = status.toLowerCase() == 'verified';
    final color = verified ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildOverviewTab(
      BuildContext context, Map<String, dynamic> customer, bool isDark) {
    final outstandingAmount = (customer['outstanding_balance'] ?? 0).toDouble();
    final totalSavings = (customer['total_savings'] ?? 0).toDouble();
    final overdueAmount = (customer['overdue_amount'] ?? 0).toDouble();
    final collectionRate = (customer['collection_rate'] ?? 0).toDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _buildStatCard(
                      theme: Theme.of(context),
                      isDark: isDark,
                      title: 'Outstanding',
                      value:
                          '₹${AppFormatters.formatCompactCurrency(outstandingAmount)}',
                      icon: Icons.account_balance_wallet_rounded,
                      color: AppColors.error)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildStatCard(
                      theme: Theme.of(context),
                      isDark: isDark,
                      title: 'Savings',
                      value:
                          '₹${AppFormatters.formatCompactCurrency(totalSavings)}',
                      icon: Icons.savings_rounded,
                      color: AppColors.success)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildStatCard(
                      theme: Theme.of(context),
                      isDark: isDark,
                      title: 'Overdue',
                      value:
                          '₹${AppFormatters.formatCompactCurrency(overdueAmount)}',
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.warning)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildStatCard(
                      theme: Theme.of(context),
                      isDark: isDark,
                      title: 'Collection Rate',
                      value: '${collectionRate.toStringAsFixed(0)}%',
                      icon: Icons.trending_up_rounded,
                      color: AppColors.info)),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoSection(customer, Theme.of(context), isDark),
        ].animate(interval: 60.ms).fadeIn().slideY(begin: 0.04, end: 0),
      ),
    );
  }

  Widget _buildStatCard(
      {required ThemeData theme,
      required bool isDark,
      required String title,
      required String value,
      required IconData icon,
      required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.08),
            color.withValues(alpha: 0.02)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 10),
          Text(title,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 10)),
          const SizedBox(height: 2),
          Text(value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
      Map<String, dynamic> customer, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(theme, Icons.phone_rounded, 'Phone',
              customer['phone'] ?? 'N/A', isDark),
          const Divider(height: 20),
          _buildInfoRow(theme, Icons.location_on_rounded, 'Area',
              customer['area'] ?? 'N/A', isDark),
          const Divider(height: 20),
          _buildInfoRow(
              theme,
              Icons.calendar_today_rounded,
              'Joined',
              customer['created_at'] is String
                  ? (customer['created_at'] as String).substring(0, 10)
                  : 'N/A',
              isDark),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      ThemeData theme, IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white70 : Colors.black87))),
        Text(value,
            style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87)),
      ],
    );
  }

  Widget _buildLoansTab(
      BuildContext context, Map<String, dynamic> customer, bool isDark) {
    final loansAsync = ref.watch(customerLoansProvider(widget.customerId));
    return loansAsync.when(
      data: (loans) => loans.isEmpty
          ? _emptyTab(isDark, Icons.account_balance_outlined, 'No active loans')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              itemCount: loans.length,
              itemBuilder: (ctx, i) => _buildLoanCard(loans[i],
                  theme: Theme.of(context), isDark: isDark, index: i),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildLoanCard(Map<String, dynamic> loan,
      {required ThemeData theme, required bool isDark, required int index}) {
    final number = loan['loan_number'] ?? 'N/A';
    final balance = (loan['outstanding_balance'] ?? 0).toDouble();
    final emi = (loan['emi'] ?? 0).toDouble();
    final status = loan['status'] ?? 'active';
    final isActive = status == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isActive ? AppColors.primary : AppColors.success)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                    isActive
                        ? Icons.credit_card_rounded
                        : Icons.check_circle_rounded,
                    color: isActive ? AppColors.primary : AppColors.success,
                    size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Loan #$number',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text('EMI: ₹${emi.toStringAsFixed(0)}/mo',
                        style: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                            fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isActive ? AppColors.primary : AppColors.success)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(status.toUpperCase(),
                    style: TextStyle(
                        color: isActive ? AppColors.primary : AppColors.success,
                        fontSize: 9,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.3)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Balance',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5))),
              Text('₹${balance.toStringAsFixed(0)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isActive ? AppColors.error : AppColors.success)),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: (index * 60).ms)
        .slideY(begin: 0.04, end: 0);
  }

  Widget _buildSavingsTab(
      BuildContext context, Map<String, dynamic> customer, bool isDark) {
    final savingsAsync = ref.watch(customerSavingsProvider(widget.customerId));
    return savingsAsync.when(
      data: (savings) => savings.isEmpty
          ? _emptyTab(isDark, Icons.savings_outlined, 'No savings plans')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              itemCount: savings.length,
              itemBuilder: (ctx, i) => _buildSavingsCard(savings[i],
                  theme: Theme.of(context), isDark: isDark, index: i),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildSavingsCard(Map<String, dynamic> plan,
      {required ThemeData theme, required bool isDark, required int index}) {
    final name = plan['plan_name'] ?? 'Savings Plan';
    final balance = (plan['balance'] ?? 0).toDouble();
    final target = (plan['target_amount'] ?? 0).toDouble();
    final monthly = (plan['monthly_deposit'] ?? 0).toDouble();
    final progress = target > 0 ? (balance / target).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.savings_rounded,
                    color: AppColors.success, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Builder(builder: (context) {
                      final cycle = (plan['collection_type'] ?? 'monthly').toString().toLowerCase();
                      String cycleText = '';
                      if (cycle == 'daily') {
                        cycleText = '₹${monthly.toStringAsFixed(0)}/day (₹${(monthly * 30).toStringAsFixed(0)}/mo)';
                      } else if (cycle == 'weekly') {
                        cycleText = '₹${monthly.toStringAsFixed(0)}/wk (₹${(monthly * 4.33).toStringAsFixed(0)}/mo)';
                      } else {
                        cycleText = '₹${monthly.toStringAsFixed(0)}/mo';
                      }
                      return Text(
                        cycleText,
                        style: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                            fontSize: 11),
                      );
                    }),
                  ],
                ),
              ),
              Text('₹${balance.toStringAsFixed(0)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900, color: AppColors.success)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : theme.colorScheme.surfaceContainerHighest,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.success)),
          ),
          const SizedBox(height: 4),
          Align(
              alignment: Alignment.centerRight,
              child: Text(
                  '${(progress * 100).toStringAsFixed(0)}% of ₹${target.toStringAsFixed(0)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.4)))),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: (index * 60).ms)
        .slideY(begin: 0.04, end: 0);
  }

  Widget _buildHistoryTab(
      BuildContext context, Map<String, dynamic> customer, bool isDark) {
    return CollectionHistoryTab(customerId: widget.customerId, isDark: isDark);
  }

  Widget _emptyTab(bool isDark, IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle),
            child: Icon(icon,
                size: 48, color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          const SizedBox(height: 16),
          Text(message,
              style:
                  TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: const [
        ShimmerCard(height: 200),
        SizedBox(height: 16),
        ShimmerCard(height: 100),
        SizedBox(height: 16),
        ShimmerCard(height: 100),
      ]),
    );
  }

  Widget _buildError(BuildContext context, String error, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.error),
          ),
          const SizedBox(height: 16),
          Text('Error loading details',
              style:
                  TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
          const SizedBox(height: 16),
          ElevatedButton(
              onPressed: _onRefresh,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: const Text('Retry')),
        ],
      ),
    );
  }
}

class CollectionHistoryTab extends ConsumerWidget {
  final String customerId;
  final bool isDark;
  const CollectionHistoryTab(
      {super.key, required this.customerId, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(customerLoansProvider(customerId)).when(
          data: (_) => Center(
              child: Text('Collection history',
                  style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38))),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        );
  }
}
