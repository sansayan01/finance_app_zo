import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/premium_app_bar.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../data/providers/upi_providers.dart';
import '../../data/models/upi_payment_request_model.dart';
import '../widgets/upi_confirm_dialog.dart';

class UpiConfirmationsPage extends ConsumerStatefulWidget {
  const UpiConfirmationsPage({super.key});

  @override
  ConsumerState<UpiConfirmationsPage> createState() =>
      _UpiConfirmationsPageState();
}

class _UpiConfirmationsPageState extends ConsumerState<UpiConfirmationsPage> {
  /// Empty string = "All" filter (no status filter applied)
  String _filter = 'pending';
  final Set<String> _selectedIds = {};
  bool _isProcessing = false;

  /// Maps customerId (auth.uid) → member full name
  Map<String, String> _memberNames = {};
  /// Maps customerId (auth.uid) → profileId (for navigation)
  Map<String, String> _profileIds = {};
  /// Maps loanId → loan number
  final Map<String, String> _loanNumbers = {};
  /// Maps savingsPlanId → plan name
  final Map<String, String> _savingsPlanNames = {};

  /// Resolves customer_id (auth.uid) → member full_name + profileId
  Future<void> _resolveMemberInfo(List<UpiPaymentRequest> requests) async {
    final client = Supabase.instance.client;
    final customerIds = requests
        .map((r) => r.customerId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (customerIds.isEmpty) return;

    final names = <String, String>{};
    final profileIdResults = <String, String>{};
    try {
      // Step A: auth.uid() → profiles.id
      final profiles = await client
          .from('profiles')
          .select('id, user_id')
          .inFilter('user_id', customerIds);
      final profileIdMap = <String, String>{}; // user_id → profile_id
      for (final p in (profiles as List)) {
        final uid = p['user_id']?.toString() ?? '';
        final pid = p['id']?.toString() ?? '';
        if (uid.isNotEmpty && pid.isNotEmpty) {
          profileIdMap[uid] = pid;
        }
      }

      // Step B: profiles.id → members.full_name
      final profileIds = profileIdMap.values.toSet().toList();
      if (profileIds.isNotEmpty) {
        final members = await client
            .from('members')
            .select('id, profile_id, full_name')
            .inFilter('profile_id', profileIds);
        for (final m in (members as List)) {
          final pid = m['profile_id']?.toString() ?? '';
          final name = m['full_name']?.toString() ?? 'Customer';
          final userId = profileIdMap.entries
              .where((e) => e.value == pid)
              .map((e) => e.key)
              .firstOrNull;
          if (userId != null) {
            names[userId] = name;
            profileIdResults[userId] = pid;
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _memberNames = {..._memberNames, ...names};
        _profileIds = {..._profileIds, ...profileIdResults};
      });
    }
  }

  /// Resolves loan IDs and savings plan IDs to human-readable labels
  Future<void> _resolvePlanLabels(List<UpiPaymentRequest> requests) async {
    final client = Supabase.instance.client;

    // Resolve loan numbers
    final loanIds = requests
        .map((r) => r.loanId)
        .where((id) => id != null && id.isNotEmpty && !_loanNumbers.containsKey(id))
        .toSet()
        .toList();
    if (loanIds.isNotEmpty) {
      try {
        final loans = await client
            .from('loans')
            .select('id, loan_number')
            .inFilter('id', loanIds);
        for (final l in (loans as List)) {
          final id = l['id']?.toString() ?? '';
          final num = l['loan_number']?.toString();
          if (id.isNotEmpty && num != null && num.isNotEmpty) {
            _loanNumbers[id] = 'Loan #$num';
          }
        }
      } catch (_) {}
    }

    // Resolve savings plan names
    final savingsIds = requests
        .map((r) => r.savingsPlanId)
        .where((id) => id != null && id.isNotEmpty && !_savingsPlanNames.containsKey(id))
        .toSet()
        .toList();
    if (savingsIds.isNotEmpty) {
      try {
        final plans = await client
            .from('savings_plans')
            .select('id, plan_name')
            .inFilter('id', savingsIds);
        for (final p in (plans as List)) {
          final id = p['id']?.toString() ?? '';
          final name = p['plan_name']?.toString();
          if (id.isNotEmpty && name != null && name.isNotEmpty) {
            _savingsPlanNames[id] = name;
          }
        }
      } catch (_) {}
    }

    if (mounted) setState(() {});
  }

  String _getMemberName(String customerId) {
    return _memberNames[customerId] ?? 'Customer';
  }

  String? _getProfileId(String customerId) {
    return _profileIds[customerId];
  }

  String _getPlanLabel(UpiPaymentRequest req) {
    if (req.isLoanPayment) {
      return _loanNumbers[req.loanId] ?? 'Loan';
    }
    return _savingsPlanNames[req.savingsPlanId] ?? 'Savings';
  }

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final requestsAsync = ref.watch(allUpiRequestsProvider(_filter));

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F1115)
          : const Color(0xFFF8F9FB),
      appBar: PremiumAppBar(
        title: 'UPI Confirmations',
        actions: [
          _HeaderIconBtn(
            icon: Icons.refresh_rounded,
            onTap: () {
              HapticFeedback.lightImpact();
              ref.invalidate(allUpiRequestsProvider);
              setState(() => _selectedIds.clear());
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AuroraBackground(
        child: Column(
          children: [
            // Filter chips
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: _PremiumFilterRow(
                filter: _filter,
                onFilterChanged: (f) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _filter = f;
                    _selectedIds.clear();
                  });
                },
              ),
            ),

            // Bulk actions bar
            if (_filter == 'pending' && _selectedIds.isNotEmpty)
              _BulkActionsBar(
                count: _selectedIds.length,
                onConfirm: _confirmSelected,
                onCancel: () => setState(() => _selectedIds.clear()),
                isProcessing: _isProcessing,
              ),

            // Content
            Expanded(
              child: requestsAsync.when(
                data: (requests) {
                  if (requests.isEmpty) {
                    return _PremiumEmptyState(filterLabel: _filterLabel);
                  }

                  // Resolve member info + plan labels (fire-and-forget)
                  final unresolved = requests
                      .where((r) => !_memberNames.containsKey(r.customerId))
                      .toList();
                  if (unresolved.isNotEmpty) {
                    _resolveMemberInfo(unresolved);
                  }
                  _resolvePlanLabels(requests);

                  final batches = _groupIntoBatches(requests);

                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async {
                      HapticFeedback.lightImpact();
                      ref.invalidate(allUpiRequestsProvider);
                      setState(() => _selectedIds.clear());
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                      itemCount: batches.length,
                      itemBuilder: (context, index) =>
                          _buildBatchCard(batches[index], index),
                    ),
                  );
                },
                loading: () => _buildShimmerLoading(),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.error_outline_rounded,
                            color: AppColors.error, size: 28),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Something went wrong',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$e',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Premium Shimmer Loading ───

  Widget _buildShimmerLoading() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      child: Column(
        children: List.generate(3, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ShimmerCard(
            height: 120 + (i % 2) * 20,
            borderRadius: 24,
          ),
        ).animate().fadeIn(
              delay: (100 * i).ms,
              duration: 400.ms,
            ).slideY(begin: 0.06, end: 0)),
      ),
    );
  }

  // ─── Batch Grouping ───

  List<List<UpiPaymentRequest>> _groupIntoBatches(
      List<UpiPaymentRequest> requests) {
    if (requests.isEmpty) return [];

    final sorted = List<UpiPaymentRequest>.from(requests)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final batches = <List<UpiPaymentRequest>>[];
    var currentBatch = <UpiPaymentRequest>[sorted.first];

    for (var i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final curr = sorted[i];

      final sameCustomer = curr.customerId == prev.customerId;
      final sameLoan =
          curr.loanId != null && curr.loanId == prev.loanId;
      final sameSavings = curr.savingsPlanId != null &&
          curr.savingsPlanId == prev.savingsPlanId;
      final withinFiveMin = curr.createdAt
              .difference(prev.createdAt)
              .abs() <=
          const Duration(minutes: 5);

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

  // ─── Batch Card ───

  Widget _buildBatchCard(List<UpiPaymentRequest> batch, int index) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final first = batch.first;
    final total = batch.fold<double>(0, (sum, r) => sum + r.amount);
    final allSelected =
        batch.every((r) => _selectedIds.contains(r.id));

    final hasLoan = batch.any((r) => r.isLoanPayment);
    final hasSavings = batch.any((r) => r.isSavingsPayment);
    final isMixed = hasLoan && hasSavings;
    final typeLabel = isMixed
        ? 'Mixed'
        : (first.isLoanPayment ? 'Loan EMI' : 'Savings Inst.');

    // Resolve member name + profile ID
    final memberName = _getMemberName(first.customerId);
    final profileId = _getProfileId(first.customerId);
    final planLabel = _getPlanLabel(first);

    final isPending = _filter == 'pending';

    return GlassCard(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Batch header
          Row(
            children: [
              if (isPending)
                _PremiumCheckbox(
                  value: allSelected,
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
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
                ),
              if (isPending) const SizedBox(width: 12),

              // Gradient icon container
              _BatchAvatar(typeLabel: typeLabel, isMixed: isMixed),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tappable member name
                    GestureDetector(
                      onTap: profileId != null
                          ? () => context.push('/staff/user-hub/$profileId')
                          : null,
                      child: Text(
                        memberName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: profileId != null
                              ? AppColors.primary
                              : theme.colorScheme.onSurface,
                          decoration: profileId != null
                              ? TextDecoration.underline
                              : null,
                          decorationColor: AppColors.primary.withValues(alpha: 0.4),
                          decorationThickness: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Plan label + batch info
                    Text(
                      '$planLabel · ${batch.length} installment${batch.length > 1 ? 's' : ''} · ₹${total.toStringAsFixed(2)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.45),
                        letterSpacing: -0.2,
                      ),
                    ),
                    // Time ago
                    Text(
                      _formatTimeAgo(first.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.35),
                        fontSize: 11,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),

              if (!isPending)
                _StatusPill(status: first.status),
            ],
          ),

          // Audit info for confirmed/rejected
          if (!isPending) ...[
            const SizedBox(height: 10),
            _AuditInfoRow(req: first),
          ],

          const SizedBox(height: 12),

          // Divider
          Container(
            height: 0.5,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),

          const SizedBox(height: 12),

          // Individual requests
          for (final req in batch)
            _RequestRow(
              req: req,
              isPending: isPending,
              isMixed: isMixed,
              isSelected: _selectedIds.contains(req.id),
              planLabel: _getPlanLabel(req),
              onToggle: () {
                HapticFeedback.selectionClick();
                setState(() {
                  if (_selectedIds.contains(req.id)) {
                    _selectedIds.remove(req.id);
                  } else {
                    _selectedIds.add(req.id);
                  }
                });
              },
              onReject: _isProcessing ? null : () => _rejectPayment(req),
            ),

          // Batch actions (when nothing is selected individually)
          if (isPending && _selectedIds.isEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    label: 'Reject All',
                    isPrimary: false,
                    isDestructive: false,
                    icon: Icons.close_rounded,
                    color: AppColors.error,
                    onTap: _isProcessing ? null : () => _rejectBatch(batch),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassButton(
                    label: 'Confirm All',
                    isPrimary: true,
                    isLoading: _isProcessing,
                    icon: Icons.check_rounded,
                    onTap: _isProcessing
                        ? null
                        : () => _confirmBatchWithDialog(batch),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(delay: (80 * index).ms, duration: 400.ms)
        .slideY(begin: 0.06, end: 0);
  }

  // ─── Time Formatting ───

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  // ─── Confirmation Dialog ───

  Future<bool> _showConfirmDialog(int count, double totalAmount) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => _PremiumConfirmDialog(
        count: count,
        totalAmount: totalAmount,
      ),
    );
    return result ?? false;
  }

  // ─── Batch Confirm/Reject ───

  Future<void> _confirmSelected() async {
    if (_selectedIds.isEmpty || _isProcessing) return;

    final allRequests =
        ref.read(allUpiRequestsProvider(_filter)).valueOrNull ?? [];
    final selectedTotal = allRequests
        .where((r) => _selectedIds.contains(r.id))
        .fold<double>(0, (sum, r) => sum + r.amount);

    final confirmed =
        await _showConfirmDialog(_selectedIds.length, selectedTotal);
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
        _showPremiumSnackBar(
          message: 'Payments confirmed and collections created',
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
        );
      }
    } catch (e) {
      if (mounted) {
        _showPremiumSnackBar(
          message: 'Error: $e',
          icon: Icons.error_rounded,
          color: AppColors.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _confirmBatchWithDialog(
      List<UpiPaymentRequest> batch) async {
    final total =
        batch.fold<double>(0, (sum, r) => sum + r.amount);
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
        _showPremiumSnackBar(
          message: '${batch.length} payments confirmed',
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
        );
      }
    } catch (e) {
      if (mounted) {
        _showPremiumSnackBar(
          message: 'Error: $e',
          icon: Icons.error_rounded,
          color: AppColors.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectPayment(UpiPaymentRequest req) async {
    if (_isProcessing) return;

    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UpiConfirmDialog(title: 'Reject Payment'),
    );
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _isProcessing = true);

    final repository = ref.read(upiRepositoryProvider);
    try {
      await repository.rejectPayment(
          requestId: req.id, rejectionReason: reason);
      ref.invalidate(allUpiRequestsProvider);
      if (mounted) {
        _showPremiumSnackBar(
          message: 'Payment rejected',
          icon: Icons.info_rounded,
          color: AppColors.warning,
        );
      }
    } catch (e) {
      if (mounted) {
        _showPremiumSnackBar(
          message: 'Error: $e',
          icon: Icons.error_rounded,
          color: AppColors.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectBatch(List<UpiPaymentRequest> batch) async {
    if (_isProcessing) return;

    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UpiConfirmDialog(title: 'Reject All Payments'),
    );
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _isProcessing = true);

    final repository = ref.read(upiRepositoryProvider);
    try {
      for (final req in batch) {
        await repository.rejectPayment(
            requestId: req.id, rejectionReason: reason);
      }
      ref.invalidate(allUpiRequestsProvider);
      if (mounted) {
        _showPremiumSnackBar(
          message: '${batch.length} payments rejected',
          icon: Icons.info_rounded,
          color: AppColors.warning,
        );
      }
    } catch (e) {
      if (mounted) {
        _showPremiumSnackBar(
          message: 'Error: $e',
          icon: Icons.error_rounded,
          color: AppColors.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showPremiumSnackBar({
    required String message,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E2230).withValues(alpha: 0.98)
                : Colors.white.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PRIVATE SUB-WIDGETS
// ═══════════════════════════════════════════════════════════════

/// Header icon button matching home_page.dart pattern.
class _HeaderIconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconBtn({required this.icon, required this.onTap});

  @override
  State<_HeaderIconBtn> createState() => _HeaderIconBtnState();
}

class _HeaderIconBtnState extends State<_HeaderIconBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
            ),
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Premium filter chip row.
class _PremiumFilterRow extends StatelessWidget {
  final String filter;
  final ValueChanged<String> onFilterChanged;

  const _PremiumFilterRow({
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildChip(context, 'pending', 'Pending', isDark),
          const SizedBox(width: 8),
          _buildChip(context, 'confirmed', 'Confirmed', isDark),
          const SizedBox(width: 8),
          _buildChip(context, 'rejected', 'Rejected', isDark),
          const SizedBox(width: 8),
          _buildChip(context, '', 'All', isDark),
        ],
      ),
    );
  }

  Widget _buildChip(
      BuildContext context, String value, String label, bool isDark) {
    final isSelected = filter == value;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => onFilterChanged(value),
      child: AnimatedScale(
        scale: isSelected ? 1.0 : 0.97,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.12)
                : isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06),
              width: isSelected ? 1 : 0.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? AppColors.primary
                  : theme.colorScheme.onSurface
                      .withValues(alpha: 0.5),
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Premium animated checkbox.
class _PremiumCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?>? onChanged;

  const _PremiumCheckbox({required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => onChanged?.call(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: value
              ? AppColors.primary
              : isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: value
                ? AppColors.primary
                : isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.12),
            width: 1.5,
          ),
        ),
        child: AnimatedScale(
          scale: value ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: const Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
    );
  }
}

/// Gradient-tinted batch avatar.
class _BatchAvatar extends StatelessWidget {
  final String typeLabel;
  final bool isMixed;

  const _BatchAvatar({required this.typeLabel, required this.isMixed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
            AppColors.primary.withValues(alpha: isDark ? 0.08 : 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        isMixed
            ? Icons.payments_rounded
            : (typeLabel == 'Loan EMI'
                ? Icons.account_balance_rounded
                : Icons.savings_rounded),
        color: AppColors.primary,
        size: 20,
      ),
    );
  }
}

/// Status pill using StatusBadge pattern.
class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (Color bg, Color fg) = switch (status) {
      'confirmed' => (
          isDark
              ? const Color(0xFF34C759).withValues(alpha: 0.18)
              : const Color(0xFF34C759).withValues(alpha: 0.12),
          const Color(0xFF34C759),
        ),
      'rejected' => (
          isDark
              ? const Color(0xFFFF3B30).withValues(alpha: 0.18)
              : const Color(0xFFFF3B30).withValues(alpha: 0.12),
          const Color(0xFFFF3B30),
        ),
      _ => (
          isDark
              ? const Color(0xFFFF9F0A).withValues(alpha: 0.18)
              : const Color(0xFFFF9F0A).withValues(alpha: 0.12),
          const Color(0xFFFF9F0A),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Individual request row within a batch.
/// Audit info row for confirmed/rejected payments.
class _AuditInfoRow extends StatelessWidget {
  final UpiPaymentRequest req;

  const _AuditInfoRow({required this.req});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRejected = req.status == 'rejected';

    final infoColor = isRejected ? AppColors.error : AppColors.success;
    final infoBg = isRejected
        ? AppColors.error.withValues(alpha: isDark ? 0.08 : 0.05)
        : AppColors.success.withValues(alpha: isDark ? 0.08 : 0.05);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: infoBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: infoColor.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Status + time
          Row(
            children: [
              Icon(
                isRejected
                    ? Icons.cancel_outlined
                    : Icons.check_circle_outline_rounded,
                color: infoColor,
                size: 14,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isRejected ? 'Rejected' : 'Confirmed',
                  style: TextStyle(
                    color: infoColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (req.confirmedAt != null)
                Text(
                  _formatTime(req.confirmedAt!),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: 11,
                    letterSpacing: -0.1,
                  ),
                ),
            ],
          ),
          // Row 2: Confirmed by name
          if (!isRejected && req.confirmedBy != null && req.confirmedBy!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Approved by ${req.confirmedBy}',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                fontSize: 11,
                letterSpacing: -0.1,
              ),
            ),
          ],
          // Row 2: Rejection reason
          if (isRejected && req.rejectionReason != null && req.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              req.rejectionReason!,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 12,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, h:mm a').format(dt);
  }
}

/// Individual request row within a batch.
class _RequestRow extends StatelessWidget {
  final UpiPaymentRequest req;
  final bool isPending;
  final bool isMixed;
  final bool isSelected;
  final String planLabel;
  final VoidCallback onToggle;
  final VoidCallback? onReject;

  const _RequestRow({
    required this.req,
    required this.isPending,
    required this.isMixed,
    required this.isSelected,
    required this.planLabel,
    required this.onToggle,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isPending)
                _PremiumCheckbox(
                  value: isSelected,
                  onChanged: (_) => onToggle(),
                ),
              if (isPending) const SizedBox(width: 10),

              // Status dot
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: req.status == 'confirmed'
                      ? AppColors.success
                      : req.status == 'rejected'
                          ? AppColors.error
                          : AppColors.warning,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),

              // Plan label + amount
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      planLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${req.amount.toStringAsFixed(2)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Type badge in mixed batches
              if (isMixed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: req.isLoanPayment
                        ? AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08)
                        : AppColors.success.withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    req.isLoanPayment ? 'EMI' : 'Savings',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: req.isLoanPayment
                          ? AppColors.primary
                          : AppColors.success,
                    ),
                  ),
                ),

              // Reject button
              if (req.status == 'pending')
                GestureDetector(
                  onTap: onReject,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: isDark ? 0.1 : 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Reject',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Rejection reason shown inline for rejected items
          if (req.status == 'rejected' &&
              req.rejectionReason != null &&
              req.rejectionReason!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 17),
              child: Text(
                req.rejectionReason!,
                style: TextStyle(
                  color: AppColors.error.withValues(alpha: 0.7),
                  fontSize: 11,
                  letterSpacing: -0.1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bulk actions bar when items are selected.
class _BulkActionsBar extends StatelessWidget {
  final int count;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool isProcessing;

  const _BulkActionsBar({
    required this.count,
    required this.onConfirm,
    required this.onCancel,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded,
              color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count item${count > 1 ? 's' : ''} selected',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
                letterSpacing: -0.2,
              ),
            ),
          ),
          GestureDetector(
            onTap: onCancel,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Clear',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isProcessing ? null : onConfirm,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: isProcessing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Confirm',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 250.ms)
        .slideY(begin: -0.15, end: 0);
  }
}

/// Premium animated empty state.
class _PremiumEmptyState extends StatelessWidget {
  final String filterLabel;

  const _PremiumEmptyState({required this.filterLabel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.1),
                    AppColors.primary.withValues(alpha: isDark ? 0.05 : 0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.payments_rounded,
                size: 36,
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1, 1),
                  duration: 500.ms,
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(height: 20),
            Text(
              'No $filterLabel found',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            )
                .animate()
                .fadeIn(delay: 150.ms, duration: 400.ms)
                .slideY(begin: 0.1, end: 0),
            const SizedBox(height: 8),
            Text(
              'Payments will appear here once submitted',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            )
                .animate()
                .fadeIn(delay: 250.ms, duration: 400.ms)
                .slideY(begin: 0.1, end: 0),
          ],
        ),
      ),
    );
  }
}

/// Premium animated confirmation dialog.
class _PremiumConfirmDialog extends StatelessWidget {
  final int count;
  final double totalAmount;

  const _PremiumConfirmDialog({
    required this.count,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E2230).withValues(alpha: 0.97)
                : Colors.white.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                blurRadius: 40,
                offset: const Offset(0, 8),
                spreadRadius: -8,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gradient icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.success.withValues(alpha: 0.15),
                      AppColors.success.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 28,
                ),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.5, 0.5),
                    end: const Offset(1, 1),
                    duration: 400.ms,
                    curve: Curves.easeOutBack,
                  )
                  .fadeIn(duration: 300.ms),

              const SizedBox(height: 20),

              Text(
                'Confirm Payment',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),

              const SizedBox(height: 8),

              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    height: 1.5,
                    letterSpacing: -0.2,
                  ),
                  children: [
                    TextSpan(
                      text: 'Confirm $count payment${count > 1 ? 's' : ''}',
                    ),
                    const TextSpan(text: ' totaling '),
                    TextSpan(
                      text: '₹${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const TextSpan(text: '?\n\n'),
                    TextSpan(
                      text:
                          'This will create collection records in the system.',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 350.ms),

              const SizedBox(height: 28),

              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: 'Cancel',
                      isPrimary: false,
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassButton(
                      label: 'Confirm',
                      isPrimary: true,
                      color: AppColors.success,
                      icon: Icons.check_rounded,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.of(context).pop(true);
                      },
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 200.ms, duration: 350.ms),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 300.ms)
            .scale(
              begin: const Offset(0.92, 0.92),
              end: const Offset(1, 1),
              duration: 350.ms,
              curve: Curves.easeOutBack,
            ),
      ),
    );
  }
}
