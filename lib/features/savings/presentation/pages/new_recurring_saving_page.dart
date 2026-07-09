import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../settings/data/providers/products_providers.dart';
import '../../../members/presentation/widgets/member_searchable_picker.dart';
import '../providers/new_recurring_saving_provider.dart';

class NewRecurringSavingPage extends ConsumerStatefulWidget {
  const NewRecurringSavingPage({super.key});

  @override
  ConsumerState<NewRecurringSavingPage> createState() =>
      _NewRecurringSavingPageState();
}

class _NewRecurringSavingPageState
    extends ConsumerState<NewRecurringSavingPage> {
  final currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final currencyFormatNoDecimals =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  final TextEditingController _installmentController = TextEditingController();
  final TextEditingController _maturityAmountController =
      TextEditingController();
  final TextEditingController _penaltyController = TextEditingController();
  final TextEditingController _initialBalanceController =
      TextEditingController();
  final TextEditingController _tenureController = TextEditingController();

  bool _isMigratedAccount = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(newRecurringSavingProvider);
      _installmentController.text = state.installmentAmount.toInt().toString();
      _maturityAmountController.text = state.maturityAmount.toInt().toString();
      _penaltyController.text = state.prematurePenalty.toInt().toString();
      _initialBalanceController.text = state.initialBalance.toInt().toString();
      _tenureController.text = state.tenure.toString();
    });
  }

  @override
  void dispose() {
    _installmentController.dispose();
    _maturityAmountController.dispose();
    _penaltyController.dispose();
    _initialBalanceController.dispose();
    _tenureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(newRecurringSavingProvider);
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
          onPressed: () {
            ref.read(newRecurringSavingProvider.notifier).reset();
            context.pop();
          },
        ),
        title: Text(
          'New Savings Plan',
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
                            child: _buildFormDetails(state, theme, isDark,
                                primary, false)),
                        const SizedBox(width: 24),
                        Expanded(
                            flex: 2,
                            child:
                                _buildSummary(state, theme, isDark, primary)),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildSummary(state, theme, isDark, primary),
                        const SizedBox(height: 20),
                        _buildFormDetails(state, theme, isDark, primary,
                            isNarrow),
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
  Widget _buildBottomBar(ThemeData theme, bool isDark, Color primary,
      NewRecurringSavingState state) {
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
                ref.read(newRecurringSavingProvider.notifier).reset();
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
                      // Migration validation
                      if (_isMigratedAccount) {
                        if (state.alreadyPaidAmount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                  'Already Paid Amount must be greater than 0 for migrated accounts'),
                              backgroundColor: theme.colorScheme.error,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                          return;
                        }
                      }
                      try {
                        await ref
                            .read(newRecurringSavingProvider.notifier)
                            .createSavingsPlan();

                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 12),
                                Text('Savings Account Opened Successfully'),
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
                  : const Icon(Icons.savings_rounded, size: 18),
              label: Text(
                state.isLoading ? 'Opening...' : 'Open Account',
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
  //  FORM DETAILS
  // ═══════════════════════════════════════════════════
  Widget _buildFormDetails(
      NewRecurringSavingState state,
      ThemeData theme,
      bool isDark,
      Color primary,
      bool isNarrow) {
    return GlassCard(
      padding: EdgeInsets.all(isNarrow ? 18 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Account Parameters',
              Icons.account_balance_wallet_rounded, theme, primary),
          const SizedBox(height: 28),

          // ── Product Template Selector ──
          _buildLabel('SELECT PRODUCT (OPTIONAL)', theme),
          const SizedBox(height: 10),
          _buildProductSelector(state, theme, isDark),

          const SizedBox(height: 24),

          // ── Member ──
          _buildLabel('MEMBER ACCOUNT', theme),
          const SizedBox(height: 10),
          MemberSearchablePicker(
            selectedId: state.memberId,
            hint: 'Search and select member',
            onChanged: (val) => ref
                .read(newRecurringSavingProvider.notifier)
                .updateMember(val),
          ),

          const SizedBox(height: 24),

          // ── Migration Toggle ──
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.fillDark : AppColors.fillLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: SwitchListTile(
              title: Text('Existing / Migrated Account',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              subtitle: Text(
                  'Enable if the customer already has funds saved in this plan.',
                  style: theme.textTheme.bodySmall),
              value: _isMigratedAccount,
              activeThumbColor: primary,
              onChanged: (val) {
                setState(() => _isMigratedAccount = val);
                if (!val) {
                  _initialBalanceController.text = '0';
                  ref
                      .read(newRecurringSavingProvider.notifier)
                      .updateInitialBalance(0);
                }
                // Phase #3 — propagate the explicit user choice to the
                // provider so the migration route is taken only when
                // the checkbox is checked.
                ref
                    .read(newRecurringSavingProvider.notifier)
                    .updateIsMigrated(val);
              },
            ),
          ).animate().fadeIn(duration: 400.ms),

          if (_isMigratedAccount) ...[
            const SizedBox(height: 20),
            _buildLabel('ALREADY PAID AMOUNT (₹)', theme),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _initialBalanceController,
              prefix: '₹',
              onChanged: (val) {
                final parsed = double.tryParse(val) ?? 0;
                ref
                    .read(newRecurringSavingProvider.notifier)
                    .updateAlreadyPaidAmount(parsed);
              },
              theme: theme,
              isDark: isDark,
            ).animate().slideY(begin: -0.2, end: 0).fadeIn(),
          ],

          _buildDivider(theme),

          // ── Collection type & Installment ──
          _buildTwoColumn(
            isNarrow: isNarrow,
            first: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('COLLECTION CYCLE', theme),
                const SizedBox(height: 10),
                _buildDropdown(
                  value: state.collectionType.name,
                  hint: 'Select',
                  items: CollectionType.values.map((e) => e.name).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      ref
                          .read(newRecurringSavingProvider.notifier)
                          .updateCollectionType(
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
            second: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('INSTALLMENT AMOUNT (₹)', theme),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _installmentController,
                  prefix: '₹',
                  onChanged: (val) {
                    final parsed = double.tryParse(val) ?? 0;
                    ref
                        .read(newRecurringSavingProvider.notifier)
                        .updateInstallmentAmount(parsed);
                  },
                  theme: theme,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildSlider(
            value: state.installmentAmount.clamp(10, 50000),
            min: 10,
            max: 50000,
            displayValue:
                currencyFormatNoDecimals.format(state.installmentAmount),
            minLabel: '₹10',
            maxLabel: '₹50K',
            onChanged: (val) {
              _installmentController.text = val.toInt().toString();
              ref
                  .read(newRecurringSavingProvider.notifier)
                  .updateInstallmentAmount(val);
            },
            theme: theme,
            primary: primary,
          ),

          _buildDivider(theme),

          // ── Start Date & Tenure ──
          _buildTwoColumn(
            isNarrow: isNarrow,
            first: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel(_isMigratedAccount ? 'START DATE (BACKDATE ALLOWED)' : 'START DATE', theme),
                const SizedBox(height: 10),
                _buildDatePicker(
                  date: state.startDate,
                  allowPastDates: _isMigratedAccount,
                  onPicked: (date) => ref
                      .read(newRecurringSavingProvider.notifier)
                      .updateStartDate(date),
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
                          ref
                              .read(newRecurringSavingProvider.notifier)
                              .updateTenure(parsed);
                        },
                        theme: theme,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _buildDropdown(
                        value: state.tenureUnit.name,
                        hint: 'Unit',
                        items: TenureUnit.values.map((e) => e.name).toList(),
                        itemLabels: ['Days', 'Weeks', 'Months', 'Years'],
                        onChanged: (val) {
                          if (val != null) {
                            ref
                                .read(newRecurringSavingProvider.notifier)
                                .updateTenureUnit(
                                  TenureUnit.values
                                      .firstWhere((e) => e.name == val),
                                );
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

          // ── Maturity Amount & Date ──
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
                    final parsed = double.tryParse(val) ?? 0;
                    ref
                        .read(newRecurringSavingProvider.notifier)
                        .updateMaturityAmount(parsed);
                  },
                  theme: theme,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildSlider(
                  value: state.maturityAmount.clamp(1000, 5000000),
                  min: 1000,
                  max: 5000000,
                  displayValue:
                      currencyFormatNoDecimals.format(state.maturityAmount),
                  minLabel: '₹1K',
                  maxLabel: '₹50L',
                  onChanged: (val) {
                    _maturityAmountController.text = val.toInt().toString();
                    ref
                        .read(newRecurringSavingProvider.notifier)
                        .updateMaturityAmount(val);
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
                  date: state.maturityDate,
                  onPicked: (date) => ref
                      .read(newRecurringSavingProvider.notifier)
                      .updateMaturityDate(date),
                  theme: theme,
                  isDark: isDark,
                ),
              ],
            ),
          ),

          _buildDivider(theme),

          // ── Penalty & Info ──
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
                    final parsed = double.tryParse(val) ?? 0;
                    ref
                        .read(newRecurringSavingProvider.notifier)
                        .updatePrematurePenalty(parsed);
                  },
                  theme: theme,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildSlider(
                  value: state.prematurePenalty.clamp(0, 10),
                  min: 0,
                  max: 10,
                  displayValue: '${state.prematurePenalty.toInt()}%',
                  minLabel: '0%',
                  maxLabel: '10%',
                  onChanged: (val) {
                    _penaltyController.text = val.toInt().toString();
                    ref
                        .read(newRecurringSavingProvider.notifier)
                        .updatePrematurePenalty(val);
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

          // ── Migration Summary Card ──
          if (_isMigratedAccount) ...[
            _buildDivider(theme),
            _buildMigrationSummary(state, theme, isDark, primary),
          ],

          const SizedBox(height: 20),

          // ── Date Freeze Toggle ──
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.fillDark : AppColors.fillLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: SwitchListTile(
              title: Text('Enable Date Freeze',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              subtitle: Text(
                  'Skipped installments will be frozen and tenure auto-extended.',
                  style: theme.textTheme.bodySmall),
              value: state.freezeEnabled,
              activeThumbColor: Colors.cyan,
              secondary: const Icon(Icons.ac_unit_rounded, color: Colors.cyan),
              onChanged: (val) {
                ref
                    .read(newRecurringSavingProvider.notifier)
                    .updateFreezeEnabled(val);
              },
            ),
          ).animate().fadeIn(duration: 400.ms),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0);
  }

  // ═══════════════════════════════════════════════════
  //  MIGRATION SUMMARY CARD
  // ═══════════════════════════════════════════════════
  Widget _buildMigrationSummary(NewRecurringSavingState state, ThemeData theme,
      bool isDark, Color primary) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
              'Migration Summary', Icons.analytics_outlined, theme, primary),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isDark
                      ? primary.withValues(alpha: 0.12)
                      : primary.withValues(alpha: 0.08),
                  isDark
                      ? primary.withValues(alpha: 0.04)
                      : primary.withValues(alpha: 0.02)
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildMigrationRow(
                    'Installments Paid',
                    '${state.installmentsPaidCount}/${state.totalInstallments}',
                    theme),
                const SizedBox(height: 10),
                _buildMigrationRow(
                    'Overdue Installments', '${state.overdueInstallments}', theme,
                    valueColor: state.overdueInstallments > 0
                        ? (isDark ? AppColors.errorDark : AppColors.error)
                        : null),
                const SizedBox(height: 10),
                _buildMigrationRow(
                    'Current Balance',
                    currencyFormat.format(state.alreadyPaidAmount),
                    theme),
                const SizedBox(height: 10),
                _buildMigrationRow(
                    'Overdue Amount',
                    currencyFormat.format(state.overdueAmount),
                    theme,
                    valueColor: state.overdueAmount > 0
                        ? (isDark ? AppColors.errorDark : AppColors.error)
                        : null),
                const SizedBox(height: 10),
                _buildMigrationRow(
                    'Next Due Date',
                    DateFormat('dd MMM').format(state.nextDueDateCalc),
                    theme),
                const SizedBox(height: 10),
                _buildMigrationRow(
                    'Maturity Date',
                    DateFormat('dd MMM yy').format(state.maturityDate),
                    theme),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.04, end: 0);
  }

  Widget _buildMigrationRow(String label, String value, ThemeData theme,
      {Color? valueColor}) {
    return Row(
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
    );
  }

  // ═══════════════════════════════════════════════════
  //  SUMMARY SIDEBAR
  // ═══════════════════════════════════════════════════
  Widget _buildSummary(NewRecurringSavingState state, ThemeData theme,
      bool isDark, Color primary) {
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
                      currencyFormat.format(state.maturityAmount),
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
                        'on ${DateFormat('dd MMM yyyy').format(state.maturityDate)}',
                        style:
                            theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              _buildKV('Deposit Cycle', _capitalize(state.collectionType.name),
                  theme),
              _buildKV('Start Date',
                  DateFormat('dd MMM yyyy').format(state.startDate), theme),
              _buildKV('Installment',
                  currencyFormat.format(state.installmentAmount), theme),
              if (state.initialBalance > 0) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ALREADY PAID AMOUNT',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text('Amount already deposited by the customer',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5))),
                          ],
                        ),
                      ),
                      Text(currencyFormat.format(state.initialBalance),
                          style: TextStyle(
                              color: isDark
                                  ? AppColors.warningDark
                                  : AppColors.orange,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
              _buildKV(
                  'Total Installments', '${state.totalInstallments}', theme),
              _buildKV('Total Capital',
                  currencyFormat.format(state.totalCapitalInvested), theme),
              Divider(
                  height: 32, color: theme.dividerColor.withValues(alpha: 0.1)),
              _buildKV('Est. Interest/Yield',
                  currencyFormat.format(state.estimatedInterest), theme,
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
                      'A ${state.prematurePenalty.toInt()}% penalty on accumulated interest applies before ${DateFormat('dd MMM yyyy').format(state.maturityDate)}.',
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
    required DateTime date,
    required Function(DateTime) onPicked,
    required ThemeData theme,
    required bool isDark,
    bool allowPastDates = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: allowPastDates ? DateTime(2020) : DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 3650)),
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
              DateFormat('dd MMM yyyy').format(date),
              style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600),
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

  // ═══════════════════════════════════════════════════
  //  PRODUCT TEMPLATE SELECTOR
  // ═══════════════════════════════════════════════════
  Widget _buildProductSelector(NewRecurringSavingState state, ThemeData theme, bool isDark) {
    final asyncProducts = ref.watch(savingsProductsProvider);
    return asyncProducts.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) {
        final activeProducts = products.where((p) => p['is_active'] == true).toList();
        if (activeProducts.isEmpty) return const SizedBox.shrink();

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.fillDark : AppColors.fillLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: state.productId,
            isExpanded: true,
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('None (Manual Entry)',
                    style: TextStyle(fontStyle: FontStyle.italic)),
              ),
              ...activeProducts.map((p) => DropdownMenuItem(
                    value: p['id'] as String,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(p['name']?.toString() ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '${p['interest_rate']}% · ${p['collection_type']} · ${p['tenure']} ${p['tenure_unit']}',
                          style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color),
                        ),
                      ],
                    ),
                  )),
            ],
            onChanged: (productId) {
              ref.read(newRecurringSavingProvider.notifier).updateProductId(productId);
              if (productId != null) {
                final product = activeProducts.firstWhere((p) => p['id'] == productId);
                _applySavingsProduct(product);
              }
            },
            decoration: const InputDecoration(
              labelText: 'Savings Product',
              hintText: 'Select a product template',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        );
      },
    );
  }

  void _applySavingsProduct(Map<String, dynamic> product) {
    final notifier = ref.read(newRecurringSavingProvider.notifier);

    // Collection type
    notifier.updateCollectionType(
      CollectionType.values.firstWhere(
        (e) => e.name == (product['collection_type'] ?? 'monthly'),
        orElse: () => CollectionType.monthly,
      ),
    );

    // Tenure
    notifier.updateTenure(product['tenure'] ?? 12);
    notifier.updateTenureUnit(
      TenureUnit.values.firstWhere(
        (e) => e.name == (product['tenure_unit'] ?? 'months'),
        orElse: () => TenureUnit.months,
      ),
    );

    // Premature penalty
    notifier.updatePrematurePenalty((product['premature_penalty'] as num?)?.toDouble() ?? 0);

    // Default installment amount
    final defaultInstallment = (product['default_installment'] as num?)?.toDouble();
    if (defaultInstallment != null && defaultInstallment > 0) {
      notifier.updateInstallmentAmount(defaultInstallment);
      _installmentController.text = defaultInstallment.toInt().toString();
    }

    // Default maturity amount
    final defaultMaturity = (product['default_maturity_amount'] as num?)?.toDouble();
    if (defaultMaturity != null && defaultMaturity > 0) {
      notifier.updateMaturityAmount(defaultMaturity);
      _maturityAmountController.text = defaultMaturity.toInt().toString();
    }

    // Update text controllers
    _tenureController.text = (product['tenure'] ?? 12).toString();
    _penaltyController.text = ((product['premature_penalty'] as num?)?.toDouble() ?? 0).toStringAsFixed(0);
  }
}
