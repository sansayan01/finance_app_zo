import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../users/presentation/providers/user_list_provider.dart';
import '../providers/new_loan_provider.dart';

class NewLoanPage extends ConsumerStatefulWidget {
  const NewLoanPage({super.key});

  @override
  ConsumerState<NewLoanPage> createState() => _NewLoanPageState();
}

class _NewLoanPageState extends ConsumerState<NewLoanPage> {
  final currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final currencyFormatNoDecimals =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  final TextEditingController _principalController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _tenureController = TextEditingController();

  bool _isMigratedLoan = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(newLoanProvider);
      _principalController.text = state.principalAmount.toInt().toString();
      _rateController.text = state.interestRate.toString();
      _tenureController.text = state.tenureMonths.toString();
    });
  }

  @override
  void dispose() {
    _principalController.dispose();
    _rateController.dispose();
    _tenureController.dispose();
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
          'Deploy Capital',
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
      ),
      body: Column(
        children: [
          // ── Scrollable form body ──
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
          // ── Fixed bottom action bar ──
          _buildBottomBar(theme, isDark, primary, state),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  BOTTOM ACTION BAR
  // ═══════════════════════════════════════════════════
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
              onPressed: state.isLoading
                  ? null
                  : () async {
                      try {
                        await ref.read(newLoanProvider.notifier).createLoan();

                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 12),
                                Text('Loan Deployed Successfully'),
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
              icon: state.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.rocket_launch_rounded, size: 18),
              label: Text(
                state.isLoading ? 'Deploying...' : 'Deploy Loan',
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

  // ═══════════════════════════════════════════════════
  //  SECTION HEADER
  // ═══════════════════════════════════════════════════
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

  // ═══════════════════════════════════════════════════
  //  FACILITY DETAILS FORM
  // ═══════════════════════════════════════════════════
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

          // ── Migration Toggle ──
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

          // ── Borrower ──
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

          // ── Principal ──
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

          // ── Rate ──
          _buildLabel('INTEREST RATE (%)', theme),
          const SizedBox(height: 10),
          _buildTextField(
            controller: _rateController,
            suffix: '% APR',
            onChanged: (val) {
              final parsed = double.tryParse(val) ?? 0;
              ref.read(newLoanProvider.notifier).updateInterestRate(parsed);
            },
            theme: theme,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildSlider(
            value: state.interestRate.clamp(0, 50),
            min: 0,
            max: 50,
            displayValue: '${state.interestRate.toStringAsFixed(1)}%',
            minLabel: '0%',
            maxLabel: '50%',
            onChanged: (val) {
              _rateController.text = val.toStringAsFixed(1);
              ref.read(newLoanProvider.notifier).updateInterestRate(val);
            },
            theme: theme,
            primary: primary,
          ),

          _buildDivider(theme),

          // ── Tenure & Collection Type ──
          _buildTwoColumn(
            isNarrow: isNarrow,
            first: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('TENURE (MONTHS)', theme),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _tenureController,
                  suffix: 'Mo',
                  onChanged: (val) {
                    final parsed = int.tryParse(val) ?? 1;
                    ref.read(newLoanProvider.notifier).updateTenure(parsed);
                  },
                  theme: theme,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildSlider(
                  value: state.tenureMonths.toDouble().clamp(1, 120),
                  min: 1,
                  max: 120,
                  displayValue: '${state.tenureMonths} Mo',
                  minLabel: '1',
                  maxLabel: '120',
                  onChanged: (val) {
                    _tenureController.text = val.toInt().toString();
                    ref
                        .read(newLoanProvider.notifier)
                        .updateTenure(val.toInt());
                  },
                  theme: theme,
                  primary: primary,
                ),
              ],
            ),
            second: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('COLLECTION TYPE', theme),
                const SizedBox(height: 10),
                _buildDropdown(
                  value: state.collectionType.name,
                  hint: 'Select',
                  items: CollectionType.values.map((e) => e.name).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(newLoanProvider.notifier).updateCollectionType(
                            CollectionType.values
                                .firstWhere((e) => e.name == val),
                          );
                    }
                  },
                  theme: theme,
                  isDark: isDark,
                ),
              ],
            ),
          ),

          _buildDivider(theme),

          // ── Interest Logic & Date ──
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

  // ═══════════════════════════════════════════════════
  //  FINANCIAL SUMMARY SIDEBAR
  // ═══════════════════════════════════════════════════
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

              // Hero metric
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
              _buildKV('Yield Rate', '${state.interestRate}% APR', theme),
              _buildKV('Tenure', '${state.tenureMonths} Months', theme),
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
                      ? AppColors.successDark.withValues(alpha: 0.12)
                      : AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.info_outline_rounded,
                    size: 18,
                    color: isDark ? AppColors.successDark : AppColors.success),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Amortization',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'A full ${state.interestLogic == InterestLogic.reducingBalance ? 'reducing balance' : 'flat rate'} schedule will be generated upon approval.',
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

  // ═══════════════════════════════════════════════════
  //  REUSABLE COMPONENTS
  // ═══════════════════════════════════════════════════
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
}
