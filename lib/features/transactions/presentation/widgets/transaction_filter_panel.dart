import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/premium_calendar_sheet.dart';
import '../../data/models/transaction_filter.dart';

class TransactionFilterPanel extends StatefulWidget {
  final TransactionFilter filter;
  final ValueChanged<TransactionFilter> onFilterChanged;

  const TransactionFilterPanel({
    super.key,
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  State<TransactionFilterPanel> createState() => _TransactionFilterPanelState();
}

class _TransactionFilterPanelState extends State<TransactionFilterPanel>
    with SingleTickerProviderStateMixin {
  late TransactionFilter _filter;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  late TextEditingController _searchController;
  late TextEditingController _amountMinController;
  late TextEditingController _amountMaxController;

  bool _isExpanded = false;
  int _searchDebounceGeneration = 0;

  @override
  void initState() {
    super.initState();
    _filter = widget.filter;

    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _searchController = TextEditingController(text: _filter.searchQuery);
    _amountMinController = TextEditingController(
      text: _filter.amountMin?.toStringAsFixed(0) ?? '',
    );
    _amountMaxController = TextEditingController(
      text: _filter.amountMax?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void didUpdateWidget(TransactionFilterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter) {
      _filter = widget.filter;
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    _searchController.dispose();
    _amountMinController.dispose();
    _amountMaxController.dispose();
    super.dispose();
  }

  void _emit() => widget.onFilterChanged(_filter);

  void _updateFilter(TransactionFilter newFilter) {
    setState(() => _filter = newFilter);
    _emit();
  }

  void _toggleExpanded() {
    HapticFeedback.lightImpact();
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  void _onSearchChanged(String value) {
    final gen = ++_searchDebounceGeneration;
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (gen == _searchDebounceGeneration && mounted) {
        _updateFilter(_filter.copyWith(
          searchQuery: value,
          clearSearchQuery: value.isEmpty,
        ));
      }
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = isFrom
        ? (_filter.dateFrom ?? now)
        : (_filter.dateTo ?? now);
    final picked = await PremiumCalendarSheet.show(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
    );

    if (picked != null) {
      if (isFrom) {
        _updateFilter(_filter.copyWith(dateFrom: picked));
      } else {
        _updateFilter(_filter.copyWith(dateTo: picked));
      }
    }
  }

  void _clearDate({required bool isFrom}) {
    if (isFrom) {
      _updateFilter(_filter.copyWith(clearDateFrom: true));
    } else {
      _updateFilter(_filter.copyWith(clearDateTo: true));
    }
  }

  void _applyDatePreset(String preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? from;
    DateTime? to;

    switch (preset) {
      case 'this_week':
        final monday = today.subtract(Duration(days: today.weekday - 1));
        from = monday;
        to = today;
        break;
      case 'this_month':
        from = DateTime(now.year, now.month, 1);
        to = today;
        break;
      case 'last_30':
        from = today.subtract(const Duration(days: 29));
        to = today;
        break;
      case 'clear':
        from = null;
        to = null;
        break;
    }

    _updateFilter(_filter.copyWith(
      dateFrom: from,
      dateTo: to,
      clearDateFrom: from == null,
      clearDateTo: to == null,
    ));
  }

  void _applyAmountRange() {
    final minText = _amountMinController.text.trim();
    final maxText = _amountMaxController.text.trim();
    final min = minText.isNotEmpty ? double.tryParse(minText) : null;
    final max = maxText.isNotEmpty ? double.tryParse(maxText) : null;

    _updateFilter(_filter.copyWith(
      amountMin: min,
      amountMax: max,
      clearAmountMin: min == null,
      clearAmountMax: max == null,
    ));
  }

  void _togglePaymentMode(PaymentMode mode) {
    HapticFeedback.selectionClick();
    final current = List<PaymentMode>.from(_filter.paymentModes);
    if (current.contains(mode)) {
      current.remove(mode);
    } else {
      current.add(mode);
    }
    _updateFilter(_filter.copyWith(
      paymentModes: current,
      clearPaymentModes: current.isEmpty,
    ));
  }

  void _clearAll() {
    _searchController.clear();
    _amountMinController.clear();
    _amountMaxController.clear();
    _updateFilter(TransactionFilter.empty);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GlassCard(
      borderRadius: 18,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSearchBar(theme, isDark),
          SizeTransition(
            sizeFactor: _expandAnimation,
            alignment: Alignment.topCenter,
            child: FadeTransition(
              opacity: _expandAnimation,
              child: _buildFilterSection(theme, isDark),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 20,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                letterSpacing: -0.1,
              ),
              decoration: InputDecoration(
                hintText: 'Search by member name...',
                hintStyle: TextStyle(
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close_rounded,
                  size: 16,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight),
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
          if (_filter.hasActiveFilters) ...[
            const SizedBox(width: 8),
            _buildFilterBadge(isDark),
            const SizedBox(width: 4),
          ],
          _buildToggleButton(isDark),
        ],
      ),
    );
  }

  Widget _buildFilterBadge(bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
        ),
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '${_filter.activeFilterCount}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildToggleButton(bool isDark) {
    return GestureDetector(
      onTap: _toggleExpanded,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _isExpanded
              ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
              : isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : AppColors.fillLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isExpanded
                ? AppColors.primary.withValues(alpha: 0.3)
                : isDark
                    ? AppColors.separatorDark
                    : AppColors.separatorLight,
          ),
        ),
        child: AnimatedRotation(
          turns: _isExpanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 300),
          child: Icon(
            Icons.tune_rounded,
            size: 18,
            color: _isExpanded
                ? AppColors.primary
                : isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            height: 1,
            thickness: 0.5,
            color: isDark ? AppColors.separatorDark : AppColors.separatorLight,
          ),
          const SizedBox(height: 16),

          if (_filter.hasActiveFilters) ...[
            _buildActiveFiltersRow(theme, isDark),
            const SizedBox(height: 16),
          ],

          _buildSectionLabel('Date Range', isDark),
          const SizedBox(height: 8),
          _buildDateRangeRow(theme, isDark),
          const SizedBox(height: 10),
          _buildDatePresetsRow(isDark),
          const SizedBox(height: 16),

          _buildSectionLabel('Amount Range', isDark),
          const SizedBox(height: 8),
          _buildAmountRangeRow(theme, isDark),
          const SizedBox(height: 16),

          _buildSectionLabel('Payment Mode', isDark),
          const SizedBox(height: 8),
          _buildPaymentModeChips(isDark),
          const SizedBox(height: 16),

          _buildSectionLabel('Sort By', isDark),
          const SizedBox(height: 8),
          _buildSortControl(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersRow(ThemeData theme, bool isDark) {
    return Row(
      children: [
        const Icon(Icons.filter_list_rounded, size: 14, color: AppColors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${_filter.activeFilterCount} filter${_filter.activeFilterCount > 1 ? 's' : ''} active',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _clearAll();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.close_rounded, size: 13, color: AppColors.error),
                const SizedBox(width: 4),
                Text(
                  'Clear All',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.errorDark : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildDateRangeRow(ThemeData theme, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildDatePicker(
            label: 'From',
            date: _filter.dateFrom,
            isDark: isDark,
            onTap: () => _pickDate(isFrom: true),
            onClear: () => _clearDate(isFrom: true),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 24,
          height: 1,
          color: isDark ? AppColors.separatorDark : AppColors.separatorLight,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildDatePicker(
            label: 'To',
            date: _filter.dateTo,
            isDark: isDark,
            onTap: () => _pickDate(isFrom: false),
            onClear: () => _clearDate(isFrom: false),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? date,
    required bool isDark,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: date != null
              ? AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.06)
              : isDark
                  ? AppColors.fillDark
                  : AppColors.fillLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: date != null
                ? AppColors.primary.withValues(alpha: 0.3)
                : isDark
                    ? AppColors.separatorDark
                    : AppColors.separatorLight,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 15,
              color: date != null
                  ? AppColors.primary
                  : isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date != null ? _formatDateShort(date) : label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: date != null ? FontWeight.w600 : FontWeight.w400,
                  color: date != null
                      ? AppColors.primary
                      : isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (date != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: AppColors.textTertiaryDark,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePresetsRow(bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final last30 = today.subtract(const Duration(days: 29));

    bool isSelected(String preset) {
      switch (preset) {
        case 'this_week':
          return _filter.dateFrom == monday && _filter.dateTo == today;
        case 'this_month':
          return _filter.dateFrom == monthStart && _filter.dateTo == today;
        case 'last_30':
          return _filter.dateFrom == last30 && _filter.dateTo == today;
        default:
          return false;
      }
    }

    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildPresetChip('This Week', isSelected('this_week'), isDark,
              () => _applyDatePreset('this_week')),
          const SizedBox(width: 8),
          _buildPresetChip('This Month', isSelected('this_month'), isDark,
              () => _applyDatePreset('this_month')),
          const SizedBox(width: 8),
          _buildPresetChip('Last 30 Days', isSelected('last_30'), isDark,
              () => _applyDatePreset('last_30')),
          if (_filter.dateFrom != null || _filter.dateTo != null) ...[
            const SizedBox(width: 8),
            _buildPresetChip('Clear Dates', false, isDark,
                () => _applyDatePreset('clear')),
          ],
        ],
      ),
    );
  }

  Widget _buildPresetChip(
      String label, bool isSelected, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
              : isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.4)
                : isDark
                    ? AppColors.separatorDark
                    : AppColors.separatorLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? AppColors.primary
                : isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
          ),
        ),
      ),
    );
  }

  Widget _buildAmountRangeRow(ThemeData theme, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildAmountField(
            controller: _amountMinController,
            label: 'Min',
            isDark: isDark,
            icon: Icons.arrow_downward_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 24,
          height: 1,
          color: isDark ? AppColors.separatorDark : AppColors.separatorLight,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildAmountField(
            controller: _amountMaxController,
            label: 'Max',
            isDark: isDark,
            icon: Icons.arrow_upward_rounded,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _applyAmountRange();
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.check_rounded, size: 20, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountField({
    required TextEditingController controller,
    required String label,
    required bool isDark,
    required IconData icon,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? AppColors.fillDark : AppColors.fillLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.separatorDark : AppColors.separatorLight,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
        ],
        onSubmitted: (_) => _applyAmountRange(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
        ),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: TextStyle(
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
            fontWeight: FontWeight.w400,
            fontSize: 13,
          ),
          prefixIcon: Icon(icon, size: 15,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 0),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildPaymentModeChips(bool isDark) {
    final modes = [
      (PaymentMode.cash, 'Cash', Icons.money_rounded),
      (PaymentMode.upi, 'UPI', Icons.phone_android_rounded),
      (PaymentMode.bankTransfer, 'Bank', Icons.account_balance_rounded),
      (PaymentMode.cheque, 'Cheque', Icons.receipt_rounded),
      (PaymentMode.card, 'Card', Icons.credit_card_rounded),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: modes.map((mode) {
        final isSelected = _filter.paymentModes.contains(mode.$1);
        return GestureDetector(
          onTap: () => _togglePaymentMode(mode.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                  : isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : isDark
                        ? AppColors.separatorDark
                        : AppColors.separatorLight,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  mode.$3,
                  size: 14,
                  color: isSelected
                      ? AppColors.primary
                      : isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                ),
                const SizedBox(width: 6),
                Text(
                  mode.$2,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primary
                        : isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSortControl(ThemeData theme, bool isDark) {
    const sortOptions = [
      ('date_desc', 'Newest First', Icons.arrow_downward_rounded),
      ('date_asc', 'Oldest First', Icons.arrow_upward_rounded),
      ('amount_desc', 'Amount: High to Low', Icons.trending_down_rounded),
      ('amount_asc', 'Amount: Low to High', Icons.trending_up_rounded),
    ];

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.fillDark : AppColors.fillLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.separatorDark : AppColors.separatorLight,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filter.sortBy,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
          dropdownColor: isDark ? AppColors.cardDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
          items: sortOptions.map((opt) {
            return DropdownMenuItem<String>(
              value: opt.$1,
              child: Row(
                children: [
                  Icon(opt.$3, size: 16,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  const SizedBox(width: 10),
                  Text(opt.$2),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              HapticFeedback.selectionClick();
              _updateFilter(_filter.copyWith(sortBy: value));
            }
          },
        ),
      ),
    );
  }

  String _formatDateShort(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
