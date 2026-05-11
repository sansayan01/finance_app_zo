import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/providers/collection_providers.dart';
import '../../data/providers/staff_providers.dart';

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
    await Future.delayed(const Duration(milliseconds: 500));
    _refreshController.refreshCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
    final area = customer['area'] ?? customer['member_area'] ?? '';
    final memberId = customer['member_id'] ?? customer['memberId'] ?? '';
    final kycStatus = customer['kyc_status'] ?? 'pending';

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // Sliver app bar with customer info
          SliverAppBar(
            expandedHeight: 220,
            floating: true,
            pinned: true,
            actions: [
              // Call button
              IconButton(
                onPressed: phone.isNotEmpty
                    ? () {
                        HapticFeedback.selectionClick();
                        // TODO: Launch phone
                      }
                    : null,
                icon: const Icon(Icons.phone_outlined),
              ),
              // More options
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      // TODO: Edit customer
                      break;
                    case 'history':
                      context.push('/staff/customer/${widget.customerId}/history');
                      break;
                    case 'documents':
                      // TODO: View documents
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Edit Customer'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'history',
                    child: Row(
                      children: [
                        Icon(Icons.history, size: 20),
                        SizedBox(width: 12),
                        Text('Collection History'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'documents',
                    child: Row(
                      children: [
                        Icon(Icons.folder_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Documents'),
                      ],
                    ),
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
                      AppColors.primary.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primary.withOpacity(0.15),
                        child: Text(
                          name.split(' ').map((e) => e[0]).take(2).join().toUpperCase(),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      
                      // Name
                      Text(
                        name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      
                      // Member ID and KYC
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'ID: $memberId',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(width: AppSpacing.sm),
                          _buildKycBadge(kycStatus),
                        ],
                      ),
                      SizedBox(height: AppSpacing.sm),
                      
                      // Phone and area
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (phone.isNotEmpty) ...[
                            Icon(
                              Icons.phone,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            SizedBox(width: 4),
                            Text(
                              phone,
                              style: theme.textTheme.bodySmall,
                            ),
                            SizedBox(width: AppSpacing.sm),
                          ],
                          if (area.isNotEmpty) ...[
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            SizedBox(width: 4),
                            Text(
                              area,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
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
      
      // Floating action button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.push('/staff/collect', extra: {
            'customerId': widget.customerId,
            'customerName': name,
            'customerPhone': phone,
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
    Color color;
    IconData icon;
    
    switch (status.toLowerCase()) {
      case 'verified':
        color = AppColors.success;
        icon = Icons.verified;
        break;
      case 'rejected':
        color = AppColors.error;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.orange;
        icon = Icons.pending;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context, Map<String, dynamic> customer) {
    final theme = Theme.of(context);
    
    // Calculate stats
    final totalLoans = customer['active_loans'] ?? 0;
    final totalSavings = (customer['total_savings'] ?? 0).toDouble();
    final outstandingAmount = (customer['outstanding_amount'] ?? 0).toDouble();
    final nextDueAmount = (customer['next_due_amount'] ?? 0).toDouble();
    final nextDueDate = customer['next_due_date'];
    final overdueAmount = (customer['overdue_amount'] ?? 0).toDouble();
    final collectionRate = (customer['collection_rate'] ?? 0).toDouble();

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  title: 'Outstanding',
                  value: '₹${AppFormatters.formatCompactCurrency(outstandingAmount)}',
                  icon: Icons.account_balance_wallet,
                  color: AppColors.error,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildStatCard(
                  context,
                  title: 'Savings',
                  value: '₹${AppFormatters.formatCompactCurrency(totalSavings)}',
                  icon: Icons.savings,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  title: 'Active Loans',
                  value: totalLoans.toString(),
                  icon: Icons.confirmation_number,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildStatCard(
                  context,
                  title: 'Collection Rate',
                  value: '${collectionRate.toStringAsFixed(0)}%',
                  icon: Icons.trending_up,
                  color: collectionRate >= 90 
                      ? AppColors.success 
                      : (collectionRate >= 70 ? Colors.orange : AppColors.error),
                ),
              ),
            ],
          ),
          
          SizedBox(height: AppSpacing.lg),
          
          // Next Due
          if (nextDueAmount > 0)
            GlassCard(
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.calendar_today,
                      color: AppColors.info,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next Due',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '₹${AppFormatters.formatCompactCurrency(nextDueAmount)}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        nextDueDate != null
                            ? AppFormatters.formatDate(DateTime.tryParse(nextDueDate) ?? DateTime.now())
                            : 'N/A',
                        style: theme.textTheme.bodySmall,
                      ),
                      SizedBox(height: 2),
                      TextButton(
                        onPressed: () {
                          context.push('/staff/collect', extra: {
                            'customerId': widget.customerId,
                          });
                        },
                        child: const Text('Collect Now'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          
          // Overdue Alert
          if (overdueAmount > 0) ...[
            SizedBox(height: AppSpacing.md),
            GlassCard(
              backgroundColor: AppColors.error.withOpacity(0.1),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.warning_amber,
                      color: AppColors.error,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overdue Amount',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '₹${AppFormatters.formatCompactCurrency(overdueAmount)}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () {
                      context.push('/staff/collect', extra: {
                        'customerId': widget.customerId,
                        'type': 'overdue',
                      });
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                    ),
                    child: const Text('Collect'),
                  ),
                ],
              ),
            ),
          ],
          
          SizedBox(height: AppSpacing.lg),
          
          // Contact info
          Text(
            'Contact Information',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          GlassCard(
            child: Column(
              children: [
                _buildInfoRow(Icons.phone, 'Phone', customer['phone'] ?? 'N/A'),
                const Divider(height: 1),
                _buildInfoRow(Icons.location_on, 'Area', customer['area'] ?? 'N/A'),
                const Divider(height: 1),
                _buildInfoRow(Icons.home, 'Address', customer['address'] ?? 'N/A'),
              ],
            ),
          ),
          
          SizedBox(height: AppSpacing.lg),
          
          // Member since
          Text(
            'Account Information',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          GlassCard(
            child: Column(
              children: [
                _buildInfoRow(
                  Icons.calendar_today,
                  'Member Since',
                  customer['created_at'] != null
                      ? AppFormatters.formatDate(
                          DateTime.tryParse(customer['created_at']) ?? DateTime.now(),
                        )
                      : 'N/A',
                ),
                const Divider(height: 1),
                _buildInfoRow(
                  Icons.verified,
                  'KYC Status',
                  (customer['kyc_status'] ?? 'pending').toString().toUpperCase(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
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
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoansTab(BuildContext context, Map<String, dynamic> customer) {
    final loansAsync = ref.watch(customerLoansProvider(widget.customerId));

    return loansAsync.when(
      data: (loans) {
        if (loans.isEmpty) {
          return _buildEmptyTab(context, 'No active loans', Icons.confirmation_number);
        }
        return ListView.builder(
          padding: EdgeInsets.all(AppSpacing.md),
          itemCount: loans.length,
          itemBuilder: (context, index) {
            final loan = loans[index];
            return _buildLoanCard(context, loan);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildLoanCard(BuildContext context, Map<String, dynamic> loan) {
    final theme = Theme.of(context);
    final loanNumber = loan['loan_number'] ?? loan['loanNumber'] ?? 'N/A';
    final principal = (loan['principal'] ?? loan['amount'] ?? 0).toDouble();
    final outstanding = (loan['outstanding_balance'] ?? loan['outstanding'] ?? 0).toDouble();
    final emi = (loan['emi'] ?? 0).toDouble();
    final status = loan['status'] ?? 'active';
    final paidEmis = loan['paid_emis'] ?? 0;
    final totalEmis = loan['total_emis'] ?? loan['tenure'] ?? 0;

    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '#${loan['loan_sequence'] ?? (index + 1)}',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        title: Text(
          loanNumber,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Row(
          children: [
            Text(
              '₹${AppFormatters.formatCompactCurrency(outstanding)} outstanding',
              style: theme.textTheme.bodySmall,
            ),
            SizedBox(width: AppSpacing.sm),
            _buildStatusBadge(status),
          ],
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDetailItem('Principal', '₹${AppFormatters.formatCompactCurrency(principal)}'),
                    _buildDetailItem('EMI', '₹${AppFormatters.formatCompactCurrency(emi)}'),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDetailItem('Progress', '$paidEmis / $totalEmis EMIs'),
                    _buildDetailItem('Status', status.toUpperCase()),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          context.push('/staff/loan/${loan['id']}/schedule');
                        },
                        icon: const Icon(Icons.schedule, size: 18),
                        label: const Text('View Schedule'),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          context.push('/staff/collect', extra: {
                            'loanId': loan['id'],
                            'customerId': widget.customerId,
                          });
                        },
                        icon: const Icon(Icons.payments, size: 18),
                        label: const Text('Collect EMI'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    
    switch (status.toLowerCase()) {
      case 'active':
        color = AppColors.success;
        break;
      case 'overdue':
        color = AppColors.error;
        break;
      case 'closed':
        color = Colors.grey;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSavingsTab(BuildContext context, Map<String, dynamic> customer) {
    final savingsAsync = ref.watch(customerSavingsProvider(widget.customerId));

    return savingsAsync.when(
      data: (savings) {
        if (savings.isEmpty) {
          return _buildEmptyTab(context, 'No savings accounts', Icons.savings);
        }
        return ListView.builder(
          padding: EdgeInsets.all(AppSpacing.md),
          itemCount: savings.length,
          itemBuilder: (context, index) {
            final saving = savings[index];
            return _buildSavingsCard(context, saving);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildSavingsCard(BuildContext context, Map<String, dynamic> saving) {
    final theme = Theme.of(context);
    final planName = saving['plan_name'] ?? 'Savings Plan';
    final balance = (saving['balance'] ?? saving['total_savings'] ?? 0).toDouble();
    final target = (saving['target_amount'] ?? 0).toDouble();
    final monthlyDeposit = (saving['monthly_deposit'] ?? 0).toDouble();
    final status = saving['status'] ?? 'active';
    final progress = target > 0 ? (balance / target * 100).clamp(0, 100) : 0.0;

    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  planName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
            SizedBox(height: AppSpacing.sm),
            
            // Progress bar
            if (target > 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress / 100,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(AppColors.success),
                  minHeight: 8,
                ),
              ),
              SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹${AppFormatters.formatCompactCurrency(balance)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '₹${AppFormatters.formatCompactCurrency(target)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ] else
              Text(
                'Balance: ₹${AppFormatters.formatCompactCurrency(balance)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            
            SizedBox(height: AppSpacing.md),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.push('/staff/savings/${saving['id']}');
                    },
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('History'),
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      context.push('/staff/collect', extra: {
                        'savingsId': saving['id'],
                        'customerId': widget.customerId,
                        'type': 'savings',
                      });
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Deposit'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab(BuildContext context, Map<String, dynamic> customer) {
    final historyAsync = ref.watch(customerCollectionHistoryProvider(widget.customerId));

    return historyAsync.when(
      data: (history) {
        if (history.isEmpty) {
          return _buildEmptyTab(context, 'No collection history', Icons.history);
        }
        return ListView.builder(
          padding: EdgeInsets.all(AppSpacing.md),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final item = history[index];
            return _buildHistoryItem(context, item);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildHistoryItem(BuildContext context, Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final amount = (item['amount'] ?? 0).toDouble();
    final type = item['type'] ?? item['payment_mode'] ?? 'cash';
    final date = item['collected_at'] ?? item['created_at'] ?? '';
    final staffName = item['staff_name'] ?? '';
    final receiptNumber = item['receipt_number'] ?? '';

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.payments,
          color: AppColors.success,
          size: 20,
        ),
      ),
      title: Text(
        '₹${AppFormatters.formatCompactCurrency(amount)}',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(type.toString().toUpperCase()),
          if (receiptNumber.isNotEmpty)
            Text(
              'Receipt: $receiptNumber',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            date.isNotEmpty
                ? AppFormatters.formatDate(DateTime.tryParse(date) ?? DateTime.now())
                : '',
            style: theme.textTheme.bodySmall,
          ),
          if (staffName.isNotEmpty)
            Text(
              staffName,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyTab(BuildContext context, String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: AppColors.error.withOpacity(0.5),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Failed to load customer',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: _onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
