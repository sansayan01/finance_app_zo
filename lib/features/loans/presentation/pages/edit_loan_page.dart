import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../users/presentation/providers/user_list_provider.dart';
import '../providers/new_loan_provider.dart';
import '../providers/loan_providers.dart';
import '../../data/models/loan_model.dart';

class EditLoanPage extends ConsumerStatefulWidget {
  final String loanId;

  const EditLoanPage({super.key, required this.loanId});

  @override
  ConsumerState<EditLoanPage> createState() => _EditLoanPageState();
}

class _EditLoanPageState extends ConsumerState<EditLoanPage> {
  final currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final currencyFormatNoDecimals =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  final TextEditingController _principalController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _tenureController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  bool _isMigratedLoan = false;
  bool _isLoadingLoan = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLoanData();
    });
  }

  Future<void> _loadLoanData() async {
    try {
      final loanAsync = await ref.read(loanDetailProvider(widget.loanId).future);
      if (!mounted) return;

      if (loanAsync != null) {
        _populateFormFromLoan(loanAsync);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading loan: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLoan = false);
      }
    }
  }

  void _populateFormFromLoan(LoanModel loan) {
    final notifier = ref.read(newLoanProvider.notifier);
    
    _principalController.text = loan.amount.toInt().toString();
    _rateController.text = loan.interestRate.toString();
    _tenureController.text = loan.tenureMonths.toString();
    _purposeController.text = loan.purpose ?? '';
    _remarksController.text = loan.remarks ?? '';

    notifier.updateBorrower(loan.customerId);
    notifier.updatePrincipal(loan.amount);
    notifier.updateInterestRate(loan.interestRate);
    notifier.updateTenureValue(loan.tenureMonths);

    if (loan.firstEmiDate != null) {
      notifier.updateFirstInstallmentDate(loan.firstEmiDate!);
    }

    if (loan.interestType == InterestType.flat) {
      notifier.updateInterestLogic(InterestLogic.flat);
    } else {
      notifier.updateInterestLogic(InterestLogic.reducingBalance);
    }
  }

  @override
  void dispose() {
    _principalController.dispose();
    _rateController.dispose();
    _tenureController.dispose();
    _purposeController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(newLoanProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 600;

    final usersAsync = ref.watch(customerListProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: theme.colorScheme.onSurface, size: 20),
          onPressed: () {
            ref.read(newLoanProvider.notifier).reset();
            context.pop();
          },
        ),
        title: Text(
          'Edit Loan',
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
      ),
      body: _isLoadingLoan
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
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
                                  child: _buildFacilityDetails(state, theme, isDark,
                                      primary, false, usersAsync)),
                              const SizedBox(width: 24),
                              Expanded(
                                  flex: 2,
                                  child: _buildFinancialSummary(
                                      state, theme, isDark, primary)),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _buildFinancialSummary(state, theme, isDark, primary),
                              const SizedBox(height: 20),
                              _buildFacilityDetails(state, theme, isDark, primary,
                                  isNarrow, usersAsync),
                            ],
                          );
                        }
                      },
                    ),
                  ),
                ),
                _buildBottomBar(theme, isDark, primary, state),
              ],
            ),
    );
  }

  Widget _buildBottomBar(
      ThemeData theme, bool isDark, Color primary, NewLoanState state) {
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
              onPressed: () {
                ref.read(newLoanProvider.notifier).reset();
                context.pop();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Cancel',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : () => _saveLoan(state),
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(
                _isSaving ? 'Saving...' : 'Save Changes',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                disabledBackgroundColor: primary.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveLoan(NewLoanState state) async {
    if (state.borrowerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a borrower'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(loansRepositoryProvider).updateLoan(
        widget.loanId,
        borrowerId: state.borrowerId!,
        principal: state.principalAmount,
        interestRate: state.interestMode == InterestMode.rate
            ? state.interestRate
            : _calculateEquivalentAPR(state),
        tenureMonths: state.tenureValue,
        frequency: state.collectionType.name,
        collectionType: state.collectionType.name,
        interestLogic: state.interestLogic.name,
        firstInstallmentDate: state.firstInstallmentDate ?? DateTime.now().add(const Duration(days: 30)),
        estimatedInstallment: state.estimatedInstallment,
        totalExposure: state.totalExposure,
        interestMode: state.interestMode.name,
        interestRateBasis: state.interestMode == InterestMode.rate
            ? state.interestRateBasis.name
            : null,
        interestAmount: state.interestMode == InterestMode.amount
            ? state.interestAmount
            : 0,
        interestBasis: state.interestMode == InterestMode.amount
            ? state.interestBasis.name
            : null,
        tenureValue: state.tenureValue,
        tenureUnit: state.tenureUnit.name,
        remarks: _remarksController.text.isEmpty ? null : _remarksController.text,
        purpose: _purposeController.text.isEmpty ? null : _purposeController.text,
      );

      if (!mounted) return;

      ref.invalidate(loansProvider);
      ref.invalidate(loanDetailProvider(widget.loanId));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Loan Updated Successfully'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  double _calculateEquivalentAPR(NewLoanState state) {
    if (state.interestAmount <= 0 || state.tenureInDays <= 0) return 0;
    
    double totalInterest;
    switch (state.interestBasis) {
      case InterestBasis.onPrincipal:
        return state.interestAmount * (365 / state.tenureInDays);
      case InterestBasis.daily:
        totalInterest = state.interestAmount * state.tenureInDays;
        break;
      case InterestBasis.weekly:
        totalInterest = state.interestAmount * (state.tenureInDays / 7);
        break;
      case InterestBasis.monthly:
        totalInterest = state.interestAmount * (state.tenureInDays / 30);
        break;
      case InterestBasis.yearly:
        totalInterest = state.interestAmount * (state.tenureInDays / 365);
        break;
    }
    return (totalInterest / state.principalAmount) * (365 / state.tenureInDays) * 100;
  }

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

  Widget _buildFacilityDetails(NewLoanState state, ThemeData theme, bool isDark,
      Color primary, bool isNarrow, AsyncValue<List<dynamic>> usersAsync) {
    return GlassCard(
      padding: EdgeInsets.all(isNarrow ? 18 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Facility Details', Icons.account_balance_rounded,
              theme, primary),
          const SizedBox(height: 20),

          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.fillDark : AppColors.fillLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: SwitchListTile(
              title: Text('Existing / Migrated Loan',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              subtitle: Text(
                  'Enable if this loan is being moved from manual records.',
                  style: theme.textTheme.bodySmall),
              value: _isMigratedLoan,
              activeThumbColor: primary,
              onChanged: (val) {
                setState(() => _isMigratedLoan = val);
              },
            ),
          ).animate().fadeIn(duration: 400.ms),

          if (_isMigratedLoan) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Migration Mode Active',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, color: primary)),
                        const SizedBox(height: 4),
                        Text(
                          'Enter the current OUTSTANDING principal balance and the REMAINING tenure. The system will resume tracking from the next installment date.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(),
          ],
          const SizedBox(height: 28),

          _buildLabel('BORROWER ACCOUNT', theme),
          const SizedBox(height: 10),
          usersAsync.when(
            data: (users) => _buildDropdown(
              value: state.borrowerId,
              hint: users.isEmpty
                  ? 'No users found'
                  : 'Select registered customer',
              items: users.map((u) => u.id as String).toList(),
              itemLabels: users.map((u) => u.fullName as String).toList(),
              onChanged: (val) =>
                  ref.read(newLoanProvider.notifier).updateBorrower(val),
              theme: theme,
              isDark: isDark,
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => _buildDropdown(
                value: null,
                hint: 'Error loading users',
                items: [],
                onChanged: (_) {},
                theme: theme,
                isDark: isDark),
          ),

          const SizedBox(height: 28),

          _buildLabel('PRINCIPAL AMOUNT (₹)', theme),
          const SizedBox(height: 10),
          _buildTextField(
            controller: _principalController,
            prefix: '₹',
            onChanged: (val) {
              final parsed = double.tryParse(val) ?? 0;
              ref.read(newLoanProvider.notifier).updatePrincipal(parsed);
            },
            theme: theme,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildSlider(
            value: state.principalAmount.clamp(1000, 1000000),
            min: 1000,
            max: 1000000,
            displayValue:
                currencyFormatNoDecimals.format(state.principalAmount),
            minLabel: '₹1K',
            maxLabel: '₹10L',
            onChanged: (val) {
              _principalController.text = val.toInt().toString();
              ref.read(newLoanProvider.notifier).updatePrincipal(val);
            },
            theme: theme,
            primary: primary,
          ),

          _buildDivider(theme),

          _buildLabel('INTEREST TYPE', theme),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.fillDark : AppColors.fillLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildInterestModeTab(
                    label: 'Interest Rate',
                    subtitle: 'APR %',
                    isSelected: state.interestMode == InterestMode.rate,
                    onTap: () => ref.read(newLoanProvider.notifier).updateInterestMode(InterestMode.rate),
                    theme: theme,
                    primary: primary,
                  ),
                ),
                Expanded(
                  child: _buildInterestModeTab(
                    label: 'Interest Amount',
                    subtitle: 'Fixed ₹',
                    isSelected: state.interestMode == InterestMode.amount,
                    onTap: () => ref.read(newLoanProvider.notifier).updateInterestMode(InterestMode.amount),
                    theme: theme,
                    primary: primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (state.interestMode == InterestMode.rate) ...[
            _buildDropdown(
              value: state.interestRateBasis.name,
              hint: 'Rate basis',
              items: InterestBasis.values.map((e) => e.name).toList(),
              itemLabels: ['Per Day', 'Per Week', 'Per Month', 'Per Year', '% of Principal'],
              onChanged: (val) {
                if (val != null) {
                  ref.read(newLoanProvider.notifier).updateInterestRateBasis(
                        InterestBasis.values.firstWhere((e) => e.name == val),
                      );
                }
              },
              theme: theme,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _rateController,
              suffix: state.interestRateBasis == InterestBasis.onPrincipal ? '%' : '%',
              onChanged: (val) {
                final parsed = double.tryParse(val) ?? 0;
                ref.read(newLoanProvider.notifier).updateInterestRate(parsed);
              },
              theme: theme,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildSlider(
              value: state.interestRate.clamp(0, state.interestRateBasis == InterestBasis.onPrincipal ? 100 : 50),
              min: 0,
              max: state.interestRateBasis == InterestBasis.onPrincipal ? 100 : 50,
              displayValue: '${state.interestRate.toStringAsFixed(1)}%',
              minLabel: '0%',
              maxLabel: state.interestRateBasis == InterestBasis.onPrincipal ? '100%' : '50%',
              onChanged: (val) {
                _rateController.text = val.toStringAsFixed(1);
                ref.read(newLoanProvider.notifier).updateInterestRate(val);
              },
              theme: theme,
              primary: primary,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: theme.textTheme.bodySmall?.color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Equivalent APR: ${(state.annualizedRate * 100).toStringAsFixed(1)}%',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            _buildDropdown(
              value: state.interestBasis.name,
              hint: 'Interest basis',
              items: InterestBasis.values.map((e) => e.name).toList(),
              itemLabels: ['Per Day', 'Per Week', 'Per Month', 'Per Year', 'On Principal'],
              onChanged: (val) {
                if (val != null) {
                  ref.read(newLoanProvider.notifier).updateInterestBasis(
                        InterestBasis.values.firstWhere((e) => e.name == val),
                      );
                }
              },
              theme: theme,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _rateController,
              suffix: state.interestBasis == InterestBasis.onPrincipal ? '₹ (flat)' : '₹',
              onChanged: (val) {
                final parsed = double.tryParse(val) ?? 0;
                ref.read(newLoanProvider.notifier).updateInterestAmount(parsed);
              },
              theme: theme,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: theme.textTheme.bodySmall?.color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      state.interestBasis == InterestBasis.onPrincipal
                          ? 'Total interest: ${currencyFormat.format(state.interestAmount)} (one-time flat)'
                          : 'Total interest: ${currencyFormat.format(state.totalInterest)}',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],

          _buildDivider(theme),

          _buildLabel('LOAN TENURE', theme),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildTextField(
                  controller: _tenureController,
                  onChanged: (val) {
                    final parsed = int.tryParse(val) ?? 1;
                    ref.read(newLoanProvider.notifier).updateTenureValue(parsed);
                  },
                  theme: theme,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildDropdown(
                  value: state.tenureUnit.name,
                  hint: 'Unit',
                  items: TenureUnit.values.map((e) => e.name).toList(),
                  itemLabels: ['Days', 'Weeks', 'Months', 'Years'],
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(newLoanProvider.notifier).updateTenureUnit(
                            TenureUnit.values.firstWhere((e) => e.name == val),
                          );
                    }
                  },
                  theme: theme,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTenureSlider(state, theme, primary),

          _buildDivider(theme),

          _buildLabel('COLLECTION TYPE', theme),
          const SizedBox(height: 10),
          _buildDropdown(
            value: state.collectionType.name,
            hint: 'Select frequency',
            items: CollectionType.values.map((e) => e.name).toList(),
            itemLabels: ['Daily', 'Weekly', 'Monthly', 'Yearly'],
            onChanged: (val) {
              if (val != null) {
                ref.read(newLoanProvider.notifier).updateCollectionType(
                      CollectionType.values.firstWhere((e) => e.name == val),
                    );
              }
            },
            theme: theme,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: theme.textTheme.bodySmall?.color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${state.numberOfInstallments} installments over ${_formatTenure(state)}',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          _buildDivider(theme),

          _buildLabel('PURPOSE', theme),
          const SizedBox(height: 10),
          _buildTextField(
            controller: _purposeController,
            onChanged: (_) {},
            theme: theme,
            isDark: isDark,
          ),

          const SizedBox(height: 20),

          _buildLabel('REMARKS', theme),
          const SizedBox(height: 10),
          _buildTextField(
            controller: _remarksController,
            onChanged: (_) {},
            theme: theme,
            isDark: isDark,
          ),

          _buildDivider(theme),

          _buildTwoColumn(
            isNarrow: isNarrow,
            first: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('INTEREST LOGIC', theme),
                const SizedBox(height: 10),
                _buildDropdown(
                  value: state.interestLogic.name,
                  hint: 'Select logic',
                  items: InterestLogic.values.map((e) => e.name).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(newLoanProvider.notifier).updateInterestLogic(
                            InterestLogic.values
                                .firstWhere((e) => e.name == val),
                          );
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
                _buildLabel('FIRST INSTALLMENT DATE', theme),
                const SizedBox(height: 10),
                _buildDatePicker(
                  date: state.firstInstallmentDate,
                  onPicked: (date) => ref
                      .read(newLoanProvider.notifier)
                      .updateFirstInstallmentDate(date),
                  theme: theme,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0);
  }

  Widget _buildFinancialSummary(
      NewLoanState state, ThemeData theme, bool isDark, Color primary) {
    return Column(
      children: [
        GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Financial Summary', Icons.calculate_outlined,
                  theme, primary),
              const SizedBox(height: 24),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primary.withValues(alpha: 0.14),
                      primary.withValues(alpha: 0.04)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('EST. INSTALLMENT',
                        style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: primary.withValues(alpha: 0.7))),
                    const SizedBox(height: 8),
                    Text(
                      currencyFormat.format(state.estimatedInstallment),
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: primary,
                          letterSpacing: -1),
                    ),
                    const SizedBox(height: 4),
                    Text('per ${_capitalize(state.collectionType.name)}',
                        style:
                            theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              _buildKV(
                  'Capital Outlay',
                  currencyFormatNoDecimals.format(state.principalAmount),
                  theme),
              _buildKV(
                  'Interest',
                  state.interestMode == InterestMode.rate
                      ? '${state.interestRate}% ${_interestBasisLabel(state.interestRateBasis)}'
                      : '${currencyFormat.format(state.interestAmount)} ${_interestBasisLabel(state.interestBasis)}',
                  theme),
              _buildKV('Tenure', _formatTenure(state), theme),
              Divider(
                  height: 32, color: theme.dividerColor.withValues(alpha: 0.1)),
              _buildKV('Interest Burden',
                  currencyFormat.format(state.interestBurden), theme,
                  valueColor:
                      isDark ? AppColors.warningDark : AppColors.orange),
              _buildKV('Total Exposure',
                  currencyFormat.format(state.totalExposure), theme,
                  valueColor: theme.colorScheme.error),
            ],
          ),
        ).animate().fadeIn(delay: 150.ms).slideX(begin: 0.08, end: 0),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _showAmortizationPreview(context, state, theme, isDark, primary),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primary.withValues(alpha: 0.08),
                  primary.withValues(alpha: 0.02)
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primary.withValues(alpha: 0.2),
                        primary.withValues(alpha: 0.05)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.table_chart_rounded, size: 22, color: primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Amortization Preview',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: primary)),
                      const SizedBox(height: 2),
                      Text('View full EMI schedule breakdown',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: primary.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ).animate().fadeIn(delay: 250.ms).slideX(begin: 0.08, end: 0),
      ],
    );
  }

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
        suffixStyle:
            theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        filled: true,
        fillColor: isDark ? AppColors.fillDark : AppColors.fillLight,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: theme.colorScheme.primary, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? AppColors.fillDark : AppColors.fillLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : null,
          hint: Text(hint, style: theme.textTheme.bodySmall),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: theme.textTheme.bodySmall?.color, size: 22),
          dropdownColor: isDark ? AppColors.elevatedDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          items: List.generate(items.length, (index) {
            final item = items[index];
            final label =
                itemLabels != null ? itemLabels[index] : _capitalize(item);
            return DropdownMenuItem<String>(
              value: item,
              child: Text(label,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            );
          }),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDatePicker({
    required DateTime? date,
    required Function(DateTime) onPicked,
    required ThemeData theme,
    required bool isDark,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now().add(const Duration(days: 30)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.fillDark : AppColors.fillLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Text(
              date != null
                  ? DateFormat('dd MMM yyyy').format(date)
                  : 'Select date',
              style: TextStyle(
                color: date != null
                    ? theme.colorScheme.onSurface
                    : theme.textTheme.bodySmall?.color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 20, color: theme.textTheme.bodySmall?.color),
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
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: primary.withValues(alpha: 0.35),
            inactiveTrackColor: theme.dividerColor.withValues(alpha: 0.12),
            thumbColor: primary,
            overlayColor: primary.withValues(alpha: 0.08),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(minLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10, color: theme.textTheme.bodySmall?.color)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(displayValue,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: primary)),
              ),
              Text(maxLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10, color: theme.textTheme.bodySmall?.color)),
            ],
          ),
        ),
      ],
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  Widget _buildInterestModeTab({
    required String label,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
    required Color primary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(label,
                style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isSelected ? primary : theme.textTheme.bodySmall?.color)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: isSelected ? primary.withValues(alpha: 0.7) : theme.textTheme.bodySmall?.color)),
          ],
        ),
      ),
    );
  }

  Widget _buildTenureSlider(NewLoanState state, ThemeData theme, Color primary) {
    final unit = state.tenureUnit;
    double min, max, value;
    String minLabel, maxLabel, displayValue;

    switch (unit) {
      case TenureUnit.days:
        min = 1;
        max = 3650;
        value = state.tenureValue.toDouble().clamp(1, 3650);
        minLabel = '1d';
        maxLabel = '10y';
        displayValue = '${state.tenureValue} Days';
        break;
      case TenureUnit.weeks:
        min = 1;
        max = 520;
        value = state.tenureValue.toDouble().clamp(1, 520);
        minLabel = '1w';
        maxLabel = '10y';
        displayValue = '${state.tenureValue} Weeks';
        break;
      case TenureUnit.months:
        min = 1;
        max = 120;
        value = state.tenureValue.toDouble().clamp(1, 120);
        minLabel = '1m';
        maxLabel = '10y';
        displayValue = '${state.tenureValue} Months';
        break;
      case TenureUnit.years:
        min = 1;
        max = 30;
        value = state.tenureValue.toDouble().clamp(1, 30);
        minLabel = '1y';
        maxLabel = '30y';
        displayValue = '${state.tenureValue} Years';
        break;
    }

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: primary.withValues(alpha: 0.35),
            inactiveTrackColor: theme.dividerColor.withValues(alpha: 0.12),
            thumbColor: primary,
            overlayColor: primary.withValues(alpha: 0.08),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).toInt() > 100 ? 100 : (max - min).toInt(),
            onChanged: (val) {
              _tenureController.text = val.toInt().toString();
              ref.read(newLoanProvider.notifier).updateTenureValue(val.toInt());
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(minLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10, color: theme.textTheme.bodySmall?.color)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(displayValue,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: primary)),
              ),
              Text(maxLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10, color: theme.textTheme.bodySmall?.color)),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTenure(NewLoanState state) {
    switch (state.tenureUnit) {
      case TenureUnit.days:
        return '${state.tenureValue} day${state.tenureValue != 1 ? 's' : ''}';
      case TenureUnit.weeks:
        return '${state.tenureValue} week${state.tenureValue != 1 ? 's' : ''}';
      case TenureUnit.months:
        return '${state.tenureValue} month${state.tenureValue != 1 ? 's' : ''}';
      case TenureUnit.years:
        return '${state.tenureValue} year${state.tenureValue != 1 ? 's' : ''}';
    }
  }

  String _interestBasisLabel(InterestBasis basis) {
    switch (basis) {
      case InterestBasis.daily:
        return '/day';
      case InterestBasis.weekly:
        return '/week';
      case InterestBasis.monthly:
        return '/month';
      case InterestBasis.yearly:
        return '/year';
      case InterestBasis.onPrincipal:
        return 'on principal';
    }
  }

  void _showAmortizationPreview(
      BuildContext context,
      NewLoanState state,
      ThemeData theme,
      bool isDark,
      Color primary) {
    final schedule = state.generateAmortizationSchedule();
    if (schedule.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in loan details first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AmortizationPreviewSheet(
        schedule: schedule,
        state: state,
        theme: theme,
        isDark: isDark,
        primary: primary,
        currencyFormat: currencyFormat,
        currencyFormatNoDecimals: currencyFormatNoDecimals,
        tenureLabel: _formatTenure(state),
      ),
    );
  }
}

class _AmortizationPreviewSheet extends StatelessWidget {
  final List<AmortizationRow> schedule;
  final NewLoanState state;
  final ThemeData theme;
  final bool isDark;
  final Color primary;
  final NumberFormat currencyFormat;
  final NumberFormat currencyFormatNoDecimals;
  final String tenureLabel;

  const _AmortizationPreviewSheet({
    required this.schedule,
    required this.state,
    required this.theme,
    required this.isDark,
    required this.primary,
    required this.currencyFormat,
    required this.currencyFormatNoDecimals,
    required this.tenureLabel,
  });

  @override
  Widget build(BuildContext context) {
    final totalPrincipal = schedule.fold<double>(0, (sum, r) => sum + r.principal);
    final totalInterest = schedule.fold<double>(0, (sum, r) => sum + r.interest);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primary.withValues(alpha: 0.2),
                            primary.withValues(alpha: 0.05)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.table_chart_rounded, size: 20, color: primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Amortization Schedule',
                              style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                          Text('${schedule.length} installments · $tenureLabel · ${state.interestLogic == InterestLogic.reducingBalance ? "Reducing Balance" : "Flat Rate"}',
                              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Principal',
                        value: currencyFormat.format(totalPrincipal),
                        icon: Icons.account_balance_wallet_rounded,
                        color: primary,
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Interest',
                        value: currencyFormat.format(totalInterest),
                        icon: Icons.trending_up_rounded,
                        color: isDark ? AppColors.warningDark : AppColors.orange,
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Total',
                        value: currencyFormat.format(totalPrincipal + totalInterest),
                        icon: Icons.summarize_rounded,
                        color: theme.colorScheme.error,
                        theme: theme,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildMiniChart(theme, totalPrincipal, totalInterest),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: 518,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              _buildHeaderCell('#', 40, theme),
                              _buildHeaderCell('Due Date', 90, theme),
                              _buildHeaderCell('EMI', 85, theme),
                              _buildHeaderCell('Principal', 85, theme),
                              _buildHeaderCell('Interest', 80, theme),
                              _buildHeaderCell('Balance', 90, theme),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
                            itemCount: schedule.length,
                            itemBuilder: (context, index) {
                              final row = schedule[index];
                              return _buildRow(row, index, theme, isDark, primary);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniChart(ThemeData theme, double totalPrincipal, double totalInterest) {
    final total = totalPrincipal + totalInterest;

    if (total == 0) return const SizedBox.shrink();

    final principalPct = (totalPrincipal / total * 100).toStringAsFixed(1);
    final interestPct = (totalInterest / total * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Expanded(
                  flex: (totalPrincipal / total * 100).round(),
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                    ),
                  ),
                ),
                Expanded(
                  flex: (totalInterest / total * 100).round(),
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.warningDark : AppColors.orange,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('Principal ($principalPct%)', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.warningDark : AppColors.orange,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('Interest ($interestPct%)', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, double width, ThemeData theme) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.5,
          color: theme.textTheme.bodySmall?.color,
        ),
        textAlign: label == '#' ? TextAlign.center : TextAlign.left,
      ),
    );
  }

  Widget _buildRow(AmortizationRow row, int index, ThemeData theme, bool isDark, Color primary) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '${row.emiNumber}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              DateFormat('dd MMM').format(row.dueDate),
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ),
          SizedBox(
            width: 85,
            child: Text(
              currencyFormat.format(row.emiAmount),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: primary,
              ),
            ),
          ),
          SizedBox(
            width: 85,
            child: Text(
              currencyFormat.format(row.principal),
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              currencyFormat.format(row.interest),
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: isDark ? AppColors.warningDark : AppColors.orange,
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              currencyFormat.format(row.balanceAfter),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 15).ms, duration: 100.ms);
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final ThemeData theme;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 8),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 10,
            color: theme.textTheme.bodySmall?.color,
          )),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: color,
            )),
          ),
        ],
      ),
    );
  }
}
