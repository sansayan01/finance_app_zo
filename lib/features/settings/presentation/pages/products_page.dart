import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/providers/products_providers.dart';
import 'product_form_sheet.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Loan & Savings Products'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'New Product',
              onPressed: () {
                final isLoan = _tabController.index == 0;
                _showForm(
                  ctx,
                  ref,
                  productType: isLoan ? ProductType.loan : ProductType.savings,
                );
              },
            ),
          ),
        ],
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor:
              theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.account_balance_outlined, size: 20), text: 'Loan Products'),
            Tab(icon: Icon(Icons.savings_outlined, size: 20), text: 'Savings Products'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _LoanProductsTab(),
          _SavingsProductsTab(),
        ],
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref,
      {required ProductType productType, Map<String, dynamic>? existing}) {
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
        productType: productType,
        existingProduct: existing,
      ),
    ).then((result) {
      if (result == true) {
        if (productType == ProductType.loan) {
          ref.invalidate(loanProductsProvider);
        } else {
          ref.invalidate(savingsProductsProvider);
        }
      }
    });
  }
}

// ─── Loan Products Tab ────────────────────────────────────────────────────

class _LoanProductsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncProducts = ref.watch(loanProductsProvider);

    return asyncProducts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (products) {
        if (products.isEmpty) {
          return _buildEmptyState(theme, 'No loan products yet',
              'Create your first loan product to get started', AppColors.primary);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          itemCount: products.length,
          itemBuilder: (context, i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildLoanCard(products[i], context, ref, theme)
                  .animate(delay: Duration(milliseconds: 40 * i))
                  .fadeIn()
                  .slideY(begin: 0.03, end: 0),
            );
          },
        );
      },
    );
  }

  Widget _buildLoanCard(
      Map<String, dynamic> product, BuildContext context, WidgetRef ref, ThemeData theme) {
    final name = product['name']?.toString() ?? '';
    final rate = product['interest_rate']?.toString() ?? '0';
    final mode = product['interest_mode']?.toString() ?? 'reducing';
    final minAmt = product['min_amount'];
    final maxAmt = product['max_amount'];
    final tenure = product['tenure_months']?.toString() ?? '-';
    final freq = product['frequency']?.toString() ?? 'monthly';
    final isActive = product['is_active'] ?? true;

    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _showEdit(context, ref, product),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  _statusBadge(isActive),
                  const SizedBox(width: 8),
                  _moreMenu(product, context, ref, ProductType.loan),
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
                    _infoChip(Icons.currency_rupee_rounded,
                        '${minAmt != null ? '₹${_formatNum(minAmt)}' : '₹0'} - ${maxAmt != null ? '₹${_formatNum(maxAmt)}' : '∞'}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEdit(BuildContext context, WidgetRef ref, Map<String, dynamic> product) {
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
        existingProduct: product,
      ),
    ).then((result) {
      if (result == true) ref.invalidate(loanProductsProvider);
    });
  }
}

// ─── Savings Products Tab ─────────────────────────────────────────────────

class _SavingsProductsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncProducts = ref.watch(savingsProductsProvider);

    return asyncProducts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (products) {
        if (products.isEmpty) {
          return _buildEmptyState(theme, 'No savings products yet',
              'Create your first savings product to get started', AppColors.success);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          itemCount: products.length,
          itemBuilder: (context, i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildSavingsCard(products[i], context, ref, theme)
                  .animate(delay: Duration(milliseconds: 40 * i))
                  .fadeIn()
                  .slideY(begin: 0.03, end: 0),
            );
          },
        );
      },
    );
  }

  Widget _buildSavingsCard(
      Map<String, dynamic> product, BuildContext context, WidgetRef ref, ThemeData theme) {
    final name = product['name']?.toString() ?? '';
    final rate = product['interest_rate']?.toString() ?? '0';
    final collectionType = product['collection_type']?.toString() ?? 'monthly';
    final minDep = product['min_deposit'];
    final maxDep = product['max_deposit'];
    final tenure = product['tenure']?.toString() ?? '-';
    final tenureUnit = product['tenure_unit']?.toString() ?? 'months';
    final penalty = product['premature_penalty']?.toString() ?? '0';
    final isActive = product['is_active'] ?? true;

    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _showEdit(context, ref, product),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  _statusBadge(isActive),
                  const SizedBox(width: 8),
                  _moreMenu(product, context, ref, ProductType.savings),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _infoChip(Icons.percent_rounded, '$rate% yield'),
                  _infoChip(Icons.autorenew_rounded, collectionType),
                  _infoChip(Icons.calendar_today_rounded, '$tenure $tenureUnit'),
                  if (double.tryParse(penalty) != null && double.parse(penalty) > 0)
                    _infoChip(Icons.warning_amber_rounded, '$penalty% penalty'),
                ],
              ),
              if (minDep != null || maxDep != null) ...[
                const SizedBox(height: 6),
                _infoChip(Icons.currency_rupee_rounded,
                    'Deposit: ${minDep != null ? '₹${_formatNum(minDep)}' : '₹0'} - ${maxDep != null ? '₹${_formatNum(maxDep)}' : '∞'}'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showEdit(BuildContext context, WidgetRef ref, Map<String, dynamic> product) {
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
        productType: ProductType.savings,
        existingProduct: product,
      ),
    ).then((result) {
      if (result == true) ref.invalidate(savingsProductsProvider);
    });
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────

Widget _buildEmptyState(ThemeData theme, String title, String subtitle, Color color) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 56,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 13,
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5))),
        ],
      ),
    ),
  );
}

Widget _statusBadge(bool isActive) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

Widget _moreMenu(
    Map<String, dynamic> product, BuildContext context, WidgetRef ref, ProductType type) {
  return PopupMenuButton<String>(
    itemBuilder: (ctx) => [
      const PopupMenuItem(value: 'edit', child: Text('Edit')),
      PopupMenuItem(
        value: 'toggle',
        child: Text(product['is_active'] == true ? 'Deactivate' : 'Activate'),
      ),
      const PopupMenuItem(
        value: 'delete',
        child: Text('Delete', style: TextStyle(color: Colors.red)),
      ),
    ],
    onSelected: (v) => _handleAction(v, product, context, ref, type),
    icon: Icon(Icons.more_vert_rounded,
        size: 20,
        color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.4)),
  );
}

String _formatNum(dynamic v) {
  final n = double.tryParse(v.toString()) ?? 0;
  if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return n.toStringAsFixed(0);
}

void _handleAction(String action, Map<String, dynamic> product,
    BuildContext context, WidgetRef ref, ProductType type) async {
  final provider = type == ProductType.loan ? loanProductsProvider : savingsProductsProvider;

  switch (action) {
    case 'edit':
      // Handled by card onTap
      break;
    case 'toggle':
      if (type == ProductType.loan) {
        await ref.read(loanProductsServiceProvider)
            .toggleActive(product['id'], !(product['is_active'] ?? true));
      } else {
        await ref.read(savingsProductsServiceProvider)
            .toggleActive(product['id'], !(product['is_active'] ?? true));
      }
      ref.invalidate(provider);
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
                child: const Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (confirm == true) {
        if (type == ProductType.loan) {
          await ref.read(loanProductsServiceProvider).deleteProduct(product['id']);
        } else {
          await ref.read(savingsProductsServiceProvider).deleteProduct(product['id']);
        }
        ref.invalidate(provider);
      }
      break;
  }
}
