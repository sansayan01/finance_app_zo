import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/enums.dart';
import '../../data/models/emi_schedule_model.dart';

/// Premium EMI list selector with a "Choose Dates" button that opens a
/// calendar popup for multi-date selection. Full dark-mode support.
///
/// Two ways to select EMIs:
/// 1. Tap "Choose Dates" → calendar popup → tap dates → Done
/// 2. Tap individual EMI rows directly
class EmiPaymentSelector extends StatefulWidget {
  final List<EMIScheduleModel> emis;
  final double emiAmount;
  final ValueChanged<List<EMIScheduleModel>>? onSelectionChanged;
  final List<String> initialSelectedIds;
  final bool multiSelect;

  const EmiPaymentSelector({
    super.key,
    required this.emis,
    required this.emiAmount,
    this.onSelectionChanged,
    this.initialSelectedIds = const [],
    this.multiSelect = true,
  });

  @override
  State<EmiPaymentSelector> createState() => _EmiPaymentSelectorState();
}

class _EmiPaymentSelectorState extends State<EmiPaymentSelector>
    with SingleTickerProviderStateMixin {
  late final Set<String> _selectedIds;
  late Map<DateTime, List<EMIScheduleModel>> _emiEvents;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<String>.from(widget.initialSelectedIds);
    _emiEvents = _buildEventMap();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EmiPaymentSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSelectedIds != widget.initialSelectedIds) {
      _selectedIds
        ..clear()
        ..addAll(widget.initialSelectedIds);
    }
    if (oldWidget.emis != widget.emis) {
      _emiEvents = _buildEventMap();
    }
  }

  // -- Helpers ----------------------------------------------------------

  Map<DateTime, List<EMIScheduleModel>> _buildEventMap() {
    final map = <DateTime, List<EMIScheduleModel>>{};
    for (final emi in widget.emis) {
      final dateOnly =
          DateTime(emi.dueDate.year, emi.dueDate.month, emi.dueDate.day);
      map.putIfAbsent(dateOnly, () => []).add(emi);
    }
    return map;
  }

  List<EMIScheduleModel> _eventsForDay(DateTime day) =>
      _emiEvents[DateTime(day.year, day.month, day.day)] ?? [];

  bool _isSelectable(EMIScheduleModel emi) =>
      emi.status != EMIStatus.paid && emi.status != EMIStatus.waived;

  List<EMIScheduleModel> get selectedEmis => widget.emis
      .where((e) => _selectedIds.contains(e.id))
      .toList(growable: false);

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  // -- Theme helpers ---------------------------------------------------

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
    final currencyFormat =
        NumberFormat.currency(symbol: '\u20b9', decimalDigits: 0);

    final unpaidEMIs = widget.emis
        .where((e) =>
            e.status != EMIStatus.paid && e.status != EMIStatus.waived)
        .toList()
      ..sort((a, b) => a.emiNumber.compareTo(b.emiNumber));

    final overdueCount = unpaidEMIs.where((e) => e.isOverdue).length;
    final dueTodayCount = unpaidEMIs.where((e) => e.isDueToday).length;
    final paidCount = widget.emis.length - unpaidEMIs.length;

    final selectedCount = _selectedIds.length;
    final totalToPay = selectedCount * widget.emiAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Header with Choose Dates button ──
        _buildHeader(unpaidEMIs.length),
        const SizedBox(height: 14),

        // ── Status summary ──
        _buildStatusSummary(
            unpaidEMIs.length, overdueCount, dueTodayCount, paidCount),
        const SizedBox(height: 12),

        // ── Total to Pay ──
        _buildTotalSection(selectedCount, totalToPay, currencyFormat),
      ],
    );
  }


  // ── Header ──────────────────────────────────────────────────────────

  Widget _buildHeader(int unpaidCount) {
    return Row(
      children: [
        // Title
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EMI Schedule',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: _textPrimary(),
                ),
              ),
              if (_selectedIds.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  '${_selectedIds.length} selected',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _successColor(),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Choose Dates button
        if (widget.multiSelect)
          GestureDetector(
            onTap: () => _showCalendarPopup(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _primaryColor(),
                    _primaryColor().withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor().withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month_rounded,
                      size: 15, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Choose Dates',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Calendar Popup ──────────────────────────────────────────────────

  void _showCalendarPopup(BuildContext context) {
    // Dates currently selected in the calendar (temp state for the popup)
    final tempSelected = Set<DateTime>.from(
      _selectedIds.expand((id) {
        final emi = widget.emis.firstWhere(
          (e) => e.id == id,
          orElse: () => widget.emis.first,
        );
        return [
          DateTime(emi.dueDate.year, emi.dueDate.month, emi.dueDate.day)
        ];
      }),
    );

    DateTime focusedDay = DateTime.now();

    // Focus on first selected date
    if (tempSelected.isNotEmpty) {
      focusedDay = tempSelected.first;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setPopupState) {
            return SafeArea(
              child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: _cardColor(),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: _isDark ? 0.4 : 0.1),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        color: _borderColor(),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month_rounded,
                            size: 20, color: _primaryColor()),
                        const SizedBox(width: 8),
                        Text(
                          'Select Payment Dates',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary(),
                          ),
                        ),
                        const Spacer(),
                        if (tempSelected.isNotEmpty)
                          GestureDetector(
                            onTap: () => setPopupState(
                                () => tempSelected.clear()),
                            child: Text(
                              'Clear all',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _errorColor(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Selected dates chips
                  if (tempSelected.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: SizedBox(
                        height: 32,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: tempSelected.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final date = tempSelected.elementAt(i);
                            final emisOnDate = _eventsForDay(date);
                            final dateStr =
                                DateFormat('dd MMM').format(date);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _primaryColor(),
                                    _primaryColor()
                                        .withValues(alpha: 0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    dateStr,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (emisOnDate.length > 1) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '(${emisOnDate.length})',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white
                                            .withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () =>
                                        setPopupState(() {
                                      // Remove this date and all its EMIs
                                      for (final emi in emisOnDate) {
                                        final emiDate = DateTime(
                                          emi.dueDate.year,
                                          emi.dueDate.month,
                                          emi.dueDate.day,
                                        );
                                        tempSelected.remove(emiDate);
                                      }
                                    }),
                                    child: Icon(Icons.close_rounded,
                                        size: 14,
                                        color: Colors.white
                                            .withValues(alpha: 0.8)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),

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
                      enabledDayPredicate: (day) {
                        // Only enable days that have unpaid EMIs
                        final emis = _eventsForDay(day);
                        return emis.any(_isSelectable);
                      },
                      selectedDayPredicate: (day) {
                        final dateOnly =
                            DateTime(day.year, day.month, day.day);
                        return tempSelected.contains(dateOnly);
                      },
                      onDaySelected: (selectedDay, newFocusedDay) {
                        final dateOnly = DateTime(
                          selectedDay.year,
                          selectedDay.month,
                          selectedDay.day,
                        );
                        setPopupState(() {
                          focusedDay = newFocusedDay;
                          if (tempSelected.contains(dateOnly)) {
                            tempSelected.remove(dateOnly);
                          } else {
                            tempSelected.add(dateOnly);
                          }
                        });
                      },
                      onPageChanged: (newFocusedDay) {
                        focusedDay = newFocusedDay;
                      },
                      eventLoader: _eventsForDay,
                      calendarStyle: CalendarStyle(
                        outsideDaysVisible: false,
                        cellMargin: const EdgeInsets.all(3),
                        todayDecoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _primaryColor().withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        todayTextStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _primaryColor(),
                        ),
                        selectedDecoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              _primaryColor(),
                              _primaryColor().withValues(alpha: 0.7),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  _primaryColor().withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        selectedTextStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                        defaultTextStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _textPrimary(),
                        ),
                        disabledTextStyle: TextStyle(
                          fontSize: 13,
                          color: _textTertiary().withValues(alpha: 0.3),
                        ),
                        weekendTextStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
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
                          final emis = events.cast<EMIScheduleModel>();
                          return _buildPopupDayMarker(emis);
                        },
                        defaultBuilder: (context, day, focusedDay) {
                          final events = _eventsForDay(day);
                          if (events.isEmpty) return null;
                          final hasOverdue = events
                              .any((e) => e.isOverdue && _isSelectable(e));
                          if (!hasOverdue) return null;
                          return Container(
                            decoration: BoxDecoration(
                              color: _errorColor().withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
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
                                color: _textTertiary().withValues(alpha: 0.3),
                              ),
                            ),
                          );
                        },
                      ),
                      headerStyle: HeaderStyle(
                        titleCentered: true,
                        headerPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                        titleTextStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary(),
                          letterSpacing: -0.3,
                        ),
                        leftChevronIcon: Icon(
                          Icons.chevron_left_rounded,
                          size: 22,
                          color: _textSecondary(),
                        ),
                        rightChevronIcon: Icon(
                          Icons.chevron_right_rounded,
                          size: 22,
                          color: _textSecondary(),
                        ),
                        formatButtonVisible: false,
                      ),
                    ),
                  ),

                  // Legend
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        _buildLegendDot(_errorColor(), 'Overdue'),
                        const SizedBox(width: 14),
                        _buildLegendDot(AppColors.orange, 'Due Today'),
                        const SizedBox(width: 14),
                        _buildLegendDot(_primaryColor(), 'Upcoming'),
                        const SizedBox(width: 14),
                        _buildLegendDot(_successColor(), 'Paid'),
                      ],
                    ),
                  ),

                  // Done button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          // Apply the calendar selections back to the main widget
                          final newIds = <String>{};
                          for (final date in tempSelected) {
                            final emis = _eventsForDay(date);
                            for (final emi in emis) {
                              if (_isSelectable(emi)) {
                                newIds.add(emi.id);
                              }
                            }
                          }
                          setState(() {
                            _selectedIds
                              ..clear()
                              ..addAll(newIds);
                          });
                          widget.onSelectionChanged
                              ?.call(selectedEmis);
                          Navigator.pop(ctx);
                          HapticFeedback.selectionClick();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor(),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          tempSelected.isEmpty
                              ? 'Done'
                              : 'Done (${tempSelected.length} date${tempSelected.length > 1 ? 's' : ''})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
  }

  Widget _buildPopupDayMarker(List<EMIScheduleModel> emis) {
    final hasOverdue = emis.any((e) => e.isOverdue && _isSelectable(e));
    final hasDueToday = emis.any((e) => e.isDueToday && _isSelectable(e));
    final allPaid = emis.every((e) => !_isSelectable(e));

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

    final count = math.min(emis.length, 3);

    return Positioned(
      bottom: 2,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (i) {
          return Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 0.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
              boxShadow: [
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.4),
                  blurRadius: 3,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: _textTertiary(),
          ),
        ),
      ],
    );
  }

  // ── Status summary ─────────────────────────────────────────────────

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
            Icon(Icons.warning_amber_rounded,
                size: 14, color: _errorColor()),
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

  // ── Total section ──────────────────────────────────────────────────

  Widget _buildTotalSection(
      int selectedCount, double total, NumberFormat currencyFormat) {
    final hasSelection = selectedCount > 0;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) => Transform.scale(
        scale: _pulseAnimation.value,
        child: child,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: hasSelection
              ? LinearGradient(colors: [
                  _successColor().withValues(alpha: 0.1),
                  _successColor().withValues(alpha: 0.04),
                ])
              : null,
          color: hasSelection ? null : _fillColor(),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasSelection
                ? _successColor().withValues(alpha: 0.25)
                : _borderColor().withValues(alpha: 0.5),
          ),
          boxShadow: hasSelection
              ? [
                  BoxShadow(
                    color: _successColor().withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Animated icon
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 300),
              tween: Tween(begin: 0.0, end: hasSelection ? 1.0 : 0.0),
              builder: (context, value, child) => Transform.scale(
                scale: 0.8 + (value * 0.2),
                child: child,
              ),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: hasSelection
                      ? LinearGradient(colors: [
                          _successColor(),
                          _successColor().withValues(alpha: 0.7),
                        ])
                      : null,
                  color:
                      hasSelection ? null : _borderColor().withValues(alpha: 0.3),
                ),
                child: Icon(
                  hasSelection ? Icons.check_rounded : Icons.touch_app_rounded,
                  size: 18,
                  color: hasSelection ? Colors.white : _textTertiary(),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasSelection
                        ? '$selectedCount EMI${selectedCount > 1 ? 's' : ''} selected'
                        : 'Select EMI(s) to pay',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: hasSelection ? _textPrimary() : _textTertiary(),
                    ),
                  ),
                  if (hasSelection) ...[
                    const SizedBox(height: 2),
                    Text(
                      '$selectedCount \u00d7 ${currencyFormat.format(widget.emiAmount)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: _textTertiary(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              currencyFormat.format(total),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: hasSelection ? _successColor() : _textTertiary(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// EMI Row (private)
