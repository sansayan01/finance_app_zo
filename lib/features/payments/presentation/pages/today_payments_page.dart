import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../../../../core/utils/file_download.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/premium_calendar_sheet.dart';
import '../../data/models/today_payment_model.dart';
import '../../data/providers/payment_providers.dart';
import '../../data/utils/payment_export.dart';
import '../../data/services/auto_collection_service.dart';
import '../../../savings/data/models/savings_model.dart';
import '../../../staff/data/providers/collection_providers.dart';
import '../../../loans/data/models/loan_model.dart';
import '../../../loans/presentation/widgets/collection_sheet.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class TodayPaymentsPage extends ConsumerStatefulWidget {
  const TodayPaymentsPage({super.key});

  @override
  ConsumerState<TodayPaymentsPage> createState() => _TodayPaymentsPageState();
}

class _TodayPaymentsPageState extends ConsumerState<TodayPaymentsPage>
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
    final newScrolled = _scrollController.offset > 20;
    if (newScrolled != _isScrolled) {
      setState(() => _isScrolled = newScrolled);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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
    final picked = await PremiumCalendarSheet.show(
      context: context,
      initialDate: filters.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      ref.read(paymentFilterProvider.notifier).setDate(picked);
    }
  }

  void _showSortSheet() {
    final filters = ref.read(paymentFilterProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _PremiumBottomSheet(
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHandle(),
              const Padding(
                padding: EdgeInsets.fromLTRB(28, 20, 28, 8),
                child: Text('Sort By',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
              ),
              ...PaymentSortBy.values.map((sort) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 2),
                    title: Text(sort.label,
                        style: TextStyle(
                          fontWeight: filters.sortBy == sort ? FontWeight.w800 : FontWeight.w500,
                          fontSize: 16,
                          color: filters.sortBy == sort ? AppColors.primary : null,
                        )),
                    trailing: filters.sortBy == sort
                        ? Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.check_rounded, color: AppColors.primary, size: 20),
                          )
                        : null,
                    onTap: () {
                      ref.read(paymentFilterProvider.notifier).setSortBy(sort);
                      Navigator.pop(ctx);
                    },
                  )),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final filters = ref.watch(paymentFilterProvider);
          final branchesAsync = ref.watch(paymentBranchesProvider);
          final agentsAsync = ref.watch(paymentAgentsProvider);
          final minController = TextEditingController(text: filters.minAmount?.toStringAsFixed(0) ?? '');
          final maxController = TextEditingController(text: filters.maxAmount?.toStringAsFixed(0) ?? '');
          return _PremiumBottomSheet(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
                child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SheetHandle(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Filters',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                    TextButton(
                      onPressed: () {
                        ref.read(paymentFilterProvider.notifier).resetFilters();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Reset All', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Payment Type
                        _FilterSection(
                          label: 'Payment Type',
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _FilterChip(
                                label: 'Both',
                                selected: filters.paymentTypeFilter == null,
                                onTap: () => ref.read(paymentFilterProvider.notifier).setPaymentType(null),
                              ),
                              _FilterChip(
                                label: 'EMI',
                                selected: filters.paymentTypeFilter == PaymentType.emi,
                                onTap: () => ref.read(paymentFilterProvider.notifier).setPaymentType(PaymentType.emi),
                              ),
                              _FilterChip(
                                label: 'Savings',
                                selected: filters.paymentTypeFilter == PaymentType.savings,
                                onTap: () => ref.read(paymentFilterProvider.notifier).setPaymentType(PaymentType.savings),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Status
                        _FilterSection(
                          label: 'Status',
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _FilterChip(
                                label: 'Pending',
                                selected: filters.statusFilters.contains(PaymentStatus.pending),
                                onTap: () => ref.read(paymentFilterProvider.notifier).toggleStatusFilter(PaymentStatus.pending),
                              ),
                              _FilterChip(
                                label: 'Overdue',
                                selected: filters.statusFilters.contains(PaymentStatus.overdue),
                                onTap: () => ref.read(paymentFilterProvider.notifier).toggleStatusFilter(PaymentStatus.overdue),
                              ),
                              _FilterChip(
                                label: 'Collected',
                                selected: filters.statusFilters.contains(PaymentStatus.collected),
                                onTap: () => ref.read(paymentFilterProvider.notifier).toggleStatusFilter(PaymentStatus.collected),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Amount Range
                        _FilterSection(
                          label: 'Amount Range',
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: minController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    hintText: 'Min',
                                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                  ),
                                  onChanged: (v) {
                                    final val = double.tryParse(v);
                                    ref.read(paymentFilterProvider.notifier).setAmountRange(
                                      min: val, clearMin: v.isEmpty,
                                      max: filters.maxAmount, clearMax: false,
                                    );
                                  },
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text('—', style: TextStyle(color: Colors.grey)),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: maxController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    hintText: 'Max',
                                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                  ),
                                  onChanged: (v) {
                                    final val = double.tryParse(v);
                                    ref.read(paymentFilterProvider.notifier).setAmountRange(
                                      min: filters.minAmount, clearMin: false,
                                      max: val, clearMax: v.isEmpty,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Payment Mode
                        _FilterSection(
                          label: 'Payment Mode',
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final mode in ['Cash', 'UPI', 'Bank Transfer', 'Cheque'])
                                _FilterChip(
                                  label: mode,
                                  selected: filters.paymentModeFilters.contains(mode.toLowerCase()),
                                  onTap: () => ref.read(paymentFilterProvider.notifier).togglePaymentMode(mode.toLowerCase()),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Overdue Days
                        _FilterSection(
                          label: 'Overdue Days',
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: OverdueBucket.values.map((bucket) => _FilterChip(
                              label: bucket.label,
                              selected: filters.overdueDayFilters.contains(bucket),
                              onTap: () => ref.read(paymentFilterProvider.notifier).toggleOverdueBucket(bucket),
                            )).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Branch
                        _FilterSection(
                          label: 'Branch',
                          child: branchesAsync.when(
                            loading: () => const LinearProgressIndicator(minHeight: 2),
                            error: (e, _) => Text('Error: $e', style: const TextStyle(fontSize: 13)),
                            data: (branches) => Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _FilterChip(
                                  label: 'All Branches',
                                  selected: filters.branchId == null,
                                  onTap: () => ref.read(paymentFilterProvider.notifier).setBranch(null),
                                ),
                                ...branches.map((b) => _FilterChip(
                                      label: b['name']!,
                                      selected: filters.branchId == b['id'],
                                      onTap: () => ref.read(paymentFilterProvider.notifier).setBranch(b['id']),
                                    )),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Agent
                        _FilterSection(
                          label: 'Agent',
                          child: agentsAsync.when(
                            loading: () => const LinearProgressIndicator(minHeight: 2),
                            error: (e, _) => Text('Error: $e', style: const TextStyle(fontSize: 13)),
                            data: (agents) => Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _FilterChip(
                                  label: 'All Agents',
                                  selected: filters.agentId == null,
                                  onTap: () => ref.read(paymentFilterProvider.notifier).setAgent(null),
                                ),
                                ...agents.map((a) => _FilterChip(
                                      label: a['name']!,
                                      selected: filters.agentId == a['id'],
                                      onTap: () => ref.read(paymentFilterProvider.notifier).setAgent(a['id']),
                                    )),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Apply Filters',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.3)),
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

  Future<void> _handlePdfExport(TodayPaymentData data) async {
    final filters = ref.read(paymentFilterProvider);
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
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
    );
  }

  void _sendReminder(TodayPayment payment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Send Reminder',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4, fontSize: 19)),
        content: Text(
          'Send payment reminder to ${payment.memberName}'
          '${payment.agentName != null ? ' and agent ${payment.agentName}' : ''}?',
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Reminder sent to ${payment.memberName}'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text('Send', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
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
      final staffName = profile?['full_name']?.toString() ?? 'Admin';

      if (payment.type == PaymentType.savings) {
        final userRole = user.role?.name ?? 'executiveAdmin';
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
      ref.invalidate(todayPaymentsProvider);
    }
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
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => CollectionSheet.savings(savingsPlan: plan),
          ),
        );
        if (mounted) ref.invalidate(todayPaymentsProvider);
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
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => CollectionSheet(loan: loan),
          ),
        );
        if (mounted) ref.invalidate(todayPaymentsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load loan: $e')),
        );
      }
    }
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //  BUILD
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final paymentsAsync = ref.watch(todayPaymentsProvider);
    final filters = ref.watch(paymentFilterProvider);
    ref.watch(autoRefreshTimerProvider);

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
        centerTitle: false,
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search customer, phone, loan...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black26,
                    fontWeight: FontWeight.w400,
                    fontSize: 16,
                  ),
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
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              )
            : GestureDetector(
                onTap: _pickDate,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      filters.isToday ? "Today's Payments" : 'Payments Â· ${filters.dateLabel}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
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
              icon: Icon(Icons.search_rounded, size: 24, color: isDark ? Colors.white70 : Colors.black54),
              onPressed: () => setState(() => _showSearch = true),
            ),
            IconButton(
              icon: Icon(
                Icons.tune_rounded,
                size: 24,
                color: filters.hasActiveFilters
                    ? AppColors.primary
                    : (isDark ? Colors.white54 : Colors.black38),
              ),
              onPressed: _showFilterSheet,
            ),
            PopupMenuButton(
              icon: Icon(Icons.more_vert_rounded, size: 24, color: isDark ? Colors.white54 : Colors.black38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              itemBuilder: (ctx) => <PopupMenuEntry<dynamic>>[
                PopupMenuItem(
                  child: ListTile(
                    leading: Icon(
                      filters.autoRefresh ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 22,
                    ),
                    title: Text(
                      filters.autoRefresh ? 'Pause Auto-refresh' : 'Enable Auto-refresh',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    dense: true,
                  ),
                  onTap: () => ref.read(paymentFilterProvider.notifier).toggleAutoRefresh(),
                ),
                PopupMenuItem(
                  child: const ListTile(
                    leading: Icon(Icons.sort_rounded, size: 22),
                    title: Text('Sort', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    dense: true,
                  ),
                  onTap: () => Future.delayed(Duration.zero, () => _showSortSheet()),
                ),
                PopupMenuItem(
                  child: const ListTile(
                    leading: Icon(Icons.refresh_rounded, size: 22),
                    title: Text('Refresh', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    dense: true,
                  ),
                  onTap: () => ref.invalidate(todayPaymentsProvider),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  child: const ListTile(
                    leading: Icon(Icons.picture_as_pdf_rounded, size: 22),
                    title: Text('Export PDF', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
        loading: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 16),
              Text('Loading payments...',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.error.withValues(alpha: 0.15),
                        AppColors.error.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                ),
                const SizedBox(height: 24),
                Text('Something went wrong',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.4,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)),
                const SizedBox(height: 8),
                Text('$e',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.5,
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(todayPaymentsProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  filters: filters,
                  onPickDate: _pickDate,
                ),
              ),

              // Active Filters
              if (filters.hasActiveFilters)
                SliverToBoxAdapter(
                  child: _ActiveFiltersBanner(
                    filters: filters,
                    onClear: () => ref.read(paymentFilterProvider.notifier).resetFilters(),
                    isDark: isDark,
                  ),
                ),

              // ── Tab Bar ──
              SliverToBoxAdapter(
                child: _PremiumTabBar(
                  controller: _tabController,
                  pendingCount: pending.length,
                  overdueCount: overdue.length,
                  collectedCount: collected.length,
                  collectedAmountText: collected.isNotEmpty
                      ? (summary.totalCollected >= 1000
                          ? '\u20b9${(summary.totalCollected / 1000).toStringAsFixed(1)}k'
                          : '\u20b9${summary.totalCollected.toInt()}')
                      : null,
                  isDark: isDark,
                ),
              ),

              // ── Tab Content ──
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _PaymentList(
                      payments: pending,
                      isDark: isDark,
                      emptyTitle: 'All clear!',
                      emptySubtitle: 'No pending payments for this date',
                      emptyIcon: Icons.wb_sunny_rounded,
                      emptyColor: AppColors.success,
                      onCall: (p) => p.memberPhone != null ? () => _makePhoneCall(p.memberPhone!) : null,
                      onRemind: (p) => () => _sendReminder(p),
                      onCollect: (p) {
                        if (p.isCollected) return null;
                        return () {
                          final hasOverdues = p.isOverdue || data.overduePayments.any((o) => o.memberId == p.memberId && p.memberId != null);
                          if (hasOverdues) {
                            _showQuickCollect(p);
                          } else {
                            _performAutoCollection(p);
                          }
                        };
                      },
                      onTap: (p) => () => _showPaymentDetails(p),
                      onRefresh: () async => ref.invalidate(todayPaymentsProvider),
                    ),
                    _GroupedOverdueList(
                      groups: data.groupedOverduePayments,
                      isDark: isDark,
                      onCall: (g) => g.memberPhone != null ? () => _makePhoneCall(g.memberPhone!) : null,
                      onRemind: (g) => () { if (g.payments.isNotEmpty) _sendReminder(g.payments.first); },
                      onCollect: (g) => () { if (g.payments.isNotEmpty) _showQuickCollect(g.payments.first); },
                      onTap: (g) => () { if (g.payments.isNotEmpty) _showPaymentDetails(g.payments.first); },
                      onRefresh: () async => ref.invalidate(todayPaymentsProvider),
                    ),
                    _GroupedCollectedList(
                      collected: collected,
                      isDark: isDark,
                      onCall: (p) => p.memberPhone != null ? () => _makePhoneCall(p.memberPhone!) : null,
                      onRemind: (p) => () => _sendReminder(p),
                      onTap: (p) => () => _showPaymentDetails(p),
                      onRefresh: () async => ref.invalidate(todayPaymentsProvider),
                    ),
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

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not launch phone dialer'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  void _showPaymentDetails(TodayPayment payment) {
    final currencyFormat = NumberFormat.currency(symbol: '\u20b9', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _PremiumBottomSheet(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SheetHandle(),
                // Header
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            payment.typeColor.withValues(alpha: 0.2),
                            payment.typeColor.withValues(alpha: 0.06),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: payment.typeColor.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      child: Icon(payment.typeIcon, color: payment.typeColor, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(payment.memberName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                          const SizedBox(height: 4),
                          _StatusPill(status: payment.status, type: payment.type),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currencyFormat.format(payment.isCollected ? (payment.amountCollected ?? payment.amountExpected) : payment.amountExpected),
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: payment.statusColor, letterSpacing: -0.8),
                        ),
                        if (payment.penaltyAmount > 0)
                          Text(
                            '+${currencyFormat.format(payment.penaltyAmount)} penalty',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.error),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Details
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.fillDark
                        : const Color(0xFFF1F3F8),
                    borderRadius: BorderRadius.circular(18),
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
                        _DetailRow('Overdue', payment.overdueLabel, valueColor: AppColors.error),
                      if (payment.penaltyAmount > 0)
                        _DetailRow('Penalty', currencyFormat.format(payment.penaltyAmount),
                            valueColor: AppColors.error),
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
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Actions — icon-only row
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
                    if (payment.memberPhone != null && !payment.isCollected)
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
        ref.invalidate(todayPaymentsProvider);
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

// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”
//  SHEET HANDLE
// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”

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

// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”
//  PREMIUM BOTTOM SHEET
// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”

class _PremiumBottomSheet extends StatelessWidget {
  final Widget child;
  const _PremiumBottomSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: child,
      ),
    );
  }
}

// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”
//  HERO HEADER
// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”

class _HeroHeader extends StatelessWidget {
  final TodayPaymentSummary summary;
  final bool isDark;
  final PaymentFilterState filters;
  final VoidCallback onPickDate;

  const _HeroHeader({
    required this.summary,
    required this.isDark,
    required this.filters,
    required this.onPickDate,
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
      margin: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + kToolbarHeight - 28, 20, 8),
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$count $label',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            amountString,
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────
//  CIRCULAR PROGRESS RING
// ──────────────────────────────────────────────────

// REMOVED: _CircularProgressRing — stats moved inside hero header
class _StaggeredFadeIn extends StatefulWidget {
  final int index;
  final Widget child;
  const _StaggeredFadeIn({required this.index, required this.child});

  @override
  State<_StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<_StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: Duration(milliseconds: 300 + widget.index * 30),
      vsync: this,
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}



// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”
//  GLOW ORB
// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”



// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”
//  QUICK STATS ROW
// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”

// ignore: unused_element
class _QuickStatsRow extends StatelessWidget {
  final TodayPaymentSummary summary;
  final bool isDark;
  const _QuickStatsRow({required this.summary, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              icon: Icons.check_circle_rounded,
              label: 'Collected',
              value: NumberFormat.currency(symbol: '\u20b9', decimalDigits: 0).format(summary.totalCollected),
              count: '${summary.countCollected}',
              color: AppColors.success,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              icon: Icons.schedule_rounded,
              label: 'Pending',
              value: NumberFormat.currency(symbol: '\u20b9', decimalDigits: 0).format(summary.totalPending),
              count: '${summary.countPending}',
              color: AppColors.warning,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              icon: Icons.warning_amber_rounded,
              label: 'Overdue',
              value: NumberFormat.currency(symbol: '\u20b9', decimalDigits: 0).format(summary.totalOverdue),
              count: '${summary.countOverdue}',
              color: AppColors.error,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”
//  STAT TILE
// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String count;
  final Color color;
  final bool isDark;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.count,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.15 : 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : color.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.18),
                      color.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const Spacer(),
              Text(
                count,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: -1.5,
                  height: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              letterSpacing: -0.4,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”
//  INLINE STAT TILE (inside hero header)
// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”



// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”
//  ACTIVE FILTERS BANNER
// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”

class _ActiveFiltersBanner extends StatelessWidget {
  final PaymentFilterState filters;
  final VoidCallback onClear;
  final bool isDark;

  const _ActiveFiltersBanner({required this.filters, required this.onClear, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glassmorphic: true,
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 16,
      borderColor: AppColors.primary.withValues(alpha: 0.12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.tune_rounded, size: 15, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              () {
                final labels = <String>[];
                if (filters.branchId != null) labels.add('Branch');
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
                fontSize: 14,
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap: onClear,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Clear',
                style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”
//  PREMIUM TAB BAR
// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”

class _PremiumTabBar extends StatelessWidget {
  final TabController controller;
  final int pendingCount;
  final int overdueCount;
  final int collectedCount;
  final String? collectedAmountText;
  final bool isDark;

  const _PremiumTabBar({
    required this.controller,
    required this.pendingCount,
    required this.overdueCount,
    required this.collectedCount,
    this.collectedAmountText,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: GlassCard(
        glassmorphic: true,
        padding: const EdgeInsets.all(5),
        borderRadius: 16,
        child: TabBar(
          controller: controller,
          labelColor: Colors.white,
          unselectedLabelColor: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: -0.2),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: -0.2),
          labelPadding: EdgeInsets.zero,
          indicatorPadding: EdgeInsets.zero,
          tabs: [
            _TabPill(label: 'Pending', count: pendingCount, color: AppColors.warning),
            _TabPill(label: 'Overdue', count: overdueCount, color: AppColors.error),
            _TabPill(label: 'Done', count: collectedCount, color: AppColors.success, amountText: collectedAmountText),
          ],
        ),
      ),
    );
  }
}

// â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"
//  TAB PILL
// â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"

class _TabPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final String? amountText;
  const _TabPill({required this.label, required this.count, required this.color, this.amountText});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              amountText != null ? '$count · $amountText' : '$count',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”
//  PAYMENT LIST
// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”

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

class _PaymentList extends StatelessWidget {
  final List<TodayPayment> payments;
  final bool isDark;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;
  final Color emptyColor;
  final VoidCallback? Function(TodayPayment) onCall;
  final VoidCallback Function(TodayPayment) onRemind;
  final VoidCallback? Function(TodayPayment) onCollect;
  final VoidCallback Function(TodayPayment) onTap;
  final Future<void> Function() onRefresh;

  const _PaymentList({
    required this.payments,
    required this.isDark,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
    required this.emptyColor,
    required this.onCall,
    required this.onRemind,
    required this.onCollect,
    required this.onTap,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return _EmptyView(
        title: emptyTitle,
        subtitle: emptySubtitle,
        icon: emptyIcon,
        color: emptyColor,
        isDark: isDark,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        itemCount: payments.length,
        itemBuilder: (context, index) {
          final p = payments[index];
          final card = _PaymentCard(
            payment: p,
            isDark: isDark,
            index: index,
            onCall: onCall(p),
            onRemind: onRemind(p),
            onTap: onTap(p),
            onCollect: onCollect(p),
          );

          if (p.isCollected) {
            return _StaggeredFadeIn(
              index: index,
              child: card,
            );
          }

          return _StaggeredFadeIn(
            index: index,
            child: Dismissible(
              key: ValueKey('pay_${p.id}'),
              direction: DismissDirection.horizontal,
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  final collectFn = onCollect(p);
                  if (collectFn != null) {
                    HapticFeedback.mediumImpact();
                    collectFn();
                  }
                } else if (direction == DismissDirection.endToStart) {
                  final callFn = onCall(p);
                  if (callFn != null) {
                    HapticFeedback.lightImpact();
                    callFn();
                  } else {
                    HapticFeedback.lightImpact();
                    onRemind(p)();
                  }
                }
                return false;
              },
              background: onCollect(p) != null
                  ? const _SwipeBackground(
                      icon: Icons.payment_rounded,
                      label: 'Collect',
                      color: AppColors.success,
                      align: Alignment.centerLeft,
                    )
                  : null,
              secondaryBackground: _SwipeBackground(
                icon: onCall(p) != null ? Icons.call_rounded : Icons.notifications_active_rounded,
                label: onCall(p) != null ? 'Call' : 'Remind',
                color: onCall(p) != null ? AppColors.success : AppColors.warning,
                align: Alignment.centerRight,
              ),
              child: card,
            ),
          );
        },
      ),
    );
  }
}

// ————————————————————————————————————————————————————————————————————————————
//  EMPTY VIEW
// ————————————————————————————————————————————————————————————————————————————

class _EmptyView extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _EmptyView({
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
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.12),
                    color.withValues(alpha: 0.03),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: color.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 28),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ————————————————————————————————————————————————————————————————————————————
//  PAYMENT CARD
// ————————————————————————————————————————————————————————————————————————————

class _PaymentCard extends StatelessWidget {
  final TodayPayment payment;
  final bool isDark;
  final int index;
  final VoidCallback? onCall;
  final VoidCallback onRemind;
  final VoidCallback onTap;
  final VoidCallback? onCollect;

  const _PaymentCard({
    required this.payment,
    required this.isDark,
    required this.index,
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
                label: payment.memberName,
                color: payment.typeColor,
                isCollected: payment.isCollected,
                photoUrl: payment.memberPhotoUrl,
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
                              currencyFormat.format(payment.isCollected ? (payment.amountCollected ?? payment.amountExpected) : payment.amountExpected),
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

// ————————————————————————————————————————————————————————————————————————————
//  PAYMENT AVATAR
// ————————————————————————————————————————————————————————————————————————————

// GROUPED OVERDUE LIST — one card per member

// â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"
//  GROUPED COLLECTED LIST — one card per member, cumulative amounts
// â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"â"

class _GroupedCollectedList extends StatelessWidget {
  final List<TodayPayment> collected;
  final bool isDark;
  final VoidCallback? Function(TodayPayment) onCall;
  final VoidCallback Function(TodayPayment) onRemind;
  final VoidCallback Function(TodayPayment) onTap;
  final Future<void> Function() onRefresh;

  const _GroupedCollectedList({
    required this.collected,
    required this.isDark,
    required this.onCall,
    required this.onRemind,
    required this.onTap,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (collected.isEmpty) {
      return _EmptyView(
        title: 'No collections yet',
        subtitle: 'Start collecting to see them here',
        icon: Icons.receipt_long_rounded,
        color: AppColors.primary,
        isDark: isDark,
      );
    }

    // Group by member + type (separate EMI and Savings cards)
    final Map<String, List<TodayPayment>> grouped = {};
    for (final p in collected) {
      final key = '${p.memberName}_${p.type.name}';
      grouped.putIfAbsent(key, () => []).add(p);
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        itemCount: grouped.length,
        itemBuilder: (context, index) {
          final groupKey = grouped.keys.elementAt(index);
          final payments = grouped[groupKey]!;
          final totalCollected = payments.fold<double>(0, (sum, p) => sum + (p.amountCollected ?? p.amountExpected));
          final payment = payments.first; // representative for callbacks
          final memberName = payment.memberName;
          final typeLabel = payment.typeLabel;

          return _StaggeredFadeIn(
            index: index,
            child: GestureDetector(
              onTap: () => onTap(payment),
              child: GlassCard(
                glassmorphic: true,
                margin: const EdgeInsets.only(bottom: 10),
                borderRadius: 14,
                borderColor: AppColors.success.withValues(alpha: isDark ? 0.18 : 0.12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _PaymentAvatar(
                      type: payment.type,
                      label: memberName,
                      color: AppColors.success,
                      isCollected: true,
                      photoUrl: payment.memberPhotoUrl,
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
                                  '$memberName • $typeLabel',
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
                              Text(
                                NumberFormat.currency(symbol: '\u20b9', decimalDigits: 0).format(totalCollected),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14.5,
                                  letterSpacing: -0.4,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${payments.length} ${payments.length == 1 ? 'payment' : 'payments'} collected',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.success,
                                  ),
                                ),
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
        },
      ),
    );
  }
}

class _GroupedOverdueList extends StatelessWidget {
  final List<GroupedOverduePayment> groups;
  final bool isDark;
  final VoidCallback? Function(GroupedOverduePayment) onCall;
  final VoidCallback Function(GroupedOverduePayment) onRemind;
  final VoidCallback? Function(GroupedOverduePayment) onCollect;
  final VoidCallback Function(GroupedOverduePayment) onTap;
  final Future<void> Function() onRefresh;

  const _GroupedOverdueList({
    required this.groups,
    required this.isDark,
    required this.onCall,
    required this.onRemind,
    required this.onCollect,
    required this.onTap,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const _EmptyView(
        title: 'No overdue',
        subtitle: 'Everything is on track',
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.success,
        isDark: false,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final g = groups[index];
          final card = _GroupedOverdueCard(
            group: g,
            isDark: isDark,
            index: index,
            onCall: onCall(g),
            onRemind: onRemind(g),
            onTap: onTap(g),
            onCollect: onCollect(g),
          );

          return _StaggeredFadeIn(
            index: index,
            child: Dismissible(
              key: ValueKey('grouped_${g.memberId}'),
              direction: DismissDirection.horizontal,
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  final collectFn = onCollect(g);
                  if (collectFn != null) {
                    HapticFeedback.mediumImpact();
                    collectFn();
                  }
                } else if (direction == DismissDirection.endToStart) {
                  final callFn = onCall(g);
                  if (callFn != null) {
                    HapticFeedback.lightImpact();
                    callFn();
                  } else {
                    HapticFeedback.lightImpact();
                    onRemind(g)();
                  }
                }
                return false;
              },
              background: onCollect(g) != null
                  ? const _SwipeBackground(
                      icon: Icons.payment_rounded,
                      label: 'Collect',
                      color: AppColors.success,
                      align: Alignment.centerLeft,
                    )
                  : null,
              secondaryBackground: _SwipeBackground(
                icon: onCall(g) != null ? Icons.call_rounded : Icons.notifications_active_rounded,
                label: onCall(g) != null ? 'Call' : 'Remind',
                color: onCall(g) != null ? AppColors.success : AppColors.warning,
                align: Alignment.centerRight,
              ),
              child: card,
            ),
          );
        },
      ),
    );
  }
}

// GROUPED OVERDUE CARD — one card per member with multiple overdues

class _GroupedOverdueCard extends StatelessWidget {
  final GroupedOverduePayment group;
  final bool isDark;
  final int index;
  final VoidCallback? onCall;
  final VoidCallback onRemind;
  final VoidCallback onTap;
  final VoidCallback? onCollect;

  const _GroupedOverdueCard({
    required this.group,
    required this.isDark,
    this.index = 0,
    this.onCall,
    required this.onRemind,
    required this.onTap,
    this.onCollect,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\u20b9', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy');
    final name = group.memberName;

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        glassmorphic: true,
        margin: const EdgeInsets.only(bottom: 10),
        borderRadius: 14,
        borderColor: AppColors.error.withValues(alpha: isDark ? 0.18 : 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _PaymentAvatar(
                type: group.payments.isNotEmpty ? group.payments.first.type : PaymentType.emi,
                label: name,
                color: AppColors.error,
                isCollected: false,
                photoUrl: group.memberPhotoUrl,
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
                        ),
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


class _PaymentAvatar extends StatelessWidget {
  final PaymentType type;
  final String label;
  final Color color;
  final bool isCollected;
  final String? photoUrl;

  const _PaymentAvatar({
    required this.type,
    required this.label,
    required this.color,
    required this.isCollected,
    this.photoUrl,
  });

  String? _resolvedPhoto() {
    final raw = photoUrl;
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final path = trimmed.startsWith('avatars/')
        ? trimmed.substring('avatars/'.length)
        : trimmed;
    return 'https://tccwdpsnuudzfyxfoohk.supabase.co/storage/v1/object/public/avatars/$path';
  }

  @override
  Widget build(BuildContext context) {
    final initial = label.isNotEmpty ? label[0].toUpperCase() : '?';
    final resolved = _resolvedPhoto();
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    Widget buildLetterAvatar() {
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
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: primary.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: resolved != null
            ? CachedNetworkImage(
                imageUrl: resolved,
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
              errorWidget: (context, url, error) => buildLetterAvatar(),
            )
            : buildLetterAvatar(),
      ),
    );
  }
}

// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”
//  STATUS PILL
// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            _label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}

// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”
//  ACTION CIRCLE
// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”

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
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”
//  EXPORT FAB
// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”



// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”
//  FILTER CHIP
// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : (isDark ? AppColors.fillDark : const Color(0xFFF1F3F8)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected
                ? AppColors.primary
                : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
          ),
        ),
      ),
    );
  }
}

// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”
//  FILTER SECTION
// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”

class _FilterSection extends StatelessWidget {
  final String label;
  final Widget child;
  const _FilterSection({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: -0.2)),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”
//  SHARE OPTION
// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”



// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”
//  DETAIL ROW
// â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: valueColor ??
                    (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
