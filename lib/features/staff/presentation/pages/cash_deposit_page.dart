import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/models/wallet_model.dart';
import '../../data/providers/staff_providers.dart';

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
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deposit Cash'),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : _buildDepositForm(user.id, theme),
    );
  }

  Widget _buildDepositForm(String staffId, ThemeData theme) {
    final walletAsync = ref.watch(staffWalletProvider(staffId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWalletBalanceCard(walletAsync, theme),
            const SizedBox(height: 24),
            _buildAmountSection(theme),
            const SizedBox(height: 24),
            _buildDepositMethodSection(theme),
            const SizedBox(height: 24),
            _buildReferenceSection(theme),
            const SizedBox(height: 24),
            _buildNotesSection(theme),
            const SizedBox(height: 32),
            _buildSubmitButton(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletBalanceCard(AsyncValue<WalletModel?> walletAsync, ThemeData theme) {
    return walletAsync.when(
      data: (wallet) {
        final cashInHand = wallet?.cashInHand ?? 0.0;
        return GlassCard(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_wallet, color: Colors.green, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cash in Hand',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(cashInHand),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  _amountController.text = cashInHand.toStringAsFixed(0);
                },
                child: const Text('Deposit All'),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text('Error: $err'),
    );
  }

  Widget _buildAmountSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Deposit Amount',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            prefixText: '₹ ',
            hintText: 'Enter amount',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter amount';
            }
            final amount = double.tryParse(value);
            if (amount == null || amount <= 0) {
              return 'Enter a valid amount';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [500, 1000, 2000, 5000, 10000].map((amt) {
            return ActionChip(
              label: Text('₹$amt'),
              onPressed: () {
                _amountController.text = amt.toString();
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDepositMethodSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Deposit Method',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMethodCard(
                theme,
                'branch',
                'Branch Counter',
                Icons.store,
                'Deposit at branch counter',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMethodCard(
                theme,
                'pickup',
                'Cash Pickup',
                Icons.local_shipping,
                'Request pickup',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMethodCard(
    ThemeData theme,
    String method,
    String title,
    IconData icon,
    String subtitle,
  ) {
    final isSelected = _depositMethod == method;

    return InkWell(
      onTap: () {
        setState(() => _depositMethod = method);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? theme.colorScheme.primary : null,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isSelected ? theme.colorScheme.primary : null,
              ),
            ),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reference Number (Optional)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _referenceController,
          decoration: InputDecoration(
            hintText: 'Receipt/Transaction number',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes (Optional)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add any notes...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(ThemeData theme) {
    return Column(
      children: [
        FilledButton.icon(
          onPressed: _isLoading ? null : _submitDeposit,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_circle),
          label: Text(_isLoading ? 'Processing...' : 'Confirm Deposit'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'This will update your cash balance',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _submitDeposit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('Not authenticated');

      final amount = double.parse(_amountController.text);

      await ref.read(staffRepositoryProvider).recordCashDeposit(
        staffId: user.id,
        amount: amount,
        method: _depositMethod,
        reference: _referenceController.text.isNotEmpty ? _referenceController.text : null,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      // Invalidate wallet provider to refresh
      ref.invalidate(staffWalletProvider(user.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deposit of ₹$amount recorded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record deposit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
