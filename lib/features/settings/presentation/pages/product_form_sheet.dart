import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/products_providers.dart';

enum ProductType { loan, savings }

class ProductFormSheet extends ConsumerStatefulWidget {
  final ProductType productType;
  final Map<String, dynamic>? existingProduct;

  const ProductFormSheet({
    super.key,
    required this.productType,
    this.existingProduct,
  });

  @override
  ConsumerState<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends ConsumerState<ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  // ─── Common ───
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;

  // ─── Loan fields ───
  late final TextEditingController _interestRateCtrl;
  late final TextEditingController _minAmountCtrl;
  late final TextEditingController _maxAmountCtrl;
  late final TextEditingController _tenureCtrl;
  late final TextEditingController _feeCtrl;
  late final TextEditingController _penaltyCtrl;
  late final TextEditingController _graceCtrl;
  late final TextEditingController _defaultPrincipalCtrl;
  String _interestMode = 'reducing';
  String _interestBasis = 'onPrincipal';
  String _interestLogic = 'reducingBalance';
  String _frequency = 'monthly';
  String _tenureUnit = 'months';

  // ─── Savings fields ───
  late final TextEditingController _savInterestRateCtrl;
  late final TextEditingController _minDepositCtrl;
  late final TextEditingController _maxDepositCtrl;
  late final TextEditingController _savTenureCtrl;
  late final TextEditingController _prematurePenaltyCtrl;
  late final TextEditingController _defaultInstallmentCtrl;
  late final TextEditingController _defaultMaturityCtrl;
  String _collectionType = 'monthly';
  String _savTenureUnit = 'months';

  bool get _isEdit => widget.existingProduct != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existingProduct;

    _nameCtrl = TextEditingController(text: p?['name']?.toString() ?? '');
    _descCtrl = TextEditingController(text: p?['description']?.toString() ?? '');

    // Loan
    _interestRateCtrl = TextEditingController(
        text: p?['interest_rate']?.toString() ?? '');
    _minAmountCtrl = TextEditingController(
        text: p?['min_amount']?.toString() ?? '');
    _maxAmountCtrl = TextEditingController(
        text: p?['max_amount']?.toString() ?? '');
    _tenureCtrl = TextEditingController(
        text: p?['tenure_months']?.toString() ?? p?['tenure']?.toString() ?? '12');
    _feeCtrl = TextEditingController(
        text: p?['processing_fee']?.toString() ?? '0');
    _penaltyCtrl = TextEditingController(
        text: p?['late_penalty_pct']?.toString() ?? '0');
    _graceCtrl = TextEditingController(
        text: p?['grace_period_days']?.toString() ?? '0');
    _defaultPrincipalCtrl = TextEditingController(
        text: p?['default_principal']?.toString() ?? '');
    _interestMode = p?['interest_mode']?.toString() ?? 'reducing';
    _interestBasis = p?['interest_basis']?.toString() ?? 'onPrincipal';
    _interestLogic = p?['interest_logic']?.toString() ?? 'reducingBalance';
    _frequency = p?['frequency']?.toString() ?? 'monthly';
    _tenureUnit = p?['tenure_unit']?.toString() ?? 'months';

    // Savings
    _savInterestRateCtrl = TextEditingController(
        text: p?['interest_rate']?.toString() ?? '0');
    _minDepositCtrl = TextEditingController(
        text: p?['min_deposit']?.toString() ?? '');
    _maxDepositCtrl = TextEditingController(
        text: p?['max_deposit']?.toString() ?? '');
    _savTenureCtrl = TextEditingController(
        text: p?['tenure']?.toString() ?? '12');
    _prematurePenaltyCtrl = TextEditingController(
        text: p?['premature_penalty']?.toString() ?? '0');
    _defaultInstallmentCtrl = TextEditingController(
        text: p?['default_installment']?.toString() ?? '');
    _defaultMaturityCtrl = TextEditingController(
        text: p?['default_maturity_amount']?.toString() ?? '');
    _collectionType = p?['collection_type']?.toString() ?? 'monthly';
    _savTenureUnit = p?['tenure_unit']?.toString() ?? 'months';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _interestRateCtrl.dispose();
    _minAmountCtrl.dispose();
    _maxAmountCtrl.dispose();
    _tenureCtrl.dispose();
    _feeCtrl.dispose();
    _penaltyCtrl.dispose();
    _graceCtrl.dispose();
    _defaultPrincipalCtrl.dispose();
    _savInterestRateCtrl.dispose();
    _minDepositCtrl.dispose();
    _maxDepositCtrl.dispose();
    _savTenureCtrl.dispose();
    _prematurePenaltyCtrl.dispose();
    _defaultInstallmentCtrl.dispose();
    _defaultMaturityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoan = widget.productType == ProductType.loan;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.fromLTRB(
          24, 8, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            // Header
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              _isEdit
                  ? (isLoan ? 'Edit Loan Product' : 'Edit Savings Product')
                  : (isLoan ? 'New Loan Product' : 'New Savings Product'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),

            // Name
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Product Name *',
                hintText: 'e.g. Personal Loan, Gold Loan',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            // Description
            TextFormField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Brief description of this product',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            if (isLoan) ..._buildLoanFields(theme),
            if (!isLoan) ..._buildSavingsFields(theme),

            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(
                  _saving ? 'Saving...' : (_isEdit ? 'Update Product' : 'Create Product'),
                  style:
                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLoanFields(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final primary = AppColors.primary;
    final double principalVal = double.tryParse(_defaultPrincipalCtrl.text) ?? 50000;
    final double rateVal = double.tryParse(_interestRateCtrl.text) ?? 0;

    return [
      // ── Interest Mode Toggle ──
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
                isSelected: _interestMode == 'rate',
                onTap: () => setState(() {
                  _interestMode = 'rate';
                  _interestLogic = 'reducingBalance';
                }),
                theme: theme,
                primary: primary,
              ),
            ),
            Expanded(
              child: _buildInterestModeTab(
                label: 'Interest Amount',
                subtitle: 'Fixed ₹',
                isSelected: _interestMode == 'amount',
                onTap: () => setState(() {
                  _interestMode = 'amount';
                }),
                theme: theme,
                primary: primary,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      if (_interestMode == 'rate') ...[
        _buildLabel('INTEREST BASIS', theme),
        const SizedBox(height: 10),
        _buildDropdown(
          value: _interestBasis,
          hint: 'Rate basis',
          items: const ['daily', 'weekly', 'monthly', 'yearly', 'onPrincipal'],
          itemLabels: const ['Per Day', 'Per Week', 'Per Month', 'Per Year', '% of Principal'],
          onChanged: (v) => setState(() => _interestBasis = v ?? 'onPrincipal'),
          theme: theme,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildLabel('INTEREST RATE (%)', theme),
        const SizedBox(height: 10),
        _buildTextField(
          controller: _interestRateCtrl,
          suffix: '%',
          onChanged: (val) => setState(() {}),
          theme: theme,
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        _buildSlider(
          value: rateVal.clamp(0, _interestBasis == 'onPrincipal' ? 100 : 50),
          min: 0,
          max: _interestBasis == 'onPrincipal' ? 100 : 50,
          displayValue: '${rateVal.toStringAsFixed(1)}%',
          minLabel: '0%',
          maxLabel: _interestBasis == 'onPrincipal' ? '100%' : '50%',
          onChanged: (val) {
            _interestRateCtrl.text = val.toStringAsFixed(1);
            setState(() {});
          },
          theme: theme,
          primary: primary,
        ),
      ] else ...[
        _buildLabel('INTEREST BASIS', theme),
        const SizedBox(height: 10),
        _buildDropdown(
          value: _interestBasis,
          hint: 'Interest basis',
          items: const ['daily', 'weekly', 'monthly', 'yearly', 'onPrincipal'],
          itemLabels: const ['Per Day', 'Per Week', 'Per Month', 'Per Year', 'On Principal'],
          onChanged: (v) => setState(() => _interestBasis = v ?? 'onPrincipal'),
          theme: theme,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildLabel('INTEREST AMOUNT (₹)', theme),
        const SizedBox(height: 10),
        _buildTextField(
          controller: _interestRateCtrl,
          prefix: '₹',
          onChanged: (val) => setState(() {}),
          theme: theme,
          isDark: isDark,
        ),
      ],

      _buildDivider(theme),

      // ── Interest Calculation ──
      _buildLabel('INTEREST CALCULATION', theme),
      const SizedBox(height: 10),
      _buildDropdown(
        value: _interestLogic,
        hint: 'Calculation method',
        items: const ['reducingBalance', 'flat'],
        itemLabels: const ['Reducing Balance', 'Flat'],
        onChanged: (v) => setState(() => _interestLogic = v ?? 'reducingBalance'),
        theme: theme,
        isDark: isDark,
      ),

      _buildDivider(theme),

      // ── Principal ──
      _buildLabel('DEFAULT PRINCIPAL AMOUNT (₹)', theme),
      const SizedBox(height: 10),
      _buildTextField(
        controller: _defaultPrincipalCtrl,
        prefix: '₹',
        onChanged: (val) => setState(() {}),
        theme: theme,
        isDark: isDark,
      ),
      const SizedBox(height: 8),
      _buildSlider(
        value: principalVal.clamp(1000, 1000000),
        min: 1000,
        max: 1000000,
        displayValue: '₹${principalVal.toInt()}',
        minLabel: '₹1K',
        maxLabel: '₹10L',
        onChanged: (val) {
          _defaultPrincipalCtrl.text = val.toInt().toString();
          setState(() {});
        },
        theme: theme,
        primary: primary,
      ),

      _buildDivider(theme),

      // ── Tenure ──
      _buildLabel('LOAN TENURE', theme),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            flex: 3,
            child: _buildTextField(
              controller: _tenureCtrl,
              onChanged: (val) {},
              theme: theme,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _buildDropdown(
              value: _tenureUnit,
              hint: 'Unit',
              items: const ['months', 'weeks', 'days'],
              itemLabels: const ['Months', 'Weeks', 'Days'],
              onChanged: (v) => setState(() => _tenureUnit = v ?? 'months'),
              theme: theme,
              isDark: isDark,
            ),
          ),
        ],
      ),

      _buildDivider(theme),

      // ── Collection Type ──
      _buildLabel('COLLECTION TYPE', theme),
      const SizedBox(height: 10),
      _buildDropdown(
        value: _frequency,
        hint: 'Select',
        items: const ['monthly', 'weekly', 'daily'],
        itemLabels: const ['Monthly', 'Weekly', 'Daily'],
        onChanged: (v) => setState(() => _frequency = v ?? 'monthly'),
        theme: theme,
        isDark: isDark,
      ),
    ];
  }

  List<Widget> _buildSavingsFields(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final primary = AppColors.success;
    final double installmentVal = double.tryParse(_defaultInstallmentCtrl.text) ?? 1000;
    final double maturityVal = double.tryParse(_defaultMaturityCtrl.text) ?? 12500;

    return [
      // ── Collection Cycle & Installment ──
      _buildLabel('COLLECTION CYCLE', theme),
      const SizedBox(height: 10),
      _buildDropdown(
        value: _collectionType,
        hint: 'Select',
        items: const ['monthly', 'weekly', 'daily', 'yearly'],
        itemLabels: const ['Monthly', 'Weekly', 'Daily', 'Yearly'],
        onChanged: (v) => setState(() => _collectionType = v ?? 'monthly'),
        theme: theme,
        isDark: isDark,
      ),
      const SizedBox(height: 16),

      _buildLabel('INSTALLMENT AMOUNT (₹)', theme),
      const SizedBox(height: 10),
      _buildTextField(
        controller: _defaultInstallmentCtrl,
        prefix: '₹',
        onChanged: (val) => setState(() {}),
        theme: theme,
        isDark: isDark,
      ),
      const SizedBox(height: 8),
      _buildSlider(
        value: installmentVal.clamp(10, 50000),
        min: 10,
        max: 50000,
        displayValue: '₹${installmentVal.toInt()}',
        minLabel: '₹10',
        maxLabel: '₹50K',
        onChanged: (val) {
          _defaultInstallmentCtrl.text = val.toInt().toString();
          setState(() {});
        },
        theme: theme,
        primary: primary,
      ),

      _buildDivider(theme),

      // ── Tenure ──
      _buildLabel('TENURE', theme),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildTextField(
              controller: _savTenureCtrl,
              onChanged: (val) {},
              theme: theme,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _buildDropdown(
              value: _savTenureUnit,
              hint: 'Unit',
              items: const ['months', 'weeks', 'days', 'years'],
              itemLabels: const ['Months', 'Weeks', 'Days', 'Years'],
              onChanged: (v) => setState(() => _savTenureUnit = v ?? 'months'),
              theme: theme,
              isDark: isDark,
            ),
          ),
        ],
      ),

      _buildDivider(theme),

      // ── Maturity Amount ──
      _buildLabel('MATURITY AMOUNT (₹)', theme),
      const SizedBox(height: 10),
      _buildTextField(
        controller: _defaultMaturityCtrl,
        prefix: '₹',
        onChanged: (val) => setState(() {}),
        theme: theme,
        isDark: isDark,
      ),
      const SizedBox(height: 8),
      _buildSlider(
        value: maturityVal.clamp(1000, 5000000),
        min: 1000,
        max: 5000000,
        displayValue: '₹${maturityVal.toInt()}',
        minLabel: '₹1K',
        maxLabel: '₹50L',
        onChanged: (val) {
          _defaultMaturityCtrl.text = val.toInt().toString();
          setState(() {});
        },
        theme: theme,
        primary: primary,
      ),
    ];
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (widget.productType == ProductType.loan) {
        await _saveLoan();
      } else {
        await _saveSavings();
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to save: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveLoan() async {
    final service = ref.read(loanProductsServiceProvider);
    final params = {
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'interestRate': double.tryParse(_interestRateCtrl.text.trim()) ?? 0,
      'interestMode': _interestMode,
      'interestBasis': _interestBasis,
      'interestLogic': _interestLogic,
      'defaultPrincipal': _defaultPrincipalCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_defaultPrincipalCtrl.text.trim()),
      'minAmount': _minAmountCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_minAmountCtrl.text.trim()),
      'maxAmount': _maxAmountCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_maxAmountCtrl.text.trim()),
      'tenureMonths': int.tryParse(_tenureCtrl.text.trim()) ?? 12,
      'tenureUnit': _tenureUnit,
      'frequency': _frequency,
      'processingFee': double.tryParse(_feeCtrl.text.trim()) ?? 0,
      'latePenaltyPct': double.tryParse(_penaltyCtrl.text.trim()) ?? 0,
      'gracePeriodDays': int.tryParse(_graceCtrl.text.trim()) ?? 0,
    };

    if (_isEdit) {
      await service.updateProduct(widget.existingProduct!['id'], name: params['name'] as String, description: params['description'] as String?, interestRate: params['interestRate'] as double, interestMode: params['interestMode'] as String, interestBasis: params['interestBasis'] as String, interestLogic: params['interestLogic'] as String, defaultPrincipal: params['defaultPrincipal'] as double?, minAmount: params['minAmount'] as double?, maxAmount: params['maxAmount'] as double?, tenureMonths: params['tenureMonths'] as int, tenureUnit: params['tenureUnit'] as String, frequency: params['frequency'] as String, processingFee: params['processingFee'] as double, latePenaltyPct: params['latePenaltyPct'] as double, gracePeriodDays: params['gracePeriodDays'] as int);
    } else {
      await service.createProduct(
        name: params['name'] as String,
        description: params['description'] as String?,
        interestRate: params['interestRate'] as double,
        interestMode: params['interestMode'] as String,
        interestBasis: params['interestBasis'] as String,
        interestLogic: params['interestLogic'] as String,
        defaultPrincipal: params['defaultPrincipal'] as double?,
        minAmount: params['minAmount'] as double?,
        maxAmount: params['maxAmount'] as double?,
        tenureMonths: params['tenureMonths'] as int,
        tenureUnit: params['tenureUnit'] as String,
        frequency: params['frequency'] as String,
        processingFee: params['processingFee'] as double,
        latePenaltyPct: params['latePenaltyPct'] as double,
        gracePeriodDays: params['gracePeriodDays'] as int,
      );
    }
    ref.invalidate(loanProductsProvider);
  }

  Future<void> _saveSavings() async {
    final service = ref.read(savingsProductsServiceProvider);
    final params = {
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'interestRate': double.tryParse(_savInterestRateCtrl.text.trim()) ?? 0,
      'collectionType': _collectionType,
      'minDeposit': _minDepositCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_minDepositCtrl.text.trim()),
      'maxDeposit': _maxDepositCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_maxDepositCtrl.text.trim()),
      'tenure': int.tryParse(_savTenureCtrl.text.trim()) ?? 12,
      'tenureUnit': _savTenureUnit,
      'prematurePenalty': double.tryParse(_prematurePenaltyCtrl.text.trim()) ?? 0,
      'defaultInstallment': _defaultInstallmentCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_defaultInstallmentCtrl.text.trim()),
      'defaultMaturityAmount': _defaultMaturityCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_defaultMaturityCtrl.text.trim()),
    };

    if (_isEdit) {
      await service.updateProduct(widget.existingProduct!['id'], name: params['name'] as String, description: params['description'] as String?, interestRate: params['interestRate'] as double, collectionType: params['collectionType'] as String, minDeposit: params['minDeposit'] as double?, maxDeposit: params['maxDeposit'] as double?, tenure: params['tenure'] as int, tenureUnit: params['tenureUnit'] as String, prematurePenalty: params['prematurePenalty'] as double, defaultInstallment: params['defaultInstallment'] as double?, defaultMaturityAmount: params['defaultMaturityAmount'] as double?);
    } else {
      await service.createProduct(
        name: params['name'] as String,
        description: params['description'] as String?,
        interestRate: params['interestRate'] as double,
        collectionType: params['collectionType'] as String,
        minDeposit: params['minDeposit'] as double?,
        maxDeposit: params['maxDeposit'] as double?,
        tenure: params['tenure'] as int,
        tenureUnit: params['tenureUnit'] as String,
        prematurePenalty: params['prematurePenalty'] as double,
        defaultInstallment: params['defaultInstallment'] as double?,
        defaultMaturityAmount: params['defaultMaturityAmount'] as double?,
      );
    }
    ref.invalidate(savingsProductsProvider);
  }

  // ═══════════════════════════════════════════════════
  //  UI HELPERS (matching loan creation page)
  // ═══════════════════════════════════════════════════

  Widget _buildLabel(String text, ThemeData theme) {
    return Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700, letterSpacing: 0.8, fontSize: 11),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.12)),
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
                itemLabels != null ? itemLabels[index] : item[0].toUpperCase() + item.substring(1);
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
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? primary
                : theme.dividerColor.withValues(alpha: 0.12),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isSelected ? primary : theme.textTheme.bodyMedium?.color)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 11,
                    color: isSelected
                        ? primary.withValues(alpha: 0.7)
                        : theme.textTheme.bodySmall?.color)),
          ],
        ),
      ),
    );
  }
}
