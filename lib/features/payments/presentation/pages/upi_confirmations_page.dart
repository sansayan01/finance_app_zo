import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
  String _filter = 'pending';

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(allUpiRequestsProvider(_filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('UPI Payment Confirmations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(allUpiRequestsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildFilterChip('pending', 'Pending'),
                const SizedBox(width: 8),
                _buildFilterChip('confirmed', 'Confirmed'),
                const SizedBox(width: 8),
                _buildFilterChip('rejected', 'Rejected'),
                const SizedBox(width: 8),
                _buildFilterChip(null, 'All'),
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
                          'No ${_filter ?? ''} UPI payments',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final req = UpiPaymentRequest.fromJson(requests[index] as Map<String, dynamic>);
                    return _buildRequestCard(req);
                  },
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

  Widget _buildFilterChip(String? value, String label) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filter = value ?? 'pending'),
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
    );
  }

  Widget _buildRequestCard(UpiPaymentRequest req) {
    final typeLabel = req.isLoanPayment ? 'Loan EMI' : 'Savings Inst.';
    final amountLabel = '₹${req.amount.toStringAsFixed(2)}';
    final timeAgo = _formatTimeAgo(req.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Icon(Icons.person, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.customerId.substring(0, 8),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$typeLabel • $amountLabel',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Text(
                  timeAgo,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'VPA: ${req.upiVpa}',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            if (req.status == 'confirmed')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text('Confirmed', style: TextStyle(color: Colors.green)),
                  ],
                ),
              ),
            if (req.status == 'rejected')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.cancel, color: Colors.red, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Rejected: ${req.rejectionReason ?? ''}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            if (req.status == 'pending')
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _rejectPayment(req),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _confirmPayment(req),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Confirm'),
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

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  Future<void> _confirmPayment(UpiPaymentRequest req) async {
    final repository = ref.read(upiRepositoryProvider);
    try {
      await repository.confirmPayment(requestId: req.id, confirmedBy: '');
      ref.invalidate(allUpiRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment confirmed'),
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
    }
  }

  Future<void> _rejectPayment(UpiPaymentRequest req) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const UpiConfirmDialog(title: 'Reject Payment'),
    );
    if (reason == null || reason.trim().isEmpty) return;

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
    }
  }
}
