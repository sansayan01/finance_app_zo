import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../../../../core/utils/file_download.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../../../core/widgets/progress_gauge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/providers/branding_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../providers/loan_providers.dart';
import '../../../home/data/providers/dashboard_providers.dart'
    show overdueLoansProvider, dashboardLoansProvider, activeLoansProvider, loanSummaryProvider;
import '../../data/models/loan_model.dart';
import '../../data/repositories/emi_repository.dart';
import '../../data/models/emi_schedule_model.dart';
import '../../data/services/loan_statement_pdf_service.dart';
import '../../data/services/loan_statement_excel_service.dart';
import '../../data/services/loan_statement_csv_service.dart';
import '../../data/services/loan_statement_archive_service.dart';
import '../../data/services/qr_png.dart';
import '../widgets/collection_sheet.dart';
import '../widgets/statement_options_sheet.dart';
import '../widgets/statement_generation_overlay.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../savings/data/providers/savings_providers.dart' show transactionsRepositoryProvider;


/// Extracts a payment date from a payment record, checking multiple fields.
/// Used by _LoanDetailPageState.
DateTime _getPaymentDate(Map<String, dynamic> payment) {
  if (payment['entered_at'] != null) {
    try {
      return AppFormatters.convertToIST(
          DateTime.parse(payment['entered_at'] as String));
    } catch (_) {}
  }
  if (payment['created_at'] != null) {
    try {
      return AppFormatters.convertToIST(
          DateTime.parse(payment['created_at'] as String));
    } catch (_) {}
  }
  if (payment['transaction_time'] != null) {
    try {
      return AppFormatters.convertToIST(
          DateTime.parse(payment['transaction_time'] as String));
    } catch (_) {}
  }
  if (payment['collection_time'] != null) {
    try {
      final dateStr = payment['collection_date'] as String?;
      final timeStr = payment['collection_time'] as String;
      DateTime? dt;
      if (dateStr != null) {
        dt = DateTime.tryParse('${dateStr}T$timeStr');
      }
      dt ??= DateTime.tryParse(timeStr);
      if (dt != null) return AppFormatters.convertToIST(dt);
    } catch (_) {}
  }
  return AppFormatters.convertToIST(DateTime.now());
}


/// Builds a detail row with label and value.
/// Used by _LoanDetailPageState.
Widget _buildDetailRow(String label, String value, ThemeData theme,
    {Color? valueColor}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        Text(value,
            style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor ?? theme.colorScheme.onSurface)),
      ],
    ),
  );
}

class LoanDetailPage extends ConsumerStatefulWidget {
  final String loanId;
  final bool showEditButton;

  const LoanDetailPage({
    super.key,
    required this.loanId,
    this.showEditButton = true,
  });

  @override
  ConsumerState<LoanDetailPage> createState() => _LoanDetailPageState();
}

class _LoanDetailPageState extends ConsumerState<LoanDetailPage> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _timelineController = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0);
  bool _hasScrolledTimeline = false;

  /// Member-level SMS opt-out state, sourced from members.sms_enabled (the
  /// only SMS opt-out column that exists). The loan/savings detail toggles
  /// drive this member flag.
  final ValueNotifier<bool> _memberSmsEnabled = ValueNotifier<bool>(true);

  /// Returns a short, display-friendly label for an [EMIStatus].
  /// Always pass [EMIScheduleModel.effectiveStatus] (not the raw `status`)
  /// so the label reflects the actual overdue state computed from `dueDate`.
  String _emiStatusLabel(EMIStatus status) => switch (status) {
        EMIStatus.paid => 'PAID',
        EMIStatus.pending => 'DUE',
        EMIStatus.overdue => 'OVERDUE',
        EMIStatus.waived => 'WAIVED',
        EMIStatus.pendingPayment => 'PEND',
        EMIStatus.frozen => 'FROZEN',
      };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      _scrollOffset.value = _scrollController.offset;
    });
    _loadMemberSmsEnabled();
  }

  Future<void> _loadMemberSmsEnabled() async {
    final loan = ref.read(loanDetailProvider(widget.loanId)).value;
    if (loan == null) return;
    final memberId = loan.memberId ?? loan.customerId;
    try {
      final client = ref.read(supabaseClientProvider);
      final memberInfo = await client
          .from('members')
          .select('sms_enabled')
          .eq('id', memberId)
          .maybeSingle();
      _memberSmsEnabled.value = memberInfo?['sms_enabled'] as bool? ?? true;
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _timelineController.dispose();
    _scrollOffset.dispose();
    _memberSmsEnabled.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loanAsync = ref.watch(loanDetailProvider(widget.loanId));
    final scheduleAsync = ref.watch(emiScheduleProvider(widget.loanId));
    final paymentHistoryAsync = ref.watch(paymentHistoryProvider(widget.loanId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return loanAsync.when(
      data: (loan) {
        if (loan == null) return const Center(child: Text('Loan Not Found'));
        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF2F2F7),
          extendBodyBehindAppBar: true,
          appBar: _buildAppBar(theme, loan),
          body: Stack(
            children: [
              _buildAmbientBackground(loan),
              RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(loanDetailProvider(widget.loanId));
                  ref.invalidate(emiScheduleProvider(widget.loanId));
                  ref.invalidate(paymentHistoryProvider(widget.loanId));
                },
                displacement: 20,
                color: theme.colorScheme.primary,
                backgroundColor: theme.cardColor,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  slivers: [
                    SliverToBoxAdapter(
                        child: SizedBox(
                            height: MediaQuery.of(context).padding.top + 60)),
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildHugeBalance(loan, theme),
                          const SizedBox(height: 16),
                          _buildNextDueAlert(loan, scheduleAsync, theme),
                          const SizedBox(height: 24),
                          _buildDigitalPass(loan, theme),
                          const SizedBox(height: 32),
                          _buildPrimaryActionRow(loan, scheduleAsync, theme),
                          const SizedBox(height: 20),
                          _buildFreezeToggle(loan, theme),
                          const SizedBox(height: 12),
                          _buildSmsToggle(loan, theme),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(40)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: isDark ? 0.5 : 0.05),
                              blurRadius: 30,
                              offset: const Offset(0, -10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Center(
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: theme.dividerColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              _buildSectionHeader('Upcoming Payments', theme),
                              const SizedBox(height: 16),
                              _buildHorizontalTimeline(
                                  loan, scheduleAsync, theme),
                              const SizedBox(height: 40),
                              _buildSectionHeader('Loan Intelligence', theme),
                              const SizedBox(height: 16),
                              _buildLoanIntelligence(loan, theme),
                              const SizedBox(height: 40),
                              _buildSectionHeader('EMI Breakdown', theme),
                              const SizedBox(height: 16),
                              ClipRect(
                                child: _buildEMISummaryHero(scheduleAsync, loan, theme),
                              ),
                              const SizedBox(height: 24),
                              ClipRect(
                                child: _buildPrincipalInterestBreakdown(
                                    scheduleAsync, loan, theme),
                              ),
                              const SizedBox(height: 40),
                              _buildSectionHeader('Financial Health', theme),
                              const SizedBox(height: 16),
                              _buildHealthMetrics(loan, scheduleAsync, theme),
                              const SizedBox(height: 40),
                              _buildSectionHeader('Staff Notes', theme),
                              const SizedBox(height: 16),
                              _buildStaffNotes(loan, theme),
                              const SizedBox(height: 40),
                              _buildSectionHeader('Payment History', theme),
                              const SizedBox(height: 16),
                              _buildPaymentHistory(paymentHistoryAsync, scheduleAsync, theme, isDark),
                              const SizedBox(height: 40),
                              _buildSectionHeader('Borrower Profile', theme),
                              const SizedBox(height: 16),
                              _buildBorrowerProfile(loan, theme),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, LoanModel loan) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ValueListenableBuilder<double>(
        valueListenable: _scrollOffset,
        builder: (context, offset, _) {
          final blurAlpha = (offset / 100).clamp(0.0, 1.0);
          return ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                  sigmaX: 15 * blurAlpha, sigmaY: 15 * blurAlpha),
              child: AppBar(
                backgroundColor: theme.scaffoldBackgroundColor
                    .withValues(alpha: 0.7 * blurAlpha),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: (val) {
                  HapticFeedback.lightImpact();
                  if (val == 'edit') {
                    _handleEdit();
                  }
                  if (val == 'statement') {
                    _handlePdfExport();
                  }
                  if (val == 'past_statements') {
                    _showPastStatements();
                  }
                  if (val == 'default') {
                    _handleStatusChange(LoanStatus.defaultStatus);
                  }
                  if (val == 'reactivate') {
                    _handleReactivate();
                  }
                  if (val == 'restructure') {
                    _handleLoanRestructure();
                  }
                  if (val == 'delete') {
                    _handleDelete();
                  }
                  if (val == 'freeze') {
                    _handleManualFreeze();
                  }
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                itemBuilder: (ctx) => [
                  if (loan.status != LoanStatus.closed && widget.showEditButton)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 12),
                          Text('Edit Loan'),
                        ],
                      ),
                    ),
                  if (loan.status == LoanStatus.defaultStatus && widget.showEditButton)
                    const PopupMenuItem(
                      value: 'reactivate',
                      child: Row(
                        children: [
                          Icon(Icons.play_circle_outline_rounded,
                              size: 18, color: AppColors.success),
                          SizedBox(width: 12),
                          Text('Reactivate Loan'),
                        ],
                      ),
                    )
                  else if (loan.status != LoanStatus.closed && widget.showEditButton)
                    const PopupMenuItem(
                      value: 'default',
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 18, color: AppColors.warning),
                          SizedBox(width: 12),
                          Text('Mark Defaulted'),
                        ],
                      ),
                    ),
                  if (loan.status != LoanStatus.closed && widget.showEditButton)
                    const PopupMenuItem(
                      value: 'restructure',
                      child: Row(
                        children: [
                          Icon(Icons.settings_suggest_rounded,
                              size: 18, color: AppColors.accent),
                          SizedBox(width: 12),
                          Text('Restructure Loan'),
                        ],
                      ),
                    ),
                  if (loan.status != LoanStatus.closed &&
                      loan.freezeEnabled &&
                      widget.showEditButton)
                    const PopupMenuItem(
                      value: 'freeze',
                      child: Row(
                        children: [
                          Icon(Icons.ac_unit_rounded,
                              size: 18, color: Colors.cyan),
                          SizedBox(width: 12),
                          Text('Freeze Skipped EMIs'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'statement',
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined, size: 18),
                        SizedBox(width: 12),
                        Text('Download Statement'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'past_statements',
                    child: Row(
                      children: [
                        Icon(Icons.history_rounded, size: 18),
                        SizedBox(width: 12),
                        Text('Past Statements'),
                      ],
                    ),
                  ),
                  if (widget.showEditButton) ...[
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 18, color: AppColors.error,
                              semanticLabel: 'Delete Loan'),
                          SizedBox(width: 12),
                          Text('Delete Loan',
                              style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
        },
      ),
    );
  }

  Widget _buildAmbientBackground(LoanModel loan) {
    return Positioned(
      top: -150,
      right: -100,
      child: Container(
        width: 400,
        height: 400,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.3),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFreezeToggle(LoanModel loan, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: loan.freezeEnabled
                ? Colors.cyan.withValues(alpha: 0.4)
                : theme.dividerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: loan.freezeEnabled
                    ? Colors.cyan.withValues(alpha: 0.15)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.ac_unit_rounded,
                size: 18,
                color: loan.freezeEnabled
                    ? Colors.cyan
                    : theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date Freeze',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    loan.freezeEnabled
                        ? 'Skipped EMIs auto-freeze'
                        : 'Off — EMIs won\'t freeze',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: loan.freezeEnabled,
              activeThumbColor: Colors.cyan,
              onChanged: (val) => _toggleFreeze(loan, val),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFreeze(LoanModel loan, bool enabled) async {
    HapticFeedback.lightImpact();
    final user = ref.read(currentUserProvider);
    if (user == null || user.orgId == null) return;
    final client = ref.read(supabaseClientProvider);
    await client.from('loans').update({
      'freeze_enabled': enabled,
    }).eq('id', loan.id);
    ref.invalidate(loanDetailProvider(widget.loanId));
  }

  Widget _buildSmsToggle(LoanModel loan, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return ValueListenableBuilder<bool>(
      valueListenable: _memberSmsEnabled,
      builder: (context, smsEnabled, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: smsEnabled
                    ? Colors.green.withValues(alpha: 0.4)
                    : theme.dividerColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: smsEnabled
                        ? Colors.green.withValues(alpha: 0.15)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    smsEnabled
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_off_rounded,
                    size: 18,
                    color: smsEnabled
                        ? Colors.green
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SMS Notifications',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        smsEnabled
                            ? 'Reminders sent for this loan'
                            : 'No SMS for this loan',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: smsEnabled,
                  activeThumbColor: Colors.green,
                  onChanged: (val) => _toggleSms(loan, val),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleSms(LoanModel loan, bool enabled) async {
    HapticFeedback.lightImpact();
    final client = ref.read(supabaseClientProvider);
    // Persist on the member row — members.sms_enabled is the only SMS opt-out
    // column that exists. The loan/savings detail toggles drive member SMS.
    final memberId = loan.memberId ?? loan.customerId;
    await client.from('members').update({
      'sms_enabled': enabled,
    }).eq('id', memberId);
    _memberSmsEnabled.value = enabled;
    ref.invalidate(loanDetailProvider(widget.loanId));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enabled
              ? 'SMS reminders enabled for this loan'
              : 'SMS reminders disabled for this loan'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Widget _buildHugeBalance(LoanModel loan, ThemeData theme) {
    return Column(
      children: [
        Text(
          'Outstanding Balance',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            letterSpacing: 1.5,
          ),
        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.5),
        const SizedBox(height: 8),
        Text(
          AppFormatters.formatCurrency(
              loan.status == LoanStatus.closed ? 0.0 : loan.outstandingBalance),
          style: theme.textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -2,
            height: 1,
          ),
        ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.9, 0.9)),
      ],
    );
  }

  Widget _buildNextDueAlert(
      LoanModel loan, AsyncValue<List<EMIScheduleModel>> scheduleAsync, ThemeData theme) {
    return scheduleAsync.when(
      data: (schedule) {
        if (schedule.isEmpty) {
          return const SizedBox.shrink();
        }

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final unpaidEmis = schedule
            .where((e) =>
                e.status != EMIStatus.paid &&
                e.status != EMIStatus.waived &&
                e.status != EMIStatus.frozen)
            .toList();
        if (unpaidEmis.isEmpty) {
          return const SizedBox.shrink();
        }
        final nextEmi = unpaidEmis.first;

        // An EMI is overdue if its due date is strictly before today
        final overdueEmis = unpaidEmis.where((e) => e.dueDate.isBefore(today)).toList();
        final isOverdue = overdueEmis.isNotEmpty;

        final daysDiff = nextEmi.dueDate.difference(today).inDays;
        final isDueToday = daysDiff == 0;
        final isDueSoon = daysDiff > 0 && daysDiff <= 7;

        // ── Overdue: single-row alert ──────────────────────────────
        if (isOverdue) {
          const alertColor = AppColors.error;
          final totalOverdueAmount = overdueEmis.fold<double>(0.0, (sum, e) => sum + e.emiAmount);
          // Total overdue days counted from the oldest overdue EMI
          final overdueDays = today.difference(overdueEmis.first.dueDate).inDays;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: alertColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: alertColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_rounded, color: alertColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${AppFormatters.formatCurrency(totalOverdueAmount)} OVERDUE',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: alertColor,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '· $overdueDays day${overdueDays == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: alertColor.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 250.ms).slideY(begin: -0.2);
        }




        // ── Not overdue: single-row pill ───────────────────────────
        Color alertColor;
        String alertText;
        IconData alertIcon;

        if (isDueToday) {
          alertColor = AppColors.warning;
          alertText = 'DUE TODAY';
          alertIcon = Icons.schedule_rounded;
        } else if (isDueSoon) {
          alertColor = AppColors.warning;
          alertText = 'Due in $daysDiff days';
          alertIcon = Icons.calendar_today_rounded;
        } else {
          alertColor = theme.colorScheme.primary;
          alertText = 'Next due in $daysDiff days';
          alertIcon = Icons.event_available_rounded;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: alertColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: alertColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(alertIcon, color: alertColor, size: 20),
              const SizedBox(width: 8),
              Text(
                alertText,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: alertColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '· ${AppFormatters.formatDate(nextEmi.dueDate)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: alertColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 250.ms).slideY(begin: -0.2);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildDigitalPass(LoanModel loan, ThemeData theme) {
    final progress = loan.totalRepayable > 0 ? ((loan.totalRepayable - loan.outstandingBalance) / loan.totalRepayable).clamp(0.0, 1.0) : 0.0;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => context.push('/users/${loan.customerId}'),
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF2C2C2E), const Color(0xFF1C1C1E)]
              : [const Color(0xFFFFFFFF), const Color(0xFFF2F2F7)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.contactless_rounded,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5)),
                      Text(
                        loan.loanNumber,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PRINCIPAL',
                              style: theme.textTheme.labelSmall?.copyWith(
                                  letterSpacing: 1,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5))),
                          Text(AppFormatters.formatCurrency(loan.amount),
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('INTEREST',
                              style: theme.textTheme.labelSmall?.copyWith(
                                  letterSpacing: 1,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5))),
                          Text(AppFormatters.formatCurrency(loan.totalInterest),
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CARDHOLDER',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                          const SizedBox(height: 2),
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: isDark
                                  ? const [
                                      Color(0xFFE5C07B), // Champagne Gold
                                      Color(0xFFF3E7C4), // Platinum
                                      Color(0xFFD1A153), // Deep Gold
                                    ]
                                  : const [
                                      Color(0xFF8A640F), // Bronze Gold
                                      Color(0xFFB38F24), // Bright Gold
                                      Color(0xFF6E4E05), // Dark Gold
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: Text(
                              (loan.customerName ?? 'MEMBER').toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'JetBrains Mono',
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFFE5C07B).withValues(alpha: 0.3)
                                : const Color(0xFF8A640F).withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                          color: isDark
                              ? const Color(0xFFE5C07B).withValues(alpha: 0.05)
                              : const Color(0xFF8A640F).withValues(alpha: 0.05),
                        ),
                        child: Text(
                          'PREMIUM',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: isDark
                                ? const Color(0xFFE5C07B)
                                : const Color(0xFF8A640F),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0, 1),
                      minHeight: 6,
                      backgroundColor:
                          theme.colorScheme.onSurface.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
    );
  }

  Widget _buildPrimaryActionRow(LoanModel loan,
      AsyncValue<List<EMIScheduleModel>> scheduleAsync, ThemeData theme) {
    return scheduleAsync.when(
      data: (schedule) {
        final nextEmi = schedule.isNotEmpty
            ? schedule
                .where((e) =>
                    e.status != EMIStatus.paid &&
                    e.status != EMIStatus.waived)
                .isNotEmpty
                ? schedule.firstWhere((e) =>
                    e.status != EMIStatus.paid &&
                    e.status != EMIStatus.waived)
                : null
            : null;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (loan.status != LoanStatus.closed)
                _buildActionButton(
                    'Collect', Icons.payments_rounded, AppColors.primary,
                    () {
                  _showCollectionSheet(context, loan, nextEmi);
                }),
              _buildActionButton('Statement', Icons.description_rounded,
                  theme.colorScheme.onSurface, () => _handlePdfExport()),
              if (loan.status != LoanStatus.closed)
                _buildActionButton('Settle', Icons.account_balance_rounded,
                    theme.colorScheme.onSurface, () => _handleSettlement(loan)),
              if (loan.status != LoanStatus.closed)
                _buildActionButton(
                    'Reminder',
                    Icons.notifications_active_rounded,
                    theme.colorScheme.onSurface,
                    () => _sendPaymentReminder(loan)),
              _buildActionButton('Call', Icons.phone_rounded,
                  theme.colorScheme.onSurface, () => _makeCall(loan.customerPhone ?? '')),
            ],
          ),
        ).animate().fadeIn(delay: 400.ms);
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.1),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Text(
      title,
      style: theme.textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
    );
  }

  Widget _buildHorizontalTimeline(LoanModel loan,
      AsyncValue<List<EMIScheduleModel>> scheduleAsync, ThemeData theme) {
    return scheduleAsync.when(
      data: (schedule) {
        if (schedule.isEmpty) return const Text('No schedule found.');

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        // Find the EMI closest to today's date
        int currentEmiIndex = 0;
        int bestDiff = today.difference(schedule[0].dueDate).inDays.abs();
        for (int i = 1; i < schedule.length; i++) {
          final diff = today.difference(schedule[i].dueDate).inDays.abs();
          if (diff < bestDiff) {
            bestDiff = diff;
            currentEmiIndex = i;
          }
        }

        // Auto-scroll to today's card after first frame
        if (currentEmiIndex > 0 && !_hasScrolledTimeline) {
          _hasScrolledTimeline = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_timelineController.hasClients) {
              final offset = currentEmiIndex * 162.0; // 150px card + 12px separator
              _timelineController.jumpTo(offset.clamp(
                  0.0, _timelineController.position.maxScrollExtent));
            }
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 170,
              child: ListView.separated(
                controller: _timelineController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: schedule.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final emi = schedule[index];
                  final isCurrent = index == currentEmiIndex;
                  return _buildTimelineCard(emi, theme,
                      loan: loan, isCurrent: isCurrent,
                      onTap: () {
                    _showEMIDetailSheet(emi, loan, theme);
                  });
                },
              ),
            ),
          ],
        );
      },
      loading: () => const ShimmerCard(height: 170),
      error: (_, __) => const Text('Error loading schedule'),
    );
  }

  // NOTE: _buildTimelineFilterTabs and _buildFilterChip removed (M1 fix).
  // These were dead code — defined but never called, with no interactivity.
  // The EMI filter functionality is handled by _buildEMIFilterChip / _selectedEmiFilter.

  Widget _buildTimelineCard(EMIScheduleModel emi, ThemeData theme,
      {LoanModel? loan, bool isCurrent = false, VoidCallback? onTap}) {
    final isPaid = emi.status == EMIStatus.paid;
    final isOverdue = emi.isOverdue;
    final color = isPaid
        ? AppColors.success
        : (isOverdue ? AppColors.error : theme.colorScheme.primary);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isCurrent ? color : color.withValues(alpha: 0.2),
            width: isCurrent ? 2 : 1.5,
          ),
          boxShadow: isCurrent
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(_emiStatusLabel(emi.effectiveStatus),
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: color)),
                ),
                const Spacer(),
                if (isCurrent) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
            const Spacer(),
            Text('EMI #${emi.emiNumber}',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
            Text(AppFormatters.formatCurrency(emi.emiAmount),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(AppFormatters.formatDate(emi.dueDate),
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            if (isOverdue || (loan != null && loan.freezeEnabled && _isFreezable(emi)) || emi.status == EMIStatus.frozen)
              const SizedBox(height: 8),
            if (isOverdue && !(loan != null && loan.freezeEnabled && _isFreezable(emi)))
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.payment_rounded, size: 12, color: AppColors.error),
                    SizedBox(width: 4),
                    Text('Collect',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error)),
                  ],
                ),
              ),
            if (loan != null && loan.freezeEnabled && _isFreezable(emi))
              GestureDetector(
                onTap: () => _freezeSingleEMI(emi, loan),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.ac_unit_rounded, size: 12, color: Colors.cyan),
                      SizedBox(width: 4),
                      Text('Freeze',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.cyan)),
                    ],
                  ),
                ),
              ),
            if (emi.status == EMIStatus.frozen)
              GestureDetector(
                onTap: () => _unfreezeSingleEMI(emi, loan!),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.unfold_more, size: 12, color: Colors.orange),
                      SizedBox(width: 4),
                      Text('Unfreeze',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showEMIDetailSheet(
      EMIScheduleModel emi, LoanModel loan, ThemeData theme) {
    final isPaid = emi.status == EMIStatus.paid;
    final isOverdue = emi.isOverdue;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24,
                    24 + MediaQuery.of(context).padding.bottom + 90),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.dividerColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (isPaid
                                    ? AppColors.success
                                    : isOverdue
                                        ? AppColors.error
                                        : theme.colorScheme.primary)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            isPaid
                                ? Icons.check_circle_rounded
                                : isOverdue
                                    ? Icons.warning_rounded
                                    : Icons.calendar_today_rounded,
                            color: isPaid
                                ? AppColors.success
                                : isOverdue
                                    ? AppColors.error
                                    : theme.colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('EMI #${emi.emiNumber}',
                                  style: theme.textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w900)),
                              Text(_emiStatusLabel(emi.effectiveStatus),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: isPaid
                                          ? AppColors.success
                                          : isOverdue
                                              ? AppColors.error
                                              : theme.colorScheme.primary,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Amount
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Text('EMI Amount',
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5))),
                          const SizedBox(height: 8),
                          Text(AppFormatters.formatCurrency(emi.emiAmount),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.primary)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Breakdown
                    Text('Breakdown',
                        style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5))),
                    const SizedBox(height: 12),

                    _buildDetailRow('Due Date',
                        AppFormatters.formatDate(emi.dueDate), theme),
                    _buildDetailRow('Principal',
                        AppFormatters.formatCurrency(loan.amount / loan.totalEmis.clamp(1, 9999)),
                        theme),
                    _buildDetailRow('Interest',
                        AppFormatters.formatCurrency(loan.totalInterest / loan.totalEmis.clamp(1, 9999)),
                        theme),
                    if (emi.penaltyAmount > 0)
                      _buildDetailRow(
                          'Penalty',
                          AppFormatters.formatCurrency(emi.penaltyAmount),
                          theme,
                          valueColor: AppColors.error),
                    _buildDetailRow('Balance After',
                        AppFormatters.formatCurrency(
                            (loan.totalRepayable - emi.emiNumber * loan.emiAmount).clamp(0.0, loan.totalRepayable)),
                        theme),
                    if (emi.paidOn != null)
                      _buildDetailRow('Paid On',
                          AppFormatters.formatDate(emi.paidOn!), theme),
                    if (emi.paymentMode != null)
                      _buildDetailRow('Payment Mode',
                          emi.paymentMode!.name.toUpperCase(), theme),

                    const SizedBox(height: 24),

                    // Action button for overdue
                    if (isOverdue)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showCollectionSheet(context, loan, emi);
                          },
                          icon: const Icon(Icons.payment_rounded, semanticLabel: 'Collect Payment'),
                          label: const Text('Collect Payment'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoanIntelligence(LoanModel loan, ThemeData theme) {
    // Calculate insights using proper tenure logic
    final totalAmount = loan.totalRepayable;
    final principal = loan.amount;
    final totalInterest = loan.totalInterest;
    final interestRatio =
        totalAmount > 0 ? (totalInterest / totalAmount) * 100 : 0;
    final principalRatio =
        totalAmount > 0 ? (principal / totalAmount) * 100 : 0;

    // Calculate tenure in days properly based on tenureValue and tenureUnit
    double tenureDays = _calculateTenureInDays(loan);
    final costPerDay = tenureDays > 0 ? totalInterest / tenureDays : 0.0;

    // Calculate tenure in months for cost/month
    double tenureMonths = _calculateTenureInMonths(loan);
    final costPerMonth = tenureMonths > 0 ? totalInterest / tenureMonths : 0.0;

    // Effective interest rate (total interest / principal * 100)
    final effectiveRate = principal > 0 ? (totalInterest / principal) * 100 : 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Principal vs Interest Visual Breakdown
          Text('Cost Breakdown',
              style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 12),

          // Stacked bar showing principal vs interest ratio
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Expanded(
                  flex: principalRatio.round().clamp(1, 99),
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(8)),
                    ),
                  ),
                ),
                Expanded(
                  flex: interestRatio.round().clamp(1, 99),
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('Principal (${principalRatio.toStringAsFixed(1)}%)',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('Interest (${interestRatio.toStringAsFixed(1)}%)',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 20),

          // Key Metrics Grid - 2x2 layout matching screenshot
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.percent_rounded,
                  label: 'Effective Rate',
                  value: '${effectiveRate.toStringAsFixed(1)}%',
                  subtitle: 'Total interest cost',
                  color: AppColors.primary,
                  theme: theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.calendar_today_rounded,
                  label: 'Cost/Month',
                  value: AppFormatters.formatCurrency(costPerMonth),
                  subtitle: 'Interest per month',
                  color: AppColors.warning,
                  theme: theme,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.today_rounded,
                  label: 'Cost/Day',
                  value: AppFormatters.formatCurrency(costPerDay),
                  subtitle: 'Interest per day',
                  color: AppColors.mint,
                  theme: theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.savings_rounded,
                  label: 'Total Interest',
                  value: AppFormatters.formatCurrency(totalInterest),
                  subtitle: 'Over full tenure',
                  color: Colors.deepPurple,
                  theme: theme,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),

          // Summary rows
          _buildInfoRow('Principal Amount',
              AppFormatters.formatCurrency(loan.amount), theme),
          const SizedBox(height: 12),
          _buildInfoRow('Total Repayable',
              AppFormatters.formatCurrency(loan.totalRepayable), theme),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1)),
          _buildInfoRow('Installment Amount',
              AppFormatters.formatCurrency(loan.emiAmount), theme,
              isBold: true),
        ],
      ),
    );
  }

  double _calculateTenureInDays(LoanModel loan) {
    if (loan.tenureValue != null && loan.tenureUnit != null) {
      final unit = loan.tenureUnit!.toLowerCase();
      final value = loan.tenureValue!;
      switch (unit) {
        case 'day':
        case 'days':
          return value.toDouble();
        case 'week':
        case 'weeks':
          return (value * 7).toDouble();
        case 'month':
        case 'months':
          return value * 30.44;
        case 'year':
        case 'years':
          return (value * 365).toDouble();
        default:
          return value * 30.44;
      }
    }
    // Fallback to tenureMonths
    return loan.tenureMonths.toDouble() * 30.44;
  }

  double _calculateTenureInMonths(LoanModel loan) {
    if (loan.tenureValue != null && loan.tenureUnit != null) {
      final unit = loan.tenureUnit!.toLowerCase();
      final value = loan.tenureValue!;
      switch (unit) {
        case 'day':
        case 'days':
          return value / 30.44;
        case 'week':
        case 'weeks':
          return value / 4.348;
        case 'month':
        case 'months':
          return value.toDouble();
        case 'year':
        case 'years':
          return value * 12;
        default:
          return value.toDouble();
      }
    }
    // Fallback to tenureMonths
    return loan.tenureMonths.toDouble();
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }




  // ─── EMI Summary Hero ───────────────────────────────────────────
  Widget _buildEMISummaryHero(
      AsyncValue<List<EMIScheduleModel>> scheduleAsync,
      LoanModel loan,
      ThemeData theme) {
    return scheduleAsync.when(
      data: (schedule) {
        if (schedule.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text('No EMI schedule available',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          );
        }

        final totalEmis = schedule.length;
        final paidCount =
            schedule.where((e) => e.status == EMIStatus.paid).length;
        final overdueCount = schedule.where((e) => e.isOverdue).length;
        final upcomingCount = schedule
            .where((e) =>
                e.status != EMIStatus.paid &&
                !e.isOverdue)
            .length;
        final totalPaid = schedule
            .where((e) => e.status == EMIStatus.paid)
            .fold<double>(0, (s, e) => s + e.emiAmount);
        // Use loan-level total instead of summing schedule emiAmounts
        final totalAmount = loan.totalRepayable;
        final progress = totalAmount > 0 ? totalPaid / totalAmount : 0.0;
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.06),
                theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Progress gauge (smaller)
                  ProgressGauge(
                    value: progress.clamp(0.0, 1.0),
                    size: 72,
                    strokeWidth: 7,
                    progressColor: AppColors.success,
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.success,
                          ),
                        ),
                        Text('paid',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                                fontSize: 8)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Stats grid
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _buildMiniStat(
                                'Paid', '$paidCount', AppColors.success, theme),
                            const SizedBox(width: 8),
                            _buildMiniStat(
                                'Overdue', '$overdueCount', AppColors.error, theme),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildMiniStat('Upcoming', '$upcomingCount',
                                theme.colorScheme.primary, theme),
                            const SizedBox(width: 8),
                            _buildMiniStat('Total', '$totalEmis',
                                AppColors.primary, theme),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Collected amount + progress bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Collected',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                          fontSize: 11)),
                  Flexible(
                    child: Text(
                      '${AppFormatters.formatCurrency(totalPaid)} / ${AppFormatters.formatCurrency(totalAmount)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                          fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressBar(
                value: progress.clamp(0.0, 1.0),
                height: 5,
                progressColor: AppColors.success,
              ),
            ],
          ),
        );
      },
      loading: () => const ShimmerCard(height: 180),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildMiniStat(
      String label, String value, Color color, ThemeData theme) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900, color: color)),
            Text(label,
                style: theme.textTheme.labelSmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 9)),
          ],
        ),
      ),
    );
  }

  // ─── Principal vs Interest Breakdown ────────────────────────────
  Widget _buildPrincipalInterestBreakdown(
      AsyncValue<List<EMIScheduleModel>> scheduleAsync,
      LoanModel loan,
      ThemeData theme) {
    return scheduleAsync.when(
      data: (schedule) {
        if (schedule.isEmpty) return const SizedBox.shrink();

        // Use loan-level values (authoritative) instead of summing
        // potentially corrupted per-EMI schedule values.
        final totalPrincipal = loan.amount;
        final totalInterest = loan.totalInterest;
        final total = totalPrincipal + totalInterest;
        final principalPct = total > 0 ? totalPrincipal / total : 0.5;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cost Breakdown',
                  style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.6))),
              const SizedBox(height: 16),
              // Stacked bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 14,
                  child: Row(
                    children: [
                      Expanded(
                        flex: (principalPct * 1000).toInt().clamp(1, 999),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.primary
                                    .withValues(alpha: 0.7),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: ((1 - principalPct) * 1000).toInt().clamp(1, 999),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.amber.shade600,
                                Colors.amber.shade400,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber
                                    .withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Labels
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Principal',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5))),
                              Text(AppFormatters.formatCurrency(totalPrincipal),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    color: theme.dividerColor.withValues(alpha: 0.3),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.amber.shade600,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Interest',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5))),
                              Text(AppFormatters.formatCurrency(totalInterest),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Percentage badges
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                        '${(principalPct * 100).toStringAsFixed(1)}% / ${((1 - principalPct) * 100).toStringAsFixed(1)}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const ShimmerCard(height: 120),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme,
      {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
        Text(value,
            style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isBold ? FontWeight.w900 : FontWeight.w700)),
      ],
    );
  }

  Widget _buildHealthMetrics(LoanModel loan,
      AsyncValue<List<EMIScheduleModel>> scheduleAsync, ThemeData theme) {
    return scheduleAsync.when(
      data: (schedule) {
        final now = DateTime.now();

        // Calculate metrics
        final totalEmis = schedule.length;
        final paidEmis =
            schedule.where((e) => e.status == EMIStatus.paid).toList();
        final overdueEmis = schedule.where((e) => e.isOverdue).toList();

        // Payment consistency score (% paid on time)
        final paidOnTime = paidEmis.where((e) {
          if (e.paidOn == null) return false;
          return e.paidOn!.isBefore(e.dueDate) ||
              e.paidOn!.isAtSameMomentAs(e.dueDate);
        }).length;
        final consistencyScore =
            paidEmis.isEmpty ? 100.0 : (paidOnTime / paidEmis.length) * 100;

        // Days since last payment
        int daysSinceLastPayment = 0;
        if (paidEmis.isNotEmpty) {
          final lastPayment = paidEmis.reduce((a, b) =>
              (a.paidOn ?? a.dueDate).isAfter(b.paidOn ?? b.dueDate) ? a : b);
          daysSinceLastPayment =
              now.difference(lastPayment.paidOn ?? lastPayment.dueDate).inDays;
        }

        // Percentage paid
        final totalAmount = loan.totalRepayable;
        final paidAmount =
            paidEmis.fold<double>(0, (sum, e) => sum + e.emiAmount);
        final percentagePaid =
            totalAmount > 0 ? (paidAmount / totalAmount) * 100 : 0;

        // Collection efficiency (paid / expected so far)
        final expectedEmis = schedule
            .where((e) =>
                e.dueDate.isBefore(now) || e.dueDate.isAtSameMomentAs(now))
            .toList();
        final expectedAmount =
            expectedEmis.fold<double>(0, (sum, e) => sum + e.emiAmount);
        final collectionEfficiency =
            (expectedAmount > 0 ? (paidAmount / expectedAmount) * 100 : 100).clamp(0.0, 100.0);

        // Risk classification
        int maxDaysPastDue = 0;
        for (final emi in overdueEmis) {
          final daysPast = now.difference(emi.dueDate).inDays;
          if (daysPast > maxDaysPastDue) maxDaysPastDue = daysPast;
        }

        String riskLevel;
        Color riskColor;
        IconData riskIcon;
        if (maxDaysPastDue >= 90) {
          riskLevel = 'High Risk';
          riskColor = AppColors.error;
          riskIcon = Icons.dangerous_rounded;
        } else if (maxDaysPastDue >= 60) {
          riskLevel = 'Medium-High Risk';
          riskColor = Colors.deepOrange;
          riskIcon = Icons.warning_rounded;
        } else if (maxDaysPastDue >= 30) {
          riskLevel = 'Medium Risk';
          riskColor = AppColors.warning;
          riskIcon = Icons.info_rounded;
        } else if (overdueEmis.isNotEmpty) {
          riskLevel = 'Low Risk';
          riskColor = Colors.amber;
          riskIcon = Icons.visibility_rounded;
        } else {
          riskLevel = 'Minimal Risk';
          riskColor = AppColors.success;
          riskIcon = Icons.shield_rounded;
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Risk Classification Badge
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: riskColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: riskColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(riskIcon, color: riskColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Risk Classification',
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5))),
                          Text(riskLevel,
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: riskColor)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: riskColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('$maxDaysPastDue DPD',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: riskColor)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Progress Bar - Percentage Paid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Repayment Progress',
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6))),
                  Text('${percentagePaid.toStringAsFixed(1)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (percentagePaid / 100).clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${AppFormatters.formatCurrency(paidAmount)} paid',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5))),
                  Text('${AppFormatters.formatCurrency(totalAmount)} total',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5))),
                ],
              ),

              const SizedBox(height: 24),

              // Health Metrics Grid
              Row(
                children: [
                  Expanded(
                    child: _buildHealthMetricCard(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Consistency',
                      value: '${consistencyScore.toStringAsFixed(0)}%',
                      subtitle: 'On-time payments',
                      color: consistencyScore >= 80
                          ? AppColors.success
                          : consistencyScore >= 50
                              ? AppColors.warning
                              : AppColors.error,
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildHealthMetricCard(
                      icon: Icons.calendar_today_rounded,
                      label: 'Last Payment',
                      value: paidEmis.isEmpty
                          ? 'N/A'
                          : '$daysSinceLastPayment ago',
                      subtitle: paidEmis.isEmpty
                          ? 'No payments yet'
                          : 'Days since last',
                      color: daysSinceLastPayment <= 30
                          ? AppColors.success
                          : daysSinceLastPayment <= 60
                              ? AppColors.warning
                              : AppColors.error,
                      theme: theme,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildHealthMetricCard(
                      icon: Icons.trending_up_rounded,
                      label: 'Collection Eff.',
                      value: '${collectionEfficiency.toStringAsFixed(0)}%',
                      subtitle: 'vs expected',
                      color: collectionEfficiency >= 90
                          ? AppColors.success
                          : collectionEfficiency >= 70
                              ? AppColors.warning
                              : AppColors.error,
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildHealthMetricCard(
                      icon: Icons.pie_chart_rounded,
                      label: 'EMI Status',
                      value: '${paidEmis.length}/$totalEmis',
                      subtitle: 'Paid / Total',
                      color: theme.colorScheme.primary,
                      theme: theme,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Original metrics
              _buildHealthRow(
                  'Status',
                  loan.status.name.toUpperCase(),
                  Icons.circle,
                  loan.status == LoanStatus.active
                      ? AppColors.success
                      : AppColors.warning,
                  theme),
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1)),
              _buildHealthRow('Tenure', loan.formattedTenure,
                  Icons.timelapse_rounded, AppColors.primary, theme),
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1)),
              _buildHealthRow(
                  'Interest Type',
                  loan.interestType.name.toUpperCase(),
                  Icons.percent_rounded,
                  AppColors.warning,
                  theme),
            ],
          ),
        );
      },
      loading: () => const ShimmerCard(height: 400),
      error: (_, __) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Center(
          child: Text('Failed to load health metrics',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.error)),
        ),
      ),
    );
  }

  Widget _buildHealthMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 10),
          Text(label,
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
        ],
      ),
    );
  }

  Widget _buildHealthRow(
      String label, String value, IconData icon, Color color, ThemeData theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 16),
        Text(label,
            style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
        const Spacer(),
        Text(value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildStaffNotes(LoanModel loan, ThemeData theme) {
    return _StaffNotesWidget(loan: loan, theme: theme);
  }

  Widget _buildPaymentHistory(
      AsyncValue<List<Map<String, dynamic>>> paymentHistoryAsync,
      AsyncValue<List<EMIScheduleModel>> scheduleAsync,
      ThemeData theme,
      bool isDark) {
    return paymentHistoryAsync.when(
      loading: () => const ShimmerCard(height: 200),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('Failed to load payment history',
            style: TextStyle(color: AppColors.error)),
      ),
      data: (payments) {
        if (payments.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long_rounded,
                      size: 48,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                  const SizedBox(height: 12),
                  Text('No payments yet',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4))),
                ],
              ),
            ),
          );
        }

        // Build EMI schedule lookup for "paid up to" dates
        final scheduleList = scheduleAsync.valueOrNull ?? [];
        final scheduleById = <String, EMIScheduleModel>{};
        for (final emi in scheduleList) {
          scheduleById[emi.id] = emi;
        }

        final recent = payments.take(10).toList();
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 430,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: recent.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => _showPaymentDetails(recent[index], theme),
                      child: _buildPaymentTile(recent[index], theme, isDark, index, scheduleById),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPaymentDetails(Map<String, dynamic> payment, ThemeData theme) {
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
    final paymentMode = payment['payment_mode']?.toString() ?? 'cash';
    final date = _getPaymentDate(payment);
    final collectedBy = payment['collected_by_name']?.toString();
    final collectedByRole = payment['collected_by_role']?.toString();
    final notes = payment['notes']?.toString();
    final referenceNumber = payment['reference_number']?.toString();
    final txId = payment['transaction_id']?.toString() ?? payment['id']?.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.payment_rounded,
                                color: AppColors.success, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Payment Received',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.5))),
                                Text(
                                    AppFormatters.formatCurrency(amount),
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.success)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Details card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow('Payment Mode',
                                paymentMode[0].toUpperCase() + paymentMode.substring(1),
                                theme),
                            _buildDetailRow(
                                'Date & Time', AppFormatters.formatDateTime(date), theme),
                            if (collectedBy != null)
                              _buildDetailRow(
                                  'Collected By', collectedBy, theme),
                            if (collectedByRole != null)
                              _buildDetailRow(
                                  'Role',
                                  collectedByRole[0].toUpperCase() +
                                      collectedByRole.substring(1),
                                  theme),
                            if (referenceNumber != null && referenceNumber.isNotEmpty)
                              _buildDetailRow('Reference', referenceNumber, theme),
                          ],
                        ),
                      ),

                      if (notes != null && notes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.info.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.note_rounded,
                                  color: AppColors.info, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(notes,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.7))),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showEditPaymentSheet(payment, theme);
                              },
                              icon: const Icon(Icons.edit_rounded, size: 18),
                              label: const Text('Edit'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: txId != null
                                  ? () {
                                      Navigator.pop(ctx);
                                      _confirmDeletePayment(payment, theme);
                                    }
                                  : null,
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              label: const Text('Delete'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                foregroundColor: AppColors.error,
                                side: BorderSide(
                                    color: AppColors.error.withValues(alpha: 0.3)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],
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

  void _showEditPaymentSheet(Map<String, dynamic> payment, ThemeData theme) {
    final currentAmount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
    final currentMode = payment['payment_mode']?.toString() ?? 'cash';
    final currentNotes = payment['notes']?.toString() ?? '';
    final currentRef = payment['reference_number']?.toString() ?? '';
    final txId = payment['transaction_id']?.toString() ?? payment['id']?.toString();

    final amountController = TextEditingController(text: currentAmount.toStringAsFixed(2));
    final notesController = TextEditingController(text: currentNotes);
    final refController = TextEditingController(text: currentRef);
    String selectedMode = currentMode;

    final modes = ['cash', 'upi', 'bank_transfer', 'cheque', 'other'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.edit_rounded,
                              color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Text('Edit Payment',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Amount
                          TextField(
                            controller: amountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Amount',
                              prefixText: '\u20b9 ',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Payment mode
                          Text('Payment Mode',
                              style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: modes.map((mode) {
                              final isSelected = selectedMode == mode;
                              return GestureDetector(
                                onTap: () => setSheetState(() => selectedMode = mode),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary.withValues(alpha: 0.15)
                                        : theme.colorScheme.surfaceContainerHighest
                                            .withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary.withValues(alpha: 0.4)
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Text(
                                    mode[0].toUpperCase() + mode.substring(1).replaceAll('_', ' '),
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? AppColors.primary : null,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),

                          // Reference
                          TextField(
                            controller: refController,
                            decoration: InputDecoration(
                              labelText: 'Reference Number (optional)',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Notes
                          TextField(
                            controller: notesController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Notes (optional)',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Save button
                          ElevatedButton(
                            onPressed: () async {
                              final newAmount = double.tryParse(amountController.text);
                              if (newAmount == null || newAmount <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Please enter a valid amount')),
                                );
                                return;
                              }

                              Navigator.pop(ctx);
                              await _updatePayment(txId, newAmount, selectedMode,
                                  refController.text, notesController.text);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Save Changes',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _updatePayment(String? txId, double amount, String mode,
      String reference, String notes) async {
    if (txId == null) return;
    final messenger = ScaffoldMessenger.of(context);

    try {
      await Supabase.instance.client
          .from('transactions')
          .update({
            'amount': amount,
            'payment_mode': mode,
            'reference_number': reference.isNotEmpty ? reference : null,
            'notes': notes.isNotEmpty ? notes : null,
          })
          .eq('id', txId);

      ref.invalidate(paymentHistoryProvider(widget.loanId));
      ref.invalidate(loanDetailProvider(widget.loanId));

      HapticFeedback.mediumImpact();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Payment updated'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _confirmDeletePayment(Map<String, dynamic> payment, ThemeData theme) {
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Payment?'),
        content: Text(
            'This will remove the payment of ${AppFormatters.formatCurrency(amount)} and restore the loan outstanding balance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await _deletePayment(payment);
            },
            child:
                const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePayment(Map<String, dynamic> payment) async {
    final txId = payment['transaction_id']?.toString() ?? payment['id']?.toString();
    if (txId == null) return;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final transactionsRepo = ref.read(transactionsRepositoryProvider);
      await transactionsRepo.deleteTransaction(txId);

      ref.invalidate(paymentHistoryProvider(widget.loanId));
      ref.invalidate(loanDetailProvider(widget.loanId));
      ref.invalidate(emiScheduleProvider(widget.loanId));

      HapticFeedback.mediumImpact();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Payment deleted'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Computes the "paid up to" date for a payment by finding the highest
  /// due date among the EMI schedules linked via selected_schedule_ids.
  DateTime? _computePaidUpToDate(
      Map<String, dynamic> payment, Map<String, EMIScheduleModel> scheduleById) {
    final scheduleIds = (payment['selected_schedule_ids'] as List?)?.cast<String>() ?? [];
    if (scheduleIds.isEmpty) return null;

    DateTime? latestDueDate;
    for (final sid in scheduleIds) {
      final emi = scheduleById[sid];
      if (emi != null) {
        if (latestDueDate == null || emi.dueDate.isAfter(latestDueDate)) {
          latestDueDate = emi.dueDate;
        }
      }
    }
    return latestDueDate;
  }

  Widget _buildPaymentTile(
      Map<String, dynamic> payment, ThemeData theme, bool isDark, int index,
      [Map<String, EMIScheduleModel>? scheduleById]) {
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
    final paymentMode = payment['payment_mode']?.toString() ?? 'cash';
    final date = _getPaymentDate(payment);
    final collectedBy = payment['collected_by_name']?.toString();

    // Compute "paid up to" date
    final paidUpToDate = scheduleById != null
        ? _computePaidUpToDate(payment, scheduleById)
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: isDark ? 0.25 : 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.payment_rounded,
              size: 18,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment via ${paymentMode[0].toUpperCase() + paymentMode.substring(1)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (paidUpToDate != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Paid up to ${DateFormat('MMM d, yyyy').format(paidUpToDate)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.success.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Text(
                  AppFormatters.formatDateTime(date),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppFormatters.formatCurrency(amount),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  letterSpacing: -0.3,
                ),
              ),
              if (collectedBy != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 11,
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          collectedBy,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(
          duration: Duration(milliseconds: 300 + (index * 30)),
          delay: Duration(milliseconds: index * 40),
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildBorrowerProfile(LoanModel loan, ThemeData theme) {
    final hasPhoto = loan.customerPhotoUrl != null && loan.customerPhotoUrl!.isNotEmpty;

    String? photoUrl;
    if (hasPhoto) {
      final raw = loan.customerPhotoUrl!.trim();
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        photoUrl = raw;
      } else {
        final rel = raw.startsWith('avatars/') ? raw.substring('avatars/'.length) : raw;
        photoUrl = 'https://tccwdpsnuudzfyxfoohk.supabase.co/storage/v1/object/public/avatars/$rel';
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          if (hasPhoto)
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Image.network(
                photoUrl ?? loan.customerPhotoUrl!,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: AppColors.primary),
                    child: Center(
                        child: Text(
                            (loan.customerName?.isNotEmpty == true
                                ? loan.customerName![0]
                                : '?'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900))),
                  );
                },
              ),
            )
          else
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.primary),
              child: Center(
                  child: Text(
                      (loan.customerName?.isNotEmpty == true
                          ? loan.customerName![0]
                          : '?'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900))),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loan.customerName ?? 'Unknown',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900)),
                Text(loan.customerPhone ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5))),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call_rounded),
            style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surface,
                padding: const EdgeInsets.all(12)),
            onPressed: () => _makeCall(loan.customerPhone ?? ''),
          ),
        ],
      ),
    );
  }

  // --- Handlers ---
  void _showCollectionSheet(
      BuildContext context, LoanModel loan, EMIScheduleModel? emi) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => CollectionSheet(loan: loan, emi: emi, branchId: ref.read(currentUserProvider)?.branchId),
      ),
    );
  }

  Future<void> _handlePdfExport() async {
    HapticFeedback.mediumImpact();
    final loan = ref.read(loanDetailProvider(widget.loanId)).value;
    if (loan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loan not loaded yet')));
      return;
    }

    final options = await showModalBottomSheet<StatementOptions>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatementOptionsSheet(
        loanStart: loan.disbursementDate ?? loan.createdAt,
      ),
    );
    if (options == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    // ── Premium loading overlay ──
    StatementGenerationOverlay.show(context);

    try {
      // Step 1: Fetch data
      final schedule = await ref.read(emiScheduleProvider(widget.loanId).future);
      final payments = await ref.read(paymentHistoryProvider(widget.loanId).future);
      final orgRaw = await ref.read(currentOrgProvider.future);
      final brandingState = ref.read(brandingProvider);
      final logoBytes = brandingState.value != null
          ? ref.read(brandingProvider.notifier).cachedLogoBytes
          : null;

      final org = LoanStatementOrgInfo(
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

      final mappedPayments = payments.map((p) {
        try {
          return LoanStatementPayment(
            date: _getPaymentDate(p),
            amount: (p['amount'] as num?)?.toDouble() ?? 0.0,
            mode: (p['payment_mode']?.toString()) ?? 'cash',
            referenceNumber: p['reference_number']?.toString(),
            notes: p['notes']?.toString(),
            collectedByName: p['collected_by_name']?.toString(),
            collectedByRole: p['collected_by_role']?.toString(),
          );
        } catch (_) {
          return LoanStatementPayment(
            date: DateTime.now(),
            amount: 0,
            mode: 'cash',
          );
        }
      }).toList();

      // Step 2: Generate
      final now = DateTime.now();
      final ref0 =
          'STMT-${loan.loanNumber}-${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';

      late final Uint8List bytes;
      late final String ext;
      late final String mime;

      switch (options.format) {
        case StatementFormat.pdf:
          final qrBytes = await QrPng.generate(
            'loan:${loan.loanNumber}',
            size: 200,
          );
          bytes = await LoanStatementPdfService.buildCustomerStatement(
            loan: loan,
            schedule: schedule,
            payments: mappedPayments,
            org: org,
            generatedByName: ref.read(currentUserProvider)?.fullName,
            periodStart: options.periodStart,
            periodEnd: options.periodEnd,
            statementRef: ref0,
            qrPngBytes: qrBytes,
          );
          ext = 'pdf';
          mime = 'application/pdf';
          break;
        case StatementFormat.excel:
          bytes = LoanStatementExcelService.build(
            loan: loan,
            schedule: schedule,
            payments: mappedPayments,
            org: org,
            periodStart: options.periodStart,
            periodEnd: options.periodEnd,
            statementRef: ref0,
          );
          ext = 'xlsx';
          mime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          break;
        case StatementFormat.csv:
          bytes = LoanStatementCsvService.build(
            loan: loan,
            schedule: schedule,
            payments: mappedPayments,
            periodStart: options.periodStart,
            periodEnd: options.periodEnd,
          );
          ext = 'csv';
          mime = 'text/csv';
          break;
      }

      // Step 3: Save
      final fileName =
          'loan_statement_${loan.loanNumber}_${now.millisecondsSinceEpoch}.$ext';

      File? localFile;
      if (kIsWeb) {
        downloadFileForWeb(bytes, fileName, mime);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        localFile = File('${dir.path}/$fileName');
        await localFile.writeAsBytes(bytes);
      }

      // Archive (best-effort, fire-and-forget)
      _archiveStatement(
        loanId: loan.id,
        bytes: bytes,
        statementRef: ref0,
        options: options,
        ext: ext,
        mime: mime,
      );

      // Dismiss loading overlay, then wait one frame for UI to settle
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
        // Show premium action sheet
        _showStatementReadySheet(
          loanNumber: loan.loanNumber,
          file: localFile!,
          ext: ext,
          mime: mime,
        );
      }
    } catch (e, st) {
      debugPrint('Statement generation failed: $e\n$st');
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  /// Fire-and-forget archive — disabled for free tier to prevent database and storage limits.
  Future<void> _archiveStatement({
    required String loanId,
    required Uint8List bytes,
    required String statementRef,
    required StatementOptions options,
    required String ext,
    required String mime,
  }) async {
    // Archiving to Supabase is disabled on the free tier to conserve storage space and rows.
    // The generated statement is downloaded or shared locally instead.
  }

  /// Premium action sheet after statement is saved on mobile.
  void _showStatementReadySheet({
    required String loanNumber,
    required File file,
    required String ext,
    required String mime,
  }) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                'Statement Ready',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'loan_statement_$loanNumber.$ext',
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
                    SharePlus.instance.share(ShareParams(
                      files: [XFile(file.path, mimeType: mime)],
                      text: 'Loan Statement - $loanNumber',
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

  Future<void> _showPastStatements() async {
    final loan = ref.read(loanDetailProvider(widget.loanId)).value;
    if (loan == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Consumer(builder: (ctx, ref, _) {
          final past = ref.watch(pastLoanStatementsProvider(loan.id));
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Past Statements',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          )),
                  const SizedBox(height: 12),
                  past.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Failed to load statements. Please try again.'),
                    ),
                    data: (rows) {
                      if (rows.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                              'No statements generated yet for this loan.',
                              textAlign: TextAlign.center),
                        );
                      }
                      return Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final r = rows[i];
                            return ListTile(
                              dense: true,
                              leading: Icon(_iconForFormat(r.format)),
                              title: Text(
                                  '${r.format.toUpperCase()} • ${r.variant}'),
                              subtitle: Text(
                                '${r.periodStart.toIso8601String().split('T').first} → ${r.periodEnd.toIso8601String().split('T').first}\n'
                                'Generated: ${r.generatedAt.toLocal()} by ${r.generatedByName ?? '—'}\n'
                                'Ref: ${r.statementRef}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'download') {
                                    await _downloadArchived(r);
                                  } else if (v == 'share') {
                                    await _shareArchived(r);
                                  } else if (v == 'email') {
                                    await _emailArchived(r);
                                  } else if (v == 'verify') {
                                    await _verifyArchived(r);
                                  } else if (v == 'delete') {
                                    await _deleteArchived(r);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                      value: 'download',
                                      child: Text('Open')),
                                  const PopupMenuItem(
                                      value: 'share', child: Text('Share')),
                                  const PopupMenuItem(
                                      value: 'email',
                                      child: Text('Email to customer')),
                                  const PopupMenuItem(
                                      value: 'verify',
                                      child: Text('Verify integrity')),
                                  if (widget.showEditButton)
                                    const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete',
                                            style:
                                                TextStyle(color: AppColors.error))),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  IconData _iconForFormat(String f) {
    switch (f) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'excel':
        return Icons.grid_on_rounded;
      case 'csv':
        return Icons.table_chart_rounded;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Future<File?> _downloadToTempAndReturn(LoanStatementArchive r) async {
    final bytes = await ref
        .read(loanStatementArchiveServiceProvider)
        .download(r.filePath);
    final fileName = '${r.statementRef}.${r.format == 'excel' ? 'xlsx' : r.format}';
    final mimeType = r.format == 'pdf'
        ? 'application/pdf'
        : r.format == 'excel'
            ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
            : 'text/csv';

    if (kIsWeb) {
      downloadFileForWeb(bytes, fileName, mimeType);
      return null;
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _downloadArchived(LoanStatementArchive r) async {
    try {
      final file = await _downloadToTempAndReturn(r);
      if (file == null) return; // Web handled via browser download
      await OpenFilex.open(file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  Future<void> _emailArchived(LoanStatementArchive r) async {
    final loan = ref.read(loanDetailProvider(widget.loanId)).value;
    final defaultEmail = loan?.customerName != null
        ? '' // we don't have email on LoanModel; let the user type / paste
        : '';
    final controller = TextEditingController(text: defaultEmail);

    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Email statement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send ${r.statementRef} as an attachment.',
                style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Recipient email',
                hintText: 'customer@example.com',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.contains('@')) Navigator.pop(ctx, v);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('Sending to $email…')));

    try {
      final client = ref.read(supabaseClientProvider);
      final res = await client.functions.invoke(
        'send-loan-statement',
        body: {
          'statement_id': r.id,
          'recipient_email': email,
        },
      );
      if (!mounted) return;
      messenger.hideCurrentSnackBar();

      final data = res.data;
      if (data is Map && data['ok'] == true) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Statement emailed.')));
      } else {
        final err = (data is Map ? data['error'] : null) ?? 'Unknown error';
        messenger.showSnackBar(SnackBar(
          content: Text('Email failed: $err'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text('Email failed: $e'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
    }
  }

  Future<void> _shareArchived(LoanStatementArchive r) async {
    try {
      final file = await _downloadToTempAndReturn(r);
      if (file == null) return; // Web handled via browser download
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: 'Loan Statement - ${r.statementRef}',
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Share failed: $e')));
    }
  }

  Future<void> _verifyArchived(LoanStatementArchive r) async {
    try {
      final bytes = await ref
          .read(loanStatementArchiveServiceProvider)
          .download(r.filePath);
      final hash = LoanStatementArchiveService.hashBytes(bytes);
      if (!mounted) return;
      final matches = hash == r.sha256Hash;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          icon: Icon(
            matches
                ? Icons.verified_rounded
                : Icons.warning_amber_rounded,
            color: matches ? AppColors.success : AppColors.error,
            size: 40,
          ),
          title: Text(matches ? 'Integrity verified' : 'Hash mismatch!'),
          content: Text(matches
              ? 'The archived file matches the SHA-256 hash recorded at generation time.\n\n'
                  'SHA-256: ${r.sha256Hash}'
              : 'The file does NOT match the recorded hash. It may have been tampered with.\n\n'
                  'Expected: ${r.sha256Hash}\nActual:    $hash'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Verify failed: $e')));
    }
  }

  Future<void> _deleteArchived(LoanStatementArchive r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete archived statement?'),
        content: Text('This will remove the file and metadata for ${r.statementRef}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref
          .read(loanStatementArchiveServiceProvider)
          .delete(r.id, r.filePath);
      ref.invalidate(pastLoanStatementsProvider(widget.loanId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Future<void> _handleSettlement(LoanModel loan) async {
    HapticFeedback.heavyImpact();
    final controller =
        TextEditingController(text: loan.outstandingBalance.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Settlement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter the final settlement amount to close this loan.',
                style: Theme.of(dialogContext).textTheme.bodySmall),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Settlement Amount',
                prefixText: '${AppFormatters.currencySymbol} ',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text) ?? 0.0;
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref
                    .read(loansRepositoryProvider)
                    .settleLoan(loan.id, amount);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ref.invalidate(loanDetailProvider(loan.id));
                ref.invalidate(loansProvider);
                ref.invalidate(loanSummaryProvider);
                ref.invalidate(dashboardLoansProvider);
                ref.invalidate(overdueLoansProvider);
                messenger.showSnackBar(SnackBar(
                    content: Text(
                        'Settlement of ${AppFormatters.formatCurrency(amount)} processed')));
              } catch (e) {
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                messenger.showSnackBar(
                    SnackBar(content: Text('Settlement failed: $e')));
              }
            },
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleEdit() async {
    HapticFeedback.mediumImpact();
    context.push('/loans/${widget.loanId}/edit');
  }

  Future<void> _handleStatusChange(LoanStatus newStatus) async {
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(loansRepositoryProvider).updateLoanStatus(
            widget.loanId,
            newStatus.name,
          );
      ref.invalidate(loanDetailProvider(widget.loanId));
      ref.invalidate(loansProvider);
      ref.invalidate(loanSummaryProvider);
      ref.invalidate(dashboardLoansProvider);
      ref.invalidate(overdueLoansProvider);
      if (!mounted) return;
      messenger.showSnackBar(
          SnackBar(content: Text('Status: ${newStatus.name.toUpperCase()}')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    }
  }

  Future<void> _handleReactivate() async {
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.play_circle_outline_rounded, color: AppColors.success),
            SizedBox(width: 12),
            Text('Reactivate Loan'),
          ],
        ),
        content: const Text(
          'This will mark the loan as active again and resume normal collection tracking. All existing EMIs will be restored to their original status. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Reactivate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(loansRepositoryProvider).updateLoanStatus(
            widget.loanId,
            LoanStatus.active.name,
          );
      ref.invalidate(loanDetailProvider(widget.loanId));
      ref.invalidate(loansProvider);
      ref.invalidate(overdueLoansProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text('Loan Reactivated Successfully'),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger
          .showSnackBar(SnackBar(content: Text('Failed to reactivate: $e')));
    }
  }

  bool _isFreezable(EMIScheduleModel emi) {
    return emi.status != EMIStatus.paid &&
        emi.status != EMIStatus.frozen &&
        emi.status != EMIStatus.waived;
  }

  Future<void> _unfreezeSingleEMI(EMIScheduleModel emi, LoanModel loan) async {
    HapticFeedback.lightImpact();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Unfreeze EMI?'),
        content: Text(
            'Are you sure you want to unfreeze EMI #${emi.emiNumber} due on ${AppFormatters.formatDate(emi.dueDate)}? This will restore this EMI and shorten the loan tenure by 1 period.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Unfreeze'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final client = ref.read(supabaseClientProvider);

    try {
      await client
          .from('emi_schedule')
          .update({'status': 'pending'}).eq('id', emi.id);

      // Decrement frozen_count
      final loanRecord = await client
          .from('loans')
          .select('frozen_count')
          .eq('id', loan.id)
          .maybeSingle();
      final currentCount = (loanRecord?['frozen_count'] as num?)?.toInt() ?? 0;

      await client.from('loans').update({
        'frozen_count': (currentCount - 1).clamp(0, 999999),
      }).eq('id', loan.id);

      if (!mounted) return;
      ref.invalidate(emiScheduleProvider(widget.loanId));
      ref.invalidate(loanDetailProvider(widget.loanId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('EMI #${emi.emiNumber} unfrozen'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      debugPrint('_unfreezeSingleEMI ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unfreeze failed: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _freezeSingleEMI(EMIScheduleModel emi, LoanModel loan) async {
    HapticFeedback.lightImpact();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Freeze EMI?'),
        content: Text(
            'Are you sure you want to freeze EMI #${emi.emiNumber} due on ${AppFormatters.formatDate(emi.dueDate)}? This will skip this EMI and extend the loan tenure by 1 period.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyan,
              foregroundColor: Colors.white,
            ),
            child: const Text('Freeze'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final client = ref.read(supabaseClientProvider);

    try {
      debugPrint('_freezeSingleEMI: emiId=${emi.id}, loanId=${loan.id}, status=${emi.status.name}');

      // Step 1: Update the EMI status
      await client
          .from('emi_schedule')
          .update({'status': 'frozen'})
          .eq('id', emi.id);

      debugPrint('_freezeSingleEMI: EMI updated successfully');

      // Step 2: Get current frozen_count
      final loanRecord = await client
          .from('loans')
          .select('frozen_count')
          .eq('id', loan.id)
          .maybeSingle();
      final currentCount = (loanRecord?['frozen_count'] as num?)?.toInt() ?? 0;

      debugPrint('_freezeSingleEMI: current frozen_count=$currentCount');

      // Step 3: Update frozen_count
      await client.from('loans').update({
        'frozen_count': currentCount + 1,
      }).eq('id', loan.id);

      debugPrint('_freezeSingleEMI: done');

      if (!mounted) return;
      ref.invalidate(emiScheduleProvider(widget.loanId));
      ref.invalidate(loanDetailProvider(widget.loanId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('EMI #${emi.emiNumber} frozen successfully'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      debugPrint('_freezeSingleEMI ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Freeze failed: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _handleManualFreeze() async {
    HapticFeedback.lightImpact();
    final loan = ref.read(loanDetailProvider(widget.loanId)).value;
    if (loan == null) return;
    final user = ref.read(currentUserProvider);
    if (user == null || user.orgId == null) return;

    final emiRepo = EMIRepository(
      ref.read(supabaseClientProvider),
      user.orgId!,
    );
    final skippedCount = await emiRepo.detectAndFreezeSkippedEMIs(widget.loanId);

    if (!mounted) return;
    if (skippedCount > 0) {
      ref.invalidate(emiScheduleProvider(widget.loanId));
      ref.invalidate(loanDetailProvider(widget.loanId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$skippedCount skipped EMI(s) frozen, tenure extended'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No skipped EMIs to freeze'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _handleDelete() async {
    HapticFeedback.heavyImpact();
    final loan = ref.read(loanDetailProvider(widget.loanId)).value;
    if (loan == null) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      final payments =
          await ref.read(paymentHistoryProvider(widget.loanId).future);
      final schedule =
          await ref.read(emiScheduleProvider(widget.loanId).future);
      final hasPayments = payments.isNotEmpty;
      final hasPaidEmis = schedule.any((e) => e.status == EMIStatus.paid);

      if (!mounted) return;
      messenger.hideCurrentSnackBar();

      if (hasPayments || hasPaidEmis) {
        final confirmCascade = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning, size: 24),
                SizedBox(width: 8),
                Text('Payments Recorded'),
              ],
            ),
            content: Text(
              'This loan has ${payments.length} payment(s) and repayment schedule records. '
              'Deleting the loan will permanently delete all associated payment history.\n\n'
              'Are you sure you want to delete the entire loan and all its data?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('DELETE ALL DATA'),
              ),
            ],
          ),
        );

        if (confirmCascade != true) return;
      }

      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Loan?'),
        content: const Text(
            'This action is irreversible. All associated repayment schedules will be purged.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);

              // Show loading indicator
              if (!mounted) return;
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                const SnackBar(content: Text('Deleting loan...')),
              );

              try {
                final repository = ref.read(loansRepositoryProvider);
                await repository.deleteLoan(widget.loanId);

                // Invalidate all loan-related providers to refresh UI
                ref.invalidate(loansProvider);
                ref.invalidate(emiScheduleProvider(widget.loanId));
                ref.invalidate(paymentHistoryProvider(widget.loanId));
                ref.invalidate(dashboardLoansProvider);
                ref.invalidate(activeLoansProvider);
                ref.invalidate(loanSummaryProvider);
                ref.invalidate(overdueLoansProvider);

                // Force UI rebuild by reading the provider again
                await ref.read(loansProvider.future);

                if (mounted) {
                  messenger.hideCurrentSnackBar();
                  // Pop back twice to exit detail page
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Loan deleted successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Delete failed: $e'),
                      backgroundColor: AppColors.error,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              }
            },
            child: const Text('DELETE', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _makeCall(String phone) async {
    final url = 'tel:$phone';
    if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url));
  }



  Future<void> _sendPaymentReminder(LoanModel loan) async {
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final schedule = await ref.read(emiScheduleProvider(widget.loanId).future);
    final nextEmi = schedule.isNotEmpty
        ? schedule.firstWhere((e) => e.status != EMIStatus.paid,
            orElse: () => schedule.last)
        : null;

    String dueInfo = '';
    Color dueColor = AppColors.textSecondary;
    if (nextEmi != null && nextEmi.status != EMIStatus.paid) {
      final daysDiff = nextEmi.dueDate.difference(DateTime.now()).inDays;
      if (daysDiff < 0) {
        dueInfo = '${daysDiff.abs()} days overdue';
        dueColor = AppColors.error;
      } else if (daysDiff == 0) {
        dueInfo = 'Due today';
        dueColor = AppColors.warning;
      } else {
        dueInfo = 'Due in $daysDiff days';
        dueColor = AppColors.primary;
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24,
                    24 + MediaQuery.of(context).padding.bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.dividerColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.notifications_active_rounded,
                            color: AppColors.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Send Reminder',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                loan.customerName ?? 'Unknown',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: isDark
                                ? AppColors.fillDark
                                : AppColors.fillLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Loan Summary Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.08),
                            AppColors.accent.withValues(alpha: 0.04),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSummaryItem(
                                'Outstanding',
                                AppFormatters.formatCurrency(loan.outstandingBalance),
                                AppColors.primary,
                                theme,
                              ),
                              _buildSummaryItem(
                                'Loan #',
                                loan.loanNumber,
                                AppColors.textSecondary,
                                theme,
                              ),
                            ],
                          ),
                          if (dueInfo.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: dueColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    dueColor == AppColors.error
                                        ? Icons.warning_rounded
                                        : dueColor == AppColors.warning
                                            ? Icons.access_time_rounded
                                            : Icons.calendar_today_rounded,
                                    size: 16,
                                    color: dueColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'EMI #${nextEmi!.emiNumber} - $dueInfo',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: dueColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Message Preview
                    Text(
                      'Message Preview',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : AppColors.cardLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        'Payment Reminder\n'
                        'Loan: ${loan.loanNumber}\n'
                        'Outstanding: ${AppFormatters.formatCurrency(loan.outstandingBalance)}\n'
                        '${dueInfo.isNotEmpty ? 'Status: $dueInfo\n' : ''}'
                        'Please pay at earliest.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Channel Buttons
                    Text(
                      'Send via',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildChannelButton(
                            context: ctx,
                            label: 'SMS',
                            icon: Icons.sms_rounded,
                            color: AppColors.info,
                            onTap: () => _sendReminderViaChannel(
                              ctx,
                              loan,
                              'sms',
                              messenger,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildChannelButton(
                            context: ctx,
                            label: 'WhatsApp',
                            icon: Icons.chat_rounded,
                            color: const Color(0xFF25D366),
                            onTap: () => _sendReminderViaChannel(
                              ctx,
                              loan,
                              'whatsapp',
                              messenger,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildChannelButton(
                            context: ctx,
                            label: 'Telegram',
                            icon: Icons.telegram_rounded,
                            color: const Color(0xFF0088CC),
                            onTap: () => _sendReminderViaChannel(
                              ctx,
                              loan,
                              'telegram',
                              messenger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
      String label, String value, Color valueColor, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildChannelButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendReminderViaChannel(
    BuildContext ctx,
    LoanModel loan,
    String channel,
    ScaffoldMessengerState messenger,
  ) async {
    Navigator.pop(ctx);

    if (loan.customerPhone == null || loan.customerPhone!.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Customer phone number not available')),
      );
      return;
    }

    final schedule = await ref.read(emiScheduleProvider(widget.loanId).future);
    final nextEmi = schedule.isNotEmpty
        ? schedule.firstWhere((e) => e.status != EMIStatus.paid,
            orElse: () => schedule.last)
        : null;

    String reminderMsg = 'Payment Reminder\n'
        'Loan: ${loan.loanNumber}\n'
        'Outstanding: ${AppFormatters.formatCurrency(loan.outstandingBalance)}';

    if (nextEmi != null && nextEmi.status != EMIStatus.paid) {
      final daysDiff = nextEmi.dueDate.difference(DateTime.now()).inDays;
      if (daysDiff < 0) {
        reminderMsg += '\nEMI #${nextEmi.emiNumber}: ${daysDiff.abs()} days OVERDUE';
      } else if (daysDiff == 0) {
        reminderMsg += '\nEMI #${nextEmi.emiNumber}: DUE TODAY';
      } else {
        reminderMsg += '\nNext EMI #${nextEmi.emiNumber}: Due in $daysDiff days';
      }
    }
    reminderMsg += '\n\nPlease pay at earliest.';

    String url;
    String successMsg;
    String errorMsg;

    switch (channel) {
      case 'sms':
        url = 'sms:${loan.customerPhone}?body=${Uri.encodeComponent(reminderMsg)}';
        successMsg = 'SMS reminder sent';
        errorMsg = 'Could not open SMS app';
        break;
      case 'whatsapp':
        url = 'https://wa.me/${loan.customerPhone}?text=${Uri.encodeComponent(reminderMsg)}';
        successMsg = 'WhatsApp reminder sent';
        errorMsg = 'Could not open WhatsApp';
        break;
      case 'telegram':
        url = 'https://t.me/${loan.customerPhone}?text=${Uri.encodeComponent(reminderMsg)}';
        successMsg = 'Telegram reminder sent';
        errorMsg = 'Could not open Telegram';
        break;
      default:
        return;
    }

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(successMsg)));
    } else {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(errorMsg)));
    }
  }

  Future<void> _handleLoanRestructure() async {
    final loan = ref.read(loanDetailProvider(widget.loanId)).value;
    if (loan == null) return;

    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    final dialogTheme = Theme.of(context);

    final newTenureController =
        TextEditingController(text: loan.tenureMonths.toString());
    final newRateController =
        TextEditingController(text: loan.interestRate.toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return PopScope(
          onPopInvokedWithResult: (didPop, result) {
            newTenureController.dispose();
            newRateController.dispose();
          },
          child: AlertDialog(
        title: const Text('Restructure Loan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Current Outstanding: ${AppFormatters.formatCurrency(loan.outstandingBalance)}',
                  style: dialogTheme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: newTenureController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'New Tenure (Months)',
                  hintText: 'Extended tenure...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newRateController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'New Interest Rate (%)',
                  hintText: 'Revised rate...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Restructuring will update the EMI schedule.',
                          style: dialogTheme.textTheme.bodySmall?.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              final newTenure = int.tryParse(newTenureController.text);
              final newRate = double.tryParse(newRateController.text);

              if (newTenure == null || newRate == null) {
                messenger.showSnackBar(
                    const SnackBar(content: Text('Invalid values')));
                return;
              }

              Navigator.pop(ctx);
              try {
                final repo = ref.read(loansRepositoryProvider);
                await repo.updateLoan(
                  loan.id,
                  interestRate: newRate,
                  tenureMonths: newTenure,
                  remarks:
                      'Restructured on ${AppFormatters.formatDate(DateTime.now())}',
                );

                await ref.read(loansRepositoryProvider).updateLoanStatus(
                      loan.id,
                      LoanStatus.restructured.name,
                    );

                ref.invalidate(loanDetailProvider(widget.loanId));
                ref.invalidate(emiScheduleProvider(widget.loanId));
                ref.invalidate(loansProvider);

                if (!mounted) return;
                messenger.showSnackBar(const SnackBar(
                    content: Text('Loan restructured successfully')));
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                    SnackBar(content: Text('Restructure failed: $e')));
              }
            },
            child: const Text('RESTRUCTURE'),
          ),
        ],
      ),
        );
      },
    );
  }

}

class _StaffNotesWidget extends ConsumerStatefulWidget {
  final LoanModel loan;
  final ThemeData theme;

  const _StaffNotesWidget({required this.loan, required this.theme});

  @override
  ConsumerState<_StaffNotesWidget> createState() => _StaffNotesWidgetState();
}

class _StaffNotesWidgetState extends ConsumerState<_StaffNotesWidget> {
  final TextEditingController _notesController = TextEditingController();
  String _searchQuery = '';
  bool _isAddingNote = false;

  List<Map<String, dynamic>> _parseNotes() {
    final remarks = widget.loan.remarks;
    if (remarks == null || remarks.isEmpty) return [];

    final parts = remarks.split(' | ');
    final notes = <Map<String, dynamic>>[];

    for (int i = 0; i < parts.length; i++) {
      final part = parts[i].trim();
      if (part.isEmpty) continue;

      if (part.contains(' |~| ')) {
        final subparts = part.split(' |~| ');
        if (subparts.length >= 3) {
          final text = subparts[0].trim();
          final author = subparts[1].trim();
          final dateStr = subparts[2].trim();
          DateTime? date;
          try {
            date = AppFormatters.convertToIST(DateTime.parse(dateStr));
          } catch (_) {
            date = AppFormatters.convertToIST(widget.loan.updatedAt);
          }

          notes.add({
            'text': text,
            'author': author,
            'date': date,
            'index': i,
            'isLatest': i == parts.length - 1,
          });
          continue;
        }
      }

      // Fallback for old style unstructured notes
      notes.add({
        'text': part,
        'author': widget.loan.staffName ?? 'Staff',
        'date': widget.loan.updatedAt,
        'index': i,
        'isLatest': i == parts.length - 1,
      });
    }

    return notes.reversed.toList();
  }

  Future<void> _addNote() async {
    if (_notesController.text.trim().isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(loansRepositoryProvider);
      final existingNotes = widget.loan.remarks ?? '';

      final currentUser = ref.read(currentUserProvider);
      final authorName = currentUser?.fullName ?? 'Staff';
      final now = DateTime.now();

      final newFormattedNote =
          "${_notesController.text.trim()} |~| $authorName |~| ${now.toIso8601String()}";

      final newNote = existingNotes.isEmpty
          ? newFormattedNote
          : '$existingNotes | $newFormattedNote';

      await repo.updateLoan(widget.loan.id, remarks: newNote);
      ref.invalidate(loanDetailProvider(widget.loan.id));

      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Note added successfully'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        _notesController.clear();
        setState(() => _isAddingNote = false);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('Failed to add note: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final allNotes = _parseNotes();
    final notes = _searchQuery.isEmpty
        ? allNotes
        : allNotes.where((note) => note['text']
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase())).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar
              if (allNotes.length > 1) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Search notes...',
                            border: InputBorder.none,
                            hintStyle: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4)),
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => setState(() => _searchQuery = ''),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Notes count
              if (allNotes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.note_rounded,
                          size: 16,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5)),
                      const SizedBox(width: 6),
                      Text(
                          '${allNotes.length} note${allNotes.length > 1 ? 's' : ''}',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),

              // Notes list
              if (notes.isEmpty && _searchQuery.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.sticky_note_2_rounded,
                          size: 40,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.2)),
                      const SizedBox(height: 8),
                      Text('No notes yet',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4))),
                      const SizedBox(height: 4),
                      Text('Add your first internal note',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.3))),
                    ],
                  ),
                )
              else if (notes.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Text('No notes match your search',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5))),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: notes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    final text = note['text'] as String;
                    final isLatest = note['isLatest'] as bool;
                    final author = note['author'] as String;
                    final date = note['date'] as DateTime;

                    final dateFormatted = AppFormatters.formatDateTime(date);

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isLatest
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : theme.colorScheme.surface.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(14),
                        border: isLatest
                            ? Border.all(
                                color: AppColors.primary
                                    .withValues(alpha: 0.2))
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isLatest
                                          ? AppColors.primary
                                          : theme.dividerColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isLatest ? 'LATEST UPDATE' : 'PAST NOTE',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                      color: isLatest
                                          ? AppColors.primary
                                          : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.4),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                dateFormatted,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.3),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            text,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: AppColors.primary
                                    .withValues(alpha: 0.1),
                                child: Text(
                                  author.isNotEmpty
                                      ? author[0].toUpperCase()
                                      : 'S',
                                  style: const TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                author,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

              // Add note section
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              if (_isAddingNote) ...[
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Write your note...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                    contentPadding: const EdgeInsets.all(14),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text('${_notesController.text.length}/500',
                          style: TextStyle(
                              fontSize: 11,
                              color: _notesController.text.length > 500
                                  ? AppColors.error
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.4))),
                    ),
                  ),
                  maxLength: 500,
                  buildCounter: (_,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _notesController.clear();
                          setState(() => _isAddingNote = false);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _notesController.text.trim().isEmpty ||
                                _notesController.text.length > 500
                            ? null
                            : _addNote,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Note'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          disabledBackgroundColor:
                              AppColors.primary.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else
                InkWell(
                  onTap: () => setState(() => _isAddingNote = true),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add_rounded,
                              size: 18, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Text('Add internal note...',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5))),
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.3)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}


