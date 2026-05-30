import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/models/savings_model.dart';
import '../../data/providers/savings_providers.dart';
import '../providers/new_recurring_saving_provider.dart' show CollectionType;
import '../../../../core/constants/enums.dart' show TenureUnit;

class EditSavingsVaultPage extends ConsumerStatefulWidget {
  final String savingId;
  const EditSavingsVaultPage({super.key, required this.savingId});

  @override
  ConsumerState<EditSavingsVaultPage> createState() =>
      _EditSavingsVaultPageState();
}

class _EditSavingsVaultPageState extends ConsumerState<EditSavingsVaultPage> {
  final currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final currencyFormatNoDecimals =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  final TextEditingController _installmentController = TextEditingController();
  final TextEditingController _maturityAmountController =
      TextEditingController();
  final TextEditingController _penaltyController = TextEditingController();
  final TextEditingController _currentBalanceController =
      TextEditingController();
  final TextEditingController _tenureController = TextEditingController();

  bool _initialized = false;
  CollectionType _collectionType = CollectionType.monthly;
  double _installmentAmount = 1000;
  double _maturityAmount = 12500;
  double _currentBalance = 0;
  DateTime _startDate = DateTime.now();
  DateTime _maturityDate = DateTime.now().add(const Duration(days: 365));
  double _prematurePenalty = 2;
  TenureUnit _tenureUnit = TenureUnit.months;
  int _tenureValue = 12;
  bool _isSaving = false;

  @override
  void dispose() {
    _installmentController.dispose();
    _maturityAmountController.dispose();
    _penaltyController.dispose();
    _currentBalanceController.dispose();
    _tenureController.dispose();
    super.dispose();
  }

  void _initializeFields(SavingsModel saving) {
    if (_initialized) return;

    _installmentController.text = saving.monthlyDeposit.toInt().toString();
    _maturityAmountController.text = saving.targetAmount.toInt().toString();
    _penaltyController.text = saving.prematurePenalty.toInt().toString();
    _currentBalanceController.text = saving.currentAmount.toInt().toString();

    _installmentAmount = saving.monthlyDeposit;
    _maturityAmount = saving.targetAmount;
    _currentBalance = saving.currentAmount;
    _startDate = saving.startDate ?? saving.createdAt;
    _maturityDate = saving.maturityDate;
    _prematurePenalty = saving.prematurePenalty;

    final typeStr = saving.collectionType.toLowerCase();
    if (typeStr == 'daily') {
      _collectionType = CollectionType.daily;
    } else if (typeStr == 'weekly') {
      _collectionType = CollectionType.weekly;
    } else {
      _collectionType = CollectionType.monthly;
    }

    // Use stored tenure unit, or derive from date range
    if (saving.tenureUnit != null && saving.tenureUnit!.isNotEmpty) {
      _tenureUnit = TenureUnit.values.firstWhere(
        (e) => e.name == saving.tenureUnit,
        orElse: () => TenureUnit.months,
      );
    } else {
      final days = _maturityDate.difference(_startDate).inDays;
      if (days % 365 == 0 && days >= 365) {
        _tenureUnit = TenureUnit.years;
      } else if (days % 7 == 0 && days >= 7) {
        _tenureUnit = TenureUnit.weeks;
      } else if (days < 7) {
        _tenureUnit = TenureUnit.days;
      } else {
        _tenureUnit = TenureUnit.months;
      }
    }

    // Use stored tenure value, or derive from dates as fallback
    _tenureValue = saving.tenure > 0 ? saving.tenure : _deriveTenureFromDates();
    _tenureController.text = _tenureValue.toString();

    _initialized = true;
  }

  int get _calculatedTotalInstallments {
    if (_tenureValue <= 0) return 0;

    // Convert tenure to total days, then to collection-type installments
    int totalDays;
    switch (_tenureUnit) {
      case TenureUnit.days:
        totalDays = _tenureValue;
        break;
      case TenureUnit.weeks:
        totalDays = _tenureValue * 7;
        break;
      case TenureUnit.months:
        totalDays = (_tenureValue * 30.44).round();
        break;
      case TenureUnit.years:
        totalDays = (_tenureValue * 365.25).round();
        break;
    }

    switch (_collectionType) {
      case CollectionType.daily:
        return totalDays;
      case CollectionType.weekly:
        return (totalDays / 7).round();
      case CollectionType.monthly:
        return (totalDays / 30.44).round();
    }
  }

  double get _calculatedTotalCapitalInvested {
    return _installmentAmount * _calculatedTotalInstallments;
  }

  double get _calculatedEstimatedInterest {
    return _maturityAmount - _calculatedTotalCapitalInvested;
  }

  String _capitalize(String s) =>
      s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;

  /// Derive tenure from dates as a fallback when no stored value exists.
  int _deriveTenureFromDates() {
    if (_maturityDate.isBefore(_startDate)) return 0;
    final days = _maturityDate.difference(_startDate).inDays;
    switch (_tenureUnit) {
      case TenureUnit.days:
        return days;
      case TenureUnit.weeks:
        return (days / 7).round();
      case TenureUnit.months:
        return (days / 30.44).round();
      case TenureUnit.years:
        return (days / 365.25).round();
    }
  }

  /// Recalculate maturity date from start date + tenure value + unit.
  DateTime _maturityFromTenure(DateTime start, int value, TenureUnit unit) {
    if (value <= 0) return start;
    switch (unit) {
      case TenureUnit.days:
        return start.add(Duration(days: value));
      case TenureUnit.weeks:
        return start.add(Duration(days: value * 7));
      case TenureUnit.months:
        final newMonth = start.month + value;
        final yearOverflow = (newMonth - 1) ~/ 12;
        final month = ((newMonth - 1) % 12) + 1;
        final day = start.day.clamp(1, _daysInMonth(start.year + yearOverflow, month));
        return DateTime(start.year + yearOverflow, month, day);
      case TenureUnit.years:
        final targetYear = start.year + value;
        final day = start.day.clamp(1, _daysInMonth(targetYear, start.month));
        return DateTime(targetYear, start.month, day);
    }
  }

  static int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  @override
  Widget build(BuildContext context) {
    final savingAsync = ref.watch(savingDetailProvider(widget.savingId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 600;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: theme.colorScheme.onSurface, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Edit Savings Vault',
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
      ),
      body: savingAsync.when(
        data: (saving) {
          if (saving == null) {
            return const Center(child: Text('Savings Plan Not Found'));
          }

          // Initialise controllers only once
          _initializeFields(saving);

          return Column(
            children: [
              // Scrollable form body
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      isNarrow ? 16 : 24, 8, isNarrow ? 16 : 24, 24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth > 900;
                      if (isDesktop) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                flex: 3,
                                child: _buildFormDetails(
                                    theme, isDark, primary, false, saving)),
                            const SizedBox(width: 24),
                            Expanded(
                                flex: 2,
                                child: _buildSummary(theme, isDark, primary)),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            _buildSummary(theme, isDark, primary),
                            const SizedBox(height: 20),
                            _buildFormDetails(
                                theme, isDark, primary, isNarrow, saving),
                          ],
                        );
                      }
                    },
                  ),
                ),
              ),
              // Bottom Action Bar
              _buildBottomBar(theme, isDark, primary, saving),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  // Bottom action bar with Save & Discard buttons
  Widget _buildBottomBar(
      ThemeData theme, bool isDark, Color primary, SavingsModel saving) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.elevatedDark : Colors.white,
        border: Border(
            top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.12))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => context.pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Discard',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isSaving
                  ? null
                  : () async {
                      setState(() => _isSaving = true);
                      try {
                        await ref
                            .read(savingsRepositoryProvider)
                            .updateSavingMetadata(widget.savingId, {
                          'monthly_deposit': _installmentAmount,
                          'target_amount': _maturityAmount,
                          'maturity_amount': _maturityAmount,
                          'start_date':
                              _startDate.toIso8601String().split('T')[0],
                          'maturity_date':
                              _maturityDate.toIso8601String().split('T')[0],
                          'collection_type': _collectionType.name,
                          'tenure_unit': _tenureUnit.name,
                          'tenure': _tenureValue,
                          'premature_penalty': _prematurePenalty,
                          'total_installments': _calculatedTotalInstallments,
                          'current_amount': _currentBalance,
                        });

                        if (!mounted) return;
                        ref.invalidate(savingDetailProvider(widget.savingId));
                        ref.invalidate(allSavingsProvider);
                        ref.invalidate(savingsSummaryProvider);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 12),
                                Text('Savings Vault Updated Successfully'),
                              ],
                            ),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                        context.pop();
                      } catch (e) {
                        setState(() => _isSaving = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: ${e.toString()}'),
                            backgroundColor: theme.colorScheme.error,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    },
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(
                _isSaving ? 'Saving...' : 'Save Changes',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDark ? AppColors.successDark : AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                disabledBackgroundColor:
                    (isDark ? AppColors.successDark : AppColors.success)
                        .withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Section header helper
  Widget _buildSectionHeader(
      String title, IconData icon, ThemeData theme, Color accent) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.18),
                accent.withValues(alpha: 0.06)
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: accent),
        ),
        const SizedBox(width: 12),
        Text(title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3)),
      ],
    );
  }

  // Detailed inputs form
  Widget _buildFormDetails(ThemeData theme, bool isDark, Color primary,
      bool isNarrow, SavingsModel saving) {
    return GlassCard(
      padding: EdgeInsets.all(isNarrow ? 18 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Account Parameters',
              Icons.account_balance_wallet_rounded, theme, primary),
          const SizedBox(height: 28),

          // Member Name (Display only to protect owner assignment)
          _buildLabel('MEMBER ACCOUNT', theme),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.fillDark.withValues(alpha: 0.5)
                  : AppColors.fillLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Icon(Icons.person_outline_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 12),
                Text(
                  saving.memberName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Adjust Current Balance
          _buildLabel('ADJUST CURRENT BALANCE (₹)', theme),
          const SizedBox(height: 10),
          _buildTextField(
            controller: _currentBalanceController,
            prefix: '₹',
            onChanged: (val) {
              setState(() {
                _currentBalance = double.tryParse(val) ?? 0;
              });
            },
            theme: theme,
            isDark: isDark,
          ),

          _buildDivider(theme),

          // Collection Type & Installment
          _buildTwoColumn(
            isNarrow: isNarrow,
            first: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('COLLECTION CYCLE', theme),
                const SizedBox(height: 10),
                _buildDropdown(
                  value: _collectionType.name,
                  hint: 'Select',
                  items: CollectionType.values.map((e) => e.name).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _collectionType = CollectionType.values
                            .firstWhere((e) => e.name == val);
                      });
                    }
                  },
                  theme: theme,
                  isDark: isDark,
                ),
              ],
            ),
            second: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('INSTALLMENT AMOUNT (₹)', theme),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _installmentController,
                  prefix: '₹',
                  onChanged: (val) {
                    setState(() {
                      _installmentAmount = double.tryParse(val) ?? 0;
                    });
                  },
                  theme: theme,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildSlider(
            value: _installmentAmount.clamp(10, 50000),
            min: 10,
            max: 50000,
            displayValue: currencyFormatNoDecimals.format(_installmentAmount),
            minLabel: '₹10',
            maxLabel: '₹50K',
            onChanged: (val) {
              setState(() {
                _installmentAmount = val;
                _installmentController.text = val.toInt().toString();
              });
            },
            theme: theme,
            primary: primary,
          ),

          _buildDivider(theme),

          // Start Date & Tenure Unit
          _buildTwoColumn(
            isNarrow: isNarrow,
            first: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('START DATE', theme),
                const SizedBox(height: 10),
                _buildDatePicker(
                  date: _startDate,
                  onPicked: (date) {
                    setState(() {
                      _startDate = date;
                      _maturityDate = _maturityFromTenure(
                          _startDate, _tenureValue, _tenureUnit);
                    });
                  },
                  theme: theme,
                  isDark: isDark,
                ),
              ],
            ),
            second: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('TENURE', theme),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        controller: _tenureController,
                        onChanged: (val) {
                          final parsed = int.tryParse(val) ?? 12;
                          setState(() {
                            _tenureValue = parsed;
                            _maturityDate = _maturityFromTenure(
                                _startDate, _tenureValue, _tenureUnit);
                          });
                        },
                        theme: theme,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _buildDropdown(
                        value: _tenureUnit.name,
                        hint: 'Unit',
                        items: TenureUnit.values.map((e) => e.name).toList(),
                        itemLabels: const ['Days', 'Weeks', 'Months', 'Years'],
                        onChanged: (val) {
                          if (val != null) {
                            final newUnit = TenureUnit.values
                                .firstWhere((e) => e.name == val);
                            setState(() {
                              _tenureUnit = newUnit;
                              _maturityDate = _maturityFromTenure(
                                  _startDate, _tenureValue, newUnit);
                            });
                          }
                        },
                        theme: theme,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          _buildDivider(theme),

          // Maturity Amount & Date
          _buildTwoColumn(
            isNarrow: isNarrow,
            first: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('MATURITY AMOUNT (₹)', theme),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _maturityAmountController,
                  prefix: '₹',
                  onChanged: (val) {
                    setState(() {
                      _maturityAmount = double.tryParse(val) ?? 0;
                    });
                  },
                  theme: theme,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildSlider(
                  value: _maturityAmount.clamp(1000, 5000000),
                  min: 1000,
                  max: 5000000,
                  displayValue:
                      currencyFormatNoDecimals.format(_maturityAmount),
                  minLabel: '₹1K',
                  maxLabel: '₹50L',
                  onChanged: (val) {
                    setState(() {
                      _maturityAmount = val;
                      _maturityAmountController.text = val.toInt().toString();
                    });
                  },
                  theme: theme,
                  primary: primary,
                ),
              ],
            ),
            second: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('MATURITY DATE', theme),
                const SizedBox(height: 10),
                _buildDatePicker(
                  date: _maturityDate,
                  onPicked: (date) {
                    setState(() {
                      _maturityDate = date;
                      // Sync tenure value from the new date range
                      _tenureValue = _deriveTenureFromDates();
                      _tenureController.text = _tenureValue.toString();
                    });
                  },
                  theme: theme,
                  isDark: isDark,
                ),
              ],
            ),
          ),

          _buildDivider(theme),

          // Premature Penalty
          _buildTwoColumn(
            isNarrow: isNarrow,
            first: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('PREMATURE PENALTY (%)', theme),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _penaltyController,
                  suffix: '%',
                  onChanged: (val) {
                    setState(() {
                      _prematurePenalty = double.tryParse(val) ?? 0;
                    });
                  },
                  theme: theme,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildSlider(
                  value: _prematurePenalty.clamp(0, 10),
                  min: 0,
                  max: 10,
                  displayValue: '${_prematurePenalty.toInt()}%',
                  minLabel: '0%',
                  maxLabel: '10%',
                  onChanged: (val) {
                    setState(() {
                      _prematurePenalty = val;
                      _penaltyController.text = val.toInt().toString();
                    });
                  },
                  theme: theme,
                  primary: primary,
                ),
              ],
            ),
            second: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    isDark
                        ? AppColors.successDark.withValues(alpha: 0.12)
                        : AppColors.success.withValues(alpha: 0.12),
                    isDark
                        ? AppColors.successDark.withValues(alpha: 0.04)
                        : AppColors.success.withValues(alpha: 0.04)
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_outlined,
                      color: isDark ? AppColors.successDark : AppColors.success,
                      size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PRINCIPAL PROTECTED',
                            style: TextStyle(
                                color: isDark
                                    ? AppColors.successDark
                                    : AppColors.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Text(
                          'Fully insured and capital-guaranteed.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontSize: 13, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0);
  }

  // Summary Sidebar / Interactive Wealth Forecast
  Widget _buildSummary(ThemeData theme, bool isDark, Color primary) {
    return Column(
      children: [
        GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                  'Wealth Forecast', Icons.radar_outlined, theme, primary),
              const SizedBox(height: 24),

              // Hero metric
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      isDark
                          ? AppColors.successDark.withValues(alpha: 0.14)
                          : AppColors.success.withValues(alpha: 0.14),
                      isDark
                          ? AppColors.successDark.withValues(alpha: 0.04)
                          : AppColors.success.withValues(alpha: 0.04)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GUARANTEED MATURITY',
                        style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: (isDark
                                    ? AppColors.successDark
                                    : AppColors.success)
                                .withValues(alpha: 0.7))),
                    const SizedBox(height: 8),
                    Text(
                      currencyFormat.format(_maturityAmount),
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? AppColors.successDark
                              : AppColors.success,
                          letterSpacing: -1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                        'on ${DateFormat('dd MMM yyyy').format(_maturityDate)}',
                        style:
                            theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              _buildKV(
                  'Deposit Cycle', _capitalize(_collectionType.name), theme),
              _buildKV('Installment', currencyFormat.format(_installmentAmount),
                  theme),
              _buildKV(
                  'Total Installments', '$_calculatedTotalInstallments', theme),
              _buildKV(
                  'Total Capital',
                  currencyFormat.format(_calculatedTotalCapitalInvested),
                  theme),
              Divider(
                  height: 32, color: theme.dividerColor.withValues(alpha: 0.1)),
              _buildKV('Est. Interest/Yield',
                  currencyFormat.format(_calculatedEstimatedInterest), theme,
                  valueColor:
                      isDark ? AppColors.successDark : AppColors.success),
            ],
          ),
        ).animate().fadeIn(delay: 150.ms).slideX(begin: 0.08, end: 0),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.warningDark.withValues(alpha: 0.12)
                      : AppColors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.warning_amber_rounded,
                    size: 18,
                    color: isDark ? AppColors.warningDark : AppColors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Premature Exit',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'A ${_prematurePenalty.toInt()}% penalty on accumulated interest applies before ${DateFormat('dd MMM yyyy').format(_maturityDate)}.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 250.ms).slideX(begin: 0.08, end: 0),
      ],
    );
  }

  // Key-Value UI Helper
  Widget _buildKV(String label, String value, ThemeData theme,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child:
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.1)),
    );
  }

  Widget _buildLabel(String text, ThemeData theme) {
    return Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700, letterSpacing: 0.8, fontSize: 11),
    );
  }

  Widget _buildTwoColumn(
      {required bool isNarrow, required Widget first, required Widget second}) {
    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [first, const SizedBox(height: 20), second],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 16),
        Expanded(child: second),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required Function(String) onChanged,
    required ThemeData theme,
    required bool isDark,
    String? prefix,
    String? suffix,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
      ],
      decoration: InputDecoration(
        prefixText: prefix != null ? '$prefix ' : null,
        suffixText: suffix,
        prefixStyle: TextStyle(
            color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
        labelStyle: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        filled: true,
        fillColor: isDark ? AppColors.fillDark : AppColors.fillLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
      ),
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    List<String>? itemLabels,
    required Function(String?) onChanged,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.fillDark : AppColors.fillLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint,
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 14)),
          isExpanded: true,
          dropdownColor: isDark ? AppColors.elevatedDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          items: List.generate(items.length, (index) {
            final val = items[index];
            final label = itemLabels != null ? itemLabels[index] : val;
            return DropdownMenuItem(
              value: val,
              child: Text(
                _capitalize(label),
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            );
          }),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDatePicker({
    required DateTime date,
    required Function(DateTime) onPicked,
    required ThemeData theme,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 3650)),
          builder: (context, child) {
            return Theme(
              data: theme.copyWith(
                colorScheme: theme.colorScheme.copyWith(
                  primary: theme.colorScheme.primary,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          onPicked(picked);
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.fillDark : AppColors.fillLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('dd MMM yyyy').format(date),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            Icon(Icons.calendar_today_rounded,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider({
    required double value,
    required double min,
    required double max,
    required String displayValue,
    required String minLabel,
    required String maxLabel,
    required Function(double) onChanged,
    required ThemeData theme,
    required Color primary,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(minLabel, style: theme.textTheme.bodySmall),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                displayValue,
                style: TextStyle(
                    color: primary, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            Text(maxLabel, style: theme.textTheme.bodySmall),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: primary,
            inactiveTrackColor: theme.dividerColor.withValues(alpha: 0.08),
            thumbColor: primary,
            overlayColor: primary.withValues(alpha: 0.12),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
