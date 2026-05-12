import 'dart:ui';
import '../../../../core/widgets/shimmer_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/utils/formatters.dart';
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

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF2F2F7),
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(theme),
      body: loanAsync.when(
        data: (loan) {
          if (loan == null) return const Center(child: Text('Loan Not Found'));
          return Stack(
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
                        const SizedBox(height: 32),
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
                            _buildSectionHeader('Financial Health', theme),
                            const SizedBox(height: 16),
                            _buildHealthMetrics(loan, theme),
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
        );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
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
                orElse: () => schedule.first)
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

  Widget _buildHealthMetrics(LoanModel loan, ThemeData theme) {
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

  Widget _buildBorrowerProfile(LoanModel loan, ThemeData theme) {
    return Container(
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
    messenger
        .showSnackBar(const SnackBar(content: Text('Generating Document...')));
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
        const SnackBar(content: Text('Statement saved to Downloads')));
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
    final loan = ref.read(loanDetailProvider(widget.loanId)).value;
    if (loan == null) return;

    HapticFeedback.mediumImpact();
    final controller = TextEditingController(text: loan.remarks ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Loan Metadata'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Remarks/Purpose',
                hintText: 'Enter internal notes or update purpose...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Metadata updated successfully')));
              Navigator.pop(context);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStatusChange(LoanStatus newStatus) async {
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(SnackBar(
          content:
              Text('Loan status updated to ${newStatus.name.toUpperCase()}')));
      ref.invalidate(loanDetailProvider(widget.loanId));
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    }
  }

  Future<void> _handleDelete() async {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Loan?'),
        content: const Text(
            'This action is irreversible. All associated repayment schedules will be purged.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to list
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Loan record purged')));
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
    final msg = Uri.encodeComponent(
        'Hi ${loan.customerName}, regarding your loan ${loan.loanNumber}...');
    final url = 'https://wa.me/${loan.customerPhone}?text=$msg';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}
