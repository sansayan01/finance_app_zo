import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/utils/formatters.dart' show AppFormatters;
import '../../../../providers/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../payments/data/services/upi_service.dart';
import '../../../payments/data/providers/upi_providers.dart';
import '../../../../core/services/app_icon_service.dart';
import '../../../home/data/providers/dashboard_providers.dart'
    show dashboardLoansProvider, dashboardTransactionsProvider, activeLoansProvider, loanSummaryProvider;
import '../../../../core/providers/branding_provider.dart';
import '../../../../core/providers/sms_provider.dart';
import '../../../savings/data/models/savings_model.dart';
import '../../../savings/data/models/savings_installment_model.dart';
import '../../../savings/data/providers/savings_providers.dart'
    show allSavingsProvider, savingDetailProvider, savingsScheduleProvider, savingsSummaryProvider, memberSavingsProvider;
import '../../../staff/data/providers/staff_providers.dart' show staffProfileProvider;
import '../../data/models/emi_schedule_model.dart';
import '../../data/models/loan_model.dart';
import '../../data/repositories/emi_repository.dart';
import '../../../savings/data/repositories/savings_repository.dart';
import '../providers/loan_providers.dart';
import '../../../payments/data/providers/payment_providers.dart';
import '../../../branch_manager/data/providers/branch_payment_providers.dart';
import 'emi_payment_selector.dart';
import '../../../savings/presentation/widgets/savings_payment_selector.dart';
import '../../../../core/widgets/premium_calendar_sheet.dart';

/// Collection mode -- determines which collection type to process
enum CollectionMode { loan, savings }

class CollectionSheet extends ConsumerStatefulWidget {
  /// Loan mode: provide [loan]
  final LoanModel? loan;
  final EMIScheduleModel? emi;

  /// Savings mode: provide [savingsPlan]
  final SavingsModel? savingsPlan;

  /// Required: which mode to use
  final CollectionMode mode;

  /// Branch ID for provider invalidation (needed for branchTodayPaymentsProvider)
  final String? branchId;

  const CollectionSheet({
    super.key,
    this.loan,
    this.emi,
    this.savingsPlan,
    this.mode = CollectionMode.loan,
    this.branchId,
  }) : assert(
          mode == CollectionMode.loan ? loan != null : savingsPlan != null,
          'loan is required for loan mode, savingsPlan for savings mode',
        );

  /// Convenience constructor for savings collection mode
  // ignore: prefer_const_constructors_in_immutables
  CollectionSheet.savings({
    super.key,
    required SavingsModel savingsPlan,
    // ignore: unnecessary_this
    this.branchId,
  })  : loan = null,
        emi = null,
        // ignore: unnecessary_this, prefer_initializing_formals
        this.savingsPlan = savingsPlan,
        mode = CollectionMode.savings;

  @override
  ConsumerState<CollectionSheet> createState() => _CollectionSheetState();
}

class _CollectionSheetState extends ConsumerState<CollectionSheet> {
  String _selectedMode = 'cash';
  bool _isSubmitting = false;
  bool _isBackdated = false;
  DateTime? _customCollectionDate;

  // UPI QR state
  bool _showUpiQr = false;
  String? _upiVpa;
  String? _upiMerchantName;
  bool _isProcessingUpi = false;
  bool _upiLoadError = false;

  /// Dynamically builds the UPI URI with the current total amount.
  String? get _currentUpiUri {
    if (_upiVpa == null) return null;
    final note = widget.mode == CollectionMode.savings
        ? 'Savings ${widget.savingsPlan?.planName ?? ""}'
        : 'Loan ${widget.loan?.loanNumber ?? ""} EMI';
    return UpiService.buildUpiUri(
      vpa: _upiVpa!,
      amount: _totalAmount,
      merchantName: _upiMerchantName ?? '',
      transactionNote: note,
    );
  }

  List<EMIScheduleModel> _allEMIs = [];
  /// IDs of EMIs the user has selected for payment.
  final Set<String> _selectedEmiIds = {};

  // Savings mode state
  List<SavingsInstallment> _savingsSchedule = [];
  final Set<String> _selectedSavingsDates = {};

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    if (widget.mode == CollectionMode.savings) {
      await _loadSavingsSchedule();
      return;
    }
    try {
      final schedule =
          await ref.read(emiScheduleProvider(widget.loan!.id).future);

      if (mounted) {
        setState(() {
          _allEMIs = schedule;
          // Auto-select first unpaid EMI if none selected yet
          if (_selectedEmiIds.isEmpty && schedule.isNotEmpty) {
            final unpaid = schedule
                .where((e) =>
                    e.status != EMIStatus.paid &&
                    e.status != EMIStatus.waived)
                .toList()
              ..sort((a, b) => a.emiNumber.compareTo(b.emiNumber));
            if (unpaid.isNotEmpty) {
              _selectedEmiIds.add(unpaid.first.id);
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSavingsSchedule() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final plan = widget.savingsPlan!;
      final paidDates = await SavingsScheduleGenerator.fetchPaidDates(
        client: client,
        planId: plan.id,
      );
      final schedule = SavingsScheduleGenerator.generate(
        plan: plan,
        paidDates: paidDates,
      );
      if (mounted) {
        setState(() {
          _savingsSchedule = schedule;
          // Auto-select first unpaid installment
          final firstUnpaid = schedule.where((s) => !s.isPaid).toList();
          if (firstUnpaid.isNotEmpty) {
            _selectedSavingsDates.add(_dateKey(firstUnpaid.first.dueDate));
          }
        });
      }
    } catch (_) {}
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _loadUpiConfig() async {
    try {
      final upiService = ref.read(upiServiceProvider);
      final vpaData = await upiService.getOrgVpa();
      if (vpaData == null || !mounted) {
        if (mounted) setState(() => _upiLoadError = true);
        return;
      }
      final vpa = vpaData['upi_vpa'] as String?;
      final merchant = vpaData['merchant_name'] as String? ?? '';
      if (vpa == null || vpa.isEmpty) {
        if (mounted) setState(() => _upiLoadError = true);
        return;
      }

      if (mounted) {
        setState(() {
          _upiVpa = vpa;
          _upiMerchantName = merchant;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _upiLoadError = true);
    }
  }

  Future<void> _openUpiApp() async {
    final uri = _currentUpiUri;
    if (uri == null) return;
    final launched = await launchUrl(Uri.parse(uri), mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No UPI app found. Scan the QR code directly.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _confirmUpiAndSubmit() async {
    if (_isProcessingUpi) return;
    setState(() => _isProcessingUpi = true);
    HapticFeedback.mediumImpact();

    try {
      // _submit() handles the collection, snackbar, and Navigator.pop
      await _submit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('UPI collection failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingUpi = false);
    }
  }

  /// The currently selected unpaid EMIs (looked up from the full schedule).
  List<EMIScheduleModel> get _selectedEMIs =>
      _allEMIs.where((e) => _selectedEmiIds.contains(e.id)).toList();

  /// The primary (first) selected EMI, used as the collection's
  /// `selected_schedule_id`.
  EMIScheduleModel? get _primarySelectedEMI =>
      _selectedEMIs.isNotEmpty ? _selectedEMIs.first : null;

  /// Whether we have any selection (EMI or savings dates).
  bool get _hasSelection {
    if (widget.mode == CollectionMode.savings) {
      return _selectedSavingsDates.isNotEmpty;
    }
    return _selectedEmiIds.isNotEmpty;
  }

  /// Sum of all selected EMIs or savings installments.
  double get _totalAmount {
    if (widget.mode == CollectionMode.savings) {
      return _savingsSchedule
          .where((s) => _selectedSavingsDates.contains(_dateKey(s.dueDate)))
          .fold<double>(0.0, (sum, s) => sum + s.amount);
    }
    return _selectedEMIs.fold<double>(0.0, (sum, e) => sum + e.emiAmount);
  }

  /// Returns created_at timestamp: backdated date when active, else now.
  String _getCreatedAt() {
    if (_isBackdated && _customCollectionDate != null) {
      final now = DateTime.now();
      final backdated = DateTime(
        _customCollectionDate!.year,
        _customCollectionDate!.month,
        _customCollectionDate!.day,
        now.hour, now.minute, now.second,
      );
      final ist = backdated.toUtc().add(const Duration(hours: 5, minutes: 30));
      return ist.toIso8601String().replaceFirst('Z', '+05:30');
    }
    return AppFormatters.nowIST();
  }

  // ─── Theme Helpers ───
  bool get _isDark =>
      Theme.of(context).brightness == Brightness.dark;

  Color get _textSecondary =>
      _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

  Color get _fillColor =>
      _isDark ? AppColors.fillDark : AppColors.fillLight;

  Color get _separator =>
      _isDark ? AppColors.separatorDark : AppColors.separatorLight;

  // ─── Premium Payment Mode Chip ───
  Widget _buildPaymentModeChip({
    required IconData icon,
    required String label,
    required String mode,
  }) {
    final isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedMode = mode);
        if (mode == 'upi') {
          setState(() => _showUpiQr = true);
          if (_upiVpa == null && !_upiLoadError) _loadUpiConfig();
        } else {
          setState(() => _showUpiQr = false);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: isSelected
            ? BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                    spreadRadius: -1,
                  ),
                ],
              )
            : BoxDecoration(
                color: _fillColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _separator,
                  width: 1,
                ),
              ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? Colors.white
                  : _textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── UPI QR Section (premium inline) ───
  Widget _buildUpiQrSection(NumberFormat currencyFormat) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDark
              ? const [Color(0xFF0A0F1E), Color(0xFF111827)]
              : const [Color(0xFF0F172A), Color(0xFF1E3A5F)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Top bar ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white70, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan & Pay',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ask the customer to scan this QR',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: AppColors.successGradient),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    currencyFormat.format(_totalAmount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── QR Code ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _upiLoadError
                ? _buildQrErrorState()
                : _currentUpiUri != null
                    ? _buildPremiumQrFrame()
                    : _buildQrLoadingState(),
          ),

          // ── VPA ──
          if (_upiVpa != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_balance_wallet_rounded, size: 13, color: Colors.white.withValues(alpha: 0.4)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _upiVpa!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Action buttons ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showUpiQr = false),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Center(
                        child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white.withValues(alpha: 0.5))),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (_currentUpiUri != null)
                  Expanded(
                    child: GestureDetector(
                      onTap: _openUpiApp,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.primary),
                              const SizedBox(width: 5),
                              Text('Open UPI', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_currentUpiUri != null) const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _isProcessingUpi || !_hasSelection ? null : _confirmUpiAndSubmit,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: _isProcessingUpi || !_hasSelection
                            ? [Colors.grey.shade600, Colors.grey.shade700]
                            : [AppColors.success, AppColors.mint]),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: _isProcessingUpi || !_hasSelection
                            ? []
                            : [BoxShadow(color: AppColors.success.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Center(
                        child: _isProcessingUpi
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                                  SizedBox(width: 6),
                                  Text('Payment Successful', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumQrFrame() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 4)),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            QrImageView(
              data: _currentUpiUri!,
              version: QrVersions.auto,
              size: 200,
              gapless: true,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.H,
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF0B1D3A)),
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0E8A7D)),
            ),
            _buildCenterBadge(),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterBadge() {
    return FutureBuilder<String>(
      future: _getIconPreset(),
      builder: (context, snapshot) {
        final presetId = snapshot.data ?? 'default';
        final preset = IconPresets.getById(presetId);
        return Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            preset.assetPreview,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackBadge(),
          ),
        );
      },
    );
  }

  Future<String> _getIconPreset() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final user = ref.read(currentUserProvider);
      if (user?.orgId == null) return 'default';
      final data = await client
          .from('organizations')
          .select('icon_preset')
          .eq('id', user!.orgId!)
          .maybeSingle();
      return data?['icon_preset'] as String? ?? 'default';
    } catch (_) {
      return 'default';
    }
  }

  Widget _buildFallbackBadge() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppColors.successGradient),
      ),
      child: Center(
        child: Text(
          'UPI',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
        ),
      ),
    );
  }

  Widget _buildQrErrorState() {
    return Center(
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.error, size: 32),
            const SizedBox(height: 8),
            Text('UPI not configured', style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                setState(() { _upiLoadError = false; _upiVpa = null; _upiMerchantName = null; });
                _loadUpiConfig();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Text('Retry', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrLoadingState() {
    return Center(
      child: SizedBox(
        width: 200,
        height: 200,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(height: 12),
            Text('Loading QR...', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      if (widget.mode == CollectionMode.savings) {
        await _submitSavings();
      } else {
        await _submitLoan();
      }

      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.mode == CollectionMode.savings
                  ? '${_selectedSavingsDates.length} installment${_selectedSavingsDates.length > 1 ? 's' : ''} \u00b7 '
                      '\u20b9${_totalAmount.toStringAsFixed(0)} deposited for ${widget.savingsPlan!.planName}'
                  : '${_selectedEMIs.length > 1 ? '${_selectedEMIs.length} EMIs \u00b7 ' : ''}'
                      '\u20b9${_totalAmount.toStringAsFixed(0)} collected from ${widget.loan!.customerName}',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Collection failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─── Loan (EMI) Collection ───
  Future<void> _submitLoan() async {
    final client = Supabase.instance.client;
    final user = ref.read(currentUserProvider);
    if (user == null || user.orgId == null) {
      throw Exception('User not found');
    }

    final profile = await client
        .from('profiles')
        .select('id, full_name, role')
        .eq('user_id', user.id)
        .maybeSingle();
    final staffId = profile?['id'] as String?;
    if (staffId == null) {
      throw Exception('Staff profile not found');
    }
    final now = DateTime.now();
    final today = now.toIso8601String().split('T').first;
    final amount = _totalAmount;
    final selectedCount = _selectedEMIs.length;
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    // Resolve member name: prefer joined data, fallback to DB lookup
    String memberName = widget.loan!.customerName ?? '';
    if (memberName.isEmpty) {
      final memberId = widget.loan!.customerId.isNotEmpty
          ? widget.loan!.customerId
          : widget.loan!.memberId;
      if (memberId != null) {
        try {
          final member = await client
              .from('members')
              .select('full_name')
              .eq('id', memberId)
              .maybeSingle();
          memberName = member?['full_name']?.toString() ?? '';
        } catch (_) {}
      }
    }
    if (memberName.isEmpty) memberName = 'Unknown';

    // 1. Single transaction record for the total
    final txResult = await client.from('transactions').insert({
      'loan_id': widget.loan!.id,
      'member_id': widget.loan!.memberId,
      'member_name': memberName,
      'type': TransactionType.emiPayment.name,
      'amount': amount,
      'payment_mode': _selectedMode,
      'description': selectedCount > 1
            ? '$selectedCount EMIs paid via $_selectedMode'
            : 'EMI #${_primarySelectedEMI?.emiNumber ?? ''} payment via $_selectedMode',
      'org_id': user.orgId!,
      'created_at': _getCreatedAt(),
      'collected_by_name': profile?['full_name']?.toString(),
      'collected_by_role': profile?['role']?.toString() ?? 'collectionAgent',
      'collected_by_user_id': staffId,
    }).select('id').single();
    final transactionId = txResult['id'] as String;

    // 2. Insert ONE collection per selected EMI (each targets exactly one EMI)
    for (final emi in _selectedEMIs) {
      await client.from('collections').insert({
        'org_id': user.orgId!,
        'staff_id': staffId,
        'loan_id': widget.loan!.id,
        'member_id': widget.loan!.memberId,
        'member_name': memberName,
        'member_phone': widget.loan!.customerPhone,
        'loan_number': widget.loan!.loanNumber,
        'amount_expected': widget.loan!.emiAmount,
        'amount_collected': widget.loan!.emiAmount,
        'is_partial': false,
        'collection_type': 'emi',
        'payment_mode': _selectedMode,
        'collection_date': _isBackdated && _customCollectionDate != null
            ? DateFormat('yyyy-MM-dd').format(_customCollectionDate!)
            : today,
        'collection_time': timeStr,
        'sync_status': 'synced',
        'selected_schedule_id': emi.id,
        'transaction_id': transactionId,
      });

      // 2b. Directly mark this EMI as paid in the schedule table.
      //     The SQL trigger `update_schedule_on_collection_v2` is supposed to do
      //     this, but in practice it may not fire or may have race conditions.
      //     Updating here ensures the provider sees `is_paid = true` immediately
      //     so the EMI doesn't appear in the "Overdue" tab after collection.
      try {
        await client.from('emi_schedule').update({
          'is_paid': true,
          'paid_on': now.toIso8601String(),
          'payment_mode': _selectedMode,
          'is_overdue': false,
        }).eq('id', emi.id);
      } catch (e) {
        debugPrint('CollectionSheet: direct emi_schedule update failed: $e');
        // Non-fatal: the SQL trigger may still handle it
      }
    }

    // 3. Loan balance is updated automatically by the SQL trigger
    //    `update_schedule_on_collection_v2` when collections are inserted.
    //    Read the trigger-updated balance for SMS and status check.
    final loanResp = await client
        .from('loans')
        .select('outstanding_amount, outstanding_balance, status')
        .eq('id', widget.loan!.id)
        .maybeSingle();

    if (loanResp != null) {
      final currentBalance =
          ((loanResp['outstanding_amount'] ?? loanResp['outstanding_balance'])
                  as num?)
              ?.toDouble() ?? 0;

      // 3b. Dispatch SMS
      try {
        debugPrint('CollectionSheet: initiating SMS dispatch...');
        String? phone = widget.loan!.customerPhone;
        // SMS opt-out lives on the member row (members.sms_enabled is the only
        // SMS opt-out column that exists). Read it from there, not the loan.
        bool smsEnabled = true;
        String? memberId = widget.loan!.memberId ?? widget.loan!.customerId;
        try {
          final memberInfo = await client
              .from('members')
              .select('phone, sms_enabled')
              .eq('id', memberId)
              .maybeSingle();
          if (phone == null || phone.isEmpty) {
            phone = memberInfo?['phone']?.toString();
          }
          smsEnabled = memberInfo?['sms_enabled'] as bool? ?? true;
        } catch (_) {}

        final branding = ref.read(brandingProvider).valueOrNull;
        if (phone != null && phone.isNotEmpty) {
          debugPrint('CollectionSheet: enqueuing SMS to $phone (memberId: ${widget.loan!.customerId})');
          await ref.read(collectionSmsSenderProvider.notifier).enqueueCollection(
                phone: phone,
                memberId: widget.loan!.customerId,
                memberName: memberName,
                loanNumber: widget.loan!.loanNumber,
                amount: amount,
                outstandingBalance: currentBalance,
                collectorName: profile?['full_name'] ?? 'Staff',
                sentBy: staffId,
                orgName: branding?.displayName,
                smsEnabled: smsEnabled,
              );
        } else {
          debugPrint('CollectionSheet: skipping SMS, phone number still null or empty');
        }
      } catch (e) {
        debugPrint('SMS collection dispatch failed: $e');
      }
    }

    // 4. Date freeze — detect and freeze skipped EMIs if enabled
    if (widget.loan!.freezeEnabled) {
      try {
        final orgId = user.orgId!;
        final emiRepo = EMIRepository(client, orgId);
        final frozenCount = await emiRepo.detectAndFreezeSkippedEMIs(widget.loan!.id);
        if (frozenCount > 0 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$frozenCount skipped EMI(s) frozen, tenure extended'),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        debugPrint('Loan date freeze detection failed: $e');
      }
    }

    // 5. Activity log
    try {
      await client.from('activity_logs').insert({
        'org_id': user.orgId!,
        'staff_id': staffId,
        'action': 'collection_recorded',
        'entity_type': 'collection',
        'entity_id': widget.loan!.id,
        'details':
            'Collected Rs${amount.toStringAsFixed(0)} from ${widget.loan!.customerName}',
        'metadata': {
          'amount': amount,
          'emi_count': selectedCount,
          'payment_mode': _selectedMode,
          'selected_schedule_ids':
              _selectedEMIs.map((e) => e.id).toList(),
        },
        'created_at': now.toIso8601String(),
      });
    } catch (_) {}

    // 6. Invalidate providers
    ref.invalidate(emiScheduleProvider(widget.loan!.id));
    ref.invalidate(loanDetailProvider(widget.loan!.id));
    ref.invalidate(paymentHistoryProvider(widget.loan!.id));
    ref.invalidate(loansProvider);
    ref.invalidate(dashboardLoansProvider);
    ref.invalidate(dashboardTransactionsProvider);
    ref.invalidate(activeLoansProvider);
    ref.invalidate(loanSummaryProvider);
    ref.invalidate(todayPaymentsProvider);
    if (widget.branchId != null) {
      ref.invalidate(branchTodayPaymentsProvider(widget.branchId!));
    }
  }

  // ─── Savings Collection ───
  Future<void> _submitSavings() async {
    final client = ref.read(supabaseClientProvider);
    final profile = await ref.read(staffProfileProvider.future);
    if (profile == null) throw Exception('Staff profile not found');

    final plan = widget.savingsPlan!;
    final now = DateTime.now();
    final amount = _totalAmount;

    // 1. Create transaction
    final txResult = await client.from('transactions').insert({
      'member_id': plan.memberId,
      'member_name': plan.memberName,
      'savings_id': plan.id,
      'amount': amount,
      'type': 'savingsDeposit',
      'payment_mode': _selectedMode,
      'description': '${_selectedSavingsDates.length} ${_selectedSavingsDates.length == 1 ? 'installment' : 'installments'} deposited via $_selectedMode',
      'org_id': profile.orgId,
      'created_at': _getCreatedAt(),
    }).select('id').single();
    final transactionId = txResult['id'] as String;

    // 2. Record collection — one record per selected installment date so
    //    SavingsScheduleGenerator.fetchPaidDates() can match each
    //    collection_date against the corresponding installment dueDate.
    final collectedAt = DateTime.now().toUtc().toIso8601String();
    final selectedDates = _selectedSavingsDates
        .map((key) => DateTime.parse(key))
        .toList()
      ..sort();
    for (final date in selectedDates) {
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      await client.from('savings_collections').insert({
        'org_id': profile.orgId,
        'savings_plan_id': plan.id,
        'member_id': plan.memberId,
        'member_name': plan.memberName,
        'amount_expected': plan.monthlyDeposit,
        'amount_collected': plan.monthlyDeposit,
        'is_partial': false,
        'payment_mode': _selectedMode,
        'collection_date': dateKey,
        'collected_at': collectedAt,
        'staff_id': profile.id,
        'collected_by_name': profile.fullName,
        'collected_by_role': profile.role.dbValue,
        'collected_by_user_id': profile.id,
        'sync_status': 'synced',
        'transaction_id': transactionId,
      });
    }

    // 3. Plan balance, installments_paid, last_payment_date, and
    //    next_due_date are now auto-updated by the PostgreSQL trigger
    //    trg_update_savings_plan_on_collection (server-side).
    //    Each INSERT into savings_collections fires the trigger,
    //    so multi-date selections correctly increment installments_paid
    //    and advance next_due_date per row.

    // Compute new balance for SMS display
    final newBalance = plan.currentAmount + amount;

    // 3b. Dispatch SMS - use savings plan's sms_enabled setting
    try {
      // Fetch phone + SMS opt-out from the member row (members.sms_enabled is
      // the only SMS opt-out column that exists — not the savings plan).
      String? phone;
      bool smsEnabled = true;
      try {
        final memberInfo = await client
            .from('members')
            .select('phone, sms_enabled')
            .eq('id', plan.memberId)
            .maybeSingle();
        phone = memberInfo?['phone']?.toString();
        smsEnabled = memberInfo?['sms_enabled'] as bool? ?? true;
      } catch (_) {}

      final branding = ref.read(brandingProvider).valueOrNull;
      await ref.read(collectionSmsSenderProvider.notifier).enqueueSavings(
            phone: phone,
            memberId: plan.memberId,
            memberName: plan.memberName,
            planName: plan.planName,
            amount: amount,
            newBalance: newBalance,
            collectorName: profile.fullName,
            sentBy: profile.id,
            orgName: branding?.displayName,
            smsEnabled: smsEnabled,
          );
    } catch (e) {
      debugPrint('SMS savings dispatch failed: $e');
    }

    // 4. Date freeze — detect and freeze skipped installments if enabled in DB
    try {
      final orgId = profile.orgId;
      if (orgId != null) {
        final savingsRepo = SavingsRepository(client, orgId);
        final frozenCount =
            await savingsRepo.detectAndFreezeSkippedInstallments(plan.id);
        if (frozenCount > 0 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '$frozenCount skipped installment(s) frozen, tenure extended'),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Savings date freeze detection failed: $e');
    }

    // 5. Activity log
    try {
      await client.from('activity_logs').insert({
        'org_id': profile.orgId,
        'staff_id': profile.id,
        'action': 'savings_collection_recorded',
        'entity_type': 'savings_collection',
        'entity_id': plan.id,
        'details':
            'Deposited Rs${amount.toStringAsFixed(0)} for ${plan.memberName} (${plan.planName})',
        'metadata': {
          'amount': amount,
          'installment_count': _selectedSavingsDates.length,
          'payment_mode': _selectedMode,
          'savings_plan_id': plan.id,
        },
        'created_at': now.toIso8601String(),
      });
    } catch (_) {}

    // 6. Invalidate savings providers
    try {
      ref.invalidate(savingDetailProvider(plan.id));
      ref.invalidate(savingsScheduleProvider(plan.id));
      ref.invalidate(allSavingsProvider);
      ref.invalidate(savingsSummaryProvider);
      ref.invalidate(memberSavingsProvider(plan.memberId));
      ref.invalidate(dashboardTransactionsProvider);
      ref.invalidate(todayPaymentsProvider);
      if (widget.branchId != null) {
        ref.invalidate(branchTodayPaymentsProvider(widget.branchId!));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat =
        NumberFormat.currency(symbol: '\u20b9', decimalDigits: 0);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // ─── 1. Premium Gradient AppBar ───
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Close button with frosted glass circle
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Quick Collect',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3)),
                        const SizedBox(height: 4),
                        // Frosted glass pill for customer/plan info
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.mode == CollectionMode.savings
                                ? '${widget.savingsPlan!.memberName.isNotEmpty ? widget.savingsPlan!.memberName : 'Unknown'} \u00b7 ${widget.savingsPlan!.planName}'
                                : '${(widget.loan!.customerName ?? '').isNotEmpty ? widget.loan!.customerName! : 'Unknown'} \u00b7 ${widget.loan!.loanNumber}',
                            style: TextStyle(
                                color:
                                    Colors.white.withValues(alpha: 0.9),
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Outstanding / Collected badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      widget.mode == CollectionMode.savings
                          ? '₹${widget.savingsPlan!.monthlyDeposit.toStringAsFixed(0)}'
                          : '₹${widget.loan!.emiAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final outstandingCard = Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    AppColors.accent.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.mode == CollectionMode.savings
                          ? 'Collected'
                          : 'Outstanding',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      currencyFormat.format(
                        widget.mode == CollectionMode.savings
                            ? widget.savingsPlan!.currentAmount
                            : widget.loan!.outstandingBalance,
                      ),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            );

            final paymentModeSection = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Payment Mode',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildPaymentModeChip(
                        icon: Icons.money_rounded,
                        label: 'Cash',
                        mode: 'cash',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPaymentModeChip(
                        icon: Icons.qr_code_rounded,
                        label: 'UPI',
                        mode: 'upi',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPaymentModeChip(
                        icon: Icons.account_balance_rounded,
                        label: 'Bank',
                        mode: 'bank_transfer',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPaymentModeChip(
                        icon: Icons.receipt_rounded,
                        label: 'Cheque',
                        mode: 'cheque',
                      ),
                    ),
                  ],
                ),
              ],
            );

            if (_showUpiQr) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    outstandingCard,
                    const SizedBox(height: 12),
                    paymentModeSection,
                    const SizedBox(height: 12),
                    _buildUpiQrSection(currencyFormat),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  outstandingCard,
                  const SizedBox(height: 12),

                  // Schedule selector (scrollable) -- mode-dependent
                  Expanded(
                    child: widget.mode == CollectionMode.savings
                        ? _buildSavingsBody(currencyFormat)
                        : _buildLoanBody(currencyFormat),
                  ),

                  const SizedBox(height: 10),
                  paymentModeSection,
                  const SizedBox(height: 12),

                  // ─── 6. Action Buttons -- Premium Style ───
                  Row(
                    children: [
                      // Cancel -- frosted glass
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: _fillColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _separator,
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: _textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Collect -- gradient with glow
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: _isSubmitting || !_hasSelection
                              ? null
                              : _submit,
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                AppColors.success,
                                AppColors.mint,
                              ]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: _isSubmitting || !_hasSelection
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: AppColors.success
                                            .withValues(alpha: 0.35),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                        spreadRadius: -4,
                                      ),
                                    ],
                            ),
                            child: Center(
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                            Icons.check_circle_rounded,
                                            size: 20,
                                            color: Colors.white),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Collect ${currencyFormat.format(_totalAmount)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Build the loan (EMI) mode body.
  Widget _buildBackdatePill() {
    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        final picked = await PremiumCalendarSheet.show(
          context: context,
          initialDate: _customCollectionDate ?? now,
          firstDate: now.subtract(const Duration(days: 365)),
          lastDate: now,
        );
        if (picked != null) {
          setState(() {
            _isBackdated = true;
            _customCollectionDate = picked;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: _isBackdated
              ? LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.accent.withValues(alpha: 0.15),
                  ],
                )
              : null,
          color: _isBackdated ? null : _fillColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isBackdated ? AppColors.primary : _separator,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 14,
              color: _isBackdated ? AppColors.primary : _textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              _isBackdated && _customCollectionDate != null
                  ? DateFormat('dd MMM yyyy').format(_customCollectionDate!)
                  : 'Backdate',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _isBackdated ? AppColors.primary : _textSecondary,
              ),
            ),
            if (_isBackdated) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isBackdated = false;
                    _customCollectionDate = null;
                  });
                },
                child: Icon(
                  Icons.close_rounded,
                  size: 12,
                  color: AppColors.primary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoanBody(NumberFormat currencyFormat) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: "EMI Schedule" + backdate pill
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Text(
                  'EMI Schedule',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const Spacer(),
                _buildBackdatePill(),
              ],
            ),
          ),
          EmiPaymentSelector(
            emis: _allEMIs,
            emiAmount: widget.loan!.emiAmount,
            initialSelectedIds: _selectedEmiIds.toList(),
            onSelectionChanged: (selected) {
              setState(() {
                _selectedEmiIds
                  ..clear()
                  ..addAll(selected.map((e) => e.id));
              });
            },
            onFreezeSkipped: () => _handleFreezeSkipped(),
          ),
        ],
      ),
    );
  }

  /// Build the savings mode body: installment calendar.
  Widget _buildSavingsBody(NumberFormat currencyFormat) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: "Savings Schedule" + backdate pill
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Text(
                  'Savings Schedule',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const Spacer(),
                _buildBackdatePill(),
              ],
            ),
          ),
          // Savings payment selector (Quick Pay + Calendar)
          if (_savingsSchedule.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Loading schedule...',
                  style: TextStyle(color: _textSecondary),
                ),
              ),
            )
          else
            SavingsPaymentSelector(
              installments: _savingsSchedule,
              installmentAmount: widget.savingsPlan!.monthlyDeposit,
              totalInstallments: widget.savingsPlan!.totalInstallments,
              initialSelectedDateKeys: _selectedSavingsDates.toList(),
              onSelectionChanged: (selected) {
                setState(() {
                  _selectedSavingsDates
                    ..clear()
                    ..addAll(selected.map((s) => _dateKey(s.dueDate)));
                });
              },
              onFreezeSkipped: () => _handleFreezeSavingsSkipped(),
            ),
        ],
      ),
    );
  }

  // ─── Freeze Skipped Actions ───

  Future<void> _handleFreezeSkipped() async {
    final user = ref.read(currentUserProvider);
    if (user == null || user.orgId == null) return;
    final emiRepo = EMIRepository(ref.read(supabaseClientProvider), user.orgId!);
    final frozenCount = await emiRepo.detectAndFreezeSkippedEMIs(widget.loan!.id);

    if (frozenCount > 0) {
      // Refresh EMIs from DB
      final freshEmis = await EMIRepository(
        ref.read(supabaseClientProvider), user.orgId!,
      ).getByLoanId(widget.loan!.id);
      setState(() {
        _allEMIs = freshEmis;
      });
      ref.invalidate(emiScheduleProvider(widget.loan!.id));
      ref.invalidate(loanDetailProvider(widget.loan!.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$frozenCount skipped EMI(s) frozen, tenure extended'),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No skipped EMIs to freeze'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _handleFreezeSavingsSkipped() async {
    final profile = await ref.read(staffProfileProvider.future);
    if (profile == null) return;
    final orgId = profile.orgId;
    if (orgId == null) return;

    final savingsRepo = SavingsRepository(ref.read(supabaseClientProvider), orgId);
    final frozenCount = await savingsRepo.detectAndFreezeSkippedInstallments(
      widget.savingsPlan!.id,
      force: true,
    );

    if (frozenCount > 0) {
      // Refresh schedule from DB
      final planResponse = await ref
          .read(supabaseClientProvider)
          .from('savings_plans')
          .select('*')
          .eq('id', widget.savingsPlan!.id)
          .maybeSingle();

      if (planResponse != null) {
        final freshPlan = SavingsModel.fromJson(planResponse);
        final paidDates = await SavingsScheduleGenerator.fetchPaidDates(
          client: ref.read(supabaseClientProvider),
          planId: widget.savingsPlan!.id,
        );
        final freshSchedule = SavingsScheduleGenerator.generate(
          plan: freshPlan,
          paidDates: paidDates,
        );
        setState(() {
          _savingsSchedule = freshSchedule;
        });
      }

      ref.invalidate(savingDetailProvider(widget.savingsPlan!.id));
      ref.invalidate(savingsScheduleProvider(widget.savingsPlan!.id));
      ref.invalidate(allSavingsProvider);
      ref.invalidate(savingsSummaryProvider);
      ref.invalidate(memberSavingsProvider(widget.savingsPlan!.memberId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$frozenCount skipped installment(s) frozen, tenure extended'),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No skipped installments to freeze'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

}
