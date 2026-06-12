import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/layout.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/progress_gauge.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../savings/data/services/savings_statement_models.dart';
import '../../../savings/data/services/savings_statement_pdf_service.dart';
import '../../data/models/customer_savings_model.dart';
import '../../data/models/customer_transaction_model.dart';
import '../../data/providers/customer_member_provider.dart';
import '../../data/providers/customer_savings_providers.dart';
import '../widgets/customer_empty_state.dart';
import '../widgets/customer_payment_trend_chart.dart' show MonthlyPaymentData;
import '../widgets/customer_savings_growth_chart.dart';
import '../widgets/customer_savings_milestones.dart';

class CustomerSavingsDetailPage extends ConsumerStatefulWidget {
  final String savingsId;

  const CustomerSavingsDetailPage({super.key, required this.savingsId});

  @override
  ConsumerState<CustomerSavingsDetailPage> createState() =>
      _CustomerSavingsDetailPageState();
}

class _CustomerSavingsDetailPageState
    extends ConsumerState<CustomerSavingsDetailPage>
    with TickerProviderStateMixin {
  late final AnimationController _headerController;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final AnimationController _staggerController;

  double _previousBalance = 0;
  double _targetBalance = 0;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerFade = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    ));

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) _staggerController.forward();
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  void _maybeRetargetBalance(double next) {
    if (_targetBalance == next) return;
    _previousBalance = _targetBalance;
    _targetBalance = next;
  }

  /// Indian-style currency formatting using full comma-formatted numbers.
  String _formatCurrency(double value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(value);
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatShortDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  Color _progressColor(double percentage, bool isDark) {
    if (percentage >= 100) return AppColors.success;
    if (percentage >= 60) {
      return isDark ? AppColors.primaryDark : AppColors.primary;
    }
    if (percentage >= 30) return AppColors.warning;
    return AppColors.error;
  }

  StatusType _statusType(String status) {
    switch (status) {
      case 'active':
        return StatusType.active;
      case 'completed':
        return StatusType.completed;
      default:
        return StatusType.standard;
    }
  }

  String _etaToGoal(CustomerSavingsModel s) {
    final remaining =
        (s.targetAmount - s.currentAmount).clamp(0.0, double.infinity);
    if (remaining <= 0) return 'Goal achieved';

    // Use maturity date when available for an accurate ETA
    if (s.maturityDate != null) {
      final now = DateTime.now();
      final diff = s.maturityDate!.difference(now);
      if (diff.isNegative || diff.inDays <= 0) return 'Maturity reached';

      // Format based on collection type
      switch (s.collectionType) {
        case 'daily':
          final days = diff.inDays;
          return '~${days}d to goal';
        case 'weekly':
          final weeks = (diff.inDays / 7).ceil();
          return '~${weeks}w to goal';
        case 'monthly':
        default:
          final months = (diff.inDays / 30.44).ceil();
          if (months <= 1) return '~1 month to goal';
          if (months < 12) return '~$months months to goal';
          final years = months ~/ 12;
          final rem = months % 12;
          if (rem == 0) {
            return '~$years yr${years == 1 ? '' : 's'} to goal';
          }
          return '~${years}y ${rem}m to goal';
      }
    }

    // Fallback: estimate from monthly deposit
    if (s.monthlyDeposit <= 0) return 'Set a monthly deposit';
    final months = (remaining / s.monthlyDeposit).ceil();
    if (months <= 1) return '~1 month to goal';
    if (months < 12) return '~$months months to goal';
    final years = months ~/ 12;
    final rem = months % 12;
    if (rem == 0) {
      return '~$years yr${years == 1 ? '' : 's'} to goal';
    }
    return '~${years}y ${rem}m to goal';
  }

  /// Build last-6-month savings growth from credit transactions.
  List<MonthlyPaymentData> _buildGrowthSeries(
      List<CustomerTransactionModel> transactions) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final now = DateTime.now();
    final buckets = <String, double>{};
    final labels = <String>[];
    for (int i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final key = '${m.year}-${m.month}';
      buckets[key] = 0;
      labels.add(months[m.month - 1]);
    }
    double running = 0;
    final keysOrdered = buckets.keys.toList();
    final orderIndex = {for (var e in keysOrdered.asMap().entries) e.value: e.key};

    for (final tx in transactions) {
      if (!tx.isCredit) continue;
      final d = tx.transactionDate;
      if (d == null) continue;
      final key = '${d.year}-${d.month}';
      if (buckets.containsKey(key)) {
        buckets[key] = (buckets[key] ?? 0) + tx.amount;
      }
    }
    final result = <MonthlyPaymentData>[];
    for (int i = 0; i < keysOrdered.length; i++) {
      running += buckets[keysOrdered[i]] ?? 0;
      result.add(MonthlyPaymentData(label: labels[i], amount: running));
    }
    // If no credits at all, still return empty list to render empty state.
    if (result.every((e) => e.amount == 0)) return const [];
    // Suppress unused warning for orderIndex usage clarity
    orderIndex.length;
    return result;
  }


  void _showStatementSheet(BuildContext context, bool isDark, CustomerSavingsModel savings) {
    String selectedFormat = 'pdf'; // pdf, excel, csv
    String selectedRange = '30'; // 30, 90, all
    String step = 'input'; // input, loading, success
    Uint8List? generatedPdfBytes;
    String? statementFilename;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: EdgeInsets.fromLTRB(
                  24,
                  16,
                  24,
                  MediaQuery.of(ctx).viewInsets.bottom +
                      MediaQuery.of(ctx).viewPadding.bottom +
                      kBottomNavBarHeight +
                      16,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2030).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (step == 'input') ...[
                        Text(
                          'Download Statement',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'FILE FORMAT',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildFormatCard(
                                label: 'PDF Report',
                                icon: Icons.picture_as_pdf_rounded,
                                color: AppColors.error,
                                isSelected: selectedFormat == 'pdf',
                                isDark: isDark,
                                onTap: () => setSheetState(() => selectedFormat = 'pdf'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildFormatCard(
                                label: 'Excel Sheet',
                                icon: Icons.table_view_rounded,
                                color: AppColors.success,
                                isSelected: selectedFormat == 'excel',
                                isDark: isDark,
                                onTap: () => setSheetState(() => selectedFormat = 'excel'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildFormatCard(
                                label: 'CSV File',
                                icon: Icons.grid_on_rounded,
                                color: AppColors.info,
                                isSelected: selectedFormat == 'csv',
                                isDark: isDark,
                                onTap: () => setSheetState(() => selectedFormat = 'csv'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'DATE RANGE',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildRangeCard(
                                label: '30 Days',
                                isSelected: selectedRange == '30',
                                isDark: isDark,
                                onTap: () => setSheetState(() => selectedRange = '30'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildRangeCard(
                                label: '90 Days',
                                isSelected: selectedRange == '90',
                                isDark: isDark,
                                onTap: () => setSheetState(() => selectedRange = '90'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildRangeCard(
                                label: 'All Time',
                                isSelected: selectedRange == 'all',
                                isDark: isDark,
                                onTap: () => setSheetState(() => selectedRange = 'all'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  HapticFeedback.lightImpact();
                                  setSheetState(() => step = 'loading');
                                  try {
                                    final supabase = Supabase.instance.client;
                                    final orgId = ref.read(currentOrgIdOrThrowProvider);

                                    // Fetch org info
                                    final orgData = await supabase
                                        .from('organizations')
                                        .select('name, address, city, state, pincode, phone, email, gst_number')
                                        .eq('id', orgId)
                                        .maybeSingle();
                                    final org = SavingsStatementOrgInfo(
                                      name: orgData?['name'] ?? 'MicroFlow Pro',
                                      address: orgData?['address'],
                                      city: orgData?['city'],
                                      state: orgData?['state'],
                                      pincode: orgData?['pincode'],
                                      phone: orgData?['phone'],
                                      email: orgData?['email'],
                                      gstNumber: orgData?['gst_number'],
                                    );

                                    // Fetch member info
                                    final memberId = ref.read(currentCustomerIdSyncProvider) ?? '';
                                    final memberData = await supabase
                                        .from('members')
                                        .select('full_name, phone, member_id')
                                        .eq('id', memberId)
                                        .maybeSingle();
                                    final customer = SavingsStatementCustomer(
                                      id: memberId,
                                      memberId: memberData?['member_id']?.toString() ?? memberId.substring(0, memberId.length > 8 ? 8 : memberId.length),
                                      fullName: memberData?['full_name'] ?? savings.displayName,
                                      phone: memberData?['phone'] ?? '',
                                    );

                                    // Map transactions with opening balance calculation
                                    final transactionsAsync = ref.read(customerSavingsTransactionsProvider(widget.savingsId));
                                    final transactions = transactionsAsync.valueOrNull ?? [];
                                    final now = DateTime.now();
                                    final periodStart = now.subtract(const Duration(days: 365));
                                    double openingBalance = 0;
                                    final deposits = <SavingsStatementTx>[];
                                    final withdrawals = <SavingsStatementTx>[];
                                    for (final t in transactions) {
                                      final date = t.transactionDate ?? DateTime.now();
                                      final isBeforePeriod = date.isBefore(periodStart);

                                      if (isBeforePeriod) {
                                        // Pre-period transactions contribute to opening balance
                                        if (t.type == 'savingsWithdrawal' || t.type == 'withdrawal') {
                                          openingBalance -= t.amount;
                                        } else {
                                          openingBalance += t.amount;
                                        }
                                      } else {
                                        // In-period transactions go into deposits/withdrawals lists
                                        final tx = SavingsStatementTx(
                                          date: date,
                                          amount: t.amount,
                                          description: t.description ?? t.type,
                                          paymentMode: t.paymentMode,
                                        );
                                        if (t.type == 'savingsWithdrawal' || t.type == 'withdrawal') {
                                          withdrawals.add(tx);
                                        } else {
                                          deposits.add(tx);
                                        }
                                      }
                                    }

                                    final periodDeposits = deposits.fold<double>(0, (s, t) => s + t.amount);
                                    final periodWithdrawals = withdrawals.fold<double>(0, (s, t) => s + t.amount);
                                    final closingBalance = openingBalance + periodDeposits - periodWithdrawals;

                                    // Build plan block
                                    final planBlock = SavingsStatementPlanBlock(
                                      planId: savings.id,
                                      planName: savings.planName ?? 'Savings Account',
                                      status: savings.status,
                                      targetAmount: savings.targetAmount,
                                      currentAmount: savings.currentAmount,
                                      openingBalance: openingBalance,
                                      closingBalance: closingBalance,
                                      interestRate: savings.interestRate,
                                      maturityDate: savings.maturityDate ?? DateTime.now().add(const Duration(days: 365)),
                                      collectionType: savings.collectionType,
                                      monthlyDeposit: savings.monthlyDeposit,
                                      maturityAmount: savings.targetAmount,
                                      deposits: deposits,
                                      withdrawals: withdrawals,
                                    );

                                    // Build portfolio summary
                                    final portfolio = SavingsStatementPortfolioSummary(
                                      openingBalance: openingBalance,
                                      totalDeposits: periodDeposits,
                                      totalWithdrawals: periodWithdrawals,
                                      interestEarned: 0,
                                      closingBalance: closingBalance,
                                      activePlans: savings.status == 'active' ? 1 : 0,
                                      totalPlans: 1,
                                    );

                                    // Generate PDF using admin template
                                    final statementData = SavingsStatementData(
                                      customer: customer,
                                      periodStart: periodStart,
                                      periodEnd: now,
                                      plans: [planBlock],
                                      portfolio: portfolio,
                                    );
                                    final pdfBytes = await SavingsStatementPdfService.build(
                                      data: statementData,
                                      org: org,
                                      statementRef: 'SAV-STMT-${now.millisecondsSinceEpoch.toRadixString(36)}',
                                    );

                                    generatedPdfBytes = pdfBytes;
                                    statementFilename = 'savings_statement_${savings.id}.pdf';

                                    if (ctx.mounted) {
                                      setSheetState(() => step = 'success');
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      setSheetState(() => step = 'input');
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Failed to generate statement: $e')),
                                      );
                                    }
                                  }
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: Text(
                                      'Generate Statement',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ] else if (step == 'loading') ...[
                        const SizedBox(height: 40),
                        CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Exporting statement report...',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 40),
                      ] else if (step == 'success') ...[
                        const SizedBox(height: 32),
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.success.withValues(alpha: 0.15),
                            border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.file_download_done_rounded,
                            color: AppColors.success,
                            size: 38,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Statement Downloaded!',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The statement file has been saved to your downloads folder.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                      blurRadius: 14,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () async {
                                      HapticFeedback.lightImpact();
                                      if (generatedPdfBytes != null) {
                                        await Printing.layoutPdf(onLayout: (format) async => generatedPdfBytes!);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.open_in_new_rounded, color: Colors.white, size: 18),
                                          SizedBox(width: 8),
                                          Text('Open', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08)),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () async {
                                      HapticFeedback.lightImpact();
                                      if (generatedPdfBytes != null) {
                                        await Printing.sharePdf(bytes: generatedPdfBytes!, filename: statementFilename ?? 'statement.pdf');
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.share_rounded, color: AppColors.primary, size: 18),
                                          const SizedBox(width: 8),
                                          Text('Share', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(ctx).pop();
                          },
                          child: Text(
                            'Close',
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black45,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFormatCard({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.2 : 0.12)
              : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : (isDark ? Colors.white54 : Colors.black45), size: 22),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeCard({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.12)
              : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final savingsAsync =
        ref.watch(customerSavingsDetailProvider(widget.savingsId));
    final transactionsAsync =
        ref.watch(customerSavingsTransactionsProvider(widget.savingsId));

    final headerGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF1A1F3A), Color(0xFF151A30)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : AppColors.primaryGradient;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      extendBody: true,
      body: AuroraBackground(
        child: savingsAsync.when(
          loading: () => _buildLoadingState(context, isDark, headerGradient),
          error: (e, _) => _buildErrorState(e, isDark, headerGradient),
          data: (savings) {
            if (savings == null) {
              return Column(
                children: [
                  _buildGradientHeader(context, isDark, headerGradient, null),
                  Expanded(
                    child: CustomerEmptyState(
                      icon: Icons.savings_rounded,
                      title: 'Vault not found',
                      subtitle:
                          'We could not load this savings vault. Pull to refresh or head back.',
                      ctaLabel: 'Go back',
                      onCtaTap: () => context.pop(),
                    ),
                  ),
                ],
              );
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _maybeRetargetBalance(savings.currentAmount);
            });

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(
                    customerSavingsDetailProvider(widget.savingsId));
                ref.invalidate(
                    customerSavingsTransactionsProvider(widget.savingsId));
              },
              color: theme.colorScheme.primary,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildGradientHeader(
                        context, isDark, headerGradient, savings),
                  ),

                  // Hero progress card
                  SliverToBoxAdapter(
                    child: _staggered(
                      0,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.sm,
                        ),
                        child: _buildHeroCard(theme, isDark, savings),
                      ),
                    ),
                  ),

                  // Action row
                  SliverToBoxAdapter(
                    child: _staggered(
                      1,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.sm / 2,
                          AppSpacing.md,
                          AppSpacing.sm,
                        ),
                        child: _buildActionRow(isDark, savings),
                      ),
                    ),
                  ),

                  // Savings growth chart
                  SliverToBoxAdapter(
                    child: _staggered(
                      2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm / 2,
                        ),
                        child: transactionsAsync.maybeWhen(
                          data: (txs) => CustomerSavingsGrowthChart(
                            data: _buildGrowthSeries(txs),
                          ),
                          orElse: () => const ShimmerCard(
                            height: 280,
                            borderRadius: 18,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Milestones
                  SliverToBoxAdapter(
                    child: _staggered(
                      3,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm / 2,
                        ),
                        child: CustomerSavingsMilestones(
                          currentAmount: savings.currentAmount,
                          targetAmount: savings.targetAmount,
                          planName: savings.displayName,
                        ),
                      ),
                    ),
                  ),

                  // Account details
                  SliverToBoxAdapter(
                    child: _staggered(
                      4,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm / 2,
                        ),
                        child: _buildDetailsCard(theme, isDark, savings),
                      ),
                    ),
                  ),

                  // Recent contributions header
                  SliverToBoxAdapter(
                    child: _staggered(
                      5,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                size: 16,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Recent Contributions',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Recent contributions list (last 5)
                  transactionsAsync.when(
                    loading: () => SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, __) => const Padding(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.md, 4, AppSpacing.md, 4,
                          ),
                          child: ShimmerCard(height: 64, borderRadius: 16),
                        ),
                        childCount: 3,
                      ),
                    ),
                    error: (e, _) => SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          'Could not load transactions: $e',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ),
                    data: (transactions) {
                      if (transactions.isEmpty) {
                        return const SliverToBoxAdapter(
                          child: CustomerEmptyState(
                            icon: Icons.savings_rounded,
                            title: 'No contributions yet',
                            subtitle:
                                'Your first deposit will appear here. Tap "Add Savings" to begin.',
                          ),
                        );
                      }
                      final recent = transactions.take(5).toList();
                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return _staggered(
                              6 + index,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.md, 3, AppSpacing.md, 3,
                                ),
                                child: _buildContributionTile(
                                    theme, isDark, recent[index]),
                              ),
                            );
                          },
                          childCount: recent.length,
                        ),
                      );
                    },
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 110),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
    );
  }

  // ---------- Builders ----------

  Widget _staggered(int index, {required Widget child}) {
    final delay = (index * 0.07).clamp(0.0, 0.9);
    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, c) {
        final progress = ((_staggerController.value - delay) / (1 - delay))
            .clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(progress);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - eased)),
            child: c,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildHeroCard(
      ThemeData theme, bool isDark, CustomerSavingsModel savings) {
    final progress = (savings.progressPercentage / 100).clamp(0.0, 1.0);
    final progressColor = _progressColor(savings.progressPercentage, isDark);

    return GlassCard(
      elevated: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProgressGauge(
                value: progress,
                size: 104,
                strokeWidth: 9,
                progressColor: progressColor,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : AppColors.fillLight,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                          begin: 0, end: savings.progressPercentage),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => Text(
                        '${v.toStringAsFixed(0)}%',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: progressColor,
                          letterSpacing: -0.3,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      'done',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saved',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight)
                            .withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: _previousBalance,
                        end: savings.currentAmount,
                      ),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => Text(
                        _formatCurrency(v),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.flag_rounded,
                          size: 14,
                          color: theme.textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.55),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Target ${_formatCurrency(savings.targetAmount)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.65),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: progressColor.withValues(alpha: isDark ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: progressColor.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: progressColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _etaToGoal(savings),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: progressColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Text(
                  _formatCurrency(
                    (savings.targetAmount - savings.currentAmount)
                        .clamp(0.0, double.infinity),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: progressColor,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'left',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: progressColor.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(bool isDark, CustomerSavingsModel savings) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.download_rounded,
            label: 'Statement',
            gradient: LinearGradient(
              colors: [
                AppColors.accent,
                AppColors.accentLight,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            onTap: () => _showStatementSheet(context, isDark, savings),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsCard(
      ThemeData theme, bool isDark, CustomerSavingsModel savings) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Account Details',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _DetailRow(
            label: 'Monthly Deposit',
            value: _formatCurrency(savings.monthlyDeposit),
          ),
          _DetailRow(
            label: 'Interest Rate',
            value: '${savings.interestRate.toStringAsFixed(1)}%',
          ),
          if (savings.tenureLabel.isNotEmpty)
            _DetailRow(
              label: 'Tenure',
              value: savings.tenureLabel,
            ),
          if (savings.maturityDate != null)
            _DetailRow(
              label: 'Maturity Date',
              value: _formatDate(savings.maturityDate!),
            ),
          _DetailRow(
            label: 'Status',
            value: savings.status[0].toUpperCase() +
                savings.status.substring(1),
            trailing: StatusBadge(
              label: savings.status[0].toUpperCase() +
                  savings.status.substring(1),
              type: _statusType(savings.status),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContributionTile(
    ThemeData theme,
    bool isDark,
    CustomerTransactionModel tx,
  ) {
    final isCredit = tx.isCredit;
    final color = isCredit ? AppColors.success : AppColors.warning;
    final sign = isCredit ? '+' : '-';
    final date = tx.transactionDate;

    Color statusColor;
    switch (tx.status.toLowerCase()) {
      case 'synced':
      case 'success':
      case 'completed':
        statusColor = AppColors.success;
        break;
      case 'pending':
        statusColor = AppColors.warning;
        break;
      case 'failed':
      case 'error':
        statusColor = AppColors.error;
        break;
      default:
        statusColor = AppColors.info;
    }

    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 12,
      ),
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCredit
                  ? Icons.south_west_rounded
                  : Icons.north_east_rounded,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description ??
                      (isCredit ? 'Savings Deposit' : 'Withdrawal'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      date != null ? _formatShortDate(date) : '—',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.35),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tx.status[0].toUpperCase() + tx.status.substring(1),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '$sign${_formatCurrency(tx.amount)}',
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(
      BuildContext context, bool isDark, LinearGradient gradient) {
    return Column(
      children: [
        _buildGradientHeader(context, isDark, gradient, null),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: const [
              ShimmerCard(height: 180, borderRadius: 22),
              SizedBox(height: 10),
              ShimmerCard(height: 56, borderRadius: 14),
              SizedBox(height: 10),
              ShimmerCard(height: 280, borderRadius: 18),
              SizedBox(height: 10),
              ShimmerCard(height: 140, borderRadius: 18),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(
      Object e, bool isDark, LinearGradient gradient) {
    return Column(
      children: [
        _buildGradientHeader(context, isDark, gradient, null),
        Expanded(
          child: CustomerEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Could not load vault',
            subtitle: e.toString(),
            ctaLabel: 'Retry',
            onCtaTap: () => ref.invalidate(
                customerSavingsDetailProvider(widget.savingsId)),
          ),
        ),
      ],
    );
  }

  Widget _buildGradientHeader(
    BuildContext context,
    bool isDark,
    LinearGradient gradient,
    CustomerSavingsModel? savings,
  ) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);

    return FadeTransition(
      opacity: _headerFade,
      child: SlideTransition(
        position: _headerSlide,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            mq.padding.top + AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _CircleIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => context.pop(),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            savings?.displayName ?? 'Savings Vault',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (savings != null) ...[
                            const SizedBox(height: 4),
                            _TypeChip(
                              label: savings.tenureLabel.isNotEmpty
                                  ? 'Recurring · ${savings.tenureLabel}'
                                  : 'Savings Plan',
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (savings != null)
                      StatusBadge(
                        label: savings.status[0].toUpperCase() +
                            savings.status.substring(1),
                        type: _statusType(savings.status),
                        glow: true,
                      ),
                  ],
                ),
                if (savings != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Current Balance',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: _previousBalance,
                      end: savings.currentAmount,
                    ),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => Text(
                      _formatCurrency(value),
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        fontFeatures: const [
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'of ${_formatCurrency(savings.targetAmount)} target  ·  ${savings.progressPercentage.toStringAsFixed(1)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Subtle pill showing the vault type/tenure in the header.
class _TypeChip extends StatelessWidget {
  final String label;
  const _TypeChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Gradient action button with iOS-grade press feedback.
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.colors.first.withValues(alpha: 0.32),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 18),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
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

/// Detail row with optional trailing widget (e.g., StatusBadge).
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;

  const _DetailRow({
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight)
                  .withValues(alpha: 0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing ??
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
        ],
      ),
    );
  }
}

/// Circular icon button used in the header.
class _CircleIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  State<_CircleIconButton> createState() => _CircleIconButtonState();
}

class _CircleIconButtonState extends State<_CircleIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _pressed
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          widget.icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
