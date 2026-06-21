import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/customer_savings_model.dart';
import '../../data/providers/customer_savings_providers.dart';
import '../../../payments/presentation/widgets/upi_payment_sheet.dart';

/// Simple installment item for the savings quick pay page.
class _SavingsInst {
  final int number;
  final DateTime dueDate;
  final bool isPaid;
  final double amount;
  final String dateKey; // YYYY-MM-DD

  const _SavingsInst({
    required this.number,
    required this.dueDate,
    required this.isPaid,
    required this.amount,
    required this.dateKey,
  });
}

class CustomerSavingsQuickPayPage extends ConsumerStatefulWidget {
  final String savingsPlanId;
  const CustomerSavingsQuickPayPage({super.key, required this.savingsPlanId});
  @override
  ConsumerState<CustomerSavingsQuickPayPage> createState() =>
      _CustomerSavingsQuickPayPageState();
}

class _CustomerSavingsQuickPayPageState
    extends ConsumerState<CustomerSavingsQuickPayPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _installmentCount = 1;
  final Set<String> _selectedDateKeys = {};
  bool _suppressTabListener = false;

  // ── Dark theme helpers (same pattern as staff selectors) ──
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

  /// Generate installment list from plan data.
  /// Since CustomerSavingsModel doesn't have startDate, we use maturityDate
  /// and tenureMonths to generate installments going backwards from maturity.
  List<_SavingsInst> _generateInstallments(CustomerSavingsModel plan) {
    final installments = <_SavingsInst>[];
    final maturity = plan.maturityDate;
    final total = plan.tenureMonths ?? 12;
    final amount = plan.monthlyDeposit;
    final collectionType = plan.collectionType;

    if (maturity == null || amount <= 0 || total <= 0) return installments;

    DateTime startDate;
    switch (collectionType) {
      case 'daily':
        startDate = maturity.subtract(Duration(days: total));
        break;
      case 'weekly':
        startDate = maturity.subtract(Duration(days: total * 7));
        break;
      case 'monthly':
      default:
        int startMonth = maturity.month - total;
        int startYear = maturity.year + ((startMonth - 1) ~/ 12);
        startMonth = ((startMonth - 1) % 12) + 1;
        int startDay = maturity.day;
        int daysInStartMonth = DateTime(startYear, startMonth + 1, 0).day;
        if (startDay > daysInStartMonth) startDay = daysInStartMonth;
        startDate = DateTime(startYear, startMonth, startDay);
        break;
    }

    DateTime currentDate = startDate;
    int number = 1;

    while (number <= total && !currentDate.isAfter(maturity)) {
      final dateKey =
          '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';

      installments.add(_SavingsInst(
        number: number,
        dueDate: currentDate,
        isPaid: false,
        amount: amount,
        dateKey: dateKey,
      ));

      switch (collectionType) {
        case 'weekly':
          currentDate = currentDate.add(const Duration(days: 7));
          break;
        case 'monthly':
          int targetMonth = currentDate.month + 1;
          int targetYear = currentDate.year + ((targetMonth - 1) ~/ 12);
          targetMonth = ((targetMonth - 1) % 12) + 1;
          int targetDay = currentDate.day;
          int daysInTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
          if (targetDay > daysInTargetMonth) targetDay = daysInTargetMonth;
          currentDate = DateTime(targetYear, targetMonth, targetDay);
          break;
        default:
          currentDate = currentDate.add(const Duration(days: 1));
      }
      number++;
    }

    return installments;
  }

  List<_SavingsInst> _unpaid(List<_SavingsInst> all) =>
      all.where((i) => !i.isPaid).toList();

  Map<DateTime, List<_SavingsInst>> _buildEventMap(List<_SavingsInst> unpaid) {
    final map = <DateTime, List<_SavingsInst>>{};
    for (final inst in unpaid) {
      final dateOnly = DateTime(inst.dueDate.year, inst.dueDate.month, inst.dueDate.day);
      map.putIfAbsent(dateOnly, () => []).add(inst);
    }
    return map;
  }

  List<_SavingsInst> _eventsForDay(DateTime day, Map<DateTime, List<_SavingsInst>> map) =>
      map[DateTime(day.year, day.month, day.day)] ?? [];

  void _applyQuickPay(List<_SavingsInst> unpaid, int count) {
    final take = math.min(count, unpaid.length);
    final selected = unpaid.take(take).toList();
    setState(() {
      _selectedDateKeys
        ..clear()
        ..addAll(selected.map((e) => e.dateKey));
      _installmentCount = count;
    });
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(customerSavingsDetailProvider(widget.savingsPlanId));

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
      body: planAsync.when(
        data: (plan) {
          if (plan == null) {
            return Center(child: Text('Savings plan not found', style: TextStyle(color: _textPrimary())));
          }

          final all = _generateInstallments(plan);
          final unpaid = _unpaid(all);

          if (unpaid.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: _isDark ? AppColors.successDark : Colors.green),
                  const SizedBox(height: 16),
                  Text('All installments are paid!', style: TextStyle(fontSize: 16, color: _textPrimary())),
                ],
              ),
            );
          }

          // Sync
          _selectedDateKeys.removeWhere((dk) => !unpaid.any((i) => i.dateKey == dk));
          if (_tabController.index == 0) {
            if (_installmentCount > unpaid.length) _installmentCount = unpaid.length;
            _applyQuickPay(unpaid, _installmentCount);
          }

          return Column(
            children: [
              _buildHeader(plan, unpaid.length, all.length),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildQuickPayTab(unpaid),
                    _buildChooseDatesPlaceholder(unpaid),
                  ],
                ),
              ),
              _buildBottomBar(plan),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildHeader(CustomerSavingsModel plan, int unpaidCount, int totalCount) {
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
          const Icon(Icons.savings, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹${plan.monthlyDeposit.toStringAsFixed(0)} / installment',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$unpaidCount of $totalCount installments remaining · ${plan.displayName}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPayTab(List<_SavingsInst> unpaid) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
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
                  Text(
                    '$_installmentCount',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: _primaryColor(),
                      height: 1,
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
          const SizedBox(height: 8),
          Text(
            'Installment${_installmentCount > 1 ? 's' : ''}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textTertiary()),
          ),
          const SizedBox(height: 20),
          _buildBreakdown(unpaid),
        ],
      ),
    );
  }

  Widget _buildChooseDatesPlaceholder(List<_SavingsInst> unpaid) {
    final selectedCount = _selectedDateKeys.length;
    final amount = unpaid.isNotEmpty ? unpaid.first.amount : 0.0;

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
                  ? '$selectedCount dates selected · ₹${(selectedCount * amount).toStringAsFixed(0)}'
                  : 'Tap to choose specific dates',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _textPrimary()),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Pick installments from the calendar',
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

  Widget _buildBreakdown(List<_SavingsInst> unpaid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment Breakdown',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _textTertiary(), letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _primaryColor().withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: _primaryColor(), width: 3)),
          ),
          child: Row(
            children: [
              Icon(Icons.savings, size: 14, color: _primaryColor()),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Selected installments', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              Text(
                '$_installmentCount × ₹${(unpaid.isNotEmpty ? unpaid.first.amount : 0).toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
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

  // ── Calendar Popup ──

  Future<void> _showCalendarPopup(BuildContext context) async {
    final planAsync = ref.read(customerSavingsDetailProvider(widget.savingsPlanId));
    final plan = planAsync.value;
    if (plan == null) return;

    final all = _generateInstallments(plan);
    final unpaid = _unpaid(all);
    final instEvents = _buildEventMap(unpaid);

    final tempSelected = Set<String>.from(_selectedDateKeys);

    DateTime focusedDay = DateTime.now();
    if (tempSelected.isNotEmpty) {
      final firstKey = tempSelected.first;
      final parts = firstKey.split('-');
      focusedDay = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
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
                                              '${tempSelected.length} installment${tempSelected.length > 1 ? 's' : ''} selected',
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
                                      final key = tempSelected.elementAt(i);
                                      final parts = key.split('-');
                                      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
                                      final dateStr = DateFormat('dd MMM').format(date);
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
                                            const SizedBox(width: 6),
                                            GestureDetector(
                                              onTap: () => setPopupState(() => tempSelected.remove(key)),
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
                                  final events = _eventsForDay(day, instEvents);
                                  return events.isNotEmpty && !events.every((i) => i.isPaid);
                                },
                                selectedDayPredicate: (day) {
                                  final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                                  return tempSelected.contains(key);
                                },
                                onDaySelected: (selectedDay, newFocusedDay) {
                                  final key = '${selectedDay.year}-${selectedDay.month.toString().padLeft(2, '0')}-${selectedDay.day.toString().padLeft(2, '0')}';
                                  setPopupState(() {
                                    focusedDay = newFocusedDay;
                                    if (tempSelected.contains(key)) {
                                      tempSelected.remove(key);
                                    } else {
                                      tempSelected.add(key);
                                    }
                                  });
                                },
                                onPageChanged: (newFocusedDay) => focusedDay = newFocusedDay,
                                eventLoader: (day) => _eventsForDay(day, instEvents),
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
                                    final dotColor = _primaryColor();
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
                                    _buildLegendDot(_primaryColor(), 'Upcoming'),
                                    _buildLegendDot(_isDark ? AppColors.successDark : Colors.green, 'Paid'),
                                    _buildLegendDot(_textTertiary(), 'Unavailable'),
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
                                    final newKeys = <String>{};
                                    for (final key in tempSelected) {
                                      final parts = key.split('-');
                                      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
                                      final events = _eventsForDay(date, instEvents);
                                      for (final inst in events) {
                                        if (!inst.isPaid) {
                                          newKeys.add(inst.dateKey);
                                        }
                                      }
                                    }
                                    setState(() {
                                      _selectedDateKeys..clear()..addAll(newKeys);
                                      _installmentCount = newKeys.length;
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

  Widget _buildBottomBar(CustomerSavingsModel plan) {
    final totalSelected = _selectedDateKeys.length * plan.monthlyDeposit;
    final count = _selectedDateKeys.length;
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
                onPressed: isEnabled ? () => _openUpiPayment(plan) : null,
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

  void _openUpiPayment(CustomerSavingsModel plan) {
    final totalAmount = _selectedDateKeys.length * plan.monthlyDeposit;
    final dateKeys = _selectedDateKeys.toList();
    final amounts = List.filled(dateKeys.length, plan.monthlyDeposit);

    final note = 'Installment${dateKeys.length > 1 ? 's' : ''} ${dateKeys.join(", ")} · ₹${totalAmount.toStringAsFixed(0)}';

    HapticFeedback.lightImpact();
    UpiPaymentSheet.show(
      context,
      amount: totalAmount,
      savingsPlanId: widget.savingsPlanId,
      savingsDateKeys: dateKeys,
      savingsAmounts: amounts,
      transactionNoteOverride: note,
    );
  }
}
