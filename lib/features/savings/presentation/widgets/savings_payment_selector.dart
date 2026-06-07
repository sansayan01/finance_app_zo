import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/savings_installment_model.dart';

/// Hybrid savings payment selector with two modes:
///
/// **Quick Pay** (default) -- +/- installment count, auto-overdue-first allocation.
/// **Custom** -- Calendar popup for picking specific dates.
///
/// Both modes emit the same `List<SavingsInstallment>` via `onSelectionChanged`.
class SavingsPaymentSelector extends StatefulWidget {
  final List<SavingsInstallment> installments;
  final double installmentAmount;
  final int totalInstallments;
  final ValueChanged<List<SavingsInstallment>>? onSelectionChanged;
  final List<String> initialSelectedDateKeys;

  const SavingsPaymentSelector({
    super.key,
    required this.installments,
    required this.installmentAmount,
    required this.totalInstallments,
    this.onSelectionChanged,
    this.initialSelectedDateKeys = const [],
  });

  @override
  State<SavingsPaymentSelector> createState() => _SavingsPaymentSelectorState();
}

class _SavingsPaymentSelectorState extends State<SavingsPaymentSelector>
    with TickerProviderStateMixin {
  late final Set<String> _selectedIds;
  late Map<DateTime, List<SavingsInstallment>> _installmentEvents;
  late final TabController _tabController;

  // Quick Pay state
  int _installmentCount = 1;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<String>.from(widget.initialSelectedDateKeys);
    _installmentEvents = _buildEventMap();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));

    // Auto-select first unpaid installment by default if nothing pre-selected
    if (_selectedIds.isEmpty) {
      final unpaid = _unpaidInstallments;
      if (unpaid.isNotEmpty) {
        _selectedIds.add(_dateKey(unpaid.first.dueDate));
        _installmentCount = 1;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onSelectionChanged?.call(selectedInstallments);
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SavingsPaymentSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSelectedDateKeys != widget.initialSelectedDateKeys) {
      _selectedIds
        ..clear()
        ..addAll(widget.initialSelectedDateKeys);
    }
    if (oldWidget.installments != widget.installments) {
      _installmentEvents = _buildEventMap();
    }
  }

  // -- Helpers ----------------------------------------------------------

  /// Date-based ID: '2026-06-01'
  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Parse a dateKey string back to a DateTime (date-only).
  DateTime _dateFromKey(String key) {
    final parts = key.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  /// Whether a given installment is overdue (due date before today and unpaid).
  bool _isOverdue(SavingsInstallment installment) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dueOnly = DateTime(
        installment.dueDate.year, installment.dueDate.month, installment.dueDate.day);
    return dueOnly.isBefore(todayOnly) && !installment.isPaid;
  }

  /// Whether a given installment is due today and unpaid.
  bool _isDueToday(SavingsInstallment installment) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dueOnly = DateTime(
        installment.dueDate.year, installment.dueDate.month, installment.dueDate.day);
    return dueOnly.isAtSameMomentAs(todayOnly) && !installment.isPaid;
  }

  Map<DateTime, List<SavingsInstallment>> _buildEventMap() {
    final map = <DateTime, List<SavingsInstallment>>{};
    for (final installment in widget.installments) {
      final dateOnly = DateTime(installment.dueDate.year,
          installment.dueDate.month, installment.dueDate.day);
      map.putIfAbsent(dateOnly, () => []).add(installment);
    }
    return map;
  }

  List<SavingsInstallment> _eventsForDay(DateTime day) =>
      _installmentEvents[DateTime(day.year, day.month, day.day)] ?? [];

  bool _isSelectable(SavingsInstallment installment) => !installment.isPaid;

  /// Sorted unpaid installments for allocation (oldest first).
  List<SavingsInstallment> get _unpaidInstallments => widget.installments
      .where(_isSelectable)
      .toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  List<SavingsInstallment> get selectedInstallments => widget.installments
      .where((e) => _selectedIds.contains(_dateKey(e.dueDate)))
      .toList(growable: false);

  // -- Quick Pay allocation (oldest-first) ------------------------------

  void _applyQuickPay(int count) {
    final unpaid = _unpaidInstallments;
    final take = math.min(count, unpaid.length);
    final selected = unpaid.take(take).toList();
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(selected.map((e) => _dateKey(e.dueDate)));
      _installmentCount = count;
    });
    widget.onSelectionChanged?.call(selectedInstallments);
  }

  // -- Theme helpers ---------------------------------------------------

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color _cardColor() => _isDark ? AppColors.cardDark : Colors.white;
  Color _textPrimary() =>
      _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  Color _textSecondary() =>
      _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
  Color _textTertiary() =>
      _isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
  Color _borderColor() =>
      _isDark ? AppColors.separatorDark : AppColors.separatorLight;
  Color _fillColor() => _isDark ? AppColors.fillDark : AppColors.fillLight;
  Color _primaryColor() => _isDark ? AppColors.primaryDark : AppColors.primary;
  Color _successColor() => _isDark ? AppColors.successDark : AppColors.success;
  Color _errorColor() => _isDark ? AppColors.errorDark : AppColors.error;

  // -- Build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final unpaidInstallments = _unpaidInstallments;
    final overdueCount = unpaidInstallments.where(_isOverdue).length;
    final dueTodayCount = unpaidInstallments.where(_isDueToday).length;
    final paidCount = widget.installments.length - unpaidInstallments.length;
    final selectedCount = _selectedIds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // -- Header --
        _buildHeader(unpaidInstallments.length),

        const SizedBox(height: 14),

        // -- Status summary --
        _buildStatusSummary(
            unpaidInstallments.length, overdueCount, dueTodayCount, paidCount),

        const SizedBox(height: 14),

        // -- Tab Bar --
        _buildTabBar(),

        const SizedBox(height: 14),

        // -- Tab Content --
        if (_tabController.index == 0)
          _buildQuickPayTab(overdueCount, dueTodayCount, unpaidInstallments.length)
        else
          _buildCustomTab(),

        const SizedBox(height: 14),

        // -- Total Section --
        _buildTotalSection(selectedCount),
      ],
    );
  }

  // -- Header -----------------------------------------------------------

  Widget _buildHeader(int unpaidCount) {
    return Row(
      children: [
        // Gradient icon container
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor(), _primaryColor().withValues(alpha: 0.7)],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: _primaryColor().withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.savings_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Savings Schedule',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: _textPrimary(),
                ),
              ),
              if (_selectedIds.isNotEmpty) ...[
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      _successColor(),
                      _successColor().withValues(alpha: 0.7),
                    ]),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_selectedIds.length} selected',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // -- Tab Bar -----------------------------------------------------------

  Widget _buildTabBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primaryColor().withValues(alpha: 0.06),
            _primaryColor().withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor().withValues(alpha: 0.4)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryColor(), _primaryColor().withValues(alpha: 0.8)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _primaryColor().withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerHeight: 0,
        labelColor: Colors.white,
        unselectedLabelColor: _textSecondary(),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _textSecondary(),
        ),
        tabs: const [
          Tab(icon: Icon(Icons.bolt_rounded, size: 18), text: 'Quick Pay'),
          Tab(icon: Icon(Icons.calendar_month_rounded, size: 18), text: 'Choose Dates'),
        ],
      ),
    );
  }

  // -- Quick Pay Tab ----------------------------------------------------

  Widget _buildQuickPayTab(
      int overdueCount, int dueTodayCount, int unpaidCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor().withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overdue/today summary
          if (overdueCount > 0 || dueTodayCount > 0) ...[
            Row(
              children: [
                if (overdueCount > 0) ...[
                  Icon(Icons.warning_amber_rounded,
                      size: 14, color: _errorColor()),
                  const SizedBox(width: 4),
                  Text(
                    '$overdueCount overdue',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _errorColor(),
                    ),
                  ),
                ],
                if (overdueCount > 0 && dueTodayCount > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Container(
                        width: 1,
                        height: 12,
                        color: _borderColor()),
                  ),
                if (dueTodayCount > 0) ...[
                  const Icon(Icons.schedule_rounded,
                      size: 14, color: AppColors.orange),
                  const SizedBox(width: 4),
                  Text(
                    '$dueTodayCount due today',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.orange,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
          ],

          // Installment counter
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _primaryColor().withValues(alpha: 0.06),
                    _primaryColor().withValues(alpha: 0.02),
                  ],
                ),
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
                            _applyQuickPay(_installmentCount - 1);
                          }
                        : null,
                  ),
                  const SizedBox(width: 24),
                  // Animated number with glow ring
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Glow ring
                        if (_installmentCount > 0)
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _primaryColor().withValues(alpha: 0.15),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _primaryColor().withValues(alpha: 0.08),
                                  blurRadius: 20,
                                  spreadRadius: -4,
                                ),
                              ],
                            ),
                          ),
                        // Number
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: anim,
                            child: child,
                          ),
                          child: Text(
                            '$_installmentCount',
                            key: ValueKey(_installmentCount),
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2,
                              color: _primaryColor(),
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  _buildCounterButton(
                    icon: Icons.add_rounded,
                    onTap: _installmentCount < unpaidCount
                        ? () {
                            HapticFeedback.selectionClick();
                            _applyQuickPay(_installmentCount + 1);
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Installment${_installmentCount > 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textSecondary(),
            ),
          ),

          const SizedBox(height: 14),

          // Allocation breakdown
          _buildAllocationBreakdown(overdueCount, dueTodayCount, unpaidCount),
        ],
      ),
    );
  }

  Widget _buildCounterButton({
    required IconData icon,
    VoidCallback? onTap,
  }) {
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
                ? LinearGradient(
                    colors: [
                      _primaryColor(),
                      _primaryColor().withValues(alpha: 0.8),
                    ],
                  )
                : null,
            color: enabled ? null : _fillColor(),
            borderRadius: BorderRadius.circular(18),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: _primaryColor().withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 28,
            color: enabled ? Colors.white : _textTertiary(),
          ),
        ),
      ),
    );
  }

  Widget _buildAllocationBreakdown(
      int overdueCount, int dueTodayCount, int unpaidCount) {
    final count = _installmentCount;

    // Calculate how the allocation works
    final overdueToPay = math.min(count, overdueCount);
    final remainingAfterOverdue = count - overdueToPay;
    final todayToPay = math.min(remainingAfterOverdue, dueTodayCount);
    final remainingAfterToday = remainingAfterOverdue - todayToPay;
    final advanceToPay = remainingAfterToday;

    final hasOverdue = overdueToPay > 0;
    final hasToday = todayToPay > 0;
    final hasAdvance = advanceToPay > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Breakdown',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _textTertiary(),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        if (hasOverdue)
          _buildBreakdownRow(
            icon: Icons.warning_amber_rounded,
            color: _errorColor(),
            label: 'Overdue Installments',
            count: overdueToPay,
          ),
        if (hasToday)
          _buildBreakdownRow(
            icon: Icons.schedule_rounded,
            color: AppColors.orange,
            label: 'Today\'s Installment',
            count: todayToPay,
          ),
        if (hasAdvance)
          _buildBreakdownRow(
            icon: Icons.fast_forward_rounded,
            color: _primaryColor(),
            label: 'Advance Installments',
            count: advanceToPay,
          ),
        if (!hasOverdue && !hasToday && !hasAdvance)
          Text(
            'No unpaid installments remaining',
            style: TextStyle(
              fontSize: 12,
              color: _textTertiary(),
            ),
          ),
      ],
    );
  }

  Widget _buildBreakdownRow({
    required IconData icon,
    required Color color,
    required String label,
    required int count,
  }) {
    final currencyFormat =
        NumberFormat.currency(symbol: '\u20b9', decimalDigits: 0);
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _fillColor(),
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: color, width: 3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary(),
                    ),
                  ),
                  Text(
                    '$count \u00d7 ${currencyFormat.format(widget.installmentAmount)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _textTertiary(),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              currencyFormat.format(count * widget.installmentAmount),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _textPrimary(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Custom Tab (Calendar) --------------------------------------------

  Widget _buildCustomTab() {
    return GestureDetector(
      onTap: () => _showCalendarPopup(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isDark
                ? [
                    _primaryColor().withValues(alpha: 0.08),
                    _primaryColor().withValues(alpha: 0.03),
                  ]
                : [
                    _primaryColor().withValues(alpha: 0.06),
                    _primaryColor().withValues(alpha: 0.02),
                  ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _primaryColor().withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: _primaryColor().withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Calendar icon
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _primaryColor(),
                      _primaryColor().withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor().withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose Specific Dates',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: _textPrimary(),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Pick exact installment dates from the calendar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _textTertiary(),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _fillColor(),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: _textSecondary(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Total Section ----------------------------------------------------

  Widget _buildTotalSection(int selectedCount) {
    final hasSelection = selectedCount > 0;
    final total = selectedCount * widget.installmentAmount;
    final currencyFormat =
        NumberFormat.currency(symbol: '\u20b9', decimalDigits: 0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: hasSelection
            ? LinearGradient(colors: [
                _successColor().withValues(alpha: 0.12),
                _successColor().withValues(alpha: 0.04),
              ])
            : LinearGradient(colors: [
                _fillColor(),
                _fillColor(),
              ]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasSelection
              ? _successColor().withValues(alpha: 0.25)
              : _borderColor().withValues(alpha: 0.5),
        ),
        boxShadow: hasSelection
            ? [
                BoxShadow(
                  color: _successColor().withValues(alpha: 0.15),
                  blurRadius: 16,
                  spreadRadius: -4,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Gradient circle with animated icon
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: hasSelection
                  ? LinearGradient(colors: [
                      _successColor(),
                      _successColor().withValues(alpha: 0.7),
                    ])
                  : null,
              color: hasSelection ? null : _borderColor().withValues(alpha: 0.3),
              boxShadow: hasSelection
                  ? [
                      BoxShadow(
                        color: _successColor().withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              hasSelection ? Icons.check_rounded : Icons.touch_app_rounded,
              size: 20,
              color: hasSelection ? Colors.white : _textTertiary(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasSelection
                      ? '$selectedCount installment${selectedCount > 1 ? 's' : ''} selected'
                      : 'Select installment(s) to pay',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: hasSelection ? _textPrimary() : _textTertiary(),
                  ),
                ),
                if (hasSelection) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$selectedCount \u00d7 ${currencyFormat.format(widget.installmentAmount)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _textTertiary(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Animated total amount
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: child,
            ),
            child: Text(
              currencyFormat.format(total),
              key: ValueKey(total.toStringAsFixed(0)),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                color: hasSelection ? _successColor() : _textTertiary(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -- Status summary ---------------------------------------------------

  Widget _buildStatusSummary(
      int unpaid, int overdue, int dueToday, int paid) {
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
            Text(
              '$overdue overdue',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _errorColor(),
              ),
            ),
            const SizedBox(width: 12),
          ],
          if (dueToday > 0) ...[
            const Icon(Icons.schedule_rounded,
                size: 14, color: AppColors.orange),
            const SizedBox(width: 4),
            Text(
              '$dueToday due today',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.orange,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Text(
            '$unpaid unpaid',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textSecondary(),
            ),
          ),
          const Spacer(),
          Text(
            '$paid paid',
            style: TextStyle(
              fontSize: 12,
              color: _textTertiary(),
            ),
          ),
        ],
      ),
    );
  }

  // -- Calendar Popup ---------------------------------------------------

  void _showCalendarPopup(BuildContext context) {
    final tempSelected = Set<String>.from(_selectedIds);

    DateTime focusedDay = DateTime.now();
    if (tempSelected.isNotEmpty) {
      focusedDay = _dateFromKey(tempSelected.first);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setPopupState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: _isDark ? 0.5 : 0.12),
                    blurRadius: 32,
                    spreadRadius: -8,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: _isDark
                            ? [
                                Colors.white.withValues(alpha: 0.08),
                                Colors.white.withValues(alpha: 0.03),
                              ]
                            : [
                                Colors.white.withValues(alpha: 0.92),
                                Colors.white.withValues(alpha: 0.80),
                              ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32)),
                      border: Border.all(
                        color: Colors.white
                            .withValues(alpha: _isDark ? 0.10 : 0.4),
                        width: 1,
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // -- Gradient accent bar --
                          Container(
                            height: 4,
                            margin: const EdgeInsets.only(top: 12),
                            width: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: const LinearGradient(
                                  colors: [AppColors.primary, AppColors.accent]),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // -- Header --
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              children: [
                                // Gradient calendar icon
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [AppColors.primary, AppColors.accent],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.25),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.calendar_month_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Select Payment Dates',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                          color: _textPrimary(),
                                        ),
                                      ),
                                      if (tempSelected.isNotEmpty)
                                        Text(
                                          '${tempSelected.length} date${tempSelected.length > 1 ? 's' : ''} selected',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _primaryColor(),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Clear all button
                                if (tempSelected.isNotEmpty)
                                  GestureDetector(
                                    onTap: () =>
                                        setPopupState(() => tempSelected.clear()),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: [
                                          _errorColor().withValues(alpha: 0.12),
                                          _errorColor().withValues(alpha: 0.06),
                                        ]),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: _errorColor().withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.close_rounded,
                                              size: 13, color: _errorColor()),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Clear',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: _errorColor(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // -- Selected dates chips --
                          if (tempSelected.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: SizedBox(
                                height: 36,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: tempSelected.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (_, i) {
                                    final dateKey = tempSelected.elementAt(i);
                                    final date = _dateFromKey(dateKey);
                                    final installmentsOnDate = _eventsForDay(date);
                                    final dateStr =
                                        DateFormat('dd MMM').format(date);
                                    return AnimatedSlide(
                                      offset: const Offset(0.2, 0),
                                      duration: Duration(
                                          milliseconds: 250 + (i * 50)),
                                      curve: Curves.easeOutCubic,
                                      child: AnimatedOpacity(
                                        opacity: 1.0,
                                        duration: Duration(
                                            milliseconds: 250 + (i * 50)),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(colors: [
                                              AppColors.primary,
                                              AppColors.accent,
                                            ]),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.circle_rounded,
                                                  size: 6,
                                                  color: Colors.white.withValues(alpha: 0.7)),
                                              const SizedBox(width: 6),
                                              Text(
                                                dateStr,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                  letterSpacing: -0.2,
                                                ),
                                              ),
                                              if (installmentsOnDate.length > 1) ...[
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withValues(alpha: 0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    '${installmentsOnDate.length}',
                                                    style: const TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w800,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(width: 6),
                                              GestureDetector(
                                                onTap: () =>
                                                    setPopupState(() {
                                                  tempSelected.remove(dateKey);
                                                }),
                                                child: Container(
                                                  width: 18,
                                                  height: 18,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.white
                                                        .withValues(alpha: 0.2),
                                                  ),
                                                  child: const Icon(
                                                    Icons.close_rounded,
                                                    size: 11,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                          if (tempSelected.isNotEmpty)
                            const SizedBox(height: 12),

                          // -- Calendar --
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
                              enabledDayPredicate: (day) {
                                final installments = _eventsForDay(day);
                                return installments.any(_isSelectable);
                              },
                              selectedDayPredicate: (day) {
                                final dateKey = _dateKey(day);
                                return tempSelected.contains(dateKey);
                              },
                              onDaySelected: (selectedDay, newFocusedDay) {
                                final dateKey = _dateKey(selectedDay);
                                setPopupState(() {
                                  focusedDay = newFocusedDay;
                                  if (tempSelected.contains(dateKey)) {
                                    tempSelected.remove(dateKey);
                                  } else {
                                    // Only add if this day has unpaid installments
                                    final installments = _eventsForDay(selectedDay);
                                    if (installments.any(_isSelectable)) {
                                      tempSelected.add(dateKey);
                                    }
                                  }
                                });
                              },
                              onPageChanged: (newFocusedDay) =>
                                  focusedDay = newFocusedDay,
                              eventLoader: _eventsForDay,
                              calendarStyle: CalendarStyle(
                                outsideDaysVisible: false,
                                cellMargin: const EdgeInsets.all(4),
                                todayDecoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _primaryColor().withValues(alpha: 0.6),
                                    width: 1.5,
                                  ),
                                ),
                                todayTextStyle: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: _primaryColor(),
                                ),
                                selectedDecoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(colors: [
                                    AppColors.primary,
                                    AppColors.accent,
                                  ]),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                selectedTextStyle: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                                defaultTextStyle: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _textPrimary(),
                                ),
                                disabledTextStyle: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor:
                                      _textTertiary().withValues(alpha: 0.3),
                                  color: _textTertiary().withValues(alpha: 0.3),
                                ),
                                weekendTextStyle: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _textSecondary(),
                                ),
                                markerDecoration: const BoxDecoration(),
                                markersMaxCount: 0,
                              ),
                              calendarBuilders: CalendarBuilders(
                                markerBuilder: (context, day, events) {
                                  if (events.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  final installments =
                                      events.cast<SavingsInstallment>();
                                  return _buildPopupDayMarker(installments);
                                },
                                defaultBuilder: (context, day, focusedDay) {
                                  final events = _eventsForDay(day);
                                  if (events.isEmpty) return null;
                                  final hasOverdue =
                                      events.any((e) => _isOverdue(e) && _isSelectable(e));
                                  if (!hasOverdue) return null;
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: [
                                        _errorColor().withValues(alpha: 0.12),
                                        _errorColor().withValues(alpha: 0.06),
                                      ]),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: _errorColor().withValues(alpha: 0.2),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${day.day}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _errorColor(),
                                      ),
                                    ),
                                  );
                                },
                                disabledBuilder: (context, day, focusedDay) {
                                  return Center(
                                    child: Text(
                                      '${day.day}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        decoration: TextDecoration.lineThrough,
                                        decorationColor:
                                            _textTertiary().withValues(alpha: 0.25),
                                        color: _textTertiary().withValues(alpha: 0.3),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              headerStyle: HeaderStyle(
                                titleCentered: true,
                                headerPadding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                titleTextStyle: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: _textPrimary(),
                                  letterSpacing: -0.5,
                                ),
                                leftChevronIcon: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _fillColor(),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.chevron_left_rounded,
                                    size: 20,
                                    color: _textSecondary(),
                                  ),
                                ),
                                rightChevronIcon: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _fillColor(),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: _textSecondary(),
                                  ),
                                ),
                                formatButtonVisible: false,
                              ),
                            ),
                          ),

                          // -- Legend --
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: _isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.black.withValues(alpha: 0.025),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _borderColor().withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildLegendDot(_errorColor(), 'Overdue'),
                                  _buildLegendDot(AppColors.orange, 'Due Today'),
                                  _buildLegendDot(_primaryColor(), 'Upcoming'),
                                  _buildLegendDot(_successColor(), 'Paid'),
                                ],
                              ),
                            ),
                          ),

                          // -- Done Button --
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                                24,
                                16,
                                24,
                                MediaQuery.of(context).padding.bottom + 16),
                            child: SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: () {
                                  final newIds = <String>{};
                                  for (final dateKey in tempSelected) {
                                    final date = _dateFromKey(dateKey);
                                    final installments = _eventsForDay(date);
                                    for (final installment in installments) {
                                      if (_isSelectable(installment)) {
                                        newIds.add(_dateKey(installment.dueDate));
                                      }
                                    }
                                  }
                                  setState(() {
                                    _selectedIds
                                      ..clear()
                                      ..addAll(newIds);
                                    // Sync installment count to match
                                    _installmentCount = newIds.length;
                                  });
                                  widget.onSelectionChanged
                                      ?.call(selectedInstallments);
                                  Navigator.pop(ctx);
                                  HapticFeedback.selectionClick();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppColors.primary,
                                        AppColors.accent,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 20,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          tempSelected.isEmpty
                                              ? 'Done'
                                              : 'Done (${tempSelected.length} date${tempSelected.length > 1 ? 's' : ''})',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.3,
                                          ),
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
            );
          },
        );
      },
    );
  }

  Widget _buildPopupDayMarker(List<SavingsInstallment> installments) {
    final hasOverdue =
        installments.any((e) => _isOverdue(e) && _isSelectable(e));
    final hasDueToday =
        installments.any((e) => _isDueToday(e) && _isSelectable(e));
    final allPaid = installments.every((e) => !_isSelectable(e));

    Color dotColor;
    if (hasOverdue) {
      dotColor = _errorColor();
    } else if (hasDueToday) {
      dotColor = AppColors.orange;
    } else if (allPaid) {
      dotColor = _successColor();
    } else {
      dotColor = _primaryColor();
    }

    final count = math.min(installments.length, 3);

    return Positioned(
      bottom: 2,
      child: Container(
        padding: hasOverdue ? const EdgeInsets.all(1.5) : EdgeInsets.zero,
        decoration: hasOverdue
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: dotColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(count, (i) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 0.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [
                  dotColor,
                  dotColor.withValues(alpha: 0.7),
                ]),
                boxShadow: [
                  BoxShadow(
                    color: dotColor.withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _textTertiary(),
          ),
        ),
      ],
    );
  }
}
