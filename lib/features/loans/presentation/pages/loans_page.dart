import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/file_download.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/widgets/glass_button.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/providers/branding_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../../core/models/statement_org_info.dart';
import '../../data/models/loan_model.dart';
import '../../data/services/portfolio_statement_pdf_service.dart';
import '../providers/loan_providers.dart';
import '../widgets/portfolio_statement_options_sheet.dart';
import '../widgets/statement_generation_overlay.dart';
import '../widgets/collection_sheet.dart';
import '../../../home/data/providers/dashboard_providers.dart' show loanSummaryProvider;
import '../../../auth/presentation/providers/auth_provider.dart';

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
  LoanStatus? _filterStatus = LoanStatus.active;
  // The loan section opens on Active so the running book is the first thing you
  // see, matching how the savings hub opens on Active vaults.

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
  Set<String>? _cachedOverdueIds;

  List<LoanModel> _getFilteredList(List<LoanModel> loans,
      [Set<String> overdueLoanIds = const {}]) {
    final overdueChanged = _cachedOverdueIds == null ||
        _cachedOverdueIds!.length != overdueLoanIds.length ||
        !_cachedOverdueIds!.containsAll(overdueLoanIds);

    if (_cachedSource == loans &&
        _cachedFilterStatus == _filterStatus &&
        _cachedSearchQuery == _searchQuery &&
        _cachedSortBy == _sortBy &&
        _cachedSortAscending == _sortAscending &&
        !overdueChanged &&
        _cachedFiltered != null) {
      return _cachedFiltered!;
    }

    var filtered = loans.where((l) {
      if (_filterStatus == LoanStatus.defaultStatus) {
        // 'At Risk' means money is actually late: the loan is flagged defaulted
        // OR it has an unpaid instalment past its due date. Nothing in the app
        // ever sets the defaulted status, so the second half is what matters.
        final isDefaulted = l.status == LoanStatus.defaultStatus;
        if (!isDefaulted && !overdueLoanIds.contains(l.id)) return false;
      } else if (_filterStatus != null && l.status != _filterStatus) {
        return false;
      }
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
    _cachedOverdueIds = overdueLoanIds;
    _cachedFiltered = filtered;
    return filtered;
  }

  final List<Map<String, dynamic>> _filters = [
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
    {'label': 'All Loans', 'status': null, 'icon': Icons.dashboard_rounded},
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.invalidate(loansProvider);
      ref.invalidate(loanSummaryProvider);
      ref.invalidate(overdueByLoanProvider);
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
    ref.invalidate(overdueByLoanProvider);
    return await ref.read(loansProvider.future).then((_) => null);
  }

  void _openCollectionSheet(LoanModel loan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CollectionSheet(
          loan: loan,
          branchId: ref.read(currentUserProvider)?.branchId,
        ),
      ),
    ).then((_) {
      ref.invalidate(loansProvider);
      ref.invalidate(loanSummaryProvider);
      ref.invalidate(overdueByLoanProvider);
    });
  }

  Future<void> _makePhoneCall(String phone) async {
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch phone dialer')),
        );
      }
    }
  }

  Future<void> _handlePortfolioStatement() async {
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    final options = await showModalBottomSheet<PortfolioStatementOptions>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const PortfolioStatementOptionsSheet(),
    );
    if (options == null || !mounted) return;

    StatementGenerationOverlay.show(context);

    try {
      final summary = await ref.read(loanSummaryProvider.future);
      final loans = await ref.read(loansProvider.future);
      final orgRaw = await ref.read(currentOrgProvider.future);
      final brandingState = ref.read(brandingProvider);
      final logoBytes = brandingState.value != null
          ? ref.read(brandingProvider.notifier).cachedLogoBytes
          : null;

      final org = StatementOrgInfo(
        name: (orgRaw?['display_name'] ??
                orgRaw?['name'] ??
                'MicroFlow Pro')
            .toString(),
        address: orgRaw?['address'] as String?,
        city: orgRaw?['city'] as String?,
        state: orgRaw?['state'] as String?,
        pincode: orgRaw?['pincode'] as String?,
        phone: orgRaw?['phone'] as String?,
        email: orgRaw?['email'] as String?,
        gstNumber: orgRaw?['gst_number'] as String?,
        logoBytes: logoBytes,
      );

      final now = DateTime.now();
      final ref0 =
          'PORTFOLIO-${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';

      // Calculate overdue amounts from EMI schedule for each loan
      final overdueAmounts = <String, double>{};
      for (final loan in loans) {
        if (loan.status != LoanStatus.active &&
            loan.status != LoanStatus.defaultStatus) {
          continue;
        }
        try {
          final schedule = await ref.read(emiScheduleProvider(loan.id).future);
          final today = DateTime(now.year, now.month, now.day);
          final overdueEmis = schedule
              .where((e) => e.status != EMIStatus.paid &&
                  e.status != EMIStatus.waived &&
                  e.status != EMIStatus.frozen &&
                  e.dueDate.isBefore(today))
              .toList();
          if (overdueEmis.isNotEmpty) {
            final total = overdueEmis.fold<double>(
                0.0, (sum, e) => sum + e.emiAmount);
            overdueAmounts[loan.id] = total;
          }
        } catch (_) {}
      }

      final bytes = await PortfolioStatementPdfService.buildPortfolioStatement(
        summary: summary,
        loans: loans,
        org: org,
        generatedByName: ref.read(currentUserProvider)?.fullName,
        periodStart: options.periodStart,
        periodEnd: options.periodEnd,
        statementRef: ref0,
        overdueAmounts: overdueAmounts,
      );

      final fileName =
          'portfolio_statement_${now.millisecondsSinceEpoch}.pdf';

      File? localFile;
      if (kIsWeb) {
        downloadFileForWeb(bytes, fileName, 'application/pdf');
      } else {
        final dir = await getApplicationDocumentsDirectory();
        localFile = File('${dir.path}/$fileName');
        await localFile.writeAsBytes(bytes);
      }

      StatementGenerationOverlay.dismiss();
      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted) return;
      if (kIsWeb) {
        messenger.showSnackBar(SnackBar(
          content: Text('Statement downloaded: $fileName'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      } else {
        _showStatementReadySheet(
          file: localFile!,
          fileName: fileName,
        );
      }
    } catch (e, st) {
      debugPrint('Portfolio statement generation failed: $e\n$st');
      StatementGenerationOverlay.dismiss();
      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Failed to generate statement.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '$e',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.error,
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  void _showStatementReadySheet({
    required File file,
    required String fileName,
  }) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.success,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Statement Ready',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                fileName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color
                      ?.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    OpenFilex.open(file.path);
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text(
                    'Open PDF',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    SharePlus.instance.share(ShareParams(
                      files: [XFile(file.path, mimeType: 'application/pdf')],
                      text: 'Loan Portfolio Statement',
                    ));
                  },
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text(
                    'Share',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loansAsync = ref.watch(loansProvider);
    final summaryAsync = ref.watch(loanSummaryProvider);
    // Loan ids with genuinely late instalments, used by the At Risk chip.
    final overdueLoanIds =
        (ref.watch(overdueByLoanProvider).valueOrNull ?? const <String, double>{})
            .keys
            .toSet();
    final overdueByLoan =
        ref.watch(overdueByLoanProvider).valueOrNull ?? const <String, double>{};
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
                            const SizedBox(width: 12),
                            // Portfolio Statement button
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _handlePortfolioStatement();
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.black.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: theme.dividerColor.withValues(alpha: 0.15),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.description_rounded,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 150.ms)
                                .scale(begin: const Offset(0.9, 0.9)),
                            const SizedBox(width: 10),
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
                    final filtered = _getFilteredList(loans, overdueLoanIds);

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
                            final loan = filtered[i];
                            final isActive =
                                loan.status == LoanStatus.active;
                            final hasPhone = loan.customerPhone != null &&
                                loan.customerPhone!.trim().isNotEmpty;

                            Widget card = Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PremiumLoanCard(
                                loan: loan,
                                overdueAmount: overdueByLoan[loan.id] ?? 0,
                                onTap: widget.onLoanTap != null
                                    ? () => widget.onLoanTap!(loan.id)
                                    : null,
                              ),
                            );

                            // Only animate first 10 items
                            if (i < 10) {
                              card = card
                                  .animate()
                                  .fadeIn(delay: (40 * i).ms)
                                  .slideY(
                                      begin: 0.08,
                                      end: 0,
                                      curve: Curves.easeOutQuart);
                            }

                            if (isActive) {
                              card = Dismissible(
                                key: ValueKey('loan_${loan.id}'),
                                direction: DismissDirection.horizontal,
                                confirmDismiss: (direction) async {
                                  if (direction ==
                                      DismissDirection.startToEnd) {
                                    HapticFeedback.mediumImpact();
                                    _openCollectionSheet(loan);
                                  } else if (hasPhone) {
                                    HapticFeedback.lightImpact();
                                    _makePhoneCall(loan.customerPhone!);
                                  }
                                  return false;
                                },
                                background: _SwipeBackground(
                                  icon: Icons.payment_rounded,
                                  label: 'Collect',
                                  color: AppColors.success,
                                  align: Alignment.centerLeft,
                                ),
                                secondaryBackground: hasPhone
                                    ? _SwipeBackground(
                                        icon: Icons.call_rounded,
                                        label: 'Call',
                                        color: AppColors.success,
                                        align: Alignment.centerRight,
                                      )
                                    : null,
                                child: card,
                              );
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
    final collectedPct = summary.totalDisbursed > 0
        ? (summary.totalCollected / summary.totalDisbursed) * 100
        : 0.0;
    final pctLabel = collectedPct > 0 && collectedPct < 1
        ? '<1%'
        : '${collectedPct.toStringAsFixed(0)}%';
    // Keep a sliver of green visible even when almost nothing is collected, so
    // the bar never looks empty.
    final barFactor = collectedPct <= 0
        ? 0.0
        : (collectedPct / 100).clamp(0.02, 1.0).toDouble();

    final muted = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.62);
    final cardColor = isDark ? const Color(0xFF16161C) : Colors.white;
    final trackColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFEEECF6);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.10), width: 1),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL OUTSTANDING',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.85,
                          color: muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          AppFormatters.formatCurrency(summary.totalOutstanding),
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.9,
                            height: 1.0,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'COLLECTED',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.85,
                        color: muted,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppFormatters.formatCurrency(summary.totalCollected),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        height: 1.0,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Recovery bar: how much of the disbursed book has actually come
            // back, so the two numbers above read as one story.
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 7,
                color: trackColor,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: barFactor,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0FA958), Color(0xFF39C878)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$pctLabel recovered',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
                Text(
                  // The bar is a share of disbursed capital, so name the
                  // denominator instead of repeating the outstanding figure
                  // that is already the headline.
                  'of ${AppFormatters.formatCurrency(summary.totalDisbursed)} disbursed',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: _buildBentoTile(
                    label: 'CAPITAL DEPLOYED',
                    value: AppFormatters.formatCurrency(summary.totalDisbursed),
                    color: isDark ? Colors.white70 : primary,
                    labelColor: muted ?? Colors.grey,
                    sub: 'across ${summary.totalLoans} loan${summary.totalLoans == 1 ? '' : 's'}',
                    background: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : const Color(0xFFF7F6FC),
                    border: theme.dividerColor.withValues(alpha: 0.10),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildBentoTile(
                    label: 'OVERDUE',
                    value: AppFormatters.formatCurrency(summary.overdueAmount),
                    color: summary.overdueAmount > 0
                        ? (isDark ? AppColors.error : const Color(0xFFB3253A))
                        : theme.textTheme.bodySmall?.color ??
                            theme.colorScheme.onSurface,
                    labelColor: muted ?? Colors.grey,
                    sub: summary.overdueAmount > 0
                        ? 'on ${summary.overdueLoans} loan${summary.overdueLoans == 1 ? '' : 's'}'
                        : 'nothing late',
                    background: summary.overdueAmount > 0
                        ? AppColors.error.withValues(alpha: 0.08)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : const Color(0xFFF7F6FC)),
                    border: summary.overdueAmount > 0
                        ? AppColors.error.withValues(alpha: 0.18)
                        : theme.dividerColor.withValues(alpha: 0.10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBentoTile({
    required String label,
    required String value,
    required Color color,
    required Color labelColor,
    required Color background,
    required Color border,
    String? sub,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: labelColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                height: 1.0,
                color: color,
              ),
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(
              sub,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: labelColor.withValues(alpha: 0.85),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 16,
                      color: theme.textTheme.bodySmall?.color
                          ?.withValues(alpha: 0.6)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
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
    final isAtRisk = _filterStatus == LoanStatus.defaultStatus;
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
            child: Icon(
                isAtRisk
                    ? Icons.verified_rounded
                    : Icons.account_balance_rounded,
                size: 72,
                color: primary.withValues(alpha: 0.2)),
          ),
          const SizedBox(height: 24),
          Text(isAtRisk ? 'Nothing At Risk' : 'No Loans Found',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900, fontSize: 24)),
          const SizedBox(height: 8),
          Text(
              isAtRisk
                  ? 'Every instalment is paid or not due yet.'
                  : 'Adjust your filters or deploy new capital.',
              textAlign: TextAlign.center,
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

class _PremiumLoanCard extends StatelessWidget {
  final LoanModel loan;
  final VoidCallback? onTap;

  /// Unpaid instalments that are already past their due date, for this loan.
  final double overdueAmount;

  const _PremiumLoanCard({
    required this.loan,
    this.onTap,
    this.overdueAmount = 0,
  });

  DateTime _computeNextDueDate(LoanModel loan) {
    final firstEmi = loan.firstEmiDate ?? loan.createdAt.add(const Duration(days: 30));
    final paid = loan.paidEmis;
    final unit = (loan.tenureUnit ?? 'month').toLowerCase();
    switch (unit) {
      case 'day':
      case 'days':
        return firstEmi.add(Duration(days: paid));
      case 'week':
      case 'weeks':
        return firstEmi.add(Duration(days: paid * 7));
      case 'year':
      case 'years':
        return DateTime(firstEmi.year + paid ~/ 12, firstEmi.month + paid % 12, firstEmi.day);
      case 'month':
      case 'months':
      default:
        return DateTime(firstEmi.year, firstEmi.month + paid, firstEmi.day);
    }
  }

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
              if (overdueAmount > 0)
                // A loan with late instalments must not look like a healthy
                // one: say how much is late, not just when the next EMI is.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.35),
                        width: 0.8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 12, color: AppColors.error),
                      const SizedBox(width: 4),
                      Text(
                        'Overdue: ${AppFormatters.formatCurrency(overdueAmount)}',
                        style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: -0.1),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        'Next Due: ${AppFormatters.formatDate(loan.nextDueDate ?? _computeNextDueDate(loan))}',
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
      margin: const EdgeInsets.only(bottom: 12),
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
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
                const SizedBox(width: 6),
                Icon(icon, color: color, size: 18),
              ]
            : [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
              ],
      ),
    );
  }
}
