import '../../../../core/widgets/shimmer_card.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/widgets/glass_button.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../data/models/loan_model.dart';
import '../providers/loan_providers.dart';
import '../../../home/data/providers/dashboard_providers.dart' show loanSummaryProvider;

class LoansPage extends ConsumerStatefulWidget {
  final void Function(String loanId)? onLoanTap;
  final bool showCreateButton;

  const LoansPage({
    super.key,
    this.onLoanTap,
    this.showCreateButton = true,
  });

  @override
  ConsumerState<LoansPage> createState() => _LoansPageState();
}

class _LoansPageState extends ConsumerState<LoansPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  LoanStatus? _filterStatus;

  // Sorting options
  String _sortBy = 'recent'; // 'recent', 'amount', 'balance', 'progress'
  bool _sortAscending = false;

  // Cached filtered/sorted list — recomputed only when inputs change
  List<LoanModel>? _cachedFiltered;
  List<LoanModel>? _cachedSource;
  LoanStatus? _cachedFilterStatus;
  String _cachedSearchQuery = '';
  String _cachedSortBy = 'recent';
  bool _cachedSortAscending = false;

  List<LoanModel> _getFilteredList(List<LoanModel> loans) {
    if (_cachedSource == loans &&
        _cachedFilterStatus == _filterStatus &&
        _cachedSearchQuery == _searchQuery &&
        _cachedSortBy == _sortBy &&
        _cachedSortAscending == _sortAscending &&
        _cachedFiltered != null) {
      return _cachedFiltered!;
    }

    var filtered = loans.where((l) {
      if (_filterStatus != null && l.status != _filterStatus) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return (l.customerName?.toLowerCase().contains(q) ?? false) ||
            l.loanNumber.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'amount':
          cmp = a.amount.compareTo(b.amount);
          break;
        case 'balance':
          cmp = a.outstandingBalance.compareTo(b.outstandingBalance);
          break;
        case 'progress':
          final pA = 1 - (a.outstandingBalance / a.totalRepayable);
          final pB = 1 - (b.outstandingBalance / b.totalRepayable);
          cmp = pA.compareTo(pB);
          break;
        default:
          cmp = a.createdAt.compareTo(b.createdAt);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    _cachedSource = loans;
    _cachedFilterStatus = _filterStatus;
    _cachedSearchQuery = _searchQuery;
    _cachedSortBy = _sortBy;
    _cachedSortAscending = _sortAscending;
    _cachedFiltered = filtered;
    return filtered;
  }

  final List<Map<String, dynamic>> _filters = [
    {'label': 'Overview', 'status': null, 'icon': Icons.dashboard_rounded},
    {
      'label': 'Active',
      'status': LoanStatus.active,
      'icon': Icons.bolt_rounded
    },
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
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.invalidate(loansProvider);
      ref.invalidate(loanSummaryProvider);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    ref.invalidate(loansProvider);
    ref.invalidate(loanSummaryProvider);
    return await ref.read(loansProvider.future).then((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    final loansAsync = ref.watch(loansProvider);
    final summaryAsync = ref.watch(loanSummaryProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            displacement: 20,
            color: primary,
            backgroundColor: theme.cardColor,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                // Premium Dynamic Header (Compact)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Portfolio Intelligence',
                                    style:
                                        theme.textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1.0,
                                      fontSize: 26,
                                    ),
                                  )
                                      .animate()
                                      .fadeIn(duration: 400.ms)
                                      .slideX(begin: -0.05),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Live Risk Analytics & Capital Deployment',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: theme.textTheme.bodySmall?.color
                                          ?.withValues(alpha: 0.6),
                                    ),
                                  )
                                      .animate()
                                      .fadeIn(delay: 100.ms)
                                      .slideX(begin: -0.05),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            if (widget.showCreateButton)
                              GlassButton(
                                label: 'DEPLOY',
                                width: 110,
                                height: 44,
                                fontSize: 13,
                                icon: Icons.add_circle_outline_rounded,
                                onTap: () => context.push('/loans/new'),
                              )
                                  .animate()
                                  .fadeIn(delay: 200.ms)
                                  .scale(begin: const Offset(0.9, 0.9)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // Redesigned Feature-Rich Analytics Dashboard
                SliverToBoxAdapter(
                  child: summaryAsync
                      .when(
                        data: (summary) => _buildAnalyticsDashboard(
                            summary, primary, isDark, theme),
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: ShimmerCard(height: 76),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                      )
                      .animate()
                      .fadeIn(delay: 300.ms),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Sticky Search & Filter Hub
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverHeaderDelegate(
                    child: Container(
                      color:
                          theme.scaffoldBackgroundColor.withValues(alpha: 0.85),
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ColorFilter.mode(
                              theme.scaffoldBackgroundColor
                                  .withValues(alpha: 0.1),
                              BlendMode.dstATop),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  children: [
                                    Expanded(
                                        child: _buildSmartSearchBar(
                                            isDark, theme)),
                                    const SizedBox(width: 10),
                                    _buildSortMenu(isDark, theme),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildPillFilters(isDark, theme, primary),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Dynamic Loan List
                loansAsync.when(
                  data: (loans) {
                    final filtered = _getFilteredList(loans);

                    if (filtered.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(theme, primary),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final card = Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PremiumLoanCard(
                                loan: filtered[i],
                                onTap: widget.onLoanTap != null
                                    ? () => widget.onLoanTap!(filtered[i].id)
                                    : null,
                              ),
                            );
                            // Only animate first 10 items to avoid
                            // creating animation controllers off-screen
                            if (i < 10) {
                              return card
                                  .animate()
                                  .fadeIn(delay: (40 * i).ms)
                                  .slideY(
                                      begin: 0.08,
                                      end: 0,
                                      curve: Curves.easeOutQuart);
                            }
                            return card;
                          },
                          childCount: filtered.length,
                        ),
                      ),
                    );
                  },
                  loading: () => SliverPadding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, __) => const Padding(
                          padding: EdgeInsets.only(bottom: 24),
                          child: ShimmerCard(height: 220),
                        ),
                        childCount: 4,
                      ),
                    ),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: Center(
                        child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Text('Error loading portfolio: $e',
                          style: theme.textTheme.bodyMedium),
                    )),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsDashboard(
      LoanSummary summary, Color primary, bool isDark, ThemeData theme) {
    return SizedBox(
      height: 66,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        physics: const BouncingScrollPhysics(),
        children: [
          _AnalyticsCard(
            label: 'CAPITAL DEPLOYED',
            value: AppFormatters.formatCurrency(summary.totalDisbursed),
            icon: Icons.account_balance_wallet_rounded,
            color: primary,
            isDark: isDark,
          ),
          const SizedBox(width: 12),
          _AnalyticsCard(
            label: 'TOTAL OUTSTANDING',
            value: AppFormatters.formatCurrency(summary.totalOutstanding),
            icon: Icons.donut_large_rounded,
            color: AppColors.warning,
            isDark: isDark,
          ),
          const SizedBox(width: 12),
          _AnalyticsCard(
            label: 'PORTFOLIO AT RISK',
            value: '${summary.parPercentage.toStringAsFixed(1)}%',
            icon: Icons.warning_amber_rounded,
            color: summary.parPercentage > 10
                ? AppColors.error
                : AppColors.success,
            subtitle: '${summary.defaultLoans} Defaults',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSmartSearchBar(bool isDark, ThemeData theme) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: isDark ? AppColors.fillDark : AppColors.fillLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search borrower name, ID...',
          hintStyle: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.textTheme.bodySmall?.color, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
              size: 18),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildSortMenu(bool isDark, ThemeData theme) {
    return PopupMenuButton<String>(
      onSelected: (val) => setState(() {
        if (_sortBy == val) {
          _sortAscending = !_sortAscending;
        } else {
          _sortBy = val;
          _sortAscending = false;
        }
      }),
      itemBuilder: (ctx) => [
        _buildPopupItem(
            'recent', 'Latest Disbursed', Icons.access_time_rounded, theme),
        _buildPopupItem(
            'amount', 'Highest Principal', Icons.payments_rounded, theme),
        _buildPopupItem(
            'balance', 'Largest Balance', Icons.account_balance_rounded, theme),
        _buildPopupItem(
            'progress', 'Nearest to Close', Icons.track_changes_rounded, theme),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDark ? AppColors.elevatedDark : Colors.white,
      child: Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          color: isDark ? AppColors.fillDark : AppColors.fillLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
        child: Icon(Icons.tune_rounded,
            color: theme.colorScheme.primary, size: 20),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(
      String value, String label, IconData icon, ThemeData theme) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Text(label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildPillFilters(bool isDark, ThemeData theme, Color primary) {
    return SizedBox(
      height: 28,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _filterStatus == filter['status'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(
                  () => _filterStatus = filter['status'] as LoanStatus?),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: 200.ms,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primary
                      : (isDark ? AppColors.fillDark : AppColors.fillLight),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? primary
                        : theme.dividerColor.withValues(alpha: 0.1),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: primary.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 1.5))
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Icon(
                      filter['icon'] as IconData,
                      size: 12,
                      color: isSelected
                          ? Colors.white
                          : theme.textTheme.bodyMedium?.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      filter['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, Color primary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.account_balance_rounded,
                size: 72, color: primary.withValues(alpha: 0.2)),
          ),
          const SizedBox(height: 24),
          Text('No Loans Found',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900, fontSize: 24)),
          const SizedBox(height: 8),
          Text('Adjust your filters or deploy new capital.',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
          GlassButton(
            label: 'Deploy Capital',
            width: 200,
            onTap: () => context.push('/loans/new'),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final bool isDark;

  const _AnalyticsCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: 15,
                            fontFamily: 'JetBrains Mono',
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumLoanCard extends StatelessWidget {
  final LoanModel loan;
  final VoidCallback? onTap;
  const _PremiumLoanCard({required this.loan, this.onTap});

  Future<void> _makeCall(String phone) async {
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> _makeWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final url = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  String? _resolvePhotoUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    final trimmed = rawUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    // Convert relative storage path to public Supabase storage URL
    final String bucket;
    final String path;
    if (trimmed.startsWith('avatars/')) {
      bucket = 'avatars';
      path = trimmed.substring('avatars/'.length);
    } else {
      bucket = 'avatars';
      path = trimmed;
    }
    return 'https://tccwdpsnuudzfyxfoohk.supabase.co/storage/v1/object/public/$bucket/$path';
  }

  Widget _buildLetterAvatar(Color primary) {
    final name = loan.customerName ?? '';
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withValues(alpha: 0.25),
            primary.withValues(alpha: 0.05)
          ],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
              color: primary,
              fontSize: 15,
              fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final statusType = loan.status == LoanStatus.active
        ? StatusType.standard
        : loan.status == LoanStatus.defaultStatus
            ? StatusType.defaultStatus
            : loan.status == LoanStatus.pending
                ? StatusType.pending
                : StatusType.completed;

    final resolvedPhotoUrl = _resolvePhotoUrl(loan.customerPhotoUrl);

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () {
        HapticFeedback.selectionClick();
        if (onTap != null) {
          onTap!();
        } else {
          context.push('/loans/${loan.id}');
        }
      },
      child: Column(
        children: [
          // Header: Avatar, Name, ID, Balance, Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Hero(
                tag: 'loan_avatar_${loan.id}',
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: primary.withValues(alpha: 0.25), width: 1.5),
                  ),
                  child: ClipOval(
                    child: resolvedPhotoUrl != null
                        ? CachedNetworkImage(
                            imageUrl: resolvedPhotoUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: primary.withValues(alpha: 0.05),
                              child: const Center(
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.2,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) =>
                                _buildLetterAvatar(primary),
                          )
                        : _buildLetterAvatar(primary),
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
                      loan.customerName ?? 'Unknown Borrower',
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: -0.3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.tag_rounded,
                            size: 11,
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.6)),
                        const SizedBox(width: 3),
                        Text(
                          loan.loanNumber,
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              fontFamily: 'JetBrains Mono',
                              fontWeight: FontWeight.w600),
                        ),
                      ],
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
                    AppFormatters.formatCurrency(loan.outstandingBalance),
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: -0.4,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StatusBadge(
                    label: loan.status.name.toUpperCase(),
                    type: statusType,
                    glow: loan.status == LoanStatus.active,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.06)),
          const SizedBox(height: 8),

          // Footer: Next EMI & Actions
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: primary.withValues(alpha: 0.15), width: 0.8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_repeat_rounded, size: 12, color: primary),
                    const SizedBox(width: 4),
                    Text(
                      'Next Due: ${AppFormatters.formatDate(loan.firstEmiDate ?? loan.createdAt.add(const Duration(days: 30)))}',
                      style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: -0.1),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (loan.customerPhone != null) ...[
                _ActionButton(
                  icon: Icons.phone_in_talk_rounded,
                  color: primary,
                  onTap: () => _makeCall(loan.customerPhone!),
                ),
                const SizedBox(width: 6),
                _ActionButton(
                  icon: Icons.chat_bubble_rounded,
                  color: AppColors.success,
                  onTap: () => _makeWhatsApp(loan.customerPhone!),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 0.8),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Icon(icon, size: 14, color: color),
          ),
        ),
      ),
    );
  }
}

class _SliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SliverHeaderDelegate({required this.child});

  @override
  double get minExtent => 86;
  @override
  double get maxExtent => 86;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      child;

  @override
  bool shouldRebuild(_SliverHeaderDelegate oldDelegate) => true;
}
