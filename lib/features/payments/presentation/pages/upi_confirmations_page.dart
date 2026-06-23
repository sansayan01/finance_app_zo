import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/aurora_background.dart';
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

class _UpiConfirmationsPageState extends ConsumerState<UpiConfirmationsPage>
    with SingleTickerProviderStateMixin {
  String _filter = 'pending';
  final Set<String> _selectedIds = {};
  bool _isProcessing = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Advanced filter state
  String _typeFilter = 'all'; // all | loan | savings
  String _sortBy = 'newest'; // newest | oldest | highest | lowest

  Map<String, String> _memberNames = {};
  Map<String, String> _profileIds = {};
  final Map<String, String> _loanNumbers = {};
  final Map<String, String> _savingsPlanNames = {};
  final Map<String, DateTime> _emiDates = {};

  late AnimationController _filterAnimController;

  @override
  void initState() {
    super.initState();
    _filterAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _filterAnimController.dispose();
    super.dispose();
  }

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
      final profiles = await client
          .from('profiles')
          .select('id, user_id')
          .inFilter('user_id', customerIds);
      final profileIdMap = <String, String>{};
      for (final p in (profiles as List)) {
        final uid = p['user_id']?.toString() ?? '';
        final pid = p['id']?.toString() ?? '';
        if (uid.isNotEmpty && pid.isNotEmpty) {
          profileIdMap[uid] = pid;
        }
      }

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

  Future<void> _resolvePlanLabels(List<UpiPaymentRequest> requests) async {
    final client = Supabase.instance.client;

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

    // Only rebuild if we actually resolved new data
    if (mounted && (loanIds.isNotEmpty || savingsIds.isNotEmpty)) {
      setState(() {});
    }
  }

  Future<void> _resolveEmiDates(List<UpiPaymentRequest> requests) async {
    final client = Supabase.instance.client;
    var didUpdate = false;

    // Loan EMIs: legacy rows may lack installment_date, so still look up
    // due_date from emi_schedule. New rows carry installment_date on the
    // request itself and skip this entirely.
    final emiIds = requests
        .where((r) =>
            r.emiScheduleId != null &&
            r.isLoanPayment &&
            r.installmentDate == null)
        .map((r) => r.emiScheduleId!)
        .where((id) => id.isNotEmpty && !_emiDates.containsKey('emi:$id'))
        .toSet()
        .toList();
    if (emiIds.isNotEmpty) {
      try {
        final rows = await client
            .from('emi_schedule')
            .select('id, due_date')
            .inFilter('id', emiIds);
        for (final r in (rows as List)) {
          final id = r['id']?.toString() ?? '';
          final due = r['due_date']?.toString();
          if (id.isNotEmpty && due != null) {
            final parsed = DateTime.tryParse(due);
            if (parsed != null) {
              _emiDates['emi:$id'] = parsed;
              didUpdate = true;
            }
          }
        }
      } catch (_) {}
    }

    // Savings installments no longer need date resolution here — each new
    // request carries its own installment_date captured at submit time.

    if (mounted && didUpdate) {
      setState(() {});
    }
  }

  String _getMemberName(String customerId) =>
      _memberNames[customerId] ?? 'Customer';
  String? _getProfileId(String customerId) => _profileIds[customerId];
  String _getPlanLabel(UpiPaymentRequest req) {
    if (req.isLoanPayment) return _loanNumbers[req.loanId] ?? 'Loan';
    return _savingsPlanNames[req.savingsPlanId] ?? 'Savings';
  }

  /// Apply tab + search + advanced filters to a list of requests
  List<UpiPaymentRequest> _applyFilters(List<UpiPaymentRequest> requests) {
    var result = List<UpiPaymentRequest>.from(requests);

    // Tab filter (client-side)
    if (_filter.isNotEmpty) {
      result = result.where((r) => r.status == _filter).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((r) {
        final name = _getMemberName(r.customerId).toLowerCase();
        final plan = _getPlanLabel(r).toLowerCase();
        final amount = r.amount.toString();
        return name.contains(q) || plan.contains(q) || amount.contains(q);
      }).toList();
    }

    // Type filter
    if (_typeFilter == 'loan') {
      result = result.where((r) => r.isLoanPayment).toList();
    } else if (_typeFilter == 'savings') {
      result = result.where((r) => r.isSavingsPayment).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'oldest':
        result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'highest':
        result.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case 'lowest':
        result.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      default: // newest
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return result;
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
      final sameSavings =
          curr.savingsPlanId != null && curr.savingsPlanId == prev.savingsPlanId;
      final withinFiveMin =
          curr.createdAt.difference(prev.createdAt).abs() <= const Duration(minutes: 5);

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
    final requestsAsync = ref.watch(allUpiRequestsProvider(''));
    final bottomPadding = _selectedIds.isNotEmpty ? 80.0 : 20.0;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F1115)
          : const Color(0xFFF8F9FB),
      body: AuroraBackground(
        child: Column(
          children: [
            // ─── HEADER ───
            _SafeAreaTop(
              child: _CompactHeader(
                selectedCount: _selectedIds.length,
                isProcessing: _isProcessing,
                onConfirmSelected: _confirmSelected,
                onClearSelection: () => setState(() => _selectedIds.clear()),
                onRefresh: () {
                  HapticFeedback.lightImpact();
                  ref.invalidate(allUpiRequestsProvider);
                  setState(() => _selectedIds.clear());
                },
              ),
            ),

            // ─── SEARCH BAR ───
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _SearchBar(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                onFilterTap: () {
                  if (_filterAnimController.isCompleted) {
                    _filterAnimController.reverse();
                  } else {
                    _filterAnimController.forward();
                  }
                },
                showFilterActive: _typeFilter != 'all',
              ),
            ),

            // ─── ADVANCED FILTER PANEL ───
            SizeTransition(
              sizeFactor: _filterAnimController,
              child: _AdvancedFilterPanel(
                typeFilter: _typeFilter,
                sortBy: _sortBy,
                onTypeChanged: (v) => setState(() => _typeFilter = v),
                onSortChanged: (v) => setState(() => _sortBy = v),
                onReset: () => setState(() {
                  _typeFilter = 'all';
                  _sortBy = 'newest';
                }),
              ),
            ),

            // ─── FILTER CHIPS + LIST ───
            Expanded(
              child: requestsAsync.when(
                data: (allRequests) {
                  final counts = _computeCounts(allRequests);

                  // Resolve member info + plan labels (fire-and-forget)
                  final unresolved = allRequests
                      .where((r) => !_memberNames.containsKey(r.customerId))
                      .toList();
                  if (unresolved.isNotEmpty) {
                    _resolveMemberInfo(unresolved);
                  }
                  _resolvePlanLabels(allRequests);
                  _resolveEmiDates(allRequests);

                  final filtered = _applyFilters(allRequests);
                  final batches = _groupIntoBatches(filtered);

                  return Column(
                    children: [
                      _CompactFilterChips(
                        currentFilter: _filter,
                        counts: counts,
                        onFilterChanged: (f) {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _filter = f;
                            _selectedIds.clear();
                          });
                        },
                      ),

                      // ─── LIST ───
                      Expanded(
                        child: batches.isEmpty
                            ? _PremiumEmptyState(filterLabel: _filterLabel)
                            : RefreshIndicator(
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
                                  padding: EdgeInsets.fromLTRB(
                                      16, 8, 16, bottomPadding),
                                  itemCount: batches.length,
                                  itemBuilder: (context, index) =>
                                      _PremiumBatchCard(
                                    batch: batches[index],
                                    filter: _filter,
                                    selectedIds: _selectedIds,
                                    memberNames: _memberNames,
                                    profileIds: _profileIds,
                                    emiDates: _emiDates,
                                    isProcessing: _isProcessing,
                                    onToggleAll: (ids) {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        for (final id in ids) {
                                          if (_selectedIds.contains(id)) {
                                            _selectedIds.remove(id);
                                          } else {
                                            _selectedIds.add(id);
                                          }
                                        }
                                      });
                                    },
                                    onToggleSingle: (id) {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        if (_selectedIds.contains(id)) {
                                          _selectedIds.remove(id);
                                        } else {
                                          _selectedIds.add(id);
                                        }
                                      });
                                    },
                                    onReject: (req) =>
                                        _rejectPayment(req),
                                    onConfirmAll: (batch) =>
                                        _confirmBatchWithDialog(batch),
                                    onRejectAll: (batch) =>
                                        _rejectBatch(batch),
                                    onMemberTap: (customerId) {
                                      final pid =
                                          _getProfileId(customerId);
                                      if (pid != null) {
                                        context
                                            .push('/staff/user-hub/$pid');
                                      }
                                    },
                                    index: index,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  );
                },
                loading: () => _buildShimmerLoading(),
                error: (e, _) => Center(
                  child: _ErrorState(error: e.toString()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, int> _computeCounts(List<UpiPaymentRequest> all) {
    return {
      'pending': all.where((r) => r.status == 'pending').length,
      'confirmed': all.where((r) => r.status == 'confirmed').length,
      'rejected': all.where((r) => r.status == 'rejected').length,
      'all': all.length,
    };
  }

  Widget _buildShimmerLoading() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        children: List.generate(
          6,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ShimmerCard(
              height: 64,
              borderRadius: 14,
            ),
          ).animate().fadeIn(
                delay: (60 * i).ms,
                duration: 350.ms,
              ),
        ),
      ),
    );
  }

  // ─── CONFIRMATION DIALOG ───

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

  // ─── BATCH CONFIRM/REJECT ───

  Future<void> _confirmSelected() async {
    if (_selectedIds.isEmpty || _isProcessing) return;

    final allRequests =
        ref.read(allUpiRequestsProvider('')).valueOrNull ?? [];
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
      final confirmedCount = await repository.confirmBatch(
        requestIds: _selectedIds.toList(),
        confirmedBy: staffId,
      );
      ref.invalidate(allUpiRequestsProvider);
      setState(() => _selectedIds.clear());
      if (mounted) {
        if (confirmedCount > 0) {
          _showPremiumSnackBar(
            message: '$confirmedCount payment${confirmedCount > 1 ? 's' : ''} confirmed and collections created',
            icon: Icons.check_circle_rounded,
            color: AppColors.success,
          );
        } else {
          _showPremiumSnackBar(
            message: 'All selected payments were already processed',
            icon: Icons.info_outline_rounded,
            color: AppColors.warning,
          );
        }
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

  Future<void> _confirmBatchWithDialog(List<UpiPaymentRequest> batch) async {
    final total = batch.fold<double>(0, (sum, r) => sum + r.amount);
    final confirmed = await _showConfirmDialog(batch.length, total);
    if (!confirmed) return;

    setState(() => _isProcessing = true);
    final staffId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final repository = ref.read(upiRepositoryProvider);
    try {
      final count = await repository.confirmBatch(
        requestIds: batch.map((r) => r.id).toList(),
        confirmedBy: staffId,
      );
      ref.invalidate(allUpiRequestsProvider);
      if (mounted) {
        if (count > 0) {
          _showPremiumSnackBar(
            message: '$count payment${count > 1 ? 's' : ''} confirmed and collections created',
            icon: Icons.check_circle_rounded,
            color: AppColors.success,
          );
        } else {
          _showPremiumSnackBar(
            message: 'All selected payments were already processed',
            icon: Icons.info_outline_rounded,
            color: AppColors.warning,
          );
        }
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
          message: '${batch.length} payment${batch.length > 1 ? 's' : ''} rejected',
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
// HEADER
// ═══════════════════════════════════════════════════════════════

class _SafeAreaTop extends StatelessWidget {
  final Widget child;
  const _SafeAreaTop({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 4,
        16,
        4,
      ),
      child: child,
    );
  }
}

class _CompactHeader extends StatelessWidget {
  final int selectedCount;
  final bool isProcessing;
  final VoidCallback onConfirmSelected;
  final VoidCallback onClearSelection;
  final VoidCallback onRefresh;

  const _CompactHeader({
    required this.selectedCount,
    required this.isProcessing,
    required this.onConfirmSelected,
    required this.onClearSelection,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        // Back button
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Title
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'UPI Confirmations',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),

        // Selection actions or refresh
        if (selectedCount > 0) ...[
          GestureDetector(
            onTap: onClearSelection,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            onTap: isProcessing ? null : onConfirmSelected,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success,
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
                      'Confirm ($selectedCount)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ] else
          GestureDetector(
            onTap: onRefresh,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.refresh_rounded,
                size: 18,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SEARCH BAR
// ═══════════════════════════════════════════════════════════════

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterTap;
  final bool showFilterActive;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onFilterTap,
    required this.showFilterActive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            Icons.search_rounded,
            size: 18,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                letterSpacing: -0.2,
              ),
              decoration: InputDecoration(
                hintText: 'Search by name, loan, amount...',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onFilterTap,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: showFilterActive
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.tune_rounded,
                size: 18,
                color: showFilterActive
                    ? AppColors.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ADVANCED FILTER PANEL
// ═══════════════════════════════════════════════════════════════

class _AdvancedFilterPanel extends StatelessWidget {
  final String typeFilter;
  final String sortBy;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onReset;

  const _AdvancedFilterPanel({
    required this.typeFilter,
    required this.sortBy,
    required this.onTypeChanged,
    required this.onSortChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Type',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onReset,
                child: Text(
                  'Reset',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildFilterOption(context, 'All', 'all', typeFilter, onTypeChanged),
              const SizedBox(width: 6),
              _buildFilterOption(context, 'Loan', 'loan', typeFilter, onTypeChanged),
              const SizedBox(width: 6),
              _buildFilterOption(context, 'Savings', 'savings', typeFilter, onTypeChanged),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Sort by',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildSortOption(context, 'Newest', 'newest'),
              const SizedBox(width: 6),
              _buildSortOption(context, 'Oldest', 'oldest'),
              const SizedBox(width: 6),
              _buildSortOption(context, 'Highest', 'highest'),
              const SizedBox(width: 6),
              _buildSortOption(context, 'Lowest', 'lowest'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOption(BuildContext context, String label, String value,
      String current, ValueChanged<String> onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = current == value;

    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.12)
              : isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? AppColors.primary
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildSortOption(
      BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = sortBy == value;

    return GestureDetector(
      onTap: () => onSortChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.12)
              : isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? AppColors.primary
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// FILTER CHIPS
// ═══════════════════════════════════════════════════════════════

class _CompactFilterChips extends StatelessWidget {
  final String currentFilter;
  final Map<String, int> counts;
  final ValueChanged<String> onFilterChanged;

  const _CompactFilterChips({
    required this.currentFilter,
    required this.counts,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip('pending', 'Pending', counts['pending'] ?? 0),
          const SizedBox(width: 6),
          _chip('confirmed', 'Confirmed', counts['confirmed'] ?? 0),
          const SizedBox(width: 6),
          _chip('rejected', 'Rejected', counts['rejected'] ?? 0),
          const SizedBox(width: 6),
          _chip('', 'All', counts['all'] ?? 0),
        ],
      ),
    );
  }

  Widget _chip(String value, String label, int count) {
    return Builder(builder: (context) {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      final isSelected = currentFilter == value;

      return GestureDetector(
        onTap: () => onFilterChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.12)
                : isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06),
              width: isSelected ? 1 : 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.primary
                          : theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}

// ═══════════════════════════════════════════════════════════════
// PREMIUM BATCH CARD
// ═══════════════════════════════════════════════════════════════

class _PremiumBatchCard extends StatelessWidget {
  final List<UpiPaymentRequest> batch;
  final String filter;
  final Set<String> selectedIds;
  final Map<String, String> memberNames;
  final Map<String, String> profileIds;
  final Map<String, DateTime> emiDates;
  final bool isProcessing;
  final ValueChanged<List<String>> onToggleAll;
  final ValueChanged<String> onToggleSingle;
  final ValueChanged<UpiPaymentRequest> onReject;
  final ValueChanged<List<UpiPaymentRequest>> onConfirmAll;
  final ValueChanged<List<UpiPaymentRequest>> onRejectAll;
  final ValueChanged<String> onMemberTap;
  final int index;

  const _PremiumBatchCard({
    required this.batch,
    required this.filter,
    required this.selectedIds,
    required this.memberNames,
    required this.profileIds,
    required this.emiDates,
    required this.isProcessing,
    required this.onToggleAll,
    required this.onToggleSingle,
    required this.onReject,
    required this.onConfirmAll,
    required this.onRejectAll,
    required this.onMemberTap,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final first = batch.first;
    final total = batch.fold<double>(0, (sum, r) => sum + r.amount);
    final typeLabel = first.isLoanPayment ? 'Loan EMI' : 'Savings';
    final isMultiInstallment = batch.length > 1;
    final allSelected = batch.every((r) => selectedIds.contains(r.id));
    final hasGlobalSelection = selectedIds.isNotEmpty;

    // Determine batch-level status
    final allConfirmed = batch.every((r) => r.isConfirmed);
    final allRejected = batch.every((r) => r.isRejected);
    final batchStatusColor = allConfirmed
        ? AppColors.success
        : allRejected
            ? AppColors.error
            : AppColors.warning;

    // Resolved customer name
    final custName = memberNames[first.customerId] ?? 'Customer';
    final hasProfile = profileIds.containsKey(first.customerId);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── HEADER ───
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                // Select-all checkbox (pending only)
                if (filter == 'pending' && isMultiInstallment) ...[
                  _TinyCheckbox(
                    value: allSelected,
                    onChanged: (_) {
                      onToggleAll(batch.map((r) => r.id).toList());
                    },
                  ),
                  const SizedBox(width: 10),
                ] else if (filter == 'pending' && !isMultiInstallment) ...[
                  _TinyCheckbox(
                    value: selectedIds.contains(first.id),
                    onChanged: (_) {
                      onToggleSingle(first.id);
                    },
                  ),
                  const SizedBox(width: 10),
                ],

                // Type icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: first.isLoanPayment
                        ? AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.1)
                        : AppColors.success.withValues(alpha: isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    first.isLoanPayment
                        ? Icons.account_balance_rounded
                        : Icons.savings_rounded,
                    size: 18,
                    color: first.isLoanPayment ? AppColors.primary : AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),

                // Name + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: hasProfile
                            ? () => onMemberTap(first.customerId)
                            : null,
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                custName,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  letterSpacing: -0.3,
                                  color: hasProfile
                                      ? AppColors.primary
                                      : theme.colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasProfile) ...[
                              const SizedBox(width: 2),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 14,
                                color: AppColors.primary.withValues(alpha: 0.6),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isMultiInstallment
                            ? '${batch.length} $typeLabel installments · ₹${total.toStringAsFixed(2)} · ${_formatTimeAgo(first.createdAt)}'
                            : '$typeLabel · ₹${total.toStringAsFixed(2)} · ${_formatTimeAgo(first.createdAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Status indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: batchStatusColor.withValues(alpha: isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    allConfirmed
                        ? 'Confirmed'
                        : allRejected
                            ? 'Rejected'
                            : '${batch.where((r) => r.isPending).length} Pending',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: batchStatusColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── INDIVIDUAL ITEMS ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                for (var i = 0; i < batch.length; i++) ...[
                  _buildInstallmentRow(
                    context,
                    batch[i],
                    i,
                    isDark,
                    theme,
                    filter,
                    selectedIds,
                    onToggleSingle,
                    onReject,
                  ),
                  if (i < batch.length - 1)
                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.04),
                    ),
                ],
              ],
            ),
          ),

          // ─── ACTION BUTTONS (pending only, no global selection) ───
          if (filter == 'pending' && !hasGlobalSelection)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: isProcessing
                          ? null
                          : () => onRejectAll(batch),
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.error.withValues(alpha: 0.1)
                              : AppColors.error.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.2),
                            width: 0.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Reject All',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: isProcessing
                          ? null
                          : () => onConfirmAll(batch),
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            'Confirm All',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: (40 * index).ms, duration: 300.ms)
        .slideX(begin: 0.04, end: 0);
  }

  String _getInstallmentLabel(UpiPaymentRequest req, int itemIndex) {
    // 1. Prefer the per-row installment_date captured at submit time.
    //    This is the actual date the customer selected / that was due
    //    for this specific request — the only source that's always right.
    if (req.installmentDate != null) {
      return _formatDueDate(req.installmentDate!);
    }
    // 2. Legacy loan rows: look up due_date from emi_schedule via the
    //    already-resolved emiDates cache.
    final emiId = req.emiScheduleId;
    if (emiId != null && emiDates.containsKey('emi:$emiId')) {
      final d = emiDates['emi:$emiId']!;
      return _formatDueDate(d);
    }
    // 3. Fallback: show number when nothing resolved.
    return req.isLoanPayment
        ? 'EMI #${itemIndex + 1}'
        : 'Installment #${itemIndex + 1}';
  }

  String _formatDueDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Due today';
    }
    return 'Due ${DateFormat('dd MMM').format(d)}';
  }

  Widget _buildInstallmentRow(
    BuildContext context,
    UpiPaymentRequest req,
    int itemIndex,
    bool isDark,
    ThemeData theme,
    String filter,
    Set<String> selectedIds,
    ValueChanged<String> onToggleSingle,
    ValueChanged<UpiPaymentRequest> onReject,
  ) {
    final statusColor = req.isConfirmed
        ? AppColors.success
        : req.isRejected
            ? AppColors.error
            : AppColors.warning;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Individual checkbox (pending only)
          if (filter == 'pending') ...[
            _TinyCheckbox(
              value: selectedIds.contains(req.id),
              onChanged: (_) => onToggleSingle(req.id),
            ),
            const SizedBox(width: 8),
          ],

          // Status dot
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),

          // Installment label — show date if available, else fallback to number
          Expanded(
            child: Text(
              _getInstallmentLabel(req, itemIndex),
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),

          // Amount
          Text(
            '₹${req.amount.toStringAsFixed(2)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: -0.2,
            ),
          ),

          // Per-item reject (pending only)
          if (filter == 'pending') ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: isProcessing ? null : () => onReject(req),
              child: Text(
                'Reject',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],

          // Rejection reason (rejected only)
          if (req.isRejected &&
              req.rejectionReason != null &&
              req.rejectionReason!.isNotEmpty &&
              filter != 'pending') ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                req.rejectionReason!,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.error.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          // Confirmed pill (confirmed only)
          if (req.isConfirmed && filter != 'pending')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                '✓',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    // created_at from Supabase comes back as a timezone-aware ISO string,
    // so DateTime.tryParse produces a UTC DateTime. Convert to local before
    // formatting or the time will display in UTC instead of the device's
    // local timezone.
    return DateFormat('dd MMM, h:mm a').format(dt.toLocal());
  }
}

// ═══════════════════════════════════════════════════════════════
// TINY CHECKBOX
// ═══════════════════════════════════════════════════════════════

class _TinyCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?>? onChanged;

  const _TinyCheckbox({required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => onChanged?.call(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: value
              ? AppColors.primary
              : isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(6),
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
            size: 13,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// EMPTY STATE
// ═══════════════════════════════════════════════════════════════

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
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.1),
                    AppColors.primary.withValues(alpha: isDark ? 0.05 : 0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.payments_rounded,
                size: 32,
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
            )
                .animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                )
                .scale(
                  begin: const Offset(0.95, 0.95),
                  end: const Offset(1.05, 1.05),
                  duration: 2000.ms,
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: 20),
            Text(
              'No $filterLabel payments',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Payments will appear here once submitted by customers',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ERROR STATE
// ═══════════════════════════════════════════════════════════════

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
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
          error,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CONFIRM DIALOG
// ═══════════════════════════════════════════════════════════════

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
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const TextSpan(text: '?\n\n'),
                    TextSpan(
                      text: 'This will create collection records in the system.',
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
                    child: _DialogButton(
                      label: 'Cancel',
                      isPrimary: false,
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DialogButton(
                      label: 'Confirm',
                      isPrimary: true,
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

class _DialogButton extends StatefulWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _DialogButton({
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: widget.isPrimary
                ? AppColors.success
                : isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.isPrimary
                    ? Colors.white
                    : theme.colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
