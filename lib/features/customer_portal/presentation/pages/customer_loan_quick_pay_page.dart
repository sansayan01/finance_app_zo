import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/customer_emi_model.dart';
import '../../data/providers/customer_loans_providers.dart';
import '../../../payments/presentation/widgets/upi_payment_sheet.dart';

class CustomerLoanQuickPayPage extends ConsumerStatefulWidget {
  final String loanId;
  const CustomerLoanQuickPayPage({super.key, required this.loanId});
  @override
  ConsumerState<CustomerLoanQuickPayPage> createState() =>
      _CustomerLoanQuickPayPageState();
}

class _CustomerLoanQuickPayPageState
    extends ConsumerState<CustomerLoanQuickPayPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _installmentCount = 1;
  final Set<String> _selectedIds = {};
  bool _suppressTabListener = false;

  // ── Dark theme helpers (same pattern as staff EmiPaymentSelector) ──
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color _cardColor() => _isDark ? AppColors.cardDark : Colors.white;
  Color _textPrimary() => _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  Color _textSecondary() => _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
  Color _textTertiary() => _isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
  Color _borderColor() => _isDark ? AppColors.separatorDark : AppColors.separatorLight;
  Color _fillColor() => _isDark ? AppColors.fillDark : AppColors.fillLight;
  Color _primaryColor() => _isDark ? AppColors.primaryDark : AppColors.primary;
  Color _errorColor() => _isDark ? AppColors.errorDark : AppColors.error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_suppressTabListener) return;
      setState(() {});
      if (_tabController.index == 1) {
        _suppressTabListener = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showCalendarPopup(context).then((_) {
            if (mounted) {
              _tabController.animateTo(0);
              Future.delayed(const Duration(milliseconds: 400), () {
                if (mounted) _suppressTabListener = false;
              });
            }
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Count total unpaid EMIs across the selected dates.
  int _countSelectedEmis(Set<DateTime> dates, Map<DateTime, List<CustomerEmiModel>> events) {
    int count = 0;
    for (final date in dates) {
      final emis = events[date] ?? [];
      count += emis.where((e) => !e.isPaid).length;
    }
    return count;
  }

  List<CustomerEmiModel> _unpaidEmis(List<CustomerEmiModel> emis) {
    return emis.where((e) => !e.isPaid).toList()
      ..sort((a, b) => a.emiNumber.compareTo(b.emiNumber));
  }

  Map<DateTime, List<CustomerEmiModel>> _buildEventMap(List<CustomerEmiModel> unpaid) {
    final map = <DateTime, List<CustomerEmiModel>>{};
    for (final emi in unpaid) {
      if (emi.dueDate == null) continue;
      final dateOnly = DateTime(emi.dueDate!.year, emi.dueDate!.month, emi.dueDate!.day);
      map.putIfAbsent(dateOnly, () => []).add(emi);
    }
    return map;
  }

  List<CustomerEmiModel> _eventsForDay(DateTime day, Map<DateTime, List<CustomerEmiModel>> map) =>
      map[DateTime(day.year, day.month, day.day)] ?? [];

  void _applyQuickPay(List<CustomerEmiModel> unpaid, int count) {
    final take = math.min(count, unpaid.length);
    final selected = unpaid.take(take).toList();
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(selected.map((e) => e.id));
      _installmentCount = count;
    });
  }

  List<CustomerEmiModel> get _selectedEmis {
    final emisAsync = ref.read(customerEmiScheduleProvider(widget.loanId));
    final emis = emisAsync.value ?? [];
    final unpaid = _unpaidEmis(emis);
    return unpaid.where((e) => _selectedIds.contains(e.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final emisAsync = ref.watch(customerEmiScheduleProvider(widget.loanId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay via UPI'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _primaryColor(),
          labelColor: _primaryColor(),
          unselectedLabelColor: _textTertiary(),
          tabs: const [
            Tab(icon: Icon(Icons.bolt_rounded, size: 18), text: 'Quick Pay'),
            Tab(icon: Icon(Icons.calendar_month_rounded, size: 18), text: 'Choose Dates'),
          ],
        ),
      ),
      body: emisAsync.when(
        data: (emis) {
          final unpaid = _unpaidEmis(emis);
          if (unpaid.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: _isDark ? AppColors.successDark : Colors.green),
                  const SizedBox(height: 16),
                  Text('All EMIs are paid!', style: TextStyle(fontSize: 16, color: _textPrimary())),
                ],
              ),
            );
          }

          final emiAmount = unpaid.first.emiAmount;

          _selectedIds.removeWhere((id) => !unpaid.any((e) => e.id == id));
          if (_tabController.index == 0 && _selectedIds.isNotEmpty) {
            final currentCount = _selectedIds.length;
            if (currentCount != _installmentCount) {
              _installmentCount = currentCount;
            }
          }

          return Column(
            children: [
              _buildHeader(emiAmount, unpaid.length, emis.length),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildQuickPayTab(unpaid, emiAmount, emis.length),
                    _buildChooseDatesPlaceholder(),
                  ],
                ),
              ),
              _buildBottomBar(),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  // ── Header ──

  Widget _buildHeader(double emiAmount, int unpaidCount, int totalCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryColor(), _primaryColor().withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹${emiAmount.toStringAsFixed(0)} / EMI',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$unpaidCount of $totalCount installments remaining',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Pay Tab ──

  Widget _buildQuickPayTab(List<CustomerEmiModel> unpaid, double emiAmount, int totalCount) {
    final overdueCount = unpaid.where((e) => e.isOverdue).length;
    final dueTodayCount = unpaid.where((e) {
      if (e.dueDate == null || e.isPaid) return false;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final due = DateTime(e.dueDate!.year, e.dueDate!.month, e.dueDate!.day);
      return due == today;
    }).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStatusSummary(unpaid.length, overdueCount, dueTodayCount, totalCount - unpaid.length),
          const SizedBox(height: 14),
          // Counter
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: _primaryColor().withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _primaryColor().withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCounterButton(
                    icon: Icons.remove_rounded,
                    onTap: _installmentCount > 1
                        ? () {
                            HapticFeedback.selectionClick();
                            _applyQuickPay(unpaid, _installmentCount - 1);
                          }
                        : null,
                  ),
                  const SizedBox(width: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                    child: Text(
                      '$_installmentCount',
                      key: ValueKey(_installmentCount),
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        color: _primaryColor(),
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  _buildCounterButton(
                    icon: Icons.add_rounded,
                    onTap: _installmentCount < unpaid.length
                        ? () {
                            HapticFeedback.selectionClick();
                            _applyQuickPay(unpaid, _installmentCount + 1);
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'EMI${_installmentCount > 1 ? 's' : ''}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textTertiary()),
          ),
          const SizedBox(height: 14),
          _buildAllocationBreakdown(overdueCount, dueTodayCount, unpaid.length),
        ],
      ),
    );
  }

  Widget _buildStatusSummary(int unpaid, int overdue, int dueToday, int paid) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _fillColor(),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          if (overdue > 0) ...[
            Icon(Icons.warning_amber_rounded, size: 14, color: _errorColor()),
            const SizedBox(width: 4),
            Text('$overdue overdue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _errorColor())),
            const SizedBox(width: 12),
          ],
          if (dueToday > 0) ...[
            const Icon(Icons.schedule_rounded, size: 14, color: AppColors.orange),
            const SizedBox(width: 4),
            Text('$dueToday due today', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.orange)),
            const SizedBox(width: 12),
          ],
          Text('$unpaid unpaid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textSecondary())),
          const Spacer(),
          Text('$paid paid', style: TextStyle(fontSize: 12, color: _textTertiary())),
        ],
      ),
    );
  }

  Widget _buildAllocationBreakdown(int overdueCount, int dueTodayCount, int unpaidCount) {
    final count = _installmentCount;
    final overdueToPay = math.min(count, overdueCount);
    final remainingAfterOverdue = count - overdueToPay;
    final todayToPay = math.min(remainingAfterOverdue, dueTodayCount);
    final remainingAfterToday = remainingAfterOverdue - todayToPay;
    final advanceToPay = remainingAfterToday;

    final emiAmount = unpaidCount > 0
        ? (_unpaidEmis(ref.read(customerEmiScheduleProvider(widget.loanId)).value ?? []).first.emiAmount)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment Breakdown',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _textTertiary(), letterSpacing: 0.5)),
        const SizedBox(height: 8),
        if (overdueToPay > 0)
          _buildBreakdownRow(Icons.warning_amber_rounded, _errorColor(), 'Overdue EMIs', overdueToPay, emiAmount),
        if (todayToPay > 0)
          _buildBreakdownRow(Icons.schedule_rounded, AppColors.orange, "Today's EMI", todayToPay, emiAmount),
        if (advanceToPay > 0)
          _buildBreakdownRow(Icons.fast_forward_rounded, _primaryColor(), 'Advance EMIs', advanceToPay, emiAmount),
        if (overdueToPay == 0 && todayToPay == 0 && advanceToPay == 0)
          Text('No unpaid EMIs remaining', style: TextStyle(fontSize: 12, color: _textTertiary())),
      ],
    );
  }

  Widget _buildBreakdownRow(IconData icon, Color color, String label, int count, double emiAmount) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('$count × ₹${emiAmount.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: _textTertiary())),
                ],
              ),
            ),
            Text('₹${(count * emiAmount).toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterButton({required IconData icon, VoidCallback? onTap}) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: enabled ? 1.0 : 0.9,
        duration: const Duration(milliseconds: 150),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: enabled
                ? LinearGradient(colors: [_primaryColor(), _primaryColor().withValues(alpha: 0.8)])
                : null,
            color: enabled ? null : _fillColor(),
            borderRadius: BorderRadius.circular(18),
            boxShadow: enabled
                ? [BoxShadow(color: _primaryColor().withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]
                : null,
          ),
          child: Icon(icon, size: 28, color: enabled ? Colors.white : _textTertiary()),
        ),
      ),
    );
  }

  // ── Choose Dates placeholder ──

  Widget _buildChooseDatesPlaceholder() {
    final selectedCount = _selectedIds.length;
    final emisAsync = ref.read(customerEmiScheduleProvider(widget.loanId));
    final unpaid = _unpaidEmis(emisAsync.value ?? []);
    final emiAmount = unpaid.isNotEmpty ? unpaid.first.emiAmount : 0.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _primaryColor().withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.calendar_month_rounded, size: 36, color: _primaryColor()),
            ),
            const SizedBox(height: 16),
            Text(
              selectedCount > 0
                  ? '$selectedCount dates selected · ₹${(selectedCount * emiAmount).toStringAsFixed(0)}'
                  : 'Tap to choose specific dates',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _textPrimary()),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Pick EMIs from the calendar',
              style: TextStyle(fontSize: 13, color: _textTertiary()),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showCalendarPopup(context),
              icon: const Icon(Icons.calendar_month_rounded, size: 20),
              label: const Text('Open Calendar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor(),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Calendar Popup ──

  Future<void> _showCalendarPopup(BuildContext context) async {
    final emisAsync = ref.read(customerEmiScheduleProvider(widget.loanId));
    final unpaid = _unpaidEmis(emisAsync.value ?? []);
    final emiEvents = _buildEventMap(unpaid);

    final tempSelected = Set<DateTime>.from(
      _selectedIds.expand((id) {
        final emi = unpaid.firstWhere(
          (e) => e.id == id,
          orElse: () => unpaid.first,
        );
        if (emi.dueDate == null) return <DateTime>[];
        return [DateTime(emi.dueDate!.year, emi.dueDate!.month, emi.dueDate!.day)];
      }),
    );

    DateTime focusedDay = DateTime.now();
    if (tempSelected.isNotEmpty) {
      focusedDay = tempSelected.first;
    }

    final cardBg = _isDark ? AppColors.cardDark : Colors.white;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: _isDark ? Colors.black54 : Colors.black87,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setPopupState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: _isDark ? 0.3 : 0.12), blurRadius: 32, spreadRadius: -8, offset: const Offset(0, -8)),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardBg.withValues(alpha: _isDark ? 0.98 : 0.92),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      border: Border.all(color: _borderColor().withValues(alpha: 0.3), width: 1),
                    ),
                    child: SafeArea(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Accent bar
                            Container(
                              height: 4,
                              margin: const EdgeInsets.only(top: 12),
                              width: 64,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                gradient: LinearGradient(colors: [_primaryColor(), _isDark ? AppColors.accentDark : AppColors.accent]),
                              ),
                            ),
                            const SizedBox(height: 18),
                            // Header
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 28),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: [_primaryColor(), _isDark ? AppColors.accentDark : AppColors.accent]),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: const Icon(Icons.calendar_month_rounded, size: 22, color: Colors.white),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Select Payment Dates',
                                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: _textPrimary())),
                                        if (tempSelected.isNotEmpty)
                                          Container(
                                            margin: const EdgeInsets.only(top: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(colors: [_primaryColor(), _primaryColor().withValues(alpha: 0.7)]),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${_countSelectedEmis(tempSelected, emiEvents)} EMIs across ${tempSelected.length} date${tempSelected.length > 1 ? 's' : ''}',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (tempSelected.isNotEmpty)
                                    GestureDetector(
                                      onTap: () => setPopupState(() => tempSelected.clear()),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: _errorColor().withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: _errorColor().withValues(alpha: 0.2)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.close_rounded, size: 13, color: _errorColor()),
                                            const SizedBox(width: 4),
                                            Text('Clear', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _errorColor())),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Selected date chips
                            if (tempSelected.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 28),
                                child: SizedBox(
                                  height: 42,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: tempSelected.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                                    itemBuilder: (_, i) {
                                      final date = tempSelected.elementAt(i);
                                      final dateStr = DateFormat('dd MMM').format(date);
                                      final events = _eventsForDay(date, emiEvents);
                                      final emiCount = events.where((e) => !e.isPaid).length;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: [_primaryColor(), _isDark ? AppColors.accentDark : AppColors.accent]),
                                          borderRadius: BorderRadius.circular(14),
                                          boxShadow: [BoxShadow(color: _primaryColor().withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(dateStr, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
                                            if (emiCount > 1) ...[
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.25),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '×$emiCount',
                                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(width: 6),
                                            GestureDetector(
                                              onTap: () => setPopupState(() => tempSelected.remove(date)),
                                              child: Container(
                                                width: 20,
                                                height: 20,
                                                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.22)),
                                                child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            if (tempSelected.isNotEmpty) const SizedBox(height: 14),
                            // Calendar
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: TableCalendar(
                                firstDay: DateTime(2020),
                                lastDay: DateTime(2030),
                                focusedDay: focusedDay,
                                calendarFormat: CalendarFormat.month,
                                rowHeight: 46,
                                daysOfWeekHeight: 40,
                                startingDayOfWeek: StartingDayOfWeek.monday,
                                rangeSelectionMode: RangeSelectionMode.disabled,
                                daysOfWeekStyle: DaysOfWeekStyle(
                                  weekdayStyle: TextStyle(color: _textTertiary(), fontSize: 12, fontWeight: FontWeight.w600),
                                  weekendStyle: TextStyle(color: _textTertiary(), fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                // tableBorder not available in this TableCalendar version
                                enabledDayPredicate: (day) {
                                  final events = _eventsForDay(day, emiEvents);
                                  return events.isNotEmpty && !events.every((e) => e.isPaid);
                                },
                                selectedDayPredicate: (day) {
                                  final dateOnly = DateTime(day.year, day.month, day.day);
                                  return tempSelected.contains(dateOnly);
                                },
                                onDaySelected: (selectedDay, newFocusedDay) {
                                  final dateOnly = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
                                  setPopupState(() {
                                    focusedDay = newFocusedDay;
                                    if (tempSelected.contains(dateOnly)) {
                                      tempSelected.remove(dateOnly);
                                    } else {
                                      tempSelected.add(dateOnly);
                                    }
                                  });
                                },
                                onPageChanged: (newFocusedDay) => focusedDay = newFocusedDay,
                                eventLoader: (day) => _eventsForDay(day, emiEvents),
                                calendarStyle: CalendarStyle(
                                  outsideDaysVisible: false,
                                  cellMargin: const EdgeInsets.all(4),
                                  todayDecoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: _primaryColor().withValues(alpha: 0.6), width: 2),
                                  ),
                                  todayTextStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _primaryColor()),
                                  selectedDecoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(colors: [_primaryColor(), _isDark ? AppColors.accentDark : AppColors.accent]),
                                  ),
                                  selectedTextStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white),
                                  defaultTextStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary()),
                                  disabledTextStyle: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.lineThrough,
                                    color: _isDark ? AppColors.textTertiaryDark : Colors.grey.withValues(alpha: 0.5),
                                  ),
                                  markerDecoration: const BoxDecoration(),
                                  markersMaxCount: 0,
                                ),
                                calendarBuilders: CalendarBuilders(
                                  markerBuilder: (context, day, events) {
                                    if (events.isEmpty) return const SizedBox.shrink();
                                    final hasOverdue = events.any((e) => e is CustomerEmiModel && e.isOverdue);
                                    final dotColor = hasOverdue ? _errorColor() : _primaryColor();
                                    return Positioned(
                                      bottom: 1,
                                      child: Container(
                                        width: 18,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: dotColor.withValues(alpha: _isDark ? 0.25 : 0.15),
                                          borderRadius: BorderRadius.circular(7),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${events.length}',
                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: dotColor),
                                        ),
                                      ),
                                    );
                                  },
                                  defaultBuilder: (context, day, focusedDay) {
                                    final events = _eventsForDay(day, emiEvents);
                                    if (events.isEmpty) return null;
                                    final hasOverdue = events.any((e) => e.isOverdue);
                                    if (!hasOverdue) return null;
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: _errorColor().withValues(alpha: _isDark ? 0.18 : 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: _errorColor().withValues(alpha: 0.25), width: 1),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text('${day.day}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _errorColor())),
                                    );
                                  },
                                ),
                                headerStyle: HeaderStyle(
                                  titleCentered: true,
                                  headerPadding: const EdgeInsets.symmetric(vertical: 14),
                                  titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: _textPrimary()),
                                  leftChevronIcon: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(color: _fillColor(), borderRadius: BorderRadius.circular(10)),
                                    child: Icon(Icons.chevron_left_rounded, size: 20, color: _textSecondary()),
                                  ),
                                  rightChevronIcon: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(color: _fillColor(), borderRadius: BorderRadius.circular(10)),
                                    child: Icon(Icons.chevron_right_rounded, size: 20, color: _textSecondary()),
                                  ),
                                  formatButtonVisible: false,
                                ),
                              ),
                            ),
                            // Legend
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: _fillColor(),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _borderColor().withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildLegendDot(_errorColor(), 'Overdue'),
                                    _buildLegendDot(AppColors.orange, 'Due Today'),
                                    _buildLegendDot(_primaryColor(), 'Upcoming'),
                                    _buildLegendDot(_isDark ? AppColors.successDark : Colors.green, 'Paid'),
                                  ],
                                ),
                              ),
                            ),
                            // Done Button
                            Padding(
                              padding: const EdgeInsets.fromLTRB(28, 24, 28, 48),
                              child: SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: () {
                                    final newIds = <String>{};
                                    for (final date in tempSelected) {
                                      final events = _eventsForDay(date, emiEvents);
                                      for (final emi in events) {
                                        if (!emi.isPaid) {
                                          newIds.add(emi.id);
                                        }
                                      }
                                    }
                                    setState(() {
                                      _selectedIds..clear()..addAll(newIds);
                                      _installmentCount = newIds.length;
                                    });
                                    Navigator.pop(ctx);
                                    HapticFeedback.selectionClick();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: [_primaryColor(), _isDark ? AppColors.accentDark : AppColors.accent]),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Container(
                                      height: 58,
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.check_circle_rounded, size: 22, color: Colors.white),
                                          const SizedBox(width: 8),
                                          Text(
                                            tempSelected.isEmpty
                                                ? 'Done'
                                                : 'Done (${tempSelected.length} date${tempSelected.length > 1 ? 's' : ''})',
                                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _textSecondary())),
        ],
      ),
    );
  }

  // ── Bottom Bar ──

  Widget _buildBottomBar() {
    final selectedEmis = _selectedEmis;
    final totalSelected = selectedEmis.fold<double>(0, (sum, e) => sum + e.emiAmount);
    final count = selectedEmis.length;
    final isEnabled = count > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor(),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Selected: $count · ₹${totalSelected.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isEnabled ? _primaryColor() : _textTertiary()),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isEnabled ? _openUpiPayment : null,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text('Pay ₹${totalSelected.toStringAsFixed(0)} via UPI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor(),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openUpiPayment() {
    final selectedEmis = _selectedEmis;
    final totalAmount = selectedEmis.fold<double>(0, (sum, e) => sum + e.emiAmount);
    final emiIds = selectedEmis.map((e) => e.id).toList();
    final emiAmounts = selectedEmis.map((e) => e.emiAmount).toList();
    final emiNumbers = selectedEmis.map((e) => e.emiNumber).toList();
    // Pass each EMI's due date so the staff confirmations page can show
    // the actual installment date the customer was paying for instead of
    // an EMI number.
    final installmentDates = selectedEmis
        .map((e) => e.dueDate)
        .whereType<DateTime>()
        .toList();

    final note = 'EMI #${emiNumbers.join(", ")} · ₹${totalAmount.toStringAsFixed(0)}';

    HapticFeedback.lightImpact();
    UpiPaymentSheet.show(
      context,
      amount: totalAmount,
      loanId: widget.loanId,
      emiScheduleIds: emiIds,
      emiAmounts: emiAmounts,
      installmentDates: installmentDates,
      transactionNoteOverride: note,
    );
  }
}
