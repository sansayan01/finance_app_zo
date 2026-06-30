import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/enums.dart';
import '../../../loans/presentation/widgets/statement_options_sheet.dart';
import '../../data/models/transaction_filter.dart';
import '../../data/services/transaction_export_options.dart';

class TransactionExportSheet extends StatefulWidget {
  final bool hasActiveFilter;
  final DateTime? filterStart;
  final DateTime? filterEnd;
  final TransactionFilter currentFilter;

  const TransactionExportSheet({
    super.key,
    this.hasActiveFilter = false,
    this.filterStart,
    this.filterEnd,
    this.currentFilter = TransactionFilter.empty,
  });

  @override
  State<TransactionExportSheet> createState() => _TransactionExportSheetState();
}

class _TransactionExportSheetState extends State<TransactionExportSheet> {
  TransactionPeriod _period = TransactionPeriod.thisMonth;
  StatementFormat _format = StatementFormat.pdf;
  bool _includeSummary = true;
  DateTime? _customStart;
  DateTime? _customEnd;

  bool _showAdvanced = false;

  final List<TransactionType> _selectedTypes = [];
  final List<PaymentMode> _selectedPaymentModes = [];
  double? _amountMin;
  double? _amountMax;
  String _searchQuery = '';
  String _sortBy = 'date_desc';

  late TextEditingController _amountMinController;
  late TextEditingController _amountMaxController;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _amountMinController = TextEditingController();
    _amountMaxController = TextEditingController();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _amountMinController.dispose();
    _amountMaxController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleAdvanced() {
    HapticFeedback.lightImpact();
    setState(() => _showAdvanced = !_showAdvanced);
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedTypes.isNotEmpty) count++;
    if (_selectedPaymentModes.isNotEmpty) count++;
    if (_amountMin != null || _amountMax != null) count++;
    if (_searchQuery.isNotEmpty) count++;
    if (_sortBy != 'date_desc') count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 18),

                      // Title
                      Text(
                        'Export Transactions',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose period, filters, and format.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 20),

                      // Period
                      _buildSectionLabel('PERIOD', isDark),
                      const SizedBox(height: 8),
                      _buildPeriodChips(isDark),
                      const SizedBox(height: 16),

                      // Format
                      _buildSectionLabel('FORMAT', isDark),
                      const SizedBox(height: 8),
                      _buildFormatSelector(isDark),
                      const SizedBox(height: 16),

                      // Include summary toggle
                      _buildSummaryToggle(isDark),
                      const SizedBox(height: 12),

                      // Advanced Filters Toggle
                      _buildAdvancedToggle(isDark),

                      // Advanced Filters (expandable)
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: _buildAdvancedFilters(isDark),
                        crossFadeState: _showAdvanced
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 300),
                      ),

                      const SizedBox(height: 16),

                      // Generate button
                      _buildGenerateButton(isDark),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

  Widget _buildPeriodChips(bool isDark) {
    final periods = [
      (TransactionPeriod.today, 'Today'),
      (TransactionPeriod.thisWeek, 'This Week'),
      (TransactionPeriod.thisMonth, 'This Month'),
      (TransactionPeriod.last30Days, 'Last 30 Days'),
      if (widget.hasActiveFilter)
        (TransactionPeriod.allFiltered, 'All Filtered'),
      (TransactionPeriod.custom, 'Custom'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: periods.map((p) {
        final isSelected = _period == p.$1;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _period = p.$1);
            if (p.$1 == TransactionPeriod.custom) _pickCustomRange();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
            child: Text(
              p.$2,
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
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFormatSelector(bool isDark) {
    final formats = [
      (StatementFormat.pdf, 'PDF', Icons.picture_as_pdf_rounded),
      (StatementFormat.excel, 'Excel', Icons.table_chart_rounded),
      (StatementFormat.csv, 'CSV', Icons.description_rounded),
    ];

    return Row(
      children: formats.map((f) {
        final isSelected = _format == f.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _format = f.$1);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                    : isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : isDark
                          ? AppColors.separatorDark
                          : AppColors.separatorLight,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    f.$3,
                    size: 20,
                    color: isSelected
                        ? AppColors.primary
                        : isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    f.$2,
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
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSummaryToggle(bool isDark) {
    return GestureDetector(
      onTap: () => setState(() => _includeSummary = !_includeSummary),
      child: Row(
        children: [
          Icon(
            _includeSummary
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: _includeSummary
                ? AppColors.primary
                : isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
          ),
          const SizedBox(width: 10),
          Text(
            'Include summary statistics',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedToggle(bool isDark) {
    return GestureDetector(
      onTap: _toggleAdvanced,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _showAdvanced
              ? AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08)
              : isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _showAdvanced
                ? AppColors.primary.withValues(alpha: 0.3)
                : isDark
                    ? AppColors.separatorDark
                    : AppColors.separatorLight,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.tune_rounded,
              size: 18,
              color: _showAdvanced
                  ? AppColors.primary
                  : isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Advanced Filters',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _showAdvanced
                      ? AppColors.primary
                      : isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                ),
              ),
            ),
            if (_activeFilterCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.accent],
                  ),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$_activeFilterCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: _showAdvanced ? 0.5 : 0,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
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

  Widget _buildAdvancedFilters(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Transaction Type
        _buildSectionLabel('TRANSACTION TYPE', isDark),
        const SizedBox(height: 8),
        _buildTypeChips(isDark),
        const SizedBox(height: 16),

        // Amount Range
        _buildSectionLabel('AMOUNT RANGE', isDark),
        const SizedBox(height: 8),
        _buildAmountRange(isDark),
        const SizedBox(height: 16),

        // Payment Mode
        _buildSectionLabel('PAYMENT MODE', isDark),
        const SizedBox(height: 8),
        _buildPaymentModeChips(isDark),
        const SizedBox(height: 16),

        // Member Search
        _buildSectionLabel('MEMBER SEARCH', isDark),
        const SizedBox(height: 8),
        _buildSearchField(isDark),
        const SizedBox(height: 16),

        // Sort By
        _buildSectionLabel('SORT BY', isDark),
        const SizedBox(height: 8),
        _buildSortDropdown(isDark),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTypeChips(bool isDark) {
    final types = [
      (TransactionType.emiPayment, 'EMI', Icons.payments_rounded),
      (TransactionType.savingsDeposit, 'Savings', Icons.savings_rounded),
      (TransactionType.loanDisbursement, 'Disbursed', Icons.account_balance_rounded),
      (TransactionType.savingsWithdrawal, 'Withdrawal', Icons.money_off_rounded),
      (TransactionType.penalty, 'Penalty', Icons.warning_rounded),
      (TransactionType.staffCashDeposit, 'Cash Deposit', Icons.account_balance_wallet_rounded),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((t) {
        final isSelected = _selectedTypes.contains(t.$1);
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (isSelected) {
                _selectedTypes.remove(t.$1);
              } else {
                _selectedTypes.add(t.$1);
              }
            });
          },
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
                  t.$3,
                  size: 14,
                  color: isSelected
                      ? AppColors.primary
                      : isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                ),
                const SizedBox(width: 6),
                Text(
                  t.$2,
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

  Widget _buildAmountRange(bool isDark) {
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
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? AppColors.fillDark : AppColors.fillLight,
        borderRadius: BorderRadius.circular(10),
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
        onChanged: (v) {
          setState(() {
            _amountMin = double.tryParse(_amountMinController.text);
            _amountMax = double.tryParse(_amountMaxController.text);
          });
        },
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
      children: modes.map((m) {
        final isSelected = _selectedPaymentModes.contains(m.$1);
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (isSelected) {
                _selectedPaymentModes.remove(m.$1);
              } else {
                _selectedPaymentModes.add(m.$1);
              }
            });
          },
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
                  m.$3,
                  size: 14,
                  color: isSelected
                      ? AppColors.primary
                      : isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                ),
                const SizedBox(width: 6),
                Text(
                  m.$2,
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

  Widget _buildSearchField(bool isDark) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? AppColors.fillDark : AppColors.fillLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.separatorDark : AppColors.separatorLight,
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
        ),
        decoration: InputDecoration(
          hintText: 'Search by member name...',
          hintStyle: TextStyle(
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
            fontWeight: FontWeight.w400,
            fontSize: 13,
          ),
          prefixIcon: Icon(Icons.search_rounded, size: 18,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: Icon(Icons.close_rounded, size: 16,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildSortDropdown(bool isDark) {
    const sortOptions = [
      ('date_desc', 'Newest First', Icons.arrow_downward_rounded),
      ('date_asc', 'Oldest First', Icons.arrow_upward_rounded),
      ('amount_desc', 'Amount: High to Low', Icons.trending_down_rounded),
      ('amount_asc', 'Amount: Low to High', Icons.trending_up_rounded),
    ];

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.fillDark : AppColors.fillLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.separatorDark : AppColors.separatorLight,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sortBy,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
          dropdownColor: isDark ? AppColors.cardDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
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
              setState(() => _sortBy = value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildGenerateButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _generate,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.share_rounded, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Generate & Share',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_activeFilterCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$_activeFilterCount',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _customStart != null && _customEnd != null
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _customStart = picked.start;
        _customEnd = picked.end;
      });
    }
  }

  void _generate() {
    if (_period == TransactionPeriod.custom &&
        (_customStart == null || _customEnd == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date range')),
      );
      return;
    }
    final options = TransactionExportOptions(
      format: _format,
      period: _period,
      customStart: _customStart,
      customEnd: _customEnd,
      includeSummary: _includeSummary,
      typeFilter: _selectedTypes,
      paymentModes: _selectedPaymentModes,
      amountMin: _amountMin,
      amountMax: _amountMax,
      searchQuery: _searchQuery,
      sortBy: _sortBy,
    );
    Navigator.pop(context, options);
  }
}
