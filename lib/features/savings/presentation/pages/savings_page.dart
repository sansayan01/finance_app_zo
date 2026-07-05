// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/file_download.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../../../core/providers/branding_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../../core/models/statement_org_info.dart';
import '../../data/models/savings_model.dart';
import '../../data/providers/savings_providers.dart';
import '../../data/services/portfolio_savings_statement_pdf_service.dart';
import '../../../loans/presentation/widgets/portfolio_statement_options_sheet.dart';
import '../../../loans/presentation/widgets/statement_generation_overlay.dart';
import '../../../home/data/providers/dashboard_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

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
  int _activeFilter = 0;
  String _searchQuery = '';
  final _searchController = TextEditingController();

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handlePortfolioStatement() async {
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    final options = await showModalBottomSheet<PortfolioStatementOptions>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const PortfolioStatementOptionsSheet(
        title: 'Savings Portfolio Statement',
        description: 'Generate a summary of your entire savings portfolio.',
      ),
    );
    if (options == null || !mounted) return;

    StatementGenerationOverlay.show(context);

    try {
      final summary = await ref.read(savingsSummaryProvider.future);
      final plans = await ref.read(savingsProvider.future);
      final orgRaw = await ref.read(currentOrgProvider.future);
      final brandingState = ref.read(brandingProvider);
      final logoBytes = brandingState.value != null
          ? ref.read(brandingProvider.notifier).cachedLogoBytes
          : null;

      final org = StatementOrgInfo(
        name: (orgRaw?['display_name'] ?? orgRaw?['name'] ?? 'MicroFlow Pro').toString(),
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
      final ref0 = 'SAVINGS-${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';

      final overdueAmounts = <String, double>{};
      for (final plan in plans) {
        if (plan.status != 'active') continue;
        try {
          final schedule = await ref.read(savingsScheduleProvider(plan.id).future);
          final today = DateTime(now.year, now.month, now.day);
          final overdueInstallments = schedule
              .where((i) => !i.isPaid && !i.isFrozen && i.dueDate.isBefore(today))
              .toList();
          if (overdueInstallments.isNotEmpty) {
            final total = overdueInstallments.fold<double>(0.0, (sum, i) => sum + i.amount);
            overdueAmounts[plan.id] = total;
          }
        } catch (_) {}
      }

      final bytes = await PortfolioSavingsStatementPdfService.buildPortfolioStatement(
        summary: summary,
        plans: plans,
        org: org,
        generatedByName: ref.read(currentUserProvider)?.fullName,
        periodStart: options.periodStart,
        periodEnd: options.periodEnd,
        statementRef: ref0,
        overdueAmounts: overdueAmounts,
      );

      final fileName = 'savings_portfolio_${now.millisecondsSinceEpoch}.pdf';

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      } else {
        _showStatementReadySheet(file: localFile!, fileName: fileName);
      }
    } catch (e, st) {
      debugPrint('Savings portfolio statement generation failed: $e\n$st');
      StatementGenerationOverlay.dismiss();
      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Failed to generate statement.', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('$e', maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: theme.colorScheme.error,
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  void _showStatementReadySheet({required File file, required String fileName}) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: AppColors.success, size: 28),
              ),
              const SizedBox(height: 16),
              Text('Statement Ready', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(fileName, style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.5)), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () { Navigator.pop(ctx); OpenFilex.open(file.path); },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Open PDF', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: theme.colorScheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () {
                    Navigator.pop(ctx);
                    SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'application/pdf')], text: 'Savings Portfolio Statement'));
                  },
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Share', style: TextStyle(fontWeight: FontWeight.w700)),
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
    final savingsAsync = ref.watch(savingsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF2F2F7),
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
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              _buildAppBar(context, theme, isDark),
              SliverToBoxAdapter(child: _buildHeroCard(savingsAsync, theme, isDark)),
              _buildFilters(theme, isDark),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
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
            color: (isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF2F2F7)).withOpacity(0.7),
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'VAULT OVERVIEW',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: theme.colorScheme.primary.withOpacity(0.8)),
          ),
          const SizedBox(height: 1),
          Text(
            'Savings Hub',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: theme.colorScheme.onSurface),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Center(
            child: GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); _handlePortfolioStatement(); },
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.dividerColor.withOpacity(0.15), width: 1),
                ),
                child: Icon(Icons.description_rounded, size: 16, color: theme.colorScheme.primary),
              ),
            ),
          ),
        ),
        if (widget.showCreateButton)
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: GestureDetector(
                onTap: () => context.push('/savings/new'),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeroCard(AsyncValue<List<SavingsModel>> savingsAsync, ThemeData theme, bool isDark) {
    return savingsAsync.when(
      data: (savings) {
        final totalSaved = savings.fold(0.0, (sum, s) => sum + s.currentAmount);
        final totalTarget = savings.fold(0.0, (sum, s) => sum + s.targetAmount);
        final progress = (totalTarget > 0 ? totalSaved / totalTarget : 0.0).clamp(0.0, 1.0);
        final avgRate = savings.isEmpty ? 0.0 : (savings.fold(0.0, (sum, s) => sum + s.interestRate) / savings.length);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Column(
            children: [
              // ── Main card — premium dark glass with muted accent ──
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF12141C).withOpacity(0.75)
                        : const Color(0xFF1A1D2E).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.white.withOpacity(0.12),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? Colors.black : const Color(0xFF1A1040)).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Subtle accent glow in top-right corner
                      Positioned(
                        top: -20,
                        right: -20,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.primary.withOpacity(isDark ? 0.12 : 0.15),
                                AppColors.primary.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Content
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryLight.withOpacity(isDark ? 0.1 : 0.12),
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                      child: Icon(Icons.savings_rounded, color: AppColors.primaryLight.withOpacity(isDark ? 0.8 : 0.9), size: 14),
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      'TOTAL SAVED',
                                      style: TextStyle(fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: Colors.white.withOpacity(0.4)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  AppFormatters.formatCurrency(totalSaved),
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.8, color: Colors.white.withOpacity(0.95), height: 1.0),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    _buildMiniMeta('${savings.length} plan${savings.length == 1 ? '' : 's'}', Colors.white.withOpacity(0.35)),
                                    const SizedBox(width: 8),
                                    Container(width: 1, height: 8, color: Colors.white.withOpacity(0.1)),
                                    const SizedBox(width: 8),
                                    _buildMiniMeta('${avgRate.toStringAsFixed(1)}% yield', Colors.white.withOpacity(0.35)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 52, height: 52,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 52, height: 52,
                                  child: CircularProgressIndicator(
                                    value: progress,
                                    strokeWidth: 3.5,
                                    backgroundColor: Colors.white.withOpacity(0.06),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primaryLight.withOpacity(isDark ? 0.7 : 0.85),
                                    ),
                                    strokeCap: StrokeCap.round,
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${(progress * 100).toInt()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.9), height: 1.0)),
                                    Text('goal', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.3), height: 1.0)),
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
              ),

            ],
          ),
        );
      },
      loading: () => const Padding(padding: EdgeInsets.fromLTRB(20, 8, 20, 8), child: ShimmerCard(height: 100)),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildMiniMeta(String text, Color color) {
    return Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color));
  }

  Widget _buildFilters(ThemeData theme, bool isDark) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _FilterDelegate(
        child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0A0A0C).withOpacity(0.85)
                    : const Color(0xFFF2F2F7).withOpacity(0.85),
              ),
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.dividerColor.withOpacity(isDark ? 0.08 : 0.06), width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.25)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) => setState(() => _searchQuery = value),
                              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                              decoration: InputDecoration(
                                hintText: 'Search by member name...',
                                hintStyle: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.3)),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        padding: EdgeInsets.zero,
                                        icon: Icon(Icons.close_rounded, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.35)),
                                        onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); },
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _buildFilterChip('All Vaults', 0, theme),
                        const SizedBox(width: 8),
                        _buildFilterChip('Active', 1, theme),
                        const SizedBox(width: 8),
                        _buildFilterChip('Matured', 2, theme),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildFilterChip(String label, int index, ThemeData theme) {
    final isSelected = _activeFilter == index;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); setState(() => _activeFilter = index); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected ? LinearGradient(colors: [AppColors.primary, AppColors.accent]) : null,
          color: !isSelected ? (isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.4)) : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.white.withOpacity(isDark ? 0.08 : 0.2), width: 0.5),
          boxShadow: [if (isSelected) BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.5),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 11,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }

  Widget _buildSavingsList(AsyncValue<List<SavingsModel>> savingsAsync, ThemeData theme, bool isDark) {
    return savingsAsync.when(
      data: (savings) {
        final filtered = savings.where((s) {
          final matchesFilter = (_activeFilter == 0) || (_activeFilter == 1 && s.status == 'active') || (_activeFilter == 2 && s.status == 'completed');
          final matchesSearch = s.memberName.toLowerCase().contains(_searchQuery.toLowerCase());
          return matchesFilter && matchesSearch;
        }).toList();

        if (filtered.isEmpty) return SliverFillRemaining(child: _buildEmptyState(theme));

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    child: _PremiumSavingCard(saving: saving),
                  ),
                ).animate().fadeIn(delay: (40 * index).ms, duration: 300.ms).slideY(begin: 0.04, end: 0, duration: 300.ms);
              },
              childCount: filtered.length,
            ),
          ),
        );
      },
      loading: () => SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => const Padding(padding: EdgeInsets.only(bottom: 8), child: ShimmerCard(height: 72)),
            childCount: 4,
          ),
        ),
      ),
      error: (e, _) => SliverFillRemaining(child: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primary.withOpacity(0.06), border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1), width: 1.5)),
            child: Icon(Icons.savings_outlined, size: 56, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text('No Savings Found', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('Your financial future starts with a single deposit.', textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5))),
        ],
      ),
    );
  }
}



class _PremiumSavingCard extends StatelessWidget {
  final SavingsModel saving;
  const _PremiumSavingCard({required this.saving});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final progress = (saving.targetAmount > 0) ? (saving.currentAmount / saving.targetAmount).clamp(0.0, 1.0) : 0.0;
    final initial = saving.memberName.trim().isNotEmpty ? saving.memberName.trim()[0].toUpperCase() : '?';
    final isActive = saving.status == 'active';
    final statusColor = isActive ? theme.colorScheme.primary : (isDark ? const Color(0xFF52D1A4) : const Color(0xFF059669));
    final statusBg = statusColor.withOpacity(isDark ? 0.12 : 0.08);
    final statusBorder = statusColor.withOpacity(isDark ? 0.2 : 0.15);

    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [primary.withOpacity(0.15), primary.withOpacity(0.06)]),
                      border: Border.all(color: primary.withOpacity(0.12), width: 1),
                    ),
                    child: Center(child: Text(initial, style: TextStyle(color: primary, fontSize: 15, fontWeight: FontWeight.w800))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(saving.memberName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: -0.2, color: theme.colorScheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(color: primary.withOpacity(0.06), borderRadius: BorderRadius.circular(4)),
                              child: Text(saving.collectionType.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: primary)),
                            ),
                            const SizedBox(width: 6),
                            Text('Due ${AppFormatters.formatDate(saving.maturityDate)}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface.withOpacity(0.4))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(AppFormatters.formatCurrency(saving.currentAmount), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: -0.3, color: statusColor)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: statusBorder, width: 0.5)),
                        child: Text(isActive ? 'ACTIVE' : 'MATURED', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 0.5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 2.5,
              child: LinearProgressIndicator(value: progress, backgroundColor: theme.colorScheme.onSurface.withOpacity(0.04), valueColor: AlwaysStoppedAnimation<Color>(statusColor)),
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => SizedBox.expand(child: child);

  @override
  double get maxExtent => 90;
  @override
  double get minExtent => 90;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}
