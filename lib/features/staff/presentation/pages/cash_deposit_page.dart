import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/wallet_model.dart';
import '../../data/providers/staff_providers.dart';
import '../../data/providers/collection_providers.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';

class CashDepositPage extends ConsumerStatefulWidget {
  const CashDepositPage({super.key});

  @override
  ConsumerState<CashDepositPage> createState() => _CashDepositPageState();
}

class _CashDepositPageState extends ConsumerState<CashDepositPage> {
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _depositMethod = 'branch';
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_rounded,
              color: isDark ? Colors.white70 : Colors.black87),
        ),
        title: const Text('Deposit Cash',
            style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(user.id, theme, isDark),
    );
  }

  Widget _buildForm(String staffId, ThemeData theme, bool isDark) {
    final walletAsync = ref.watch(staffWalletProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            walletAsync.when(
              data: (wallet) => _buildWalletCard(wallet!, theme, isDark),
              loading: () => const ShimmerCard(height: 100),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),
            _buildAmountSection(theme, isDark),
            const SizedBox(height: 20),
            _buildMethodSection(theme, isDark),
            const SizedBox(height: 20),
            _buildReferenceSection(theme, isDark),
            const SizedBox(height: 20),
            _buildNotesSection(theme, isDark),
            const SizedBox(height: 32),
            _buildSubmitButton(theme),
          ].animate(interval: 60.ms).fadeIn().slideY(begin: 0.04, end: 0),
        ),
      ),
    );
  }

  Widget _buildWalletCard(WalletModel wallet, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cash in Hand',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500)),
                Text(
                    NumberFormat.currency(locale: 'en_IN', symbol: '₹')
                        .format(wallet.cashInHand),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          TextButton(
            onPressed: () =>
                _amountController.text = wallet.cashInHand.toStringAsFixed(0),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('All',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountSection(ThemeData theme, bool isDark) {
    return _section(
      theme,
      isDark,
      'Amount',
      Icons.payments_rounded,
      child: TextFormField(
        controller: _amountController,
        keyboardType: TextInputType.number,
        style: theme.textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w900, color: AppColors.primary),
        decoration: InputDecoration(
          prefixText: '₹ ',
          prefixStyle: theme.textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w900, color: AppColors.primary),
          hintText: '0',
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          filled: true,
          fillColor: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : theme.colorScheme.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (v) {
          if (v == null || v.isEmpty) return 'Enter amount';
          final amt = double.tryParse(v);
          if (amt == null || amt <= 0) return 'Invalid amount';
          return null;
        },
      ),
    );
  }

  Widget _buildMethodSection(ThemeData theme, bool isDark) {
    final methods = [
      {
        'id': 'branch',
        'icon': Icons.account_balance_rounded,
        'label': 'Branch Deposit'
      },
      {
        'id': 'bank',
        'icon': Icons.account_balance_wallet_rounded,
        'label': 'Bank Transfer'
      },
      {'id': 'upi', 'icon': Icons.qr_code_rounded, 'label': 'UPI'},
    ];

    return _section(
      theme,
      isDark,
      'Deposit Method',
      Icons.swap_horiz_rounded,
      child: Row(
        children: methods.map((m) {
          final isSelected = _depositMethod == m['id'];
          return Expanded(
            child: Padding(
              padding:
                  EdgeInsets.only(right: m['id'] != methods.last['id'] ? 8 : 0),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _depositMethod = m['id'] as String);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : theme.colorScheme.surface),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color:
                            isSelected ? AppColors.primary : Colors.transparent,
                        width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Icon(m['icon'] as IconData,
                          color: isSelected
                              ? AppColors.primary
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4),
                          size: 22),
                      const SizedBox(height: 6),
                      Text(m['label'] as String,
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? AppColors.primary : null)),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReferenceSection(ThemeData theme, bool isDark) {
    return _section(
      theme,
      isDark,
      'Reference',
      Icons.tag_rounded,
      child: TextField(
        controller: _referenceController,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Transaction ref. or receipt no.',
          hintStyle: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          filled: true,
          fillColor: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : theme.colorScheme.surface,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildNotesSection(ThemeData theme, bool isDark) {
    return _section(
      theme,
      isDark,
      'Notes',
      Icons.notes_rounded,
      child: TextField(
        controller: _notesController,
        maxLines: 2,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Optional notes...',
          hintStyle: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          filled: true,
          fillColor: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : theme.colorScheme.surface,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.upload_rounded, size: 22),
                  SizedBox(width: 10),
                  Text('Confirm Deposit',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700))
                ],
              ),
      ),
    );
  }

  Widget _section(ThemeData theme, bool isDark, String title, IconData icon,
      {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();
    try {
      final profile = await ref.read(staffProfileProvider.future);
      if (profile == null) throw Exception('No profile');
      final repo = ref.read(staffRepositoryProvider);
      final amount = double.parse(_amountController.text);
      await repo.recordCashDeposit(
        staffId: profile.id,
        amount: amount,
        method: _depositMethod,
        reference: _referenceController.text.isNotEmpty
            ? _referenceController.text
            : null,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('₹${amount.toStringAsFixed(0)} deposited successfully'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
        ref.invalidate(staffWalletProvider);
        ref.invalidate(recentActivitiesProvider);
        ref.invalidate(todayCollectionStatsProvider);
        ref.invalidate(todayCollectionsProvider);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class ShimmerCard extends StatelessWidget {
  final double height;
  const ShimmerCard({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}
