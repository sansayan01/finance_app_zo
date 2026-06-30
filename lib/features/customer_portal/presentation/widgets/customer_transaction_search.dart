import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/models/customer_transaction_filter.dart';

/// Premium transaction search widget with animated expand/collapse,
/// date range, type chips, amount range, and sort controls.
///
/// Designed for embedding inside [CustomerTransactionsPage].
class CustomerTransactionSearch extends ConsumerStatefulWidget {
  final ValueChanged<CustomerTransactionFilter> onFilterChanged;
  final CustomerTransactionFilter initialFilter;

  const CustomerTransactionSearch({
    super.key,
    required this.onFilterChanged,
    this.initialFilter = CustomerTransactionFilter.empty,
  });

  @override
  ConsumerState<CustomerTransactionSearch> createState() =>
      _CustomerTransactionSearchState();
}

class _CustomerTransactionSearchState
    extends ConsumerState<CustomerTransactionSearch>
    with SingleTickerProviderStateMixin {
  late CustomerTransactionFilter _filter;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  late TextEditingController _searchController;
  late TextEditingController _amountMinController;
  late TextEditingController _amountMaxController;
  final FocusNode _searchFocus = FocusNode();

  bool _isExpanded = false;

  // Debounce timer for search
  int _searchDebounceGeneration = 0;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;

    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _searchController = TextEditingController(text: _filter.searchQuery ?? '');
    _amountMinController = TextEditingController(
      text: _filter.amountMin?.toStringAsFixed(0) ?? '',
    );
    _amountMaxController = TextEditingController(
      text: _filter.amountMax?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    _searchController.dispose();
    _amountMinController.dispose();
    _amountMaxController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────

  void _emit() => widget.onFilterChanged(_filter);

  void _updateFilter(CustomerTransactionFilter newFilter) {
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
        _updateFilter(
          _filter.copyWith(
            searchQuery: value,
            clearSearchQuery: value.isEmpty,
          ),
        );
      }
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = isFrom ? _filter.dateFrom : _filter.dateTo;
    final firstDate = DateTime(2020);
    final lastDate = DateTime(now.year + 1, 12, 31);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                  surface: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  onSurface: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
          ),
          child: child!,
        );
      },
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

  void _clearAll() {
    _searchController.clear();
    _amountMinController.clear();
    _amountMaxController.clear();
    _updateFilter(CustomerTransactionFilter.empty);
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GlassCard(
      borderRadius: 18,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Search bar row ──
          _buildSearchBar(theme, isDark),
          // ── Animated filter section ──
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
    );
  }

  // ── Search bar ─────────────────────────────────────────────────

  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          // Search icon
          Icon(
            Icons.search_rounded,
            size: 20,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
          const SizedBox(width: 10),
          // Text field
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                letterSpacing: -0.1,
              ),
              decoration: InputDecoration(
                hintText: 'Search transactions...',
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
          // Clear button
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
          // Filter count badge (when active)
          if (_filter.hasActiveFilters) ...[
            const SizedBox(width: 8),
            _buildFilterBadge(isDark),
            const SizedBox(width: 4),
          ],
          // Expand/collapse toggle
          _buildToggleButton(isDark),
        ],
      ),
    );
  }

  Widget _buildFilterBadge(bool isDark) {
    return AnimatedContainer(
      duration: AppSpacing.animationFast,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.premiumGradient,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
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
        duration: AppSpacing.animationNormal,
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

  // ── Filter section ─────────────────────────────────────────────

  Widget _buildFilterSection(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Divider
          Divider(
            height: 1,
            thickness: 0.5,
            color: isDark ? AppColors.separatorDark : AppColors.separatorLight,
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Active filters chips ──
          if (_filter.hasActiveFilters) ...[
            _buildActiveFiltersRow(theme, isDark),
            const SizedBox(height: AppSpacing.md),
          ],

          // ── Type filter chips ──
          _buildSectionLabel('Transaction Type', isDark),
          const SizedBox(height: AppSpacing.sm),
          _buildTypeChips(theme, isDark),
          const SizedBox(height: AppSpacing.md),

          // ── Date range ──
          _buildSectionLabel('Date Range', isDark),
          const SizedBox(height: AppSpacing.sm),
          _buildDateRangeRow(theme, isDark),
          const SizedBox(height: AppSpacing.md),

          // ── Amount range ──
          _buildSectionLabel('Amount Range', isDark),
          const SizedBox(height: AppSpacing.sm),
          _buildAmountRangeRow(theme, isDark),
          const SizedBox(height: AppSpacing.md),

          // ── Sort options ──
          _buildSectionLabel('Sort By', isDark),
          const SizedBox(height: AppSpacing.sm),
          _buildSortControl(theme, isDark),
        ],
      ),
    );
  }

  // ── Active filters display ────────────────────────────────────

  Widget _buildActiveFiltersRow(ThemeData theme, bool isDark) {
    return Row(
      children: [
        Icon(
          Icons.filter_list_rounded,
          size: 14,
          color: AppColors.primary,
        ),
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
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.close_rounded,
                  size: 13,
                  color: isDark ? AppColors.errorDark : AppColors.error,
                ),
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

  // ── Section label ─────────────────────────────────────────────

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

  // ── Type filter chips ─────────────────────────────────────────

  static const List<_TypeChipData> _typeChips = [
    _TypeChipData('all', 'All', Icons.dashboard_rounded, AppColors.primary),
    _TypeChipData('emi', 'EMI', Icons.payment_rounded, AppColors.info),
    _TypeChipData(
        'deposit', 'Deposit', Icons.savings_rounded, AppColors.success),
    _TypeChipData('withdrawal', 'Withdrawal',
        Icons.account_balance_rounded, AppColors.orange),
    _TypeChipData(
        'collection', 'Collection', Icons.receipt_rounded, AppColors.mint),
    _TypeChipData('penalty', 'Penalty', Icons.warning_rounded, AppColors.rose),
  ];

  Widget _buildTypeChips(ThemeData theme, bool isDark) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _typeChips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = _typeChips[index];
          final isSelected = (_filter.typeFilter ?? 'all') == chip.value;
          return _buildTypeChip(chip, isSelected, isDark);
        },
      ),
    );
  }

  Widget _buildTypeChip(_TypeChipData chip, bool isSelected, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _updateFilter(
          _filter.copyWith(
            typeFilter: chip.value == 'all' ? null : chip.value,
            clearTypeFilter: chip.value == 'all',
          ),
        );
      },
      child: AnimatedContainer(
        duration: AppSpacing.animationNormal,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? chip.color.withValues(alpha: isDark ? 0.2 : 0.1)
              : isDark
                  ? AppColors.fillDark
                  : AppColors.fillLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? chip.color.withValues(alpha: isDark ? 0.5 : 0.3)
                : isDark
                    ? AppColors.separatorDark
                    : AppColors.separatorLight,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: chip.color.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              chip.icon,
              size: 15,
              color: isSelected
                  ? chip.color
                  : isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
            ),
            const SizedBox(width: 6),
            Text(
              chip.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? chip.color
                    : isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Date range row ────────────────────────────────────────────

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
                child: Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Amount range row ──────────────────────────────────────────

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
        _buildAmountApplyButton(isDark),
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
          prefixIcon: Icon(
            icon,
            size: 15,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 0,
          ),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildAmountApplyButton(bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _applyAmountRange();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.premiumGradient,
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
        child: const Icon(
          Icons.check_rounded,
          size: 20,
          color: Colors.white,
        ),
      ),
    );
  }

  // ── Sort control ──────────────────────────────────────────────

  static const List<_SortOption> _sortOptions = [
    _SortOption('date_desc', 'Newest First', Icons.arrow_downward_rounded),
    _SortOption('date_asc', 'Oldest First', Icons.arrow_upward_rounded),
    _SortOption('amount_desc', 'Amount High', Icons.trending_down_rounded),
    _SortOption('amount_asc', 'Amount Low', Icons.trending_up_rounded),
  ];

  Widget _buildSortControl(ThemeData theme, bool isDark) {
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
          items: _sortOptions.map((opt) {
            return DropdownMenuItem<String>(
              value: opt.value,
              child: Row(
                children: [
                  Icon(
                    opt.icon,
                    size: 16,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  const SizedBox(width: 10),
                  Text(opt.label),
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

  // ── Date formatting ───────────────────────────────────────────

  String _formatDateShort(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// ── Private data classes ──────────────────────────────────────────

class _TypeChipData {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _TypeChipData(this.value, this.label, this.icon, this.color);
}

class _SortOption {
  final String value;
  final String label;
  final IconData icon;

  const _SortOption(this.value, this.label, this.icon);
}
