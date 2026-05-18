import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../../core/widgets/glass_card.dart';

/// Loads the current org row for editing.
final _orgProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  final row =
      await client.from('organizations').select().eq('id', orgId).single();
  return row;
});

/// Organization Profile — Exec Admin owns this.
///
/// Schema strategy:
///   • Core fields use existing top-level columns of [organizations].
///   • New compliance fields (PAN, license, fiscal year, currency, locale,
///     timezone) go inside the existing [settings] JSONB column under the
///     "profile" key — no SQL migration required.
///
/// Persisted JSON shape (in organizations.settings):
///   {
///     "profile": {
///       "pan_number":   "ABCDE1234F",
///       "license_number": "NBFC-N-12.345",
///       "fiscal_year_start_month": 4,    // 1-12 (Apr=4 for India)
///       "currency": "INR",
///       "locale":   "en_IN",
///       "timezone": "Asia/Kolkata"
///     }
///   }
class OrganizationProfilePage extends ConsumerStatefulWidget {
  const OrganizationProfilePage({super.key});

  @override
  ConsumerState<OrganizationProfilePage> createState() =>
      _OrganizationProfilePageState();
}

class _OrganizationProfilePageState
    extends ConsumerState<OrganizationProfilePage> {
  final _formKey = GlobalKey<FormState>();

  // Identity
  final _legalNameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _domainCtrl = TextEditingController();

  // Compliance
  final _gstCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();

  // Address
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();

  // Contact
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // Locale
  String _currency = 'INR';
  String _locale = 'en_IN';
  String _timezone = 'Asia/Kolkata';
  int _fyStartMonth = 4; // April

  bool _initialized = false;
  bool _saving = false;

  static const _currencies = ['INR', 'USD', 'EUR', 'GBP', 'BDT', 'NPR', 'LKR'];
  static const _locales = [
    'en_IN',
    'hi_IN',
    'bn_IN',
    'ta_IN',
    'te_IN',
    'mr_IN',
    'en_US',
    'en_GB',
  ];
  static const _timezones = [
    'Asia/Kolkata',
    'Asia/Dhaka',
    'Asia/Kathmandu',
    'Asia/Colombo',
    'UTC',
    'America/New_York',
    'Europe/London',
  ];
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void dispose() {
    _legalNameCtrl.dispose();
    _displayNameCtrl.dispose();
    _domainCtrl.dispose();
    _gstCtrl.dispose();
    _panCtrl.dispose();
    _licenseCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _hydrate(Map<String, dynamic> org) {
    if (_initialized) return;
    _legalNameCtrl.text = (org['name'] as String?) ?? '';
    _displayNameCtrl.text = (org['display_name'] as String?) ?? '';
    _domainCtrl.text = (org['domain'] as String?) ?? '';
    _gstCtrl.text = (org['gst_number'] as String?) ?? '';
    _addressCtrl.text = (org['address'] as String?) ?? '';
    _cityCtrl.text = (org['city'] as String?) ?? '';
    _stateCtrl.text = (org['state'] as String?) ?? '';
    _pincodeCtrl.text = (org['pincode'] as String?) ?? '';
    _phoneCtrl.text = (org['phone'] as String?) ?? '';
    _emailCtrl.text = (org['email'] as String?) ?? '';

    final settings = (org['settings'] as Map?)?.cast<String, dynamic>() ?? {};
    final profile =
        (settings['profile'] as Map?)?.cast<String, dynamic>() ?? {};
    _panCtrl.text = (profile['pan_number'] as String?) ?? '';
    _licenseCtrl.text = (profile['license_number'] as String?) ?? '';
    _currency = (profile['currency'] as String?) ?? 'INR';
    _locale = (profile['locale'] as String?) ?? 'en_IN';
    _timezone = (profile['timezone'] as String?) ?? 'Asia/Kolkata';
    final fy = profile['fiscal_year_start_month'];
    _fyStartMonth = fy is int ? fy : (fy is num ? fy.toInt() : 4);

    _initialized = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final orgId = ref.read(currentOrgIdOrThrowProvider);

      // Read existing settings to preserve other keys.
      final existing =
          await client.from('organizations').select('settings').eq('id', orgId).single();
      final existingSettings =
          (existing['settings'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};

      final mergedSettings = <String, dynamic>{
        ...existingSettings,
        'profile': {
          'pan_number': _panCtrl.text.trim(),
          'license_number': _licenseCtrl.text.trim(),
          'fiscal_year_start_month': _fyStartMonth,
          'currency': _currency,
          'locale': _locale,
          'timezone': _timezone,
        },
      };

      await client.from('organizations').update({
        'name': _legalNameCtrl.text.trim(),
        'display_name': _displayNameCtrl.text.trim().isEmpty
            ? null
            : _displayNameCtrl.text.trim(),
        'domain': _domainCtrl.text.trim().isEmpty
            ? null
            : _domainCtrl.text.trim(),
        'gst_number': _gstCtrl.text.trim().isEmpty
            ? null
            : _gstCtrl.text.trim(),
        'address': _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        'state':
            _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
        'pincode': _pincodeCtrl.text.trim().isEmpty
            ? null
            : _pincodeCtrl.text.trim(),
        'phone':
            _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'email':
            _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'settings': mergedSettings,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', orgId);

      ref.invalidate(_orgProfileProvider);
      ref.invalidate(currentOrgProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text('Organization profile saved'),
          ]),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncOrg = ref.watch(_orgProfileProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Organization Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: asyncOrg.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load organization\n\n$e',
                textAlign: TextAlign.center),
          ),
        ),
        data: (org) {
          _hydrate(org);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Section(
                    title: 'Identity',
                    icon: Icons.business_outlined,
                    children: [
                      _TextField(
                        controller: _legalNameCtrl,
                        label: 'Legal Name *',
                        hint: 'Registered name on incorporation docs',
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                      ),
                      _TextField(
                        controller: _displayNameCtrl,
                        label: 'Display Name',
                        hint: 'Friendly brand name shown in app',
                      ),
                      _TextField(
                        controller: _domainCtrl,
                        label: 'Website / Domain',
                        hint: 'example.com',
                        keyboardType: TextInputType.url,
                      ),
                    ],
                  ).animate().fadeIn().slideY(begin: 0.04, end: 0),
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Compliance & Registration',
                    icon: Icons.verified_outlined,
                    children: [
                      _TextField(
                        controller: _gstCtrl,
                        label: 'GST Number',
                        hint: '15-digit GSTIN',
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 15,
                      ),
                      _TextField(
                        controller: _panCtrl,
                        label: 'PAN Number',
                        hint: '10-character PAN',
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 10,
                        validator: (v) {
                          if (v == null || v.isEmpty) return null;
                          final ok = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$')
                              .hasMatch(v.trim());
                          return ok ? null : 'Invalid PAN format';
                        },
                      ),
                      _TextField(
                        controller: _licenseCtrl,
                        label: 'License / NBFC Registration No.',
                        hint: 'RBI / regulatory registration ID',
                      ),
                    ],
                  ).animate(delay: 50.ms).fadeIn().slideY(begin: 0.04, end: 0),
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Registered Address',
                    icon: Icons.location_on_outlined,
                    children: [
                      _TextField(
                        controller: _addressCtrl,
                        label: 'Street Address',
                        maxLines: 2,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _TextField(
                              controller: _cityCtrl,
                              label: 'City',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TextField(
                              controller: _stateCtrl,
                              label: 'State',
                            ),
                          ),
                        ],
                      ),
                      _TextField(
                        controller: _pincodeCtrl,
                        label: 'Pincode',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        maxLength: 6,
                      ),
                    ],
                  ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.04, end: 0),
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Contact',
                    icon: Icons.phone_outlined,
                    children: [
                      _TextField(
                        controller: _phoneCtrl,
                        label: 'Phone',
                        keyboardType: TextInputType.phone,
                      ),
                      _TextField(
                        controller: _emailCtrl,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+')
                              .hasMatch(v.trim());
                          return ok ? null : 'Invalid email';
                        },
                      ),
                    ],
                  ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.04, end: 0),
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Financial & Locale',
                    icon: Icons.public_rounded,
                    children: [
                      _DropdownField<int>(
                        label: 'Financial Year Start',
                        value: _fyStartMonth,
                        items: List.generate(
                          12,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text(_months[i]),
                          ),
                        ),
                        onChanged: (v) =>
                            setState(() => _fyStartMonth = v ?? 4),
                        helper: 'Month your fiscal year begins (Apr for India)',
                      ),
                      _DropdownField<String>(
                        label: 'Currency',
                        value: _currency,
                        items: _currencies
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _currency = v ?? 'INR'),
                      ),
                      _DropdownField<String>(
                        label: 'Locale',
                        value: _locale,
                        items: _locales
                            .map((l) =>
                                DropdownMenuItem(value: l, child: Text(l)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _locale = v ?? 'en_IN'),
                      ),
                      _DropdownField<String>(
                        label: 'Timezone',
                        value: _timezone,
                        items: _timezones
                            .map((t) =>
                                DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _timezone = v ?? 'Asia/Kolkata'),
                      ),
                    ],
                  ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.04, end: 0),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                          : const Icon(Icons.save_rounded),
                      label: Text(_saving ? 'Saving…' : 'Save Changes',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              letterSpacing: -0.3)),
                    ),
                  ).animate(delay: 250.ms).fadeIn(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Reusable form widgets ────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Text(title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;

  const _TextField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        textCapitalization: textCapitalization,
        validator: validator,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          counterText: maxLength != null ? '' : null,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? helper;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
