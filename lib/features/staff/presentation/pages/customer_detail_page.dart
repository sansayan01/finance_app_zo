import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../data/providers/collection_providers.dart';

class CustomerDetailPage extends ConsumerStatefulWidget {
  final String customerId;
  final Map<String, dynamic>? initialData;

  const CustomerDetailPage({
    super.key,
    required this.customerId,
    this.initialData,
  });

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
    final customerAsync = ref.watch(customerDetailProvider(widget.customerId));

    return Scaffold(
      body: customerAsync.when(
        data: (customer) => _buildContent(context, customer),
        loading: () => _buildLoadingSkeleton(context),
        error: (err, _) => _buildError(context, err.toString()),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> customer) {
    final theme = Theme.of(context);
    final name = customer['full_name'] ?? customer['member_name'] ?? 'Unknown';
    final phone = customer['phone'] ?? '';
    final memberId = customer['member_id'] ?? customer['memberId'] ?? '';
    final kycStatus = customer['kyc_status'] ?? 'pending';

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 240,
            floating: true,
            pinned: true,
            actions: [
              IconButton(
                onPressed: phone.isNotEmpty
                    ? () {
                        HapticFeedback.selectionClick();
                      }
                    : null,
                icon: const Icon(Icons.phone_outlined),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {},
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit Customer'),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        child: Text(
                          name.split(' ').map((e) => e[0]).take(2).join().toUpperCase(),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Text(
                        name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('ID: $memberId', style: theme.textTheme.bodySmall),
                          SizedBox(width: AppSpacing.sm),
                          _buildKycBadge(kycStatus),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Loans'),
                Tab(text: 'Savings'),
                Tab(text: 'History'),
              ],
            ),
          ),
        ],
        body: SmartRefresher(
          controller: _refreshController,
          onRefresh: _onRefresh,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(context, customer),
              _buildLoansTab(context, customer),
              _buildSavingsTab(context, customer),
              _buildHistoryTab(context, customer),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/staff/collect', extra: {
            'customerId': widget.customerId,
            'customerName': name,
          });
        },
        icon: const Icon(Icons.payments_outlined),
        label: const Text('Collect'),
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildKycBadge(String status) {
    Color color = status.toLowerCase() == 'verified' ? AppColors.success : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context, Map<String, dynamic> customer) {
    final outstandingAmount = (customer['outstanding_amount'] ?? 0).toDouble();
    final totalSavings = (customer['total_savings'] ?? 0).toDouble();

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Outstanding', '₹${AppFormatters.formatCompactCurrency(outstandingAmount)}', Icons.account_balance_wallet, AppColors.error),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildStatCard('Savings', '₹${AppFormatters.formatCompactCurrency(totalSavings)}', Icons.savings, AppColors.success),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          _buildInfoSection(customer),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          SizedBox(height: AppSpacing.sm),
          Text(title, style: theme.textTheme.bodySmall),
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInfoSection(Map<String, dynamic> customer) {
    return GlassCard(
      child: Column(
        children: [
          _buildInfoRow(Icons.phone, 'Phone', customer['phone'] ?? 'N/A'),
          const Divider(),
          _buildInfoRow(Icons.location_on, 'Area', customer['area'] ?? 'N/A'),
          const Divider(),
          _buildInfoRow(Icons.calendar_today, 'Joined', customer['created_at'] ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          SizedBox(width: 12),
          Text(label),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLoansTab(BuildContext context, Map<String, dynamic> customer) {
    final loansAsync = ref.watch(customerLoansProvider(widget.customerId));
    return loansAsync.when(
      data: (loans) => loans.isEmpty 
          ? const Center(child: Text('No active loans')) 
          : ListView.builder(
              padding: EdgeInsets.all(AppSpacing.md),
              itemCount: loans.length,
              itemBuilder: (context, index) => _buildLoanCard(loans[index]),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildLoanCard(Map<String, dynamic> loan) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text('Loan: ${loan['loan_number']}'),
        subtitle: Text('Balance: ₹${loan['balance_amount']}'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _buildSavingsTab(BuildContext context, Map<String, dynamic> customer) {
    return const Center(child: Text('Savings Plans'));
  }

  Widget _buildHistoryTab(BuildContext context, Map<String, dynamic> customer) {
    return const Center(child: Text('Collection History'));
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: const [
          ShimmerCard(height: 200),
          SizedBox(height: 16),
          ShimmerCard(height: 100),
          SizedBox(height: 16),
          ShimmerCard(height: 100),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $error'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _onRefresh, child: const Text('Retry')),
        ],
      ),
    );
  }
}
