import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../data/services/customer_receipt_service.dart';

/// Premium receipt viewer page with share, download, and print actions.
///
/// Displays a custom Flutter widget that mirrors the PDF receipt layout
/// with staggered entrance animations and a glassmorphic action bar.
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
  bool _isDownloading = false;
  bool _isSharing = false;
  bool _isPrinting = false;

  static final _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Animation<double> _staggered(int index, {double duration = 0.5}) {
    final start = (index * 0.08).clamp(0.0, 1.0);
    final end = (start + duration).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _staggerController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
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

  bool get _isSynced => widget.status.toLowerCase() == 'synced';

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

  // ── Indian-style money format ──
  String _money(num v) {
    final negative = v < 0;
    final n = v.abs();
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
    return '${negative ? '-' : ''}\u20b9$grouped.$fracStr';
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
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // ── Gradient Header ──
                  _buildHeader(context, isDark),
                  // ── Receipt Card ──
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: _buildReceiptCard(context, isDark, theme),
                  ),
                  // Bottom spacing for action bar
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          // ── Glass Action Bar ──
          _buildActionBar(context, isDark, theme),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final topPadding = mq.padding.top + AppSpacing.md;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.primaryDark.withValues(alpha: 0.25),
                  AppColors.accentDark.withValues(alpha: 0.15),
                  AppColors.backgroundDark,
                ]
              : [
                  AppColors.primary,
                  AppColors.accent,
                  AppColors.primaryLight,
                ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.lg, topPadding, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button + Title
              Row(
                children: [
                  _GlassIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    isDark: isDark,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Receipt',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  // Sync status chip
                  _StatusChip(isSynced: _isSynced),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Receipt number
              Text(
                _receiptNumber,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontFamily: 'monospace',
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptCard(
      BuildContext context, bool isDark, ThemeData theme) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.surfaceLight;
    final borderColor =
        isDark ? AppColors.separatorDark : AppColors.separatorLight;
    final textTertiary = isDark
        ? AppColors.textTertiaryDark
        : AppColors.textTertiaryLight;

    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _staggered(0),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(_staggered(0)),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: AppColors.textPrimaryLight.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // ── Type Banner ──
              AnimatedBuilder(
                animation: _staggerController,
                builder: (context, child) => FadeTransition(
                  opacity: _staggered(1),
                  child: child,
                ),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  color: _typeColor.withValues(alpha: isDark ? 0.15 : 0.08),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _typeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(_typeIcon, size: 18, color: _typeColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _typeLabel,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: _typeColor,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Text(
                              _dateTimeFmt.format(widget.date),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: textTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Amount Hero ──
              AnimatedBuilder(
                animation: _staggerController,
                builder: (context, child) => FadeTransition(
                  opacity: _staggered(2),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(_staggered(2)),
                    child: child,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 24, horizontal: 16),
                  child: Column(
                    children: [
                      Text(
                        'AMOUNT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: textTertiary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final glow =
                              (_pulseController.value * 0.15).clamp(0.0, 0.15);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: _typeColor.withValues(alpha: glow),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Text(
                              _money(widget.amount),
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                                letterSpacing: -1.0,
                                height: 1.1,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ── Divider ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: List.generate(
                    60,
                    (i) => Expanded(
                      child: Container(
                        height: 1,
                        color: i.isEven
                            ? borderColor
                            : Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Details ──
              AnimatedBuilder(
                animation: _staggerController,
                builder: (context, child) => FadeTransition(
                  opacity: _staggered(3),
                  child: child,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (widget.memberName != null &&
                          widget.memberName!.isNotEmpty)
                        _DetailRow(
                          label: 'Member',
                          value: widget.memberName!,
                          isDark: isDark,
                          icon: Icons.person_outline_rounded,
                        ),
                      if (widget.paymentMode != null &&
                          widget.paymentMode!.isNotEmpty)
                        _DetailRow(
                          label: 'Payment Mode',
                          value: _formatPaymentMode(widget.paymentMode!),
                          isDark: isDark,
                          icon: Icons.credit_card_rounded,
                        ),
                      if (widget.referenceNumber != null &&
                          widget.referenceNumber!.isNotEmpty)
                        _DetailRow(
                          label: 'Reference No.',
                          value: widget.referenceNumber!,
                          isDark: isDark,
                          icon: Icons.tag_rounded,
                          isMonospace: true,
                        ),
                      if (widget.description != null &&
                          widget.description!.isNotEmpty)
                        _DetailRow(
                          label: 'Description',
                          value: widget.description!,
                          isDark: isDark,
                          icon: Icons.notes_rounded,
                        ),
                      _DetailRow(
                        label: 'Transaction ID',
                        value: widget.transactionId,
                        isDark: isDark,
                        icon: Icons.fingerprint_rounded,
                        isMonospace: true,
                      ),
                    ],
                  ),
                ),
              ),

              // ── QR Placeholder ──
              AnimatedBuilder(
                animation: _staggerController,
                builder: (context, child) => FadeTransition(
                  opacity: _staggered(4),
                  child: child,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.fillDark
                              : AppColors.fillLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_2_rounded,
                              size: 28,
                              color: textTertiary,
                            ),
                            Text(
                              'QR',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: textTertiary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Scan to verify',
                        style: TextStyle(
                          fontSize: 10,
                          color: textTertiary,
                        ),
                      ),
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

  Widget _buildActionBar(
      BuildContext context, bool isDark, ThemeData theme) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.85)
            : AppColors.surfaceLight.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.separatorDark : AppColors.separatorLight,
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
            child: _ActionButton(
              icon: Icons.ios_share_rounded,
              label: 'Share',
              isLoading: _isSharing,
              color: AppColors.primary,
              isDark: isDark,
              onTap: _share,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _ActionButton(
              icon: Icons.download_rounded,
              label: 'Download',
              isLoading: _isDownloading,
              color: AppColors.success,
              isDark: isDark,
              onTap: _download,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _ActionButton(
              icon: Icons.print_rounded,
              label: 'Print',
              isLoading: _isPrinting,
              color: AppColors.info,
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
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.3),
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isSynced;

  const _StatusChip({required this.isSynced});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isSynced
            ? AppColors.success.withValues(alpha: 0.2)
            : AppColors.warning.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
        border: Border.all(
          color: isSynced
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isSynced ? AppColors.success : AppColors.warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isSynced ? 'Synced' : 'Pending',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final IconData icon;
  final bool isMonospace;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.isDark,
    required this.icon,
    this.isMonospace = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isDark ? AppColors.fillDark : AppColors.fillLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFamily: isMonospace ? 'monospace' : null,
                    fontSize: isMonospace ? 12 : 14,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLoading;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isLoading,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppSpacing.animationNormal,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.2 : 0.15),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            else
              Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
