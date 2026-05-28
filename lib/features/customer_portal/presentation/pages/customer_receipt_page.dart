import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../data/services/customer_receipt_service.dart';

/// Super-premium receipt confirmation page.
///
/// Hero pulse checkmark, animated counting amount with Indian currency,
/// glass meta/member cards, dotted dividers, staggered fade+slide entrance,
/// and gradient action row (Download / Share / Done).
class CustomerReceiptPage extends ConsumerStatefulWidget {
  final String transactionId;
  final double amount;
  final String type;
  final DateTime date;
  final String? memberName;
  final String? paymentMode;
  final String? referenceNumber;
  final String? description;
  final String status;

  const CustomerReceiptPage({
    super.key,
    required this.transactionId,
    required this.amount,
    required this.type,
    required this.date,
    this.memberName,
    this.paymentMode,
    this.referenceNumber,
    this.description,
    this.status = 'synced',
  });

  @override
  ConsumerState<CustomerReceiptPage> createState() =>
      _CustomerReceiptPageState();
}

class _CustomerReceiptPageState extends ConsumerState<CustomerReceiptPage>
    with TickerProviderStateMixin {
  late AnimationController _staggerController;
  late AnimationController _pulseController;
  late AnimationController _checkController;
  bool _isDownloading = false;
  bool _isSharing = false;
  bool _isPrinting = false;

  static final _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _pulseController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  Animation<double> _staggered(int index) {
    final start = (index * 0.07).clamp(0.0, 1.0);
    final end = (start + 0.45).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _staggerController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  Widget _animatedEntry(int index, Widget child) {
    final anim = _staggered(index);
    return AnimatedBuilder(
      animation: anim,
      builder: (context, c) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, 22 * (1 - anim.value)),
          child: c,
        ),
      ),
      child: child,
    );
  }

  String get _receiptNumber {
    final clean = widget.transactionId.replaceAll('-', '').toUpperCase();
    return 'RCP-${clean.length >= 8 ? clean.substring(0, 8) : clean}';
  }

  String get _typeLabel {
    switch (widget.type) {
      case 'emiPayment':
        return 'EMI Payment';
      case 'savingsDeposit':
      case 'deposit':
        return 'Savings Deposit';
      case 'savingsWithdrawal':
      case 'withdrawal':
        return 'Savings Withdrawal';
      case 'loanDisbursement':
        return 'Loan Disbursement';
      case 'collection':
        return 'Collection';
      case 'penalty':
        return 'Penalty';
      default:
        return widget.type
            .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}')
            .replaceFirst(widget.type[0], widget.type[0].toUpperCase());
    }
  }

  IconData get _typeIcon {
    switch (widget.type) {
      case 'emiPayment':
      case 'collection':
        return Icons.payment_rounded;
      case 'savingsDeposit':
      case 'deposit':
        return Icons.savings_rounded;
      case 'savingsWithdrawal':
      case 'withdrawal':
        return Icons.account_balance_rounded;
      case 'loanDisbursement':
        return Icons.account_balance_wallet_rounded;
      case 'penalty':
        return Icons.warning_amber_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  Color get _typeColor {
    switch (widget.type) {
      case 'emiPayment':
      case 'collection':
        return AppColors.indigo;
      case 'savingsDeposit':
      case 'deposit':
        return AppColors.mint;
      case 'loanDisbursement':
        return AppColors.success;
      case 'savingsWithdrawal':
      case 'withdrawal':
        return AppColors.orange;
      case 'penalty':
        return AppColors.error;
      default:
        return AppColors.info;
    }
  }

  String get _statusLower => widget.status.toLowerCase();
  bool get _isSynced => _statusLower == 'synced';
  bool get _isFailed => _statusLower == 'failed';

  StatusType get _statusType {
    if (_isSynced) return StatusType.active;
    if (_isFailed) return StatusType.defaultStatus;
    return StatusType.pending;
  }

  String get _statusLabel {
    if (_isSynced) return 'Synced';
    if (_isFailed) return 'Failed';
    return 'Pending';
  }

  // ── Share ──
  Future<void> _share() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    HapticFeedback.mediumImpact();
    try {
      await CustomerReceiptService.shareReceipt(
        transactionId: widget.transactionId,
        amount: widget.amount,
        type: widget.type,
        date: widget.date,
        memberName: widget.memberName,
        paymentMode: widget.paymentMode,
        referenceNumber: widget.referenceNumber,
        description: widget.description,
        status: widget.status,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share receipt: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  // ── Download ──
  Future<void> _download() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    HapticFeedback.mediumImpact();
    try {
      final path = await CustomerReceiptService.downloadReceipt(
        transactionId: widget.transactionId,
        amount: widget.amount,
        type: widget.type,
        date: widget.date,
        memberName: widget.memberName,
        paymentMode: widget.paymentMode,
        referenceNumber: widget.referenceNumber,
        description: widget.description,
        status: widget.status,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt saved to $path'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save receipt: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  // ── Print ──
  Future<void> _print() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    HapticFeedback.mediumImpact();
    try {
      await CustomerReceiptService.printReceipt(
        transactionId: widget.transactionId,
        amount: widget.amount,
        type: widget.type,
        date: widget.date,
        memberName: widget.memberName,
        paymentMode: widget.paymentMode,
        referenceNumber: widget.referenceNumber,
        description: widget.description,
        status: widget.status,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to print receipt: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  // ── Indian-style money format with L / Cr suffix ──
  String _money(num v) {
    final negative = v < 0;
    final n = v.abs();
    if (n >= 10000000) {
      return '${negative ? '-' : ''}₹${(n / 10000000).toStringAsFixed(2)} Cr';
    }
    if (n >= 100000) {
      return '${negative ? '-' : ''}₹${(n / 100000).toStringAsFixed(2)} L';
    }
    final whole = n.truncate();
    final fraction = ((n - whole) * 100).round();
    final wholeStr = whole.toString();
    String grouped;
    if (wholeStr.length <= 3) {
      grouped = wholeStr;
    } else {
      final last3 = wholeStr.substring(wholeStr.length - 3);
      final rest = wholeStr.substring(0, wholeStr.length - 3);
      final restRev = rest.split('').reversed.join();
      final buf = StringBuffer();
      for (var i = 0; i < restRev.length; i++) {
        if (i > 0 && i % 2 == 0) buf.write(',');
        buf.write(restRev[i]);
      }
      grouped = '${buf.toString().split('').reversed.join()},$last3';
    }
    final fracStr = fraction.toString().padLeft(2, '0');
    return '${negative ? '-' : ''}₹$grouped.$fracStr';
  }

  String _formatPaymentMode(String mode) {
    switch (mode.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'upi':
        return 'UPI';
      case 'bank_transfer':
      case 'banktransfer':
        return 'Bank Transfer';
      case 'cheque':
      case 'check':
        return 'Cheque';
      case 'online':
        return 'Online';
      case 'wallet':
        return 'Wallet';
      default:
        return mode
            .replaceAll('_', ' ')
            .replaceFirst(mode[0], mode[0].toUpperCase());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Stack(
        children: [
          // Ambient aurora behind hero only — sits in upper portion
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 440,
            child: IgnorePointer(
              child: AuroraBackground(child: const SizedBox.expand()),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _buildAppBar(context, isDark, theme),
                      _animatedEntry(0, _buildHero(context, isDark, theme)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, 0, AppSpacing.md, 0),
                        child: Column(
                          children: [
                            _animatedEntry(
                              1,
                              _buildMetaCard(context, isDark, theme),
                            ),
                            if (widget.memberName != null &&
                                widget.memberName!.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.md),
                              _animatedEntry(
                                2,
                                _buildMemberCard(context, isDark, theme),
                              ),
                            ],
                            if (widget.description != null &&
                                widget.description!.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.md),
                              _animatedEntry(
                                3,
                                _buildDescriptionCard(context, isDark, theme),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            _animatedEntry(
                              4,
                              _buildVerifyCard(context, isDark, theme),
                            ),
                            const SizedBox(height: 120),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Floating action bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _animatedEntry(
                5, _buildActionBar(context, isDark, theme)),
          ),
        ],
      ),
    );
  }

  // ─── App Bar ───────────────────────────────────────────────
  Widget _buildAppBar(BuildContext context, bool isDark, ThemeData theme) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.md, topPadding + 8, AppSpacing.md, 4),
      child: Row(
        children: [
          _GlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            isDark: isDark,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Receipt',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  _receiptNumber,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight)
                        .withValues(alpha: 0.6),
                    fontFamily: 'monospace',
                    letterSpacing: 0.8,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(label: _statusLabel, type: _statusType),
        ],
      ),
    );
  }

  // ─── Hero ──────────────────────────────────────────────────
  Widget _buildHero(BuildContext context, bool isDark, ThemeData theme) {
    final heroColor = _isFailed
        ? AppColors.error
        : (_isSynced ? AppColors.success : AppColors.warning);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.lg),
      child: Column(
        children: [
          // Pulse + checkmark
          AnimatedBuilder(
            animation: Listenable.merge([_pulseController, _checkController]),
            builder: (context, _) {
              final pulse = _pulseController.value;
              final check = Curves.easeOutBack.transform(_checkController.value);
              return SizedBox(
                width: 130,
                height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulse ring
                    Container(
                      width: 110 + pulse * 18,
                      height: 110 + pulse * 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: heroColor
                            .withValues(alpha: 0.08 * (1 - pulse * 0.6)),
                      ),
                    ),
                    Container(
                      width: 96 + pulse * 10,
                      height: 96 + pulse * 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: heroColor
                            .withValues(alpha: 0.16 * (1 - pulse * 0.5)),
                      ),
                    ),
                    // Inner gradient circle with check
                    Transform.scale(
                      scale: 0.6 + check * 0.4,
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              heroColor,
                              Color.lerp(heroColor, AppColors.primary, 0.45) ??
                                  AppColors.primary,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: heroColor.withValues(alpha: 0.45),
                              blurRadius: 24,
                              spreadRadius: 1,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isFailed
                              ? Icons.close_rounded
                              : (_isSynced
                                  ? Icons.check_rounded
                                  : Icons.hourglass_top_rounded),
                          color: Colors.white,
                          size: 46,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _isFailed
                ? 'Transaction Failed'
                : (_isSynced
                    ? 'Payment Successful'
                    : 'Payment Pending'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _typeLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight)
                  .withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Counting amount
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: widget.amount),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return ShaderMask(
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.accent,
                  ],
                ).createShader(rect),
                child: Text(
                  _money(value),
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1.4,
                    height: 1.05,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            _dateTimeFmt.format(widget.date),
            style: theme.textTheme.bodySmall?.copyWith(
              color: (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight)
                  .withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Meta Card ─────────────────────────────────────────────
  Widget _buildMetaCard(BuildContext context, bool isDark, ThemeData theme) {
    final rows = <_MetaItem>[
      _MetaItem(
        icon: Icons.fingerprint_rounded,
        label: 'Transaction ID',
        value: widget.transactionId,
        monospace: true,
      ),
      _MetaItem(
        icon: Icons.event_rounded,
        label: 'Date & Time',
        value: _dateTimeFmt.format(widget.date),
      ),
      _MetaItem(
        icon: _typeIcon,
        label: 'Type',
        value: _typeLabel,
        valueColor: _typeColor,
      ),
      if (widget.paymentMode != null && widget.paymentMode!.isNotEmpty)
        _MetaItem(
          icon: Icons.credit_card_rounded,
          label: 'Payment Mode',
          value: _formatPaymentMode(widget.paymentMode!),
        ),
      if (widget.referenceNumber != null && widget.referenceNumber!.isNotEmpty)
        _MetaItem(
          icon: Icons.tag_rounded,
          label: 'Reference No.',
          value: widget.referenceNumber!,
          monospace: true,
        ),
    ];

    return TicketCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text(
                'Transaction Details',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              StatusBadge(label: _statusLabel, type: _statusType),
            ],
          ),
          const SizedBox(height: 14),
          _DottedDivider(isDark: isDark),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++) ...[
            _MetaRow(item: rows[i], isDark: isDark),
            if (i < rows.length - 1) ...[
              const SizedBox(height: 12),
              _DottedDivider(isDark: isDark),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }

  // ─── Member Card ───────────────────────────────────────────
  Widget _buildMemberCard(BuildContext context, bool isDark, ThemeData theme) {
    final name = widget.memberName!;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.85),
                  AppColors.accent.withValues(alpha: 0.85),
                ],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              initials.isEmpty ? '?' : initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Member',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight)
                        .withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.verified_rounded,
            color: AppColors.success.withValues(alpha: 0.85),
            size: 22,
          ),
        ],
      ),
    );
  }

  // ─── Description Card ──────────────────────────────────────
  Widget _buildDescriptionCard(
      BuildContext context, bool isDark, ThemeData theme) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notes_rounded,
                size: 16,
                color: (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight)
                    .withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'Note',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight)
                      .withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.description!,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Verify QR Card ────────────────────────────────────────
  Widget _buildVerifyCard(BuildContext context, bool isDark, ThemeData theme) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isDark ? AppColors.fillDark : AppColors.fillLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? AppColors.separatorDark
                    : AppColors.separatorLight,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.qr_code_2_rounded,
              size: 36,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verify this receipt',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Scan the QR code on the printed copy to confirm authenticity.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight)
                        .withValues(alpha: 0.6),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Action Bar ────────────────────────────────────────────
  Widget _buildActionBar(BuildContext context, bool isDark, ThemeData theme) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.surfaceDark : AppColors.surfaceLight)
            .withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(
            color:
                (isDark ? AppColors.separatorDark : AppColors.separatorLight)
                    .withValues(alpha: 0.6),
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _GradientActionButton(
              icon: Icons.download_rounded,
              label: 'Download',
              isLoading: _isDownloading,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.accent],
              ),
              onTap: _download,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _TonalActionButton(
              icon: Icons.ios_share_rounded,
              label: 'Share',
              isLoading: _isSharing,
              color: AppColors.info,
              isDark: isDark,
              onTap: _share,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _TonalActionButton(
              icon: Icons.print_rounded,
              label: 'Print',
              isLoading: _isPrinting,
              color: AppColors.success,
              isDark: isDark,
              onTap: _print,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Private helper widgets ─────────────────────────────────────────

class _MetaItem {
  final IconData icon;
  final String label;
  final String value;
  final bool monospace;
  final Color? valueColor;

  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
    this.monospace = false,
    this.valueColor,
  });
}

class _MetaRow extends StatelessWidget {
  final _MetaItem item;
  final bool isDark;

  const _MetaRow({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: (isDark ? AppColors.fillDark : AppColors.fillLight)
                .withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Icon(
            item.icon,
            size: 16,
            color: (isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight)
                .withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight)
                      .withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFamily: item.monospace ? 'monospace' : null,
                  fontSize: item.monospace ? 12.5 : 14,
                  color: item.valueColor,
                  letterSpacing: item.monospace ? 0.4 : -0.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DottedDivider extends StatelessWidget {
  final bool isDark;
  const _DottedDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color =
        (isDark ? AppColors.separatorDark : AppColors.separatorLight)
            .withValues(alpha: 0.9);
    return LayoutBuilder(
      builder: (context, c) {
        const dashWidth = 4.0;
        const dashGap = 4.0;
        final count = (c.maxWidth / (dashWidth + dashGap)).floor();
        return Row(
          children: List.generate(count, (i) {
            return Padding(
              padding: EdgeInsets.only(right: i == count - 1 ? 0 : dashGap),
              child: Container(
                width: dashWidth,
                height: 1.2,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (isDark ? AppColors.cardDark : AppColors.surfaceLight)
              .withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isDark
                    ? AppColors.separatorDark
                    : AppColors.separatorLight)
                .withValues(alpha: 0.7),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
          size: 16,
        ),
      ),
    );
  }
}

class _GradientActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isLoading;
  final Gradient gradient;
  final VoidCallback onTap;

  const _GradientActionButton({
    required this.icon,
    required this.label,
    required this.isLoading,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_GradientActionButton> createState() => _GradientActionButtonState();
}

class _GradientActionButtonState extends State<_GradientActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isLoading ? null : widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TonalActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isLoading;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _TonalActionButton({
    required this.icon,
    required this.label,
    required this.isLoading,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_TonalActionButton> createState() => _TonalActionButtonState();
}

class _TonalActionButtonState extends State<_TonalActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isLoading ? null : widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: widget.isDark ? 0.18 : 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.color
                  .withValues(alpha: widget.isDark ? 0.28 : 0.2),
            ),
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.color,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, color: widget.color, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class TicketCard extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const TicketCard({super.key, required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColors.cardDark : AppColors.surfaceLight;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04);
    
    return CustomPaint(
      painter: TicketBorderPainter(
        color: bgColor,
        borderColor: borderColor,
        punchRadius: 8,
        punchPosition: 64.0,
      ),
      child: ClipPath(
        clipper: TicketClipper(
          punchRadius: 8,
          punchPosition: 64.0,
        ),
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: child,
        ),
      ),
    );
  }
}

class TicketClipper extends CustomClipper<Path> {
  final double punchRadius;
  final double punchPosition;

  TicketClipper({required this.punchRadius, required this.punchPosition});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0.0, 0.0);
    path.lineTo(0.0, punchPosition - punchRadius);
    
    // Left notch
    path.arcToPoint(
      Offset(0.0, punchPosition + punchRadius),
      radius: Radius.circular(punchRadius),
      clockwise: true,
    );
    
    path.lineTo(0.0, size.height - 24);
    path.quadraticBezierTo(0.0, size.height, 24, size.height);
    path.lineTo(size.width - 24, size.height);
    path.quadraticBezierTo(size.width, size.height, size.width, size.height - 24);
    
    path.lineTo(size.width, punchPosition + punchRadius);
    
    // Right notch
    path.arcToPoint(
      Offset(size.width, punchPosition - punchRadius),
      radius: Radius.circular(punchRadius),
      clockwise: true,
    );
    
    path.lineTo(size.width, 24);
    path.quadraticBezierTo(size.width, 0.0, size.width - 24, 0.0);
    path.lineTo(24, 0.0);
    path.quadraticBezierTo(0.0, 0.0, 0.0, 24);
    
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class TicketBorderPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final double punchRadius;
  final double punchPosition;

  TicketBorderPainter({
    required this.color,
    required this.borderColor,
    required this.punchRadius,
    required this.punchPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    path.moveTo(24, 0.0);
    path.lineTo(size.width - 24, 0.0);
    path.quadraticBezierTo(size.width, 0.0, size.width, 24);
    path.lineTo(size.width, punchPosition - punchRadius);
    
    // Right notch
    path.arcToPoint(
      Offset(size.width, punchPosition + punchRadius),
      radius: Radius.circular(punchRadius),
      clockwise: false,
    );
    
    path.lineTo(size.width, size.height - 24);
    path.quadraticBezierTo(size.width, size.height, size.width - 24, size.height);
    path.lineTo(24, size.height);
    path.quadraticBezierTo(0.0, size.height, 0.0, size.height - 24);
    path.lineTo(0.0, punchPosition + punchRadius);
    
    // Left notch
    path.arcToPoint(
      Offset(0.0, punchPosition - punchRadius),
      radius: Radius.circular(punchRadius),
      clockwise: false,
    );
    
    path.lineTo(0.0, 24);
    path.quadraticBezierTo(0.0, 0.0, 24, 0.0);
    path.close();

    // Draw shadow
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Draw card background
    canvas.drawPath(path, paint);

    // Draw border
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant TicketBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderColor != borderColor;
}
