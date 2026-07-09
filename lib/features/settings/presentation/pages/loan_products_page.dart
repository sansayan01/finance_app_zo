import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/providers/products_providers.dart';
import 'product_form_sheet.dart';

class LoanProductsPage extends ConsumerWidget {
  const LoanProductsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncProducts = ref.watch(loanProductsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Loan Products'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Product',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: asyncProducts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (products) {
          if (products.isEmpty) {
            return _buildEmptyState(theme, context, ref);
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            itemCount: products.length,
            itemBuilder: (context, i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildProductCard(products[i], context, ref, theme)
                    .animate(delay: Duration(milliseconds: 40 * i))
                    .fadeIn()
                    .slideY(begin: 0.03, end: 0),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          children: [
            Icon(Icons.account_balance_outlined,
                size: 56,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text(
              'No loan products yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Create your first loan product to get started',
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showForm(context, ref),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create Loan Product',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(
      Map<String, dynamic> product, BuildContext context, WidgetRef ref, ThemeData theme) {
    final name = product['name']?.toString() ?? '';
    final rate = product['interest_rate']?.toString() ?? '0';
    final mode = product['interest_mode']?.toString() ?? 'reducing';
    final minAmt = product['min_amount'];
    final maxAmt = product['max_amount'];
    final tenure = product['tenure_months']?.toString() ?? product['tenure']?.toString() ?? '-';
    final freq = product['frequency']?.toString() ?? 'monthly';
    final isActive = product['is_active'] ?? true;

    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _showForm(context, ref, existing: product),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.success.withValues(alpha: 0.12)
                          : Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isActive ? AppColors.success : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(isActive ? 'Deactivate' : 'Activate'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                    onSelected: (v) => _handleAction(v, product, context, ref),
                    icon: Icon(Icons.more_vert_rounded,
                        size: 20,
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.4)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _infoChip(Icons.percent_rounded, '$rate% $mode'),
                  _infoChip(Icons.calendar_today_rounded, '$tenure ${freq}s'),
                  if (minAmt != null || maxAmt != null)
                    _infoChip(
                        Icons.currency_rupee_rounded,
                        '${minAmt != null ? '₹${_formatNum(minAmt)}' : '₹0'} - ${maxAmt != null ? '₹${_formatNum(maxAmt)}' : '∞'}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  String _formatNum(dynamic v) {
    final n = double.tryParse(v.toString()) ?? 0;
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }

  void _showForm(BuildContext context, WidgetRef ref,
      {Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ProductFormSheet(
        productType: ProductType.loan,
        existingProduct: existing,
      ),
    ).then((result) {
      if (result == true) ref.invalidate(loanProductsProvider);
    });
  }

  void _handleAction(
      String action, Map<String, dynamic> product, BuildContext context, WidgetRef ref) async {
    final service = ref.read(loanProductsServiceProvider);
    switch (action) {
      case 'edit':
        _showForm(context, ref, existing: product);
        break;
      case 'toggle':
        await service.toggleActive(product['id'], !(product['is_active'] ?? true));
        ref.invalidate(loanProductsProvider);
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Product'),
            content: Text('Delete "${product['name']}"? This cannot be undone.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        if (confirm == true) {
          await service.deleteProduct(product['id']);
          ref.invalidate(loanProductsProvider);
        }
        break;
    }
  }
}
