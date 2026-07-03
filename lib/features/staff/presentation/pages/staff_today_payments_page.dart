import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../../../../core/utils/file_download.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../payments/data/models/today_payment_model.dart';
import '../../../payments/data/providers/payment_providers.dart' show TodayPaymentData;
import '../../../payments/data/utils/payment_export.dart';
import '../../../payments/data/services/auto_collection_service.dart';
import '../../../branch_manager/data/providers/branch_payment_providers.dart';
import '../../data/providers/staff_branch_providers.dart';
import '../../data/providers/collection_providers.dart';
import '../../../savings/data/models/savings_model.dart';
import '../../../loans/data/models/loan_model.dart';
import '../../../loans/presentation/widgets/collection_sheet.dart';
import '../../../../core/widgets/premium_calendar_sheet.dart';

class StaffTodayPaymentsPage extends ConsumerStatefulWidget {
  const StaffTodayPaymentsPage({super.key});

  @override
  ConsumerState<StaffTodayPaymentsPage> createState() =>
      _StaffTodayPaymentsPageState();
}

class _StaffTodayPaymentsPageState
    extends ConsumerState<StaffTodayPaymentsPage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showSearch = false;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        HapticFeedback.selectionClick();
      }
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final newScrolled = _scrollController.offset > 80;
    if (newScrolled != _isScrolled) {
      setState(() => _isScrolled = newScrolled);
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
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
      HapticFeedback.selectionClick();
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
      builder: (ctx) => _SheetWrapper(
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHandle(),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Sort By',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              ...PaymentSortBy.values.map((sort) => ListTile(
                    title: Text(sort.label),
                    trailing: filters.sortBy == sort
                        ? Icon(Icons.check_circle, color: AppColors.primary)
                        : null,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(branchPaymentFilterProvider.notifier).setSortBy(sort);
                      Navigator.pop(ctx);
                    },
                  )),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ).animate().slideY(begin: 0.1, end: 0, duration: 350.ms, curve: Curves.easeOutCubic),
    );
  }

  void _showFilterSheet() {
    final branchId = ref.read(staffBranchIdProvider).valueOrNull;
    if (branchId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final filters = ref.watch(branchPaymentFilterProvider);
          final minController = TextEditingController(text: filters.minAmount?.toStringAsFixed(0) ?? '');
          final maxController = TextEditingController(text: filters.maxAmount?.toStringAsFixed(0) ?? '');
          final notifier = ref.read(branchPaymentFilterProvider.notifier);
          return _SheetWrapper(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SheetHandle(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Filters',
                        style:
                            TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        notifier.resetFilters();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Reset'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSection('Payment Type', Wrap(
                          spacing: 8, runSpacing: 8,
                          children: [
                            _FilterChip(label: 'Both', selected: filters.paymentTypeFilter == null, onTap: () => notifier.setPaymentType(null)),
                            _FilterChip(label: 'EMI', selected: filters.paymentTypeFilter == PaymentType.emi, onTap: () => notifier.setPaymentType(PaymentType.emi)),
                            _FilterChip(label: 'Savings', selected: filters.paymentTypeFilter == PaymentType.savings, onTap: () => notifier.setPaymentType(PaymentType.savings)),
                          ],
                        )),
                        _buildSection('Status', Wrap(
                          spacing: 8, runSpacing: 8,
                          children: [
                            _FilterChip(label: 'Pending', selected: filters.statusFilters.contains(PaymentStatus.pending), onTap: () => notifier.toggleStatusFilter(PaymentStatus.pending)),
                            _FilterChip(label: 'Overdue', selected: filters.statusFilters.contains(PaymentStatus.overdue), onTap: () => notifier.toggleStatusFilter(PaymentStatus.overdue)),
                            _FilterChip(label: 'Collected', selected: filters.statusFilters.contains(PaymentStatus.collected), onTap: () => notifier.toggleStatusFilter(PaymentStatus.collected)),
                          ],
                        )),
                        _buildSection('Amount Range', Row(children: [
                          Expanded(child: TextField(controller: minController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(hintText: 'Min', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), onChanged: (v) => notifier.setAmountRange(min: double.tryParse(v), clearMin: v.isEmpty, max: filters.maxAmount))),
                          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('—', style: TextStyle(color: Colors.grey))),
                          Expanded(child: TextField(controller: maxController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(hintText: 'Max', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), onChanged: (v) => notifier.setAmountRange(min: filters.minAmount, max: double.tryParse(v), clearMax: v.isEmpty))),
                        ])),
                        _buildSection('Payment Mode', Wrap(
                          spacing: 8, runSpacing: 8,
                          children: [for (final mode in ['Cash', 'UPI', 'Bank Transfer', 'Cheque'])
                            _FilterChip(label: mode, selected: filters.paymentModeFilters.contains(mode.toLowerCase()), onTap: () => notifier.togglePaymentMode(mode.toLowerCase())),
                          ],
                        )),
                        _buildSection('Overdue Days', Wrap(
                          spacing: 8, runSpacing: 8,
                          children: OverdueBucket.values.map((b) => _FilterChip(label: b.label, selected: filters.overdueDayFilters.contains(b), onTap: () => notifier.toggleOverdueBucket(b))).toList(),
                        )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(ctx);
                    },
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
      ).animate().slideY(begin: 0.1, end: 0, duration: 350.ms, curve: Curves.easeOutCubic);
      },
      ),
    );
  }

  Widget _buildSection(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Future<void> _handlePdfExport(TodayPaymentData data) async {
    final filters = ref.read(branchPaymentFilterProvider);
    final fileName = 'payments_report_${filters.dateLabel.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    const mime = 'application/pdf';

    try {
      final bytes = await PaymentExport.generatePdf(data, filters.dateLabel);

      if (kIsWeb) {
        downloadFileForWeb(bytes, fileName, mime);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Report downloaded: $fileName'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);

        if (mounted) {
          _showReportReadySheet(
            dateLabel: filters.dateLabel,
            file: file,
            ext: 'pdf',
            mime: mime,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to export report: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  void _showReportReadySheet({
    required String dateLabel,
    required File file,
    required String ext,
    required String mime,
  }) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SheetWrapper(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 20),

                // Success icon
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
                  'Report Ready',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  file.path.split('/').last,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),

                // Open button
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
                    label: Text(
                      'Open ${ext.toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Share button
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
                      SharePlus.instance.share(
                        ShareParams(
                          files: [XFile(file.path, mimeType: mime)],
                          text: 'Payments Report - $dateLabel',
                        ),
                      );
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
      ).animate().slideY(begin: 0.1, end: 0, duration: 350.ms, curve: Curves.easeOutCubic),
    );
  }

  void _sendReminder(TodayPayment payment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Send Reminder'),
        content: Text('Send payment reminder to ${payment.memberName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
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
    // Fetch the full savings plan
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
        Navigator.of(context, rootNavigator: true).push(
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
        Navigator.of(context, rootNavigator: true).push(
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

  Future<void> _performAutoCollection(TodayPayment payment, String branchId) async {
    final client = ref.read(supabaseClientProvider);
    final user = ref.read(currentUserProvider);
    if (user == null || user.orgId == null) return;

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
      final staffName = profile?['full_name']?.toString() ?? 'Staff';

      if (payment.type == PaymentType.savings) {
        final userRole = user.role?.name ?? 'collectionAgent';
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
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final branchAsync = ref.watch(staffBranchIdProvider);

    if (branchAsync.isLoading) {
      return Scaffold(
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        appBar: AppBar(title: const Text('Today\'s Payments')),
        body: const _ShimmerLoading(),
      );
    }

    final branchId = branchAsync.valueOrNull;

    if (branchId == null) {
      return Scaffold(
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        appBar: AppBar(title: const Text('Today\'s Payments')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'No branch assigned to your profile.\nContact your admin to assign a branch.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final paymentsAsync = ref.watch(branchTodayPaymentsProvider(branchId));
    final filters = ref.watch(branchPaymentFilterProvider);

    // Auto-refresh timer
    ref.listen<BranchPaymentFilterState>(branchPaymentFilterProvider,
        (prev, next) {
      if (next.autoRefresh && next.isToday) {
        ref.watch(branchAutoRefreshTimerProvider);
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
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
                style:
                    TextStyle(color: isDark ? Colors.white : Colors.black),
              )
            : GestureDetector(
                onTap: _pickDate,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      filters.isToday
                          ? "Today's Payments"
                          : 'Payments · ${filters.dateLabel}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ],
                ),
              ),
        actions: [
          if (!_showSearch) ...[
            IconButton(
              icon: Icon(Icons.search_rounded,
                  size: 24,
                  color: isDark ? Colors.white70 : Colors.black54),
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _showSearch = true);
              },
            ),
            IconButton(
              icon: Icon(
                Icons.tune_rounded,
                size: 24,
                color: filters.hasActiveFilters
                    ? AppColors.primary
                    : (isDark ? Colors.white54 : Colors.black38),
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                _showFilterSheet();
              },
            ),
            PopupMenuButton(
              icon: Icon(Icons.more_vert_rounded,
                  size: 24,
                  color: isDark ? Colors.white54 : Colors.black38),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              itemBuilder: (ctx) => <PopupMenuEntry<dynamic>>[
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
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref
                        .read(branchPaymentFilterProvider.notifier)
                        .toggleAutoRefresh();
                  },
                ),
                PopupMenuItem(
                  child: const ListTile(
                    leading: Icon(Icons.sort_rounded, size: 20),
                    title: Text('Sort'),
                    dense: true,
                  ),
                  onTap: () =>
                      Future.delayed(Duration.zero, () => _showSortSheet()),
                ),
                PopupMenuItem(
                  child: const ListTile(
                    leading: Icon(Icons.refresh_rounded, size: 20),
                    title: Text('Refresh'),
                    dense: true,
                  ),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ref.invalidate(branchTodayPaymentsProvider(branchId));
                  },
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  child: const ListTile(
                    leading: Icon(Icons.picture_as_pdf_rounded, size: 20),
                    title: Text('Export PDF'),
                    dense: true,
                  ),
                  onTap: () => paymentsAsync.maybeWhen(
                    data: (data) => Future.delayed(Duration.zero, () => _handlePdfExport(data)),
                    orElse: () {},
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: AuroraBackground(
        child: paymentsAsync.when(
        loading: () => const _ShimmerLoading(),
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
                  onPressed: () {
                    ref.invalidate(branchTodayPaymentsProvider(branchId));
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
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
          final groupedOverdue = data.groupedOverduePayments;

          return CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Scrollable compact bento hero header
              SliverToBoxAdapter(
                child: _HeroHeader(
                  summary: summary,
                  isDark: isDark,
                ),
              ),

              // Active Filters
              if (filters.hasActiveFilters)
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
                    _buildPaymentList(pending, overdue, isDark, 'No pending payments',
                        'Everything is up to date!', Icons.schedule_rounded,
                        AppColors.warning, branchId),
                    _buildGroupedOverdueList(
                        groupedOverdue, isDark, branchId),
                    _buildPaymentList(collected, overdue, isDark, 'No collections yet',
                        'Payments you collect will appear here',
                        Icons.check_circle_outline_rounded,
                        AppColors.success, branchId),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }







  // Active Filters
  Widget _buildActiveFilters(BranchPaymentFilterState filters, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_rounded,
              size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              () {
                final labels = <String>[];
                if (filters.agentId != null) labels.add('Agent');
                if (filters.paymentTypeFilter != null) {
                  labels.add(filters.paymentTypeFilter == PaymentType.emi ? 'EMI' : 'Savings');
                }
                if (filters.statusFilters.isNotEmpty) labels.add('Status');
                if (filters.minAmount != null || filters.maxAmount != null) labels.add('Amount');
                if (filters.paymentModeFilters.isNotEmpty) labels.add('Payment Mode');
                if (filters.overdueDayFilters.isNotEmpty) labels.add('Overdue Days');
                if (labels.length > 3) return 'Filtered by: ${labels.length} active filters';
                return 'Filtered by: ${labels.join(' + ')}';
              }(),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: () =>
                ref.read(branchPaymentFilterProvider.notifier).resetFilters(),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Clear',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Payment List — with staggered animations and swipe actions
  Widget _buildPaymentList(
      List<TodayPayment> payments, List<TodayPayment> overduePayments, bool isDark, String emptyTitle,
      String emptySubtitle, IconData emptyIcon, Color emptyColor,
      String branchId) {
    if (payments.isEmpty) {
      return _AnimatedEmptyState(
        title: emptyTitle,
        subtitle: emptySubtitle,
        icon: emptyIcon,
        color: emptyColor,
        isDark: isDark,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.lightImpact();
        ref.invalidate(branchTodayPaymentsProvider(branchId));
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: payments.length,
        itemBuilder: (context, index) {
          final payment = payments[index];
          final onCallFn = payment.memberPhone != null
              ? () => _makePhoneCall(payment.memberPhone!)
              : null;
          void onRemindFn() => _sendReminder(payment);
          final onCollectFn = !payment.isCollected
              ? () {
                  final hasOverdues = payment.isOverdue || overduePayments.any((o) => o.memberId == payment.memberId && payment.memberId != null);
                  if (hasOverdues) {
                    _showQuickCollect(payment);
                  } else {
                    _performAutoCollection(payment, branchId);
                  }
                }
              : null;

          final card = _PaymentCard(
            payment: payment,
            isDark: isDark,
            onCall: onCallFn,
            onRemind: onRemindFn,
            onTap: () => _showPaymentDetails(payment),
            onCollect: onCollectFn,
          );

          // Stagger animation
          final animatedCard = card
              .animate(delay: Duration(milliseconds: index * 35))
              .fadeIn(duration: 350.ms, curve: Curves.easeOut)
              .slideY(
                begin: 0.08,
                end: 0,
                duration: 350.ms,
                curve: Curves.easeOutCubic,
              );

          // Swipe-to-action (only for uncollected items)
          if (payment.isCollected) return animatedCard;
          return Dismissible(
            key: ValueKey('pay_${payment.id}'),
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
                ? _buildSwipeBackground(
                    isDark,
                    Icons.payment_rounded,
                    'Collect',
                    AppColors.primary,
                    Alignment.centerLeft,
                  )
                : null,
            secondaryBackground: _buildSwipeBackground(
              isDark,
              onCallFn != null
                  ? Icons.call_rounded
                  : Icons.notifications_active_rounded,
              onCallFn != null ? 'Call' : 'Remind',
              onCallFn != null
                  ? AppColors.success
                  : AppColors.warning,
              Alignment.centerRight,
            ),
            onUpdate: (details) {
              if (details.progress > 0.3 &&
                  details.progress < 0.35) {
                HapticFeedback.selectionClick();
              }
            },
            child: animatedCard,
          );
        },
      ),
    );
  }

  // Grouped Overdue List — one card per loan
  Widget _buildGroupedOverdueList(
      List<GroupedOverduePayment> groups, bool isDark, String branchId) {
    if (groups.isEmpty) {
      return _AnimatedEmptyState(
        title: 'No overdue payments',
        subtitle: 'No one is behind schedule',
        icon: Icons.warning_amber_rounded,
        color: AppColors.error,
        isDark: isDark,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.lightImpact();
        ref.invalidate(branchTodayPaymentsProvider(branchId));
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          final card = _GroupedOverdueCard(
            group: group,
            isDark: isDark,
            onCall: group.memberPhone != null
                ? () => _makePhoneCall(group.memberPhone!)
                : null,
            onRemind: () {
              // Send reminder for the first payment
              if (group.payments.isNotEmpty) {
                _sendReminder(group.payments.first);
              }
            },
            onTap: () {
              // Show details for the first payment
              if (group.payments.isNotEmpty) {
                _showPaymentDetails(group.payments.first);
              }
            },
            onCollect: () {
              // Collect using the first payment's loan info
              if (group.payments.isNotEmpty) {
                _showQuickCollect(group.payments.first);
              }
            },
          );

          final animatedCard = card
              .animate(delay: Duration(milliseconds: index * 35))
              .fadeIn(duration: 350.ms, curve: Curves.easeOut)
              .slideY(
                begin: 0.08,
                end: 0,
                duration: 350.ms,
                curve: Curves.easeOutCubic,
              );

          return Dismissible(
            key: ValueKey('grouped_${group.memberId}'),
            direction: DismissDirection.horizontal,
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                HapticFeedback.mediumImpact();
                if (group.payments.isNotEmpty) {
                  _showQuickCollect(group.payments.first);
                }
              } else if (direction == DismissDirection.endToStart) {
                if (group.memberPhone != null) {
                  HapticFeedback.lightImpact();
                  _makePhoneCall(group.memberPhone!);
                } else {
                  HapticFeedback.lightImpact();
                  if (group.payments.isNotEmpty) {
                    _sendReminder(group.payments.first);
                  }
                }
              }
              return false;
            },
            background: _buildSwipeBackground(
              isDark,
              Icons.payment_rounded,
              'Collect',
              AppColors.primary,
              Alignment.centerLeft,
            ),
            secondaryBackground: _buildSwipeBackground(
              isDark,
              group.memberPhone != null
                  ? Icons.call_rounded
                  : Icons.notifications_active_rounded,
              group.memberPhone != null ? 'Call' : 'Remind',
              group.memberPhone != null
                  ? AppColors.success
                  : AppColors.warning,
              Alignment.centerRight,
            ),
            onUpdate: (details) {
              if (details.progress > 0.3 && details.progress < 0.35) {
                HapticFeedback.selectionClick();
              }
            },
            child: animatedCard,
          );
        },
      ),
    );
  }

  Widget _buildSwipeBackground(
      bool isDark, IconData icon, String label, Color color, Alignment align) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: align,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: align == Alignment.centerRight
            ? [
                Text(label,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                Icon(icon, color: color, size: 20),
              ]
            : [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w700)),
              ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phone) async {
    HapticFeedback.lightImpact();
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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
      builder: (ctx) => _SheetWrapper(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SheetHandle(),

                // Header
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            payment.typeColor.withValues(alpha: 0.18),
                            payment.typeColor.withValues(alpha: 0.06),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
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
                          Text(
                            payment.memberName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _StatusPill(
                              status: payment.status, type: payment.type),
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
                const SizedBox(height: 24),

                // Details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).brightness == Brightness.dark
                        ? AppColors.fillDark
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      _DetailRow('Type', payment.typeLabel),
                      if (payment.loanNumber != null)
                        _DetailRow('Loan Number', payment.loanNumber!),
                      if (payment.emiNumber != null)
                        _DetailRow('EMI Number', '#${payment.emiNumber}'),
                      if (payment.planName != null)
                        _DetailRow('Savings Plan', payment.planName!),
                      _DetailRow('Due Date', dateFormat.format(payment.dueDate)),
                      if (payment.isOverdue)
                        _DetailRow('Overdue', payment.overdueLabel,
                            valueColor: AppColors.error),
                      if (payment.penaltyAmount > 0)
                        _DetailRow('Penalty',
                            currencyFormat.format(payment.penaltyAmount),
                            valueColor: AppColors.error),
                      if (payment.memberPhone != null)
                        _DetailRow('Phone', payment.memberPhone!),
                      if (payment.paymentMode != null)
                        _DetailRow(
                            'Payment Mode', payment.paymentMode!.toUpperCase()),
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

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (payment.memberPhone != null)
                      _DetailActionButton(
                        icon: Icons.call_rounded,
                        color: AppColors.success,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(ctx);
                          _makePhoneCall(payment.memberPhone!);
                        },
                      ),
                    if (payment.memberPhone != null && !payment.isCollected)
                      const SizedBox(width: 14),
                    if (!payment.isCollected) ...[
                      _DetailActionButton(
                        icon: Icons.notifications_active_rounded,
                        color: AppColors.warning,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(ctx);
                          _sendReminder(payment);
                        },
                      ),
                      const SizedBox(width: 14),
                      _DetailActionButton(
                        icon: Icons.payment_rounded,
                        color: AppColors.primary,
                        onTap: () {
                          HapticFeedback.mediumImpact();
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
                          HapticFeedback.lightImpact();
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
      ).animate().slideY(begin: 0.1, end: 0, duration: 350.ms, curve: Curves.easeOutCubic),
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



// Detail Row
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
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.grey.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Payment Card — premium compact style
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
      child: GlassCard(
        glassmorphic: true,
        margin: const EdgeInsets.only(bottom: 10),
        borderRadius: 14,
        borderColor: payment.statusColor.withValues(alpha: isDark ? 0.15 : 0.1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _PaymentAvatar(
                type: payment.type,
                icon: payment.typeIcon,
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
    );
  }
}

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

// ═══════════════════════════════════════════════════════════════════════════
// GROUPED OVERDUE CARD — shows multiple overdue EMIs in one card
// ═══════════════════════════════════════════════════════════════════════════

class _GroupedOverdueCard extends StatelessWidget {
  final GroupedOverduePayment group;
  final bool isDark;
  final VoidCallback? onCall;
  final VoidCallback onRemind;
  final VoidCallback onTap;
  final VoidCallback onCollect;

  const _GroupedOverdueCard({
    required this.group,
    required this.isDark,
    this.onCall,
    required this.onRemind,
    required this.onTap,
    required this.onCollect,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\u20b9', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy');
    final name = group.memberName;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.error.withValues(alpha: isDark ? 0.18 : 0.08),
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
                type: group.payments.isNotEmpty ? group.payments.first.type : PaymentType.emi,
                icon: group.payments.isNotEmpty ? group.payments.first.typeIcon : Icons.warning_amber_rounded,
                color: AppColors.error,
                isCollected: false,
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
                            name,
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
                              currencyFormat.format(group.totalAmount),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14.5,
                                letterSpacing: -0.4,
                                color: AppColors.error,
                              ),
                            ),
                            if (group.totalPenalty > 0) ...[
                              const SizedBox(width: 3),
                              Text(
                                '+${currencyFormat.format(group.totalPenalty)}',
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
                                group.payments.length > 1
                                    ? '${group.payments.length} overdue ${group.payments.first.type == PaymentType.savings ? "savings" : "EMIs"} \u00b7 ${group.loanLabel}'
                                    : '${group.payments.isNotEmpty ? group.payments.first.typeLabel : "EMI"} \u00b7 ${group.loanLabel}',
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
                                  const Icon(
                                    Icons.schedule_rounded,
                                    size: 10,
                                    color: AppColors.error,
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      'Due: ${dateFormat.format(group.earliestDueDate)}',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
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
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () { HapticFeedback.mediumImpact(); onCollect(); },
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
                        ),
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


// ═══════════════════════════════════════════════════════════════════════════
// PREMIUM HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

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
      margin: const EdgeInsets.fromLTRB(20, 72, 20, 8),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF080D1A),
                  Color(0xFF0F172A),
                ]
              : const [
                  Color(0xFF0F172A),
                  Color(0xFF1E3A5F),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.1),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
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
                  fontSize: 11,
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
          const SizedBox(height: 14),
          // Large Amount
          Text(
            currencyFormat.format(summary.totalDue),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 18),
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

// Shimmer loading state
class _ShimmerLoading extends StatelessWidget {
  const _ShimmerLoading();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppColors.fillDark : Colors.grey.shade300;
    final highlight = isDark ? AppColors.elevatedDark : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(
              3,
              (i) => Expanded(
                child: Container(
                  height: 90,
                  margin: EdgeInsets.only(right: i < 2 ? 10 : 0),
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(
            4,
            (i) => Container(
              height: 100,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Animated empty state with pulsing icon
class _AnimatedEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _AnimatedEmptyState({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.12),
                    color.withValues(alpha: 0.04),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: 0.15),
                  width: 2,
                ),
              ),
              child:
                  Icon(icon, size: 56, color: color.withValues(alpha: 0.7)),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  duration: 1800.ms,
                  begin: const Offset(1, 1),
                  end: const Offset(1.06, 1.06),
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 500.ms, curve: Curves.easeOut)
          .slideY(
              begin: 0.1,
              end: 0,
              duration: 500.ms,
              curve: Curves.easeOutCubic),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ANIMATED GLOW ORB — floating decorative element
// ═══════════════════════════════════════════════════════════════════════════



// ═══════════════════════════════════════════════════════════════════════════
// ANIMATED EXPORT FAB — with glow pulse
// ═══════════════════════════════════════════════════════════════════════════



// ═══════════════════════════════════════════════════════════════════════════
// SHEET HANDLE — consistent drag indicator
// ═══════════════════════════════════════════════════════════════════════════

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        width: 40,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(100),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARE OPTION — for export bottom sheet
// ═══════════════════════════════════════════════════════════════════════════



// ═══════════════════════════════════════════════════════════════════════════
// FILTER CHIP — for filter bottom sheet
// ═══════════════════════════════════════════════════════════════════════════

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.separatorDark,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? AppColors.primary
                : AppColors.textSecondaryDark,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STATUS PILL — payment status indicator
// ═══════════════════════════════════════════════════════════════════════════

class _StatusPill extends StatelessWidget {
  final PaymentStatus status;
  final PaymentType type;

  const _StatusPill({required this.status, required this.type});

  Color get statusColor {
    switch (status) {
      case PaymentStatus.overdue:
        return AppColors.error;
      case PaymentStatus.pending:
        return type == PaymentType.emi ? AppColors.warning : AppColors.mint;
      case PaymentStatus.collected:
        return AppColors.success;
    }
  }

  String get statusLabel {
    switch (status) {
      case PaymentStatus.overdue:
        return 'Overdue';
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.collected:
        return 'Collected';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (status == PaymentStatus.pending || status == PaymentStatus.overdue) {
      return const SizedBox.shrink();
    }
    final color = statusColor;
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
            statusLabel,
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

class _PaymentAvatar extends StatelessWidget {
  final PaymentType type;
  final IconData icon;
  final Color color;
  final bool isCollected;

  const _PaymentAvatar({
    required this.type,
    required this.icon,
    required this.color,
    required this.isCollected,
  });

  @override
  Widget build(BuildContext context) {
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
        child: Icon(
          icon,
          color: color.withValues(alpha: isCollected ? 0.5 : 0.85),
          size: 18,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHEET WRAPPER — animated bottom sheet container
// ═══════════════════════════════════════════════════════════════════════════

class _SheetWrapper extends StatelessWidget {
  final Widget child;
  const _SheetWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ClipRRect(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
        child: child,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ANIMATED BOTTOM SHEET — with slide-in effect
// ═══════════════════════════════════════════════════════════════════════════

