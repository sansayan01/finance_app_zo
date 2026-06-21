import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/upi_providers.dart';
import '../../data/models/upi_payment_request_model.dart';
import '../widgets/upi_confirm_dialog.dart';

class UpiConfirmationsPage extends ConsumerStatefulWidget {
  const UpiConfirmationsPage({super.key});

  @override
  ConsumerState<UpiConfirmationsPage> createState() => _UpiConfirmationsPageState();
}

class _UpiConfirmationsPageState extends ConsumerState<UpiConfirmationsPage> {
  /// Empty string = "All" filter (no status filter applied)
  String _filter = 'pending';
  final Set<String> _selectedIds = {};
  bool _isProcessing = false;

  /// Human-readable label for the current filter
  String get _filterLabel {
    switch (_filter) {
      case 'pending':
        return 'pending';
      case 'confirmed':
        return 'confirmed';
      case 'rejected':
        return 'rejected';
      default:
        return 'UPI payments';
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(allUpiRequestsProvider(_filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('UPI Payment Confirmations'),
        actions: [
          if (_filter == 'pending' && _selectedIds.isNotEmpty)
            TextButton.icon(
              onPressed: _isProcessing ? null : _confirmSelected,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle, color: Colors.white),
              label: Text(
                _isProcessing ? 'Confirming...' : 'Confirm (${_selectedIds.length})',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(allUpiRequestsProvider);
              setState(() => _selectedIds.clear());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Wrap(
              spacing: 8,
              children: [
                _buildFilterChip('pending', 'Pending'),
                _buildFilterChip('confirmed', 'Confirmed'),
                _buildFilterChip('rejected', 'Rejected'),
                _buildFilterChip('', 'All'),
              ],
            ),
          ),
          Expanded(
            child: requestsAsync.when(
              data: (requests) {
                if (requests.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payment, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No $_filterLabel found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final batches = _groupIntoBatches(requests);

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(allUpiRequestsProvider);
                    setState(() => _selectedIds.clear());
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: batches.length,
                    itemBuilder: (context, index) => _buildBatchCard(batches[index]),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  /// Groups requests by customer_id + loan_id/savings_plan_id + created_at within 5 min.
  List<List<UpiPaymentRequest>> _groupIntoBatches(List<UpiPaymentRequest> requests) {
    if (requests.isEmpty) return [];

    final sorted = List<UpiPaymentRequest>.from(requests)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final batches = <List<UpiPaymentRequest>>[];
    var currentBatch = <UpiPaymentRequest>[sorted.first];

    for (var i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final curr = sorted[i];

      final sameCustomer = curr.customerId == prev.customerId;
      final sameLoan = curr.loanId != null && curr.loanId == prev.loanId;
      final sameSavings = curr.savingsPlanId != null && curr.savingsPlanId == prev.savingsPlanId;
      final withinFiveMin = curr.createdAt.difference(prev.createdAt).abs() <= const Duration(minutes: 5);

      if (sameCustomer && (sameLoan || sameSavings) && withinFiveMin) {
        currentBatch.add(curr);
      } else {
        batches.add(currentBatch);
        currentBatch = [curr];
      }
    }
    batches.add(currentBatch);

    return batches;
  }

  Widget _buildBatchCard(List<UpiPaymentRequest> batch) {
    final first = batch.first;
    final total = batch.fold<double>(0, (sum, r) => sum + r.amount);
    final typeLabel = first.isLoanPayment ? 'Loan EMI' : 'Savings Inst.';
    final allSelected = batch.every((r) => _selectedIds.contains(r.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Batch header with select-all
            Row(
              children: [
                if (_filter == 'pending')
                  Checkbox(
                    value: allSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          for (final r in batch) {
                            _selectedIds.add(r.id);
                          }
                        } else {
                          for (final r in batch) {
                            _selectedIds.remove(r.id);
                          }
                        }
                      });
                    },
                    activeColor: AppColors.primary,
                  ),
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Icon(
                    first.isLoanPayment ? Icons.account_balance : Icons.savings,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${batch.length} $typeLabel installment${batch.length > 1 ? 's' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        '₹${total.toStringAsFixed(2)} total · ${_formatTimeAgo(first.createdAt)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (_filter != 'pending')
                  Icon(
                    first.status == 'confirmed' ? Icons.check_circle : Icons.cancel,
                    color: first.status == 'confirmed' ? Colors.green : Colors.red,
                    size: 20,
                  ),
              ],
            ),

            const Divider(),

            // Individual requests within the batch
            for (final req in batch)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    if (_filter == 'pending')
                      Checkbox(
                        value: _selectedIds.contains(req.id),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedIds.add(req.id);
                            } else {
                              _selectedIds.remove(req.id);
                            }
                          });
                        },
                        activeColor: AppColors.primary,
                      ),
                    Icon(
                      req.status == 'confirmed'
                          ? Icons.check_circle
                          : req.status == 'rejected'
                              ? Icons.cancel
                              : Icons.pending,
                      size: 16,
                      color: req.status == 'confirmed'
                          ? Colors.green
                          : req.status == 'rejected'
                              ? Colors.red
                              : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '₹${req.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    if (req.status == 'pending')
                      TextButton(
                        onPressed: _isProcessing ? null : () => _rejectPayment(req),
                        child: const Text('Reject', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                  ],
                ),
              ),

            // Confirm/Reject buttons for individual batches (when nothing is selected)
            if (_filter == 'pending' && _selectedIds.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : () => _rejectBatch(batch),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Reject All'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : () => _confirmBatchWithDialog(batch),
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check, size: 16),
                        label: Text(_isProcessing ? 'Confirming...' : 'Confirm All'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _filter = value;
          _selectedIds.clear();
        });
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  // ── Confirmation dialog ──

  Future<bool> _showConfirmDialog(int count, double totalAmount) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Text(
          'Confirm $count payment${count > 1 ? 's' : ''} totaling ₹${totalAmount.toStringAsFixed(2)}?\n\n'
          'This will create collection records in the system.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Batch confirm/reject ──

  Future<void> _confirmSelected() async {
    if (_selectedIds.isEmpty || _isProcessing) return;

    // Show confirmation dialog
    final confirmed = await _showConfirmDialog(_selectedIds.length, 0);
    if (!confirmed) return;

    setState(() => _isProcessing = true);

    final staffId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final repository = ref.read(upiRepositoryProvider);
    try {
      await repository.confirmBatch(
        requestIds: _selectedIds.toList(),
        confirmedBy: staffId,
      );
      ref.invalidate(allUpiRequestsProvider);
      setState(() => _selectedIds.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payments confirmed and collections created'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _confirmBatchWithDialog(List<UpiPaymentRequest> batch) async {
    final total = batch.fold<double>(0, (sum, r) => sum + r.amount);
    final confirmed = await _showConfirmDialog(batch.length, total);
    if (!confirmed) return;
    await _confirmBatch(batch);
  }

  Future<void> _confirmBatch(List<UpiPaymentRequest> batch) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    final staffId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final repository = ref.read(upiRepositoryProvider);
    try {
      await repository.confirmBatch(
        requestIds: batch.map((r) => r.id).toList(),
        confirmedBy: staffId,
      );
      ref.invalidate(allUpiRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${batch.length} payments confirmed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectPayment(UpiPaymentRequest req) async {
    if (_isProcessing) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const UpiConfirmDialog(title: 'Reject Payment'),
    );
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _isProcessing = true);

    final repository = ref.read(upiRepositoryProvider);
    try {
      await repository.rejectPayment(requestId: req.id, rejectionReason: reason);
      ref.invalidate(allUpiRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectBatch(List<UpiPaymentRequest> batch) async {
    if (_isProcessing) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const UpiConfirmDialog(title: 'Reject All Payments'),
    );
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _isProcessing = true);

    final repository = ref.read(upiRepositoryProvider);
    try {
      for (final req in batch) {
        await repository.rejectPayment(requestId: req.id, rejectionReason: reason);
      }
      ref.invalidate(allUpiRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${batch.length} payments rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
