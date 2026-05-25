// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/glass_button.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../loans/data/models/loan_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/providers/branch_scoped_providers.dart';

/// Premium branch-scoped loans page for Branch Manager Portal.
/// Mirrors the admin LoansPage styling with branch-level filtering.
class BranchLoansPage extends ConsumerStatefulWidget {
  const BranchLoansPage({super.key});

  @override
  ConsumerState<BranchLoansPage> createState() => _BranchLoansPageState();
}

class _BranchLoansPageState extends ConsumerState<BranchLoansPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _activeFilter = 0; // 0: Overview, 1: Active, 2: At Risk, 3: Settled

  final List<Map<String, dynamic>> _filters = [
    {'label': 'Overview', 'status': null, 'icon': Icons.dashboard_rounded},
    {'label': 'Active', 'status': LoanStatus.active, 'icon': Icons.bolt_rounded},
    {
      'label': 'At Risk',
      'status': LoanStatus.defaultStatus,
      'icon': Icons.warning_amber_rounded
    },
    {
      'label': 'Settled',
      'status': LoanStatus.closed,
      'icon': Icons.verified_rounded
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authProvider).user;
    final branchId = user?.branchId;

    if (branchId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Branch Loans')),
        body: const Center(child: Text('No branch assigned to your profile.')),
      );
    }

    final loansAsync = ref.watch(branchLoansProvider(branchId));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF2F2F7),
      body: AuroraBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(branchLoansProvider(branchId));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // App Bar
              SliverAppBar(
                pinned: true,
                elevation: 0,
                backgroundColor: isDark
                    ? const Color(0xFF0A0A0C).withValues(alpha: 0.85)
                    : const Color(0xFFF2F2F7).withValues(alpha: 0.85),
                surfaceTintColor: Colors.transparent,
                title: Text(
                  'Branch Loans',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                systemOverlayStyle:
                    isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
              ),

              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: _buildSearchBar(theme, isDark),
                ),
              ),

              // Filter Chips
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      final isActive = _activeFilter == index;
                      return GestureDetector(
                        onTap: () => setState(() => _activeFilter = index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primary
                                : isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isActive
                                  ? AppColors.primary
                                  : isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                filter['icon'] as IconData,
                                size: 16,
                                color: isActive
                                    ? Colors.white
                                    : isDark
                                        ? Colors.white70
                                        : Colors.black54,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                filter['label'] as String,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      isActive ? FontWeight.w600 : FontWeight.w500,
                                  color: isActive
                                      ? Colors.white
                                      : isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(
                            duration: 300.ms,
                            delay: Duration(milliseconds: 50 * index),
                          );
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Summary Cards
              SliverToBoxAdapter(
                child: loansAsync.when(
                  data: (loans) => _buildSummaryRow(theme, isDark, loans),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Loan Cards
              loansAsync.when(
                data: (loans) {
                  final filtered = _applyFilters(loans);
                  if (filtered.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(theme, isDark),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final loan = filtered[index];
                        return _buildLoanCard(
                          context, theme, isDark, loan, index,
                        );
                      },
                    ),
                  );
                },
                loading: () => SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.builder(
                    itemCount: 6,
                    itemBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: ShimmerCard(height: 120),
                    ),
                  ),
                ),
                error: (error, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${error.toString()}'),
                        const SizedBox(height: 16),
                        GlassButton(
                          label: 'Retry',
                          icon: Icons.refresh,
                          onTap: () =>
                              ref.invalidate(branchLoansProvider(branchId)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  // Search Bar
  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Search by name, phone, or loan ID...',
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: isDark ? Colors.white38 : Colors.black38, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // Summary Row
  Widget _buildSummaryRow(ThemeData theme, bool isDark, List<LoanModel> loans) {
    final activeLoans = loans.where((l) => l.status == LoanStatus.active).toList();
    final atRiskLoans = loans.where((l) => l.status == LoanStatus.defaultStatus).toList();
    final totalOutstanding = loans
        .where((l) => l.status == LoanStatus.active || l.status == LoanStatus.defaultStatus)
        .fold<double>(0, (sum, l) => sum + l.outstandingBalance);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatChip(
              theme, isDark,
              icon: Icons.bolt_rounded,
              label: 'Active',
              value: '${activeLoans.length}',
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatChip(
              theme, isDark,
              icon: Icons.warning_amber_rounded,
              label: 'At Risk',
              value: '${atRiskLoans.length}',
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatChip(
              theme, isDark,
              icon: Icons.account_balance_wallet_rounded,
              label: 'Outstanding',
              value: AppFormatters.formatCompactCurrency(totalOutstanding),
              color: AppColors.info,
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
    );
  }

  Widget _buildStatChip(
    ThemeData theme,
    bool isDark, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // Loan Card
  Widget _buildLoanCard(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    LoanModel loan,
    int index,
  ) {
    final customerName = loan.customerName ?? 'Unknown';
    final customerPhone = loan.customerPhone ?? '';
    final progress = loan.amount > 0
        ? (1 - (loan.outstandingBalance / loan.amount)).clamp(0.0, 1.0)
        : 0.0;

    StatusType statusType;
    String statusLabel;
    switch (loan.status) {
      case LoanStatus.active:
        statusType = StatusType.active;
        statusLabel = 'Active';
        break;
      case LoanStatus.defaultStatus:
        statusType = StatusType.defaultStatus;
        statusLabel = 'At Risk';
        break;
      case LoanStatus.closed:
        statusType = StatusType.completed;
        statusLabel = 'Closed';
        break;
      case LoanStatus.pending:
        statusType = StatusType.pending;
        statusLabel = 'Pending';
        break;
      default:
        statusType = StatusType.standard;
        statusLabel = loan.status.name;
    }

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      onTap: () => context.push('/branch/loans/${loan.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: avatar + name + status
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.8),
                      AppColors.accent.withValues(alpha: 0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    customerName.isNotEmpty ? customerName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (customerPhone.isNotEmpty)
                      Text(
                        AppFormatters.formatPhone(customerPhone),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white54 : Colors.black45,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              StatusBadge(label: statusLabel, type: statusType),
            ],
          ),
          const SizedBox(height: 16),

          // Loan details
          Row(
            children: [
              Expanded(
                child: _buildDetailColumn(
                  theme, isDark,
                  label: 'Loan Amount',
                  value: AppFormatters.formatCompactCurrency(loan.amount),
                ),
              ),
              Expanded(
                child: _buildDetailColumn(
                  theme, isDark,
                  label: 'Outstanding',
                  value: AppFormatters.formatCompactCurrency(loan.outstandingBalance),
                  valueColor: loan.outstandingBalance > 0
                      ? AppColors.warning
                      : AppColors.success,
                ),
              ),
              Expanded(
                child: _buildDetailColumn(
                  theme, isDark,
                  label: 'Loan ID',
                  value: loan.loanNumber.isNotEmpty
                      ? loan.loanNumber
                      : loan.id.substring(0, 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor:
                  isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(
                progress >= 1
                    ? AppColors.success
                    : progress >= 0.5
                        ? AppColors.info
                        : AppColors.warning,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(progress * 100).toStringAsFixed(0)}% repaid',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.white38 : Colors.black38,
              fontSize: 11,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(
          duration: 350.ms,
          delay: Duration(milliseconds: 60 * index.clamp(0, 8)),
        );
  }

  Widget _buildDetailColumn(
    ThemeData theme,
    bool isDark, {
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // Empty State
  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : AppColors.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_rounded,
              size: 48,
              color: isDark ? Colors.white24 : AppColors.primary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _searchQuery.isNotEmpty ? 'No loans match your search' : 'No loans found',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Loans for your branch will appear here',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  // Filter Logic
  List<LoanModel> _applyFilters(List<LoanModel> loans) {
    var filtered = loans;

    // Status filter
    final selectedStatus = _filters[_activeFilter]['status'] as LoanStatus?;
    if (selectedStatus != null) {
      filtered = filtered.where((l) => l.status == selectedStatus).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((l) {
        final name = (l.customerName ?? '').toLowerCase();
        final phone = l.customerPhone ?? '';
        final number = l.loanNumber.toLowerCase();
        final id = l.id.toLowerCase();
        return name.contains(q) || phone.contains(q) || number.contains(q) || id.contains(q);
      }).toList();
    }

    return filtered;
  }
}
