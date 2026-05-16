import 'dart:io';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/widgets/shimmer_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/utils/formatters.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../providers/loan_providers.dart';
import '../../data/models/loan_model.dart';
import '../../data/models/emi_schedule_model.dart';
import '../widgets/collection_sheet.dart';

class LoanDetailPage extends ConsumerStatefulWidget {
  final String loanId;
  const LoanDetailPage({super.key, required this.loanId});

  @override
  ConsumerState<LoanDetailPage> createState() => _LoanDetailPageState();
}

class _LoanDetailPageState extends ConsumerState<LoanDetailPage> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() => _scrollOffset = _scrollController.offset);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loanAsync = ref.watch(loanDetailProvider(widget.loanId));
    final scheduleAsync = ref.watch(emiScheduleProvider(widget.loanId));
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
                        _buildNextDueAlert(scheduleAsync, theme),
                        const SizedBox(height: 24),
                        _buildDigitalPass(loan, theme),
                        const SizedBox(height: 32),
                        _buildPrimaryActionRow(loan, scheduleAsync, theme),
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
                            _buildSectionHeader('Payment History', theme),
                            const SizedBox(height: 16),
                            _buildPaymentHistory(loan, theme),
                            const SizedBox(height: 40),
                            _buildSectionHeader('EMI Breakdown', theme),
                            const SizedBox(height: 16),
                            _buildEMIBreakdownTable(scheduleAsync, theme),
                            const SizedBox(height: 40),
                            _buildSectionHeader('Financial Health', theme),
                            const SizedBox(height: 16),
                            _buildHealthMetrics(loan, scheduleAsync, theme),
                            const SizedBox(height: 40),
                            _buildSectionHeader('NPA Classification', theme),
                            const SizedBox(height: 16),
                            _buildNPAClassification(scheduleAsync, theme),
                            const SizedBox(height: 40),
                            _buildSectionHeader('Staff Notes', theme),
                            const SizedBox(height: 16),
                            _buildStaffNotes(loan, theme),
                            const SizedBox(height: 40),
                            _buildSectionHeader('Penalty & Late Fees', theme),
                            const SizedBox(height: 16),
                            _buildPenaltyTracking(scheduleAsync, theme),
                            const SizedBox(height: 40),
                            _buildSectionHeader('Prepayment & Foreclosure', theme),
                            const SizedBox(height: 16),
                            _buildPrepaymentInfo(loan, theme),
                            const SizedBox(height: 40),
                            _buildSectionHeader('Borrower Profile', theme),
                            const SizedBox(height: 16),
                            _buildBorrowerProfile(loan, theme),
                            const SizedBox(height: 40),
                            _buildSectionHeader('Activity Timeline', theme),
                            const SizedBox(height: 16),
                             _buildActivityTimeline(loan, scheduleAsync, theme),
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

  PreferredSizeWidget _buildAppBar(ThemeData theme, LoanModel? loan) {
    final blurAlpha = (_scrollOffset / 100).clamp(0.0, 1.0);
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        child: BackdropFilter(
          filter:
              ImageFilter.blur(sigmaX: 15 * blurAlpha, sigmaY: 15 * blurAlpha),
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
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                itemBuilder: (ctx) => [
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
                  if (loan != null && loan.status == LoanStatus.defaultStatus)
                    const PopupMenuItem(
                      value: 'reactivate',
                      child: Row(
                        children: [
                          Icon(Icons.play_circle_outline_rounded,
                              size: 18, color: Colors.green),
                          SizedBox(width: 12),
                          Text('Reactivate Loan'),
                        ],
                      ),
                    )
                  else
                    const PopupMenuItem(
                      value: 'default',
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 18, color: Colors.orange),
                          SizedBox(width: 12),
                          Text('Mark Defaulted'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'restructure',
                    child: Row(
                      children: [
                        Icon(Icons.settings_suggest_rounded,
                            size: 18, color: Colors.purple),
                        SizedBox(width: 12),
                        Text('Restructure Loan'),
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
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            size: 18, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Delete Loan',
                            style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
              const Color(0xFF5E5CE6).withValues(alpha: 0.3),
              Colors.transparent,
            ],
          ),
        ),
      ),
    ).animate(onPlay: (c) => c.repeat()).rotate(duration: 20.seconds);
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
          AppFormatters.formatCurrency(loan.outstandingBalance),
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
      AsyncValue<List<EMIScheduleModel>> scheduleAsync, ThemeData theme) {
    return scheduleAsync.when(
      data: (schedule) {
        if (schedule.isEmpty) {
          return const SizedBox.shrink();
        }

        final now = DateTime.now();
        final nextEmi = schedule.firstWhere(
          (e) => e.status != EMIStatus.paid,
          orElse: () => schedule.last,
        );

        if (nextEmi.status == EMIStatus.paid) {
          return const SizedBox.shrink();
        }

        final daysDiff = nextEmi.dueDate.difference(now).inDays;
        final isOverdue = daysDiff < 0;
        final isDueToday = daysDiff == 0;
        final isDueSoon = daysDiff > 0 && daysDiff <= 7;

        Color alertColor;
        String alertText;
        IconData alertIcon;

        if (isOverdue) {
          alertColor = Colors.red;
          alertText = '${daysDiff.abs()} days OVERDUE';
          alertIcon = Icons.error_rounded;
        } else if (isDueToday) {
          alertColor = Colors.orange;
          alertText = 'DUE TODAY';
          alertIcon = Icons.schedule_rounded;
        } else if (isDueSoon) {
          alertColor = Colors.orange;
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
                '· ${nextEmi.dueDate.day}/${nextEmi.dueDate.month}/${nextEmi.dueDate.year}',
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
    final progress =
        (loan.amount - loan.outstandingBalance) / loan.totalRepayable;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
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
            color: const Color(0xFF5E5CE6).withValues(alpha: 0.2),
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
                            fontFamily: 'JetBrains Mono',
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
                          Text('${loan.interestRate}%',
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0, 1),
                      minHeight: 6,
                      backgroundColor:
                          theme.colorScheme.onSurface.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF5E5CE6)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2);
  }

  Widget _buildPrimaryActionRow(LoanModel loan,
      AsyncValue<List<EMIScheduleModel>> scheduleAsync, ThemeData theme) {
    return scheduleAsync.when(
      data: (schedule) {
        final nextEmi = schedule.isNotEmpty
            ? schedule.firstWhere((e) => e.status != EMIStatus.paid,
                orElse: () => schedule.last)
            : null;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildActionButton(
                  'Pay', Icons.add_rounded, const Color(0xFF5E5CE6), () {
                if (nextEmi != null) {
                  _showCollectionSheet(context, loan, nextEmi);
                }
              }),
              _buildActionButton('Statement', Icons.description_rounded,
                  theme.colorScheme.onSurface, () => _handlePdfExport()),
              _buildActionButton('Settle', Icons.account_balance_rounded,
                  theme.colorScheme.onSurface, () => _handleSettlement(loan)),
              _buildActionButton('Reminder', Icons.notifications_active_rounded,
                  theme.colorScheme.onSurface, () => _sendPaymentReminder(loan)),
              _buildActionButton('Message', Icons.chat_bubble_rounded,
                  theme.colorScheme.onSurface, () => _makeWhatsApp(loan)),
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
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.1),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
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
        return SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: schedule.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final emi = schedule[index];
              return _buildTimelineCard(emi, theme);
            },
          ),
        );
      },
      loading: () => const ShimmerCard(height: 160),
      error: (_, __) => const Text('Error loading schedule'),
    );
  }

  Widget _buildTimelineCard(EMIScheduleModel emi, ThemeData theme) {
    final isPaid = emi.status == EMIStatus.paid;
    final isOverdue = emi.status == EMIStatus.overdue;
    final color = isPaid
        ? Colors.green
        : (isOverdue ? Colors.red : theme.colorScheme.primary);

    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text(emi.status.name.toUpperCase(),
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w900, color: color)),
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
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildLoanIntelligence(LoanModel loan, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          _buildInfoRow('Principal Amount',
              AppFormatters.formatCurrency(loan.amount), theme),
          const SizedBox(height: 12),
          _buildInfoRow('Total Interest',
              AppFormatters.formatCurrency(loan.totalInterest), theme),
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

  Widget _buildPaymentHistory(LoanModel loan, ThemeData theme) {
    final paymentHistoryAsync = ref.watch(paymentHistoryProvider(loan.id));
    
    return paymentHistoryAsync.when(
      data: (payments) {
        if (payments.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              children: [
                Icon(Icons.receipt_long_rounded, 
                    size: 48, 
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text('No payments recorded yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          );
        }

        double totalPaid = payments.fold<double>(
            0.0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0.0));

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF5E5CE6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF5E5CE6).withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Paid',
                          style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(AppFormatters.formatCurrency(totalPaid),
                          style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF5E5CE6))),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${payments.length} payment${payments.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.green)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: payments.length > 10 ? 10 : payments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final payment = payments[index];
                return _buildPaymentTile(payment, theme);
              },
            ),
            if (payments.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Showing 10 of ${payments.length} payments',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
              ),
          ],
        );
      },
      loading: () => const ShimmerCard(height: 200),
      error: (_, __) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('Failed to load payment history',
            style: TextStyle(color: Colors.red)),
      ),
    );
  }

  Widget _buildPaymentTile(Map<String, dynamic> payment, ThemeData theme) {
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
    final paymentMode = payment['payment_mode'] as String? ?? 'cash';
    final enteredAt = payment['entered_at'] != null
        ? DateTime.parse(payment['entered_at'] as String)
        : DateTime.now();
    final notes = payment['notes'] as String?;

    IconData modeIcon;
    Color modeColor;
    switch (paymentMode) {
      case 'cash':
        modeIcon = Icons.payments_rounded;
        modeColor = Colors.green;
        break;
      case 'upi':
        modeIcon = Icons.qr_code_rounded;
        modeColor = Colors.purple;
        break;
      case 'bank_transfer':
        modeIcon = Icons.account_balance_rounded;
        modeColor = Colors.blue;
        break;
      case 'cheque':
        modeIcon = Icons.book_rounded;
        modeColor = Colors.orange;
        break;
      case 'card':
        modeIcon = Icons.credit_card_rounded;
        modeColor = Colors.teal;
        break;
      default:
        modeIcon = Icons.payments_rounded;
        modeColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: modeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(modeIcon, color: modeColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(paymentMode.replaceAll('_', ' ').toUpperCase(),
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(
                  '${enteredAt.day}/${enteredAt.month}/${enteredAt.year} at ${enteredAt.hour.toString().padLeft(2, '0')}:${enteredAt.minute.toString().padLeft(2, '0')}',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(notes,
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                ],
              ],
            ),
          ),
          Text(AppFormatters.formatCurrency(amount),
              style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.green)),
        ],
      ),
    );
  }

  Widget _buildEMIBreakdownTable(
      AsyncValue<List<EMIScheduleModel>> scheduleAsync, ThemeData theme) {
    return scheduleAsync.when(
      data: (schedule) {
        if (schedule.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text('No EMI schedule available',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          );
        }

        int paidCount = schedule.where((e) => e.status == EMIStatus.paid).length;
        int overdueCount = schedule.where((e) => e.status == EMIStatus.overdue).length;
        int upcomingCount = schedule.where((e) => e.status == EMIStatus.upcoming).length;

        double totalPrincipal = schedule.fold<double>(0, (s, e) => s + e.principal);
        double totalInterest = schedule.fold<double>(0, (s, e) => s + e.interest);
        double totalPaid = schedule.where((e) => e.status == EMIStatus.paid).fold<double>(0, (s, e) => s + e.emiAmount);

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatBadge('Paid', paidCount, Colors.green, theme),
                  _buildStatBadge('Overdue', overdueCount, Colors.red, theme),
                  _buildStatBadge('Upcoming', upcomingCount, theme.colorScheme.primary, theme),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5E5CE6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text('Collected',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                        Text(AppFormatters.formatCurrency(totalPaid),
                            style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF5E5CE6))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(flex: 1, child: Text('#', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)))),
                        Expanded(flex: 2, child: Text('Due Date', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)))),
                        Expanded(flex: 2, child: Text('Principal', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)))),
                        Expanded(flex: 2, child: Text('Interest', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)))),
                        Expanded(flex: 2, child: Text('Amount', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)))),
                        Expanded(flex: 2, child: Text('Balance', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)))),
                        Expanded(flex: 1, child: Text('Status', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)))),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: schedule.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final emi = schedule[index];
                      return _buildEMIRow(emi, theme);
                    },
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Expanded(flex: 1, child: Text('')),
                        Expanded(flex: 2, child: Text('Total', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900))),
                        Expanded(flex: 2, child: Text(AppFormatters.formatCurrency(totalPrincipal), style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900))),
                        Expanded(flex: 2, child: Text(AppFormatters.formatCurrency(totalInterest), style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900))),
                        Expanded(flex: 2, child: Text(AppFormatters.formatCurrency(totalPrincipal + totalInterest), style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900))),
                        const Expanded(flex: 2, child: Text('')),
                        const Expanded(flex: 1, child: Text('')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const ShimmerCard(height: 300),
      error: (_, __) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('Failed to load EMI schedule',
            style: TextStyle(color: Colors.red)),
      ),
    );
  }

  Widget _buildStatBadge(String label, int count, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label,
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          Text('$count',
              style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: color)),
        ],
      ),
    );
  }

  Widget _buildEMIRow(EMIScheduleModel emi, ThemeData theme) {
    final isPaid = emi.status == EMIStatus.paid;
    final isOverdue = emi.status == EMIStatus.overdue;
    final color = isPaid ? Colors.green : (isOverdue ? Colors.red : theme.colorScheme.primary);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text('${emi.emiNumber}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700))),
          Expanded(flex: 2, child: Text('${emi.dueDate.day}/${emi.dueDate.month}/${emi.dueDate.year}', style: theme.textTheme.bodySmall)),
          Expanded(flex: 2, child: Text(AppFormatters.formatCurrency(emi.principal), style: theme.textTheme.bodySmall)),
          Expanded(flex: 2, child: Text(AppFormatters.formatCurrency(emi.interest), style: theme.textTheme.bodySmall)),
          Expanded(flex: 2, child: Text(AppFormatters.formatCurrency(emi.emiAmount), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700))),
          Expanded(flex: 2, child: Text(AppFormatters.formatCurrency(emi.balanceAfter), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.primary))),
          Expanded(flex: 1, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(emi.status.name.substring(0, 3).toUpperCase(),
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color)),
          )),
        ],
      ),
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          _buildHealthRow(
              'Status',
              loan.status.name.toUpperCase(),
              Icons.circle,
              loan.status == LoanStatus.active ? Colors.green : Colors.orange,
              theme),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1)),
          _buildHealthRow('Tenure', '${loan.tenureMonths} Months',
              Icons.timelapse_rounded, const Color(0xFF5E5CE6), theme),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1)),
          _buildHealthRow('Interest Type', loan.interestType.name.toUpperCase(),
              Icons.percent_rounded, Colors.orange, theme),
        ],
      ),
    );
  }

  Widget _buildNPAClassification(
      AsyncValue<List<EMIScheduleModel>> scheduleAsync, ThemeData theme) {
    return scheduleAsync.when(
      data: (schedule) {
        final now = DateTime.now();
        int maxDaysPastDue = 0;
        int overdueCount = 0;

        for (final emi in schedule) {
          if (emi.status == EMIStatus.overdue || emi.status == EMIStatus.defaulted) {
            overdueCount++;
            final daysPast = now.difference(emi.dueDate).inDays;
            if (daysPast > maxDaysPastDue) {
              maxDaysPastDue = daysPast;
            }
          }
        }

        String npaStatus;
        Color npaColor;
        IconData npaIcon;
        String npaDescription;

        if (maxDaysPastDue >= 90) {
          npaStatus = 'NPA - Non Performing Asset';
          npaColor = Colors.red;
          npaIcon = Icons.error_outline_rounded;
          npaDescription = 'Loan is classified as NPA (90+ days overdue). Immediate action required.';
        } else if (maxDaysPastDue >= 60) {
          npaStatus = 'Doubtful Asset';
          npaColor = Colors.deepOrange;
          npaIcon = Icons.warning_amber_rounded;
          npaDescription = 'Loan is 60+ days overdue. High risk of becoming NPA.';
        } else if (maxDaysPastDue >= 30) {
          npaStatus = 'Special Mention (30 DPD)';
          npaColor = Colors.orange;
          npaIcon = Icons.info_outline_rounded;
          npaDescription = 'Loan is 30+ days overdue. Monitor closely.';
        } else if (overdueCount > 0) {
          npaStatus = 'Standard - Watch List';
          npaColor = Colors.amber;
          npaIcon = Icons.visibility_rounded;
          npaDescription = '$overdueCount overdue EMI(s). Keep under observation.';
        } else {
          npaStatus = 'Standard - Performing';
          npaColor = Colors.green;
          npaIcon = Icons.check_circle_outline_rounded;
          npaDescription = 'Loan is performing well. No overdue EMIs.';
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: npaColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: npaColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: npaColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(npaIcon, color: npaColor, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Asset Classification',
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                            Text(npaStatus,
                                style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: npaColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(npaDescription,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                  if (maxDaysPastDue > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: npaColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Maximum Days Past Due',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w600)),
                          Text('$maxDaysPastDue days',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: npaColor)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const ShimmerCard(height: 200),
      error: (_, __) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('Failed to load NPA info',
            style: TextStyle(color: Colors.red)),
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
    final notesController = TextEditingController();
    
    return StatefulBuilder(
      builder: (context, setState) {
        final notes = <String, DateTime>{};
        if (loan.remarks != null && loan.remarks!.isNotEmpty) {
          notes[loan.remarks!] = loan.updatedAt;
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (notes.isNotEmpty) ...[
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: notes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final entry = notes.entries.elementAt(index);
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(entry.key,
                                  style: theme.textTheme.bodyMedium),
                              const SizedBox(height: 4),
                              Text(
                                '${entry.value.day}/${entry.value.month}/${entry.value.year} at ${entry.value.hour.toString().padLeft(2, '0')}:${entry.value.minute.toString().padLeft(2, '0')}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                    fontSize: 11),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const Divider(height: 24),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Add internal note...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: () async {
                          if (notesController.text.trim().isEmpty) return;
                          
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final repo = ref.read(loansRepositoryProvider);
                            final existingNotes = loan.remarks ?? '';
                            final newNote = existingNotes.isEmpty 
                                ? notesController.text 
                                : '$existingNotes | ${notesController.text}';
                            
                            await repo.updateLoan(loan.id, remarks: newNote);
                            ref.invalidate(loanDetailProvider(widget.loanId));
                            
                            messenger.showSnackBar(
                                const SnackBar(content: Text('Note added')));
                          } catch (e) {
                            messenger.showSnackBar(
                                SnackBar(content: Text('Failed to add note: $e')));
                          }
                        },
                        icon: const Icon(Icons.add_rounded),
                        style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF5E5CE6)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPenaltyTracking(
      AsyncValue<List<EMIScheduleModel>> scheduleAsync, ThemeData theme) {
    return scheduleAsync.when(
      data: (schedule) {
        final overdueEmis = schedule.where((e) => 
            e.status == EMIStatus.overdue || e.status == EMIStatus.defaulted).toList();
        
        double totalPenalty = schedule.fold<double>(0, (s, e) => s + e.penaltyAmount);
        double unpaidPenalty = schedule.where((e) => !e.penaltyPaid).fold<double>(0, (s, e) => s + e.penaltyAmount);
        double paidPenalty = schedule.where((e) => e.penaltyPaid).fold<double>(0, (s, e) => s + e.penaltyAmount);

        if (totalPenalty == 0 && overdueEmis.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.green.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                const SizedBox(width: 12),
                Text('No penalties accrued',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.green, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: unpaidPenalty > 0 
                    ? Colors.red.withValues(alpha: 0.08)
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: unpaidPenalty > 0 
                        ? Colors.red.withValues(alpha: 0.2)
                        : Colors.transparent),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Penalty',
                              style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                          const SizedBox(height: 4),
                          Text(AppFormatters.formatCurrency(totalPenalty),
                              style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: unpaidPenalty > 0 ? Colors.red : Colors.green)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Unpaid',
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                          Text(AppFormatters.formatCurrency(unpaidPenalty),
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.red)),
                        ],
                      ),
                    ],
                  ),
                  if (paidPenalty > 0) ...[
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Paid Penalty',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                        Text(AppFormatters.formatCurrency(paidPenalty),
                            style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.green)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (overdueEmis.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Overdue EMIs with Penalty',
                  style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: overdueEmis.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final emi = overdueEmis[index];
                  final daysOverdue = DateTime.now().difference(emi.dueDate).inDays;
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.warning_rounded, color: Colors.red, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('EMI #${emi.emiNumber}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700)),
                              Text('$daysOverdue days overdue',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.red, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Text(AppFormatters.formatCurrency(emi.penaltyAmount),
                            style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: Colors.red)),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        );
      },
      loading: () => const ShimmerCard(height: 200),
      error: (_, __) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('Failed to load penalty info',
            style: TextStyle(color: Colors.red)),
      ),
    );
  }

  Widget _buildPrepaymentInfo(LoanModel loan, ThemeData theme) {
    final foreclosureCharge = loan.outstandingBalance * 0.02;
    final totalForeclosureAmount = loan.outstandingBalance + foreclosureCharge;
    final interestSaved = loan.totalRepayable - loan.amount - (loan.totalRepayable - loan.outstandingBalance);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF5E5CE6).withValues(alpha: 0.1),
                const Color(0xFF5E5CE6).withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF5E5CE6).withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5E5CE6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, 
                        color: Color(0xFF5E5CE6), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Foreclosure Amount',
                            style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                        Text(AppFormatters.formatCurrency(totalForeclosureAmount),
                            style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF5E5CE6))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _buildPrepaymentRow('Outstanding Balance', 
                  AppFormatters.formatCurrency(loan.outstandingBalance), theme),
              const SizedBox(height: 12),
              _buildPrepaymentRow('Foreclosure Charge (2%)', 
                  AppFormatters.formatCurrency(foreclosureCharge), theme,
                  isCharge: true),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.savings_rounded, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Potential Interest Saved',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green, fontWeight: FontWeight.w600)),
                    ),
                    Text(AppFormatters.formatCurrency(interestSaved > 0 ? interestSaved : 0),
                        style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Colors.green)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, 
                  color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Prepayment allowed after 6 EMIs. Foreclosure charge: 2% of outstanding.',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrepaymentRow(String label, String value, ThemeData theme,
      {bool isCharge = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
        Text(value,
            style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isCharge ? Colors.red : null)),
      ],
    );
  }

  Widget _buildBorrowerProfile(LoanModel loan, ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Color(0xFF5E5CE6)),
                child: Center(
                    child: Text((loan.customerName ?? '?')[0],
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
        ),
        if (loan.staffName != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.badge_rounded, 
                      color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Assigned Agent',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                      Text(loan.staffName!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.call_rounded, size: 20),
                  style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.surface,
                      padding: const EdgeInsets.all(8)),
                  onPressed: () => _makeCall(loan.staffName!),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActivityTimeline(LoanModel loan,
      AsyncValue<List<EMIScheduleModel>> scheduleAsync, ThemeData theme) {
    final activities = _buildActivityList(loan, scheduleAsync);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: activities.length,
        separatorBuilder: (_, __) => _buildTimelineConnector(theme),
        itemBuilder: (context, index) {
          final activity = activities[index];
          return _buildTimelineItem(activity, theme);
        },
      ),
    );
  }

  List<_ActivityItem> _buildActivityList(LoanModel loan,
      AsyncValue<List<EMIScheduleModel>> scheduleAsync) {
    final activities = <_ActivityItem>[];

    activities.add(_ActivityItem(
      icon: Icons.add_circle_rounded,
      color: const Color(0xFF5E5CE6),
      title: 'Loan Created',
      subtitle: 'Loan ${loan.loanNumber} disbursed',
      date: loan.createdAt,
    ));

    if (loan.disbursementDate != null) {
      activities.add(_ActivityItem(
        icon: Icons.currency_rupee_rounded,
        color: Colors.green,
        title: 'Amount Disbursed',
        subtitle: AppFormatters.formatCurrency(loan.amount),
        date: loan.disbursementDate!,
      ));
    }

    if (loan.status == LoanStatus.active || loan.status == LoanStatus.closed) {
      activities.add(_ActivityItem(
        icon: Icons.check_circle_rounded,
        color: Colors.green,
        title: 'Loan Activated',
        subtitle: 'Status changed to Active',
        date: loan.updatedAt,
      ));
    }

    final schedule = scheduleAsync.value;
    if (schedule != null) {
      final paidEmis = schedule.where((e) => e.status == EMIStatus.paid && e.paidOn != null).toList();
      for (final emi in paidEmis.take(3)) {
        activities.add(_ActivityItem(
          icon: Icons.payment_rounded,
          color: Colors.blue,
          title: 'EMI #${emi.emiNumber} Paid',
          subtitle: '${AppFormatters.formatCurrency(emi.emiAmount)} via ${emi.paymentMode?.name ?? 'unknown'}',
          date: emi.paidOn!,
        ));
      }

      final overdueEmis = schedule.where((e) => e.status == EMIStatus.overdue).toList();
      for (final emi in overdueEmis) {
        activities.add(_ActivityItem(
          icon: Icons.warning_rounded,
          color: Colors.red,
          title: 'EMI #${emi.emiNumber} Overdue',
          subtitle: 'Due: ${emi.dueDate.day}/${emi.dueDate.month}/${emi.dueDate.year}',
          date: emi.dueDate,
        ));
      }
    }

    if (loan.status == LoanStatus.closed) {
      activities.add(_ActivityItem(
        icon: Icons.celebration_rounded,
        color: Colors.amber,
        title: 'Loan Closed',
        subtitle: 'Fully repaid',
        date: loan.updatedAt,
      ));
    }

    activities.sort((a, b) => b.date.compareTo(a.date));
    return activities.take(10).toList();
  }

  Widget _buildTimelineConnector(ThemeData theme) {
    return Container(
      width: 2,
      height: 20,
      color: theme.dividerColor,
      margin: const EdgeInsets.only(left: 20),
    );
  }

  Widget _buildTimelineItem(_ActivityItem activity, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: activity.color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(activity.icon, color: activity.color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(activity.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700)),
              Text(activity.subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              const SizedBox(height: 2),
              Text(
                '${activity.date.day}/${activity.date.month}/${activity.date.year} at ${activity.date.hour.toString().padLeft(2, '0')}:${activity.date.minute.toString().padLeft(2, '0')}',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Handlers ---
  void _showCollectionSheet(
      BuildContext context, LoanModel loan, EMIScheduleModel emi) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CollectionSheet(loan: loan, emi: emi),
    );
  }

  Future<void> _handlePdfExport() async {
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
        const SnackBar(content: Text('Generating statement...')));

    try {
      final loan = ref.read(loanDetailProvider(widget.loanId)).value;
      if (loan == null) return;

      final schedule = await ref.read(emiScheduleProvider(widget.loanId).future);
      final payments = await ref.read(paymentHistoryProvider(widget.loanId).future);

      final sb = StringBuffer();
      sb.writeln('========================================');
      sb.writeln('        LOAN STATEMENT');
      sb.writeln('========================================');
      sb.writeln('');
      sb.writeln('Loan Number: ${loan.loanNumber}');
      sb.writeln('Customer: ${loan.customerName ?? 'N/A'}');
      sb.writeln('Phone: ${loan.customerPhone ?? 'N/A'}');
      sb.writeln('Generated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}');
      sb.writeln('');
      sb.writeln('----------------------------------------');
      sb.writeln('LOAN DETAILS');
      sb.writeln('----------------------------------------');
      sb.writeln('Principal: ${AppFormatters.formatCurrency(loan.amount)}');
      sb.writeln('Interest Rate: ${loan.interestRate}%');
      sb.writeln('Interest Type: ${loan.interestType.name.toUpperCase()}');
      sb.writeln('Tenure: ${loan.tenureMonths} months');
      sb.writeln('EMI Amount: ${AppFormatters.formatCurrency(loan.emiAmount)}');
      sb.writeln('Total Interest: ${AppFormatters.formatCurrency(loan.totalInterest)}');
      sb.writeln('Total Repayable: ${AppFormatters.formatCurrency(loan.totalRepayable)}');
      sb.writeln('Outstanding: ${AppFormatters.formatCurrency(loan.outstandingBalance)}');
      sb.writeln('Status: ${loan.status.name.toUpperCase()}');
      sb.writeln('');
      sb.writeln('----------------------------------------');
      sb.writeln('EMI SCHEDULE');
      sb.writeln('----------------------------------------');
      for (final emi in schedule) {
        sb.writeln('EMI #${emi.emiNumber} | Due: ${emi.dueDate.day}/${emi.dueDate.month}/${emi.dueDate.year} | Amount: ${AppFormatters.formatCurrency(emi.emiAmount)} | Principal: ${AppFormatters.formatCurrency(emi.principal)} | Interest: ${AppFormatters.formatCurrency(emi.interest)} | Balance: ${AppFormatters.formatCurrency(emi.balanceAfter)} | Status: ${emi.status.name.toUpperCase()}');
        if (emi.paidOn != null) {
          sb.writeln('   Paid on: ${emi.paidOn!.day}/${emi.paidOn!.month}/${emi.paidOn!.year} via ${emi.paymentMode?.name ?? 'N/A'}');
        }
      }
      sb.writeln('');
      sb.writeln('----------------------------------------');
      sb.writeln('PAYMENT HISTORY');
      sb.writeln('----------------------------------------');
      if (payments.isEmpty) {
        sb.writeln('No payments recorded yet.');
      } else {
        for (final payment in payments) {
          final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
          final mode = payment['payment_mode'] as String? ?? 'cash';
          final date = payment['entered_at'] != null
              ? DateTime.parse(payment['entered_at'] as String)
              : DateTime.now();
          final notes = payment['notes'] as String?;
          sb.writeln('${date.day}/${date.month}/${date.year} | $mode | ${AppFormatters.formatCurrency(amount)}${notes != null ? ' | $notes' : ''}');
        }
      }
      sb.writeln('');
      sb.writeln('========================================');
      sb.writeln('End of Statement');
      sb.writeln('========================================');

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/loan_statement_${loan.loanNumber}.txt');
      await file.writeAsString(sb.toString());

      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: 'Loan Statement - ${loan.loanNumber}',
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('Failed to generate statement: $e')));
    }
  }

  Future<void> _handleSettlement(LoanModel loan) async {
    HapticFeedback.heavyImpact();
    final controller =
        TextEditingController(text: loan.outstandingBalance.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Settlement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter the final settlement amount to close this loan.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Settlement Amount',
                prefixText: '₹ ',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text) ?? 0.0;
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              try {
                await ref
                    .read(loansRepositoryProvider)
                    .settleLoan(loan.id, amount);
                ref.invalidate(loanDetailProvider(loan.id));
                ref.invalidate(loansProvider);
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(
                    content: Text(
                        'Settlement of ${AppFormatters.formatCurrency(amount)} processed')));
              } catch (e) {
                if (!mounted) return;
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
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
          content: Text('Status: ${newStatus.name.toUpperCase()}')));
    } catch (e) {
      if (!mounted) return;
      messenger
          .showSnackBar(SnackBar(content: Text('Failed to update: $e')));
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
            Icon(Icons.play_circle_outline_rounded, color: Colors.green),
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
              backgroundColor: Colors.green,
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
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text('Loan Reactivated Successfully'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger
          .showSnackBar(SnackBar(content: Text('Failed to reactivate: $e')));
    }
  }

  Future<void> _handleDelete() async {
    HapticFeedback.heavyImpact();
    final loan = ref.read(loanDetailProvider(widget.loanId)).value;
    if (loan == null) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Checking for existing payments...')));

    try {
      final payments = await ref.read(paymentHistoryProvider(widget.loanId).future);
      final schedule = await ref.read(emiScheduleProvider(widget.loanId).future);
      final hasPayments = payments.isNotEmpty;
      final hasPaidEmis = schedule.any((e) => e.status == EMIStatus.paid);

      if (!mounted) return;
      messenger.hideCurrentSnackBar();

      if (hasPayments || hasPaidEmis) {
        messenger.showSnackBar(SnackBar(
          content: Text('Cannot delete loan with ${payments.length} payment(s) recorded. Close the loan instead.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ));
        return;
      }
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Loan?'),
        content: const Text(
            'This action is irreversible. All associated repayment schedules will be purged.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final client = ref.read(supabaseClientProvider);
                await client.from('emi_schedule').delete().eq('loan_id', widget.loanId);
                await client.from('loans').delete().eq('id', widget.loanId);
                ref.invalidate(loansProvider);
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Loan record deleted')));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Delete failed: $e')));
              }
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _makeCall(String phone) async {
    final url = 'tel:$phone';
    if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url));
  }

  Future<void> _makeWhatsApp(LoanModel loan) async {
    final schedule = await ref.read(emiScheduleProvider(widget.loanId).future);
    final nextEmi = schedule.isNotEmpty
        ? schedule.firstWhere((e) => e.status != EMIStatus.paid,
            orElse: () => schedule.last)
        : null;

    String dueInfo = '';
    if (nextEmi != null && nextEmi.status != EMIStatus.paid) {
      final daysDiff = nextEmi.dueDate.difference(DateTime.now()).inDays;
      if (daysDiff < 0) {
        dueInfo = '\n\nYour EMI #${nextEmi.emiNumber} of ${AppFormatters.formatCurrency(nextEmi.emiAmount)} is OVERDUE by ${daysDiff.abs()} days (Due: ${nextEmi.dueDate.day}/${nextEmi.dueDate.month}/${nextEmi.dueDate.year}).';
      } else if (daysDiff == 0) {
        dueInfo = '\n\nYour EMI #${nextEmi.emiNumber} of ${AppFormatters.formatCurrency(nextEmi.emiAmount)} is DUE TODAY.';
      } else {
        dueInfo = '\n\nYour next EMI #${nextEmi.emiNumber} of ${AppFormatters.formatCurrency(nextEmi.emiAmount)} is due in $daysDiff days (${nextEmi.dueDate.day}/${nextEmi.dueDate.month}/${nextEmi.dueDate.year}).';
      }
    }

    final msg = Uri.encodeComponent(
        'Hi ${loan.customerName},\n\nThis is regarding your loan ${loan.loanNumber}.\n\nOutstanding Balance: ${AppFormatters.formatCurrency(loan.outstandingBalance)}$dueInfo\n\nPlease contact us for any queries. Thank you!');
    final url = 'https://wa.me/${loan.customerPhone}?text=$msg';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sendPaymentReminder(LoanModel loan) async {
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    final dialogTheme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Payment Reminder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send reminder to ${loan.customerName}?',
                style: dialogTheme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text('Outstanding: ${AppFormatters.formatCurrency(loan.outstandingBalance)}',
                style: dialogTheme.textTheme.bodySmall?.copyWith(
                    color: dialogTheme.colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL')),
          ElevatedButton.icon(
            icon: const Icon(Icons.sms_rounded, size: 18),
            onPressed: () async {
              Navigator.pop(ctx);
              final schedule = await ref.read(emiScheduleProvider(widget.loanId).future);
              final nextEmi = schedule.isNotEmpty
                  ? schedule.firstWhere((e) => e.status != EMIStatus.paid,
                      orElse: () => schedule.last)
                  : null;

              String reminderMsg = 'Payment Reminder - Loan ${loan.loanNumber}. ';
              reminderMsg += 'Outstanding: ${AppFormatters.formatCurrency(loan.outstandingBalance)}. ';
              if (nextEmi != null && nextEmi.status != EMIStatus.paid) {
                final daysDiff = nextEmi.dueDate.difference(DateTime.now()).inDays;
                if (daysDiff < 0) {
                  reminderMsg += 'EMI #${nextEmi.emiNumber} is ${daysDiff.abs()} days overdue. ';
                } else if (daysDiff == 0) {
                  reminderMsg += 'EMI #${nextEmi.emiNumber} is due TODAY. ';
                } else {
                  reminderMsg += 'Next EMI #${nextEmi.emiNumber} due in $daysDiff days. ';
                }
              }
              reminderMsg += 'Please pay at earliest.';

              final smsUrl = 'sms:${loan.customerPhone}?body=${Uri.encodeComponent(reminderMsg)}';
              if (await canLaunchUrl(Uri.parse(smsUrl))) {
                await launchUrl(Uri.parse(smsUrl));
                if (!mounted) return;
                messenger.showSnackBar(const SnackBar(
                    content: Text('SMS reminder sent')));
              } else {
                if (!mounted) return;
                messenger.showSnackBar(const SnackBar(
                    content: Text('Could not open SMS app')));
              }
            },
            label: const Text('SMS'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.chat_rounded, size: 18),
            onPressed: () async {
              Navigator.pop(ctx);
              final schedule = await ref.read(emiScheduleProvider(widget.loanId).future);
              final nextEmi = schedule.isNotEmpty
                  ? schedule.firstWhere((e) => e.status != EMIStatus.paid,
                      orElse: () => schedule.last)
                  : null;

              String reminderMsg = 'Payment Reminder\nLoan: ${loan.loanNumber}\nOutstanding: ${AppFormatters.formatCurrency(loan.outstandingBalance)}';
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

              final waUrl = 'https://wa.me/${loan.customerPhone}?text=${Uri.encodeComponent(reminderMsg)}';
              if (await canLaunchUrl(Uri.parse(waUrl))) {
                await launchUrl(Uri.parse(waUrl), mode: LaunchMode.externalApplication);
                if (!mounted) return;
                messenger.showSnackBar(const SnackBar(
                    content: Text('WhatsApp reminder sent')));
              } else {
                if (!mounted) return;
                messenger.showSnackBar(const SnackBar(
                    content: Text('Could not open WhatsApp')));
              }
            },
            label: const Text('WhatsApp'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLoanRestructure() async {
    final loan = ref.read(loanDetailProvider(widget.loanId)).value;
    if (loan == null) return;

    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    final dialogTheme = Theme.of(context);

    final newTenureController = TextEditingController(text: loan.tenureMonths.toString());
    final newRateController = TextEditingController(text: loan.interestRate.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restructure Loan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Outstanding: ${AppFormatters.formatCurrency(loan.outstandingBalance)}',
                  style: dialogTheme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: newTenureController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'New Tenure (Months)',
                  hintText: 'Extended tenure...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newRateController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'New Interest Rate (%)',
                  hintText: 'Revised rate...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Restructuring will update the EMI schedule.',
                          style: dialogTheme.textTheme.bodySmall?.copyWith(
                              color: Colors.orange, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              final newTenure = int.tryParse(newTenureController.text);
              final newRate = double.tryParse(newRateController.text);
              
              if (newTenure == null || newRate == null) {
                messenger.showSnackBar(const SnackBar(content: Text('Invalid values')));
                return;
              }

              Navigator.pop(ctx);
              try {
                final repo = ref.read(loansRepositoryProvider);
                await repo.updateLoan(
                  loan.id,
                  interestRate: newRate,
                  tenureMonths: newTenure,
                  remarks: 'Restructured on ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
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
                messenger.showSnackBar(SnackBar(content: Text('Restructure failed: $e')));
              }
            },
            child: const Text('RESTRUCTURE'),
          ),
        ],
      ),
    );
  }
}

class _ActivityItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final DateTime date;

  _ActivityItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.date,
  });
}

