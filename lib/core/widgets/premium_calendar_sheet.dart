import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../constants/app_colors.dart';

/// A super-premium calendar bottom sheet that replaces the basic [showDatePicker].
class PremiumCalendarSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onDateSelected;

  const PremiumCalendarSheet({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onDateSelected,
  });

  static Future<DateTime?> show({
    required BuildContext context,
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    HapticFeedback.lightImpact();
    final first = firstDate ?? DateTime(2020);
    final last = lastDate ?? DateTime(2030);
    final completer = Completer<DateTime?>();
    showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return _PremiumCalendarStatefulWrapper(
          initialDate: initialDate,
          firstDate: first,
          lastDate: last,
          onDateSelected: (date) {
            completer.complete(date);
            Navigator.of(ctx).pop();
          },
        );
      },
    );
    return completer.future;
  }

  @override
  State<PremiumCalendarSheet> createState() => _PremiumCalendarSheetState();
}

class _PremiumCalendarSheetState extends State<PremiumCalendarSheet> {
  late DateTime _selectedDate;
  late DateTime _focusedDay;
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _focusedDay = widget.initialDate;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isDark = Theme.of(context).brightness == Brightness.dark;
  }

  void _selectDate(DateTime date) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day);
    });
  }

  void _applyDate() {
    HapticFeedback.heavyImpact();
    widget.onDateSelected(_selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.88;
    _isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final isToday = _sameDay(_selectedDate, DateTime.now());
    final todayFormatted = dateFormat.format(_selectedDate);

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.6 : 0.15),
            blurRadius: 40,
            spreadRadius: -10,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _isDark
                    ? [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.04), Colors.white.withValues(alpha: 0.02)]
                    : [Colors.white.withValues(alpha: 0.97), Colors.white.withValues(alpha: 0.93), Colors.white.withValues(alpha: 0.88)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
              border: Border.all(
                color: Colors.white.withValues(alpha: _isDark ? 0.08 : 0.5),
                width: 1,
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle + Gradient Accent Bar
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      children: [
                        Container(
                          width: 40, height: 5,
                          decoration: BoxDecoration(
                            color: _isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 4, width: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, curve: Curves.easeOutCubic),

                  const SizedBox(height: 20),

                  // Header: Icon + Title + Selected Date
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Row(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6)),
                              BoxShadow(color: AppColors.accent.withValues(alpha: 0.15), blurRadius: 24, spreadRadius: -4, offset: const Offset(0, 8)),
                            ],
                          ),
                          child: const Icon(Icons.calendar_month_rounded, size: 24, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isToday ? 'Today' : 'Select Date',
                                style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.6,
                                  color: _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(todayFormatted, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: _isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.close_rounded, size: 18, color: _isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 350.ms, delay: 50.ms).slideY(begin: -0.15, curve: Curves.easeOutCubic),

                  const SizedBox(height: 24),

                  // Quick Date Shortcuts
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Row(
                      children: [
                        _QuickDateChip(label: 'Today', icon: Icons.today_rounded, selected: _sameDay(_selectedDate, DateTime.now()), isDark: _isDark, onTap: () => _selectDate(DateTime.now())),
                        const SizedBox(width: 10),
                        _QuickDateChip(label: 'Yesterday', icon: Icons.chevron_left_rounded, selected: _sameDay(_selectedDate, DateTime.now().subtract(const Duration(days: 1))), isDark: _isDark, onTap: () => _selectDate(DateTime.now().subtract(const Duration(days: 1)))),
                        const SizedBox(width: 10),
                        _QuickDateChip(label: 'This Week', icon: Icons.date_range_rounded, selected: _isThisWeek(_selectedDate), isDark: _isDark, onTap: () { final now = DateTime.now(); final monday = now.subtract(Duration(days: now.weekday - 1)); _selectDate(monday); }),
                        const SizedBox(width: 10),
                        _QuickDateChip(label: 'This Month', icon: Icons.event_rounded, selected: _isSameMonth(_selectedDate, DateTime.now()), isDark: _isDark, onTap: () => _selectDate(DateTime(DateTime.now().year, DateTime.now().month, 1))),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: -0.1, curve: Curves.easeOutCubic),

                  const SizedBox(height: 20),

                  // Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Divider(height: 1, color: _isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
                  ),

                  // Table Calendar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _buildCalendar(),
                  ).animate().fadeIn(duration: 500.ms, delay: 150.ms).slideY(begin: 0.1, curve: Curves.easeOutCubic),

                  const SizedBox(height: 8),

                  // Bottom bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 8, 28, 12),
                    child: _buildBottomBar(dateFormat, isToday),
                  ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.15, curve: Curves.easeOutCubic),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: widget.firstDate,
      lastDay: widget.lastDate,
      focusedDay: _focusedDay,
      calendarFormat: CalendarFormat.month,
      rowHeight: 48,
      daysOfWeekHeight: 36,
      startingDayOfWeek: StartingDayOfWeek.monday,
      rangeSelectionMode: RangeSelectionMode.disabled,
      selectedDayPredicate: (day) => _sameDay(_selectedDate, day),
      onDaySelected: (selectedDay, newFocusedDay) {
        _selectDate(selectedDay);
        setState(() => _focusedDay = newFocusedDay);
      },
      onPageChanged: (newFocusedDay) {
        setState(() => _focusedDay = newFocusedDay);
        HapticFeedback.lightImpact();
      },
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        cellMargin: const EdgeInsets.all(3),
        todayDecoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.accent.withValues(alpha: 0.08)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        todayTextStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primary),
        selectedDecoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [
            BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 1, offset: const Offset(0, 3)),
            BoxShadow(color: AppColors.accent.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: -4, offset: const Offset(0, 6)),
          ],
        ),
        selectedTextStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white),
        defaultTextStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
        weekendTextStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
        disabledTextStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.12)),
        defaultDecoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.transparent),
        tableBorder: TableBorder.symmetric(outside: BorderSide.none, inside: BorderSide.none),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: _isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
        weekendStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: _isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
      ),
      headerStyle: HeaderStyle(
        titleCentered: false,
        titleTextFormatter: (date, locale) => DateFormat('MMMM yyyy').format(date),
        headerPadding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
        leftChevronIcon: _ChevronButton(icon: Icons.chevron_left_rounded, isDark: _isDark),
        rightChevronIcon: _ChevronButton(icon: Icons.chevron_right_rounded, isDark: _isDark),
        formatButtonVisible: false,
      ),
    );
  }

  Widget _buildBottomBar(DateFormat dateFormat, bool isToday) {
    final formatted = dateFormat.format(_selectedDate);
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.primary.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppColors.primary, AppColors.accent]))),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isToday ? 'Today — $formatted' : formatted,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _applyDate,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5)),
                BoxShadow(color: AppColors.accent.withValues(alpha: 0.15), blurRadius: 20, spreadRadius: -4),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Apply', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isThisWeek(DateTime date) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return date.isAfter(monday.subtract(const Duration(days: 1))) && date.isBefore(sunday.add(const Duration(days: 1)));
  }

  bool _isSameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;
}

class _PremiumCalendarStatefulWrapper extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onDateSelected;
  const _PremiumCalendarStatefulWrapper({required this.initialDate, required this.firstDate, required this.lastDate, required this.onDateSelected});
  @override
  State<_PremiumCalendarStatefulWrapper> createState() => _PremiumCalendarStatefulWrapperState();
}

class _PremiumCalendarStatefulWrapperState extends State<_PremiumCalendarStatefulWrapper> {
  @override
  Widget build(BuildContext context) => PremiumCalendarSheet(initialDate: widget.initialDate, firstDate: widget.firstDate, lastDate: widget.lastDate, onDateSelected: widget.onDateSelected);
}

class _QuickDateChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;
  const _QuickDateChip({required this.label, required this.icon, required this.selected, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 250.ms,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? const LinearGradient(colors: [AppColors.primary, AppColors.accent], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
          color: selected ? null : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? Colors.white.withValues(alpha: 0.2) : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06))),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight))),
          ],
        ),
      ),
    );
  }
}

class _ChevronButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  const _ChevronButton({required this.icon, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38, height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
      ),
      child: Icon(icon, size: 20, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
    );
  }
}
