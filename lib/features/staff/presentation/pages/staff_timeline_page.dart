import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../../branch_manager/data/providers/branch_scoped_providers.dart';
import '../../data/providers/staff_branch_providers.dart';

class StaffTimelinePage extends ConsumerStatefulWidget {
  const StaffTimelinePage({super.key});

  @override
  ConsumerState<StaffTimelinePage> createState() => _StaffTimelinePageState();
}

class _StaffTimelinePageState extends ConsumerState<StaffTimelinePage> {
  String _activeFilter = 'all'; // 'all', 'collections', 'savings'

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final branchAsync = ref.watch(staffBranchIdProvider);

    if (branchAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Timeline')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final branchId = branchAsync.valueOrNull;

    if (branchId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Timeline')),
        body: const Center(child: Text('No branch assigned to your profile.\nContact your admin to assign a branch.')),
      );
    }

    final collectionsAsync = ref.watch(staffCollectionHistoryProvider(branchId));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF2F2F7),
      body: AuroraBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(branchRecentTransactionsProvider(branchId));
            ref.invalidate(staffCollectionHistoryProvider(branchId));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // App Bar
              SliverAppBar(
                pinned: true,
                elevation: 0,
                backgroundColor: isDark
                    ? const Color(0xFF0A0A0C).withValues(alpha: 0.85)
                    : const Color(0xFFF2F2F7).withValues(alpha: 0.85),
                surfaceTintColor: Colors.transparent,
                title: Text(
                  'Timeline',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                systemOverlayStyle:
                    isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
              ),

              // Filter Chips
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Row(
                    children: [
                      _filterChip('All', 'all', isDark),
                      const SizedBox(width: 10),
                      _filterChip('Collections', 'collections', isDark),
                      const SizedBox(width: 10),
                      _filterChip('Savings', 'savings', isDark),
                    ],
                  ),
                ),
              ),

              // Timeline Content — using collections
              collectionsAsync.when(
                data: (collections) {
                  final filtered = _filterCollections(collections);
                  if (filtered.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(theme, isDark),
                    );
                  }

                  // Group by date
                  final grouped = _groupByDate(filtered);
                  final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        // Calculate which item this is
                        int runningIndex = 0;
                        for (final date in dates) {
                          final items = grouped[date]!;
                          if (index == runningIndex) {
                            return _buildDateHeader(date, isDark);
                          }
                          runningIndex++;
                          for (int i = 0; i < items.length; i++) {
                            if (index == runningIndex) {
                              return _buildCollectionCard(
                                context, theme, isDark, items[i], i,
                              );
                            }
                            runningIndex++;
                          }
                        }
                        return const SizedBox.shrink();
                      },
                      childCount: dates.fold<int>(0, (sum, date) => 1 + (grouped[date]?.length ?? 0)),
                    ),
                  );
                },
                loading: () => SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.builder(
                    itemCount: 8,
                    itemBuilder: (_, __) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: const ShimmerCard(
                        height: 80,
                        borderRadius: 16,
                      ),
                    ),
                  ),
                ),
                error: (e, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 48, color: Color(0xFFEF4444)),
                        const SizedBox(height: 16),
                        Text('Error loading timeline',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value, bool isDark) {
    final isActive = _activeFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary
              : isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isActive
                ? AppColors.primary
                : isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive
                ? Colors.white
                : isDark
                    ? Colors.white70
                    : Colors.black87,
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildDateHeader(String dateStr, bool isDark) {
    final date = DateTime.tryParse(dateStr);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    String label;
    if (date != null) {
      final d = DateTime(date.year, date.month, date.day);
      if (d == today) {
        label = 'Today';
      } else if (d == yesterday) {
        label = 'Yesterday';
      } else {
        label = DateFormat('EEEE, dd MMM yyyy').format(date);
      }
    } else {
      label = dateStr;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildCollectionCard(
      BuildContext context, ThemeData theme, bool isDark, Map<String, dynamic> collection, int index) {
    final f = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final amount = (collection['amount_collected'] as num?)?.toDouble() ?? 0;
    final memberName = collection['member_name'] as String? ?? 'Unknown';
    final loanNumber = collection['loan_number'] as String?;
    final paymentMode = collection['payment_mode'] as String?;
    final collectionType = collection['collection_type'] as String? ?? 'emi';
    final time = collection['collection_time'] as String?;
    final collector = collection['collector'] as Map<String, dynamic>?;
    final collectorName = collector?['full_name'] as String?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: GlassCard(
        borderRadius: 16,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Timeline dot + line
            Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: collectionType == 'savings'
                        ? const Color(0xFF10B981)
                        : const Color(0xFF667EEA),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: collectionType == 'savings'
                          ? const Color(0xFF10B981).withValues(alpha: 0.3)
                          : const Color(0xFF667EEA).withValues(alpha: 0.3),
                      width: 3,
                    ),
                  ),
                ),
                Container(
                  width: 2,
                  height: 30,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                ),
              ],
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          memberName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (time != null)
                        Text(
                          DateFormat('hh:mm a').format(DateTime.tryParse('${collection['collection_date']}T$time') ?? DateTime.now()),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white30 : Colors.black26,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: collectionType == 'savings'
                              ? const Color(0xFF10B981).withValues(alpha: 0.1)
                              : const Color(0xFF667EEA).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          collectionType == 'savings' ? 'Savings' : 'EMI',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: collectionType == 'savings'
                                ? const Color(0xFF10B981)
                                : const Color(0xFF667EEA),
                          ),
                        ),
                      ),
                      if (loanNumber != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          loanNumber,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white30 : Colors.black26,
                          ),
                        ),
                      ],
                      if (paymentMode != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          paymentMode == 'cash'
                              ? Icons.payments_rounded
                              : Icons.phone_android_rounded,
                          size: 12,
                          color: isDark ? Colors.white30 : Colors.black26,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          paymentMode.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white30 : Colors.black26,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (collectorName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'By $collectorName',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white24 : Colors.black26,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Amount
            Text(
              f.format(amount),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF10B981),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(
          delay: Duration(milliseconds: 50 * index.clamp(0, 15)),
          duration: 300.ms,
        );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.timeline_rounded,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'No activity yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              'Collections and transactions will appear here as they happen',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white38 : Colors.black38),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95));
  }

  List<Map<String, dynamic>> _filterCollections(List<Map<String, dynamic>> collections) {
    switch (_activeFilter) {
      case 'collections':
        return collections.where((c) => (c['collection_type'] ?? 'emi') != 'savings').toList();
      case 'savings':
        return collections.where((c) => (c['collection_type'] ?? 'emi') == 'savings').toList();
      default:
        return collections;
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupByDate(List<Map<String, dynamic>> collections) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final c in collections) {
      final date = c['collection_date'] as String? ?? 'Unknown';
      map.putIfAbsent(date, () => []).add(c);
    }
    return map;
  }
}
