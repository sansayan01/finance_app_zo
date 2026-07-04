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
  final VoidCallback? onFreezeSkipped;
  final List<String> initialSelectedDateKeys;

  const SavingsPaymentSelector({
    super.key,
    required this.installments,
    required this.installmentAmount,
    required this.totalInstallments,
    this.onSelectionChanged,
    this.onFreezeSkipped,
    this.initialSelectedDateKeys = const [],
  });

  @override
  State<SavingsPaymentSelector> createState() => _SavingsPaymentSelectorState();
}

class _SavingsPaymentSelectorState extends State<SavingsPaymentSelector> {
  late final Set<String> _selectedIds;
  late Map<DateTime, List<SavingsInstallment>> _installmentEvents;

  // Quick Pay state
  int _installmentCount = 1;
  late final TextEditingController _countController;
  late final FocusNode _countFocusNode;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<String>.from(widget.initialSelectedDateKeys);
    _installmentEvents = _buildEventMap();
    _countController = TextEditingController(text: '$_installmentCount');
    _countFocusNode = FocusNode()
      ..addListener(() {
        if (!_countFocusNode.hasFocus && _countController.text.isEmpty) {
          _countController.text = '$_installmentCount';
        }
        if (mounted) {
          setState(() {});
        }
      });

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
    _countController.dispose();
    _countFocusNode.dispose();
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
    if (installment.isFrozen) return false;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dueOnly = DateTime(
        installment.dueDate.year, installment.dueDate.month, installment.dueDate.day);
    return dueOnly.isBefore(todayOnly) && !installment.isPaid;
  }

  /// Whether a given installment is due today and unpaid.
  bool _isDueToday(SavingsInstallment installment) {
    if (installment.isFrozen) return false;
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

  bool _isSelectable(SavingsInstallment installment) =>
      !installment.isPaid && !installment.isFrozen;

  /// Sorted unpaid installments for allocation (oldest first).
  List<SavingsInstallment> get _unpaidInstallments => widget.installments
      .where(_isSelectable)
      .toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  List<SavingsInstallment> get selectedInstallments => widget.installments
      .where((e) => _selectedIds.contains(_dateKey(e.dueDate)))
      .toList(growable: false);

  /// Checks if there are unpaid installments between min and max paid that can be frozen.
  bool _hasFreezableSkipped() {
    final paidNumbers = widget.installments
        .where((e) => e.isPaid)
        .map((e) => e.number)
        .toList();
    if (paidNumbers.length < 2) return false;
    final minPaid = paidNumbers.reduce((a, b) => a < b ? a : b);
    final maxPaid = paidNumbers.reduce((a, b) => a > b ? a : b);
    return widget.installments.any((e) =>
        e.number > minPaid &&
        e.number < maxPaid &&
        !e.isPaid &&
        !e.isFrozen);
  }

  // -- Quick Pay allocation (oldest-first) ------------------------------

  void _applyQuickPay(int count) {
    final unpaid = _unpaidInstallments;
    final take = math.min(count, unpaid.length);
    final selected = unpaid.take(take).toList();
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(selected.map((e) => _dateKey(e.dueDate)));
      _installmentCount = take;
      _countController.text = '$take';
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
    final paidCount = widget.installments.where((e) => e.isPaid).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // -- Header --
        _buildCompactHeader(unpaidInstallments.length),

        const SizedBox(height: 14),

        // -- Status summary --
        _buildStatusSummary(
            unpaidInstallments.length, overdueCount, dueTodayCount, paidCount),

        // -- Freeze skipped button --
        if (widget.onFreezeSkipped != null && _hasFreezableSkipped()) ...[
          const SizedBox(height: 10),
          _buildFreezeSkippedButton(),
        ],

        const SizedBox(height: 14),

        // -- Tab Bar: Quick Pay header + Calendar icon --
        _buildTabBar(),

        const SizedBox(height: 14),

        // -- Quick Pay Content --
        _buildQuickPayTab(overdueCount, dueTodayCount, unpaidInstallments.length),
      ],
    );
  }

  // -- Header (compact, matches EMI selector) -----------------------------

  Widget _buildCompactHeader(int unpaidCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_selectedIds.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_successColor(), _successColor().withValues(alpha: 0.7)]),
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
    );
  }

  Widget _buildFreezeSkippedButton() {
    return GestureDetector(
      onTap: widget.onFreezeSkipped,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.cyan.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.ac_unit_rounded, size: 16, color: Colors.cyan),
            SizedBox(width: 8),
            Text(
              'Freeze Skipped Dates',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.cyan,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Tab Bar -----------------------------------------------------------

  Widget _buildTabBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
      child: Row(
        children: [
          Icon(Icons.bolt_rounded, size: 18, color: _primaryColor()),
          const SizedBox(width: 8),
          Text(
            'Quick Pay',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _textPrimary(),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _showCalendarPopup(context),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _primaryColor().withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.calendar_month_rounded, size: 18, color: _primaryColor()),
            ),
          ),
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
          // Installment counter
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  const SizedBox(width: 16),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _cardColor(),
                      border: Border.all(
                        color: _primaryColor().withValues(alpha: 0.2),
                        width: 2.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor().withValues(alpha: 0.18),
                          blurRadius: 24,
                          spreadRadius: -2,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          IgnorePointer(
                            ignoring: !_countFocusNode.hasFocus,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: _countFocusNode.hasFocus ? 1.0 : 0.0,
                              child: TextField(
                                controller: _countController,
                                focusNode: _countFocusNode,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.5,
                                  color: _primaryColor().withValues(alpha: 0.85),
                                  height: 1,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                  fillColor: Colors.transparent,
                                ),
                                onChanged: (value) {
                                  if (value.isEmpty) return;
                                  final count = int.tryParse(value);
                                  if (count != null && count > 0) {
                                    _applyQuickPay(count);
                                  }
                                },
                                onTap: () {
                                  _countController.selection = TextSelection(
                                    baseOffset: 0,
                                    extentOffset: _countController.text.length,
                                  );
                                },
                                onSubmitted: (value) {
                                  final count = int.tryParse(value) ?? _installmentCount;
                                  _applyQuickPay(count);
                                  _countFocusNode.unfocus();
                                },
                              ),
                            ),
                          ),
                          if (!_countFocusNode.hasFocus)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                _countFocusNode.requestFocus();
                              },
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  transitionBuilder: (Widget child, Animation<double> animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: ScaleTransition(
                                        scale: animation,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Text(
                                    '$_installmentCount',
                                    key: ValueKey<int>(_installmentCount),
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1.5,
                                      color: _primaryColor().withValues(alpha: 0.85),
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
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
  final isPlus = icon == Icons.add_rounded;
  return GestureDetector(
    onTap: enabled ? onTap : null,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: enabled
            ? LinearGradient(
                colors: isPlus
                    ? [
                        _primaryColor(),
                        _primaryColor().withValues(alpha: 0.85),
                      ]
                    : [
                        _primaryColor().withValues(alpha: 0.2),
                        _primaryColor().withValues(alpha: 0.12),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: enabled ? null : _fillColor(),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: enabled
              ? _primaryColor().withValues(alpha: 0.4)
              : _borderColor().withValues(alpha: 0.2),
          width: 1.2,
        ),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: _primaryColor().withValues(alpha: isPlus ? 0.45 : 0.18),
                  blurRadius: isPlus ? 24 : 12,
                  offset: Offset(0, isPlus ? 8 : 4),
                  spreadRadius: isPlus ? 2 : 0,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 200),
        child: Icon(
          icon,
          size: 28,
          color: enabled
              ? isPlus
                  ? Colors.white
                  : _primaryColor().withValues(alpha: 0.8)
              : _textTertiary(),
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

  // -- Status summary ---------------------------------------------------

  Widget _buildStatusSummary(
      int unpaid, int overdue, int dueToday, int paid) {
    final frozenCount =
        widget.installments.where((e) => e.isFrozen && !e.isPaid).length;
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
          if (frozenCount > 0) ...[
            const SizedBox(width: 12),
            const Icon(Icons.ac_unit_rounded, size: 14, color: Colors.cyan),
            const SizedBox(width: 4),
            Text(
              '$frozenCount frozen',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.cyan,
              ),
            ),
          ],
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
                                // Today button - jump to today's date
                                if (tempSelected.isNotEmpty)
                                  const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setPopupState(() {
                                      focusedDay = DateTime.now();
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: [
                                        _primaryColor().withValues(alpha: 0.12),
                                        _primaryColor().withValues(alpha: 0.06),
                                      ]),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _primaryColor()
                                            .withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.today_rounded,
                                            size: 13,
                                            color: _primaryColor()),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Today',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: _primaryColor(),
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
                                  final hasFrozen = events
                                      .any((e) => e.isFrozen);
                                  if (hasFrozen) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.grey.withValues(alpha: 0.25),
                                          width: 1,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${day.day}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _textTertiary(),
                                          decoration: TextDecoration.lineThrough,
                                          decorationColor: Colors.grey,
                                        ),
                                      ),
                                    );
                                  }
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
                                MediaQuery.of(context).padding.bottom + 80),
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
                                    _countController.text = '${newIds.length}';
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
    final hasFrozen = installments.any((e) => e.isFrozen);
    final hasOverdue =
        installments.any((e) => _isOverdue(e) && _isSelectable(e));
    final hasDueToday =
        installments.any((e) => _isDueToday(e) && _isSelectable(e));
    final allPaid = installments.every((e) => !_isSelectable(e) && !e.isFrozen);

    Color dotColor;
    if (hasFrozen) {
      dotColor = Colors.cyan;
    } else if (hasOverdue) {
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
