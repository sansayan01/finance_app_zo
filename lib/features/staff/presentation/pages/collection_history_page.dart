import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../data/providers/collection_providers.dart';
import '../../data/providers/staff_providers.dart';

class CollectionHistoryPage extends ConsumerStatefulWidget {
  final String? staffId;
  final String? customerId;
  const CollectionHistoryPage({super.key, this.staffId, this.customerId});

  @override
  ConsumerState<CollectionHistoryPage> createState() => _CollectionHistoryPageState();
}

class _CollectionHistoryPageState extends ConsumerState<CollectionHistoryPage> {
  String _filter = 'all';
  int? _month, _year;
  final _f = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white70 : Colors.black87)),
        title: const Text('Logbook', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        centerTitle: false,
        actions: [
          _chip(theme, Icons.filter_list_rounded, _filter == 'all' ? 'All' : _filter == 'cash' ? 'Cash' : 'Digital', () => _showFilter(theme)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async { ref.invalidate(collectionHistoryProvider); await Future.delayed(const Duration(milliseconds: 500)); },
        child: _body(theme, isDark),
      ),
    );
  }

  Widget _chip(ThemeData theme, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(width: 2),
          Icon(Icons.expand_more_rounded, size: 16, color: AppColors.primary),
        ]),
      ),
    );
  }

  Widget _body(ThemeData theme, bool isDark) {
    return ref.watch(staffProfileProvider).when(
      data: (p) {
        final params = (staffId: widget.staffId ?? p?.id, customerId: widget.customerId, year: _year, month: _month, type: _filter == 'all' ? null : _filter, paymentMode: null) as HistoryParams;
        return ref.watch(collectionHistoryProvider(params)).when(
          data: (h) => h.isEmpty ? _empty(theme) : _list(theme, isDark, h),
          loading: () => ListView.builder(itemCount: 5, itemBuilder: (_, __) => const Padding(padding: EdgeInsets.fromLTRB(20, 8, 20, 0), child: ShimmerCard(height: 80))),
          error: (_, __) => Center(child: Text('Failed', style: TextStyle(color: theme.colorScheme.error))),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _list(ThemeData theme, bool isDark, List<Map<String, dynamic>> history) {
    double total = 0;
    for (final i in history) {
      total += (i['amount_collected'] as num?)?.toDouble() ?? 0;
    }

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final i in history) {
      final d = (i['collection_date'] as String? ?? '').length >= 10 ? (i['collection_date'] as String).substring(0, 10) : 'Unknown';
      grouped.putIfAbsent(d, () => []).add(i);
    }

    final entries = grouped.entries.toList()..sort((a, b) => b.key.compareTo(a.key));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _hero(theme, total, history.length, isDark),
          ),
        ),
        ...entries.asMap().entries.map((g) {
          final items = g.value.value;
          final dayTotal = items.fold<double>(0, (s, i) => s + ((i['amount_collected'] as num?)?.toDouble() ?? 0));
          return SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(child: _sectionHeader(theme, g.value.key, dayTotal)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _card(theme, isDark, items[index], index).animate().fadeIn(duration: 400.ms, delay: (index * 40).ms).slideX(begin: 0.04, end: 0),
                    childCount: items.length,
                  ),
                ),
              ),
            ],
          );
        }),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _hero(ThemeData theme, double total, int count, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.15), blurRadius: 30, offset: const Offset(0, 15)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(top: -40, right: -40, child: Container(width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.1)))),
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('COLLECTION OVERVIEW', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
                    _trendIndicator(true),
                  ],
                ),
                const SizedBox(height: 16),
                Text(_f.format(total), style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: -1.5)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _heroStat('TXNS', '$count', Icons.history_rounded),
                    const SizedBox(width: 32),
                    _heroStat('CASH', '70%', Icons.payments_rounded),
                    const SizedBox(width: 32),
                    _heroStat('DIGITAL', '30%', Icons.account_balance_rounded),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trendIndicator(bool up) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: (up ? AppColors.success : AppColors.error).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: up ? AppColors.success : AppColors.error, size: 12),
          const SizedBox(width: 4),
          Text(up ? '+14%' : '-5%', style: TextStyle(color: up ? AppColors.success : AppColors.error, fontSize: 10, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String val, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 14),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ],
        ),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _sectionHeader(ThemeData theme, String dateStr, double dayTotal) {
    final dt = DateTime.tryParse(dateStr);
    final now = DateTime.now();
    String label;
    if (dt != null) {
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        label = 'TODAY';
      } else if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) {
        label = 'YESTERDAY';
      } else {
        label = DateFormat('MMM d, y').format(dt).toUpperCase();
      }
    } else {
      label = dateStr.toUpperCase();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface.withValues(alpha: 0.35), letterSpacing: 1.5)),
          Text('₹${_f.format(dayTotal)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface.withValues(alpha: 0.35))),
        ],
      ),
    );
  }

  Widget _card(ThemeData theme, bool isDark, Map<String, dynamic> item, int index) {
    final name = item['member_name'] as String? ?? 'Unknown';
    final amount = (item['amount_collected'] as num?)?.toDouble() ?? 0;
    final mode = item['payment_mode'] as String? ?? 'cash';
    final isDigital = mode.toLowerCase() != 'cash';
    final color = isDigital ? AppColors.info : AppColors.success;
    final time = item['collection_time'] as String?;
    String timeStr = '--:--';
    if (time != null) {
      try {
        final parsed = DateTime.parse(time).toLocal();
        timeStr = '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C24) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(left: 0, top: 0, bottom: 0, child: Container(width: 5, color: color)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                  child: Center(child: Icon(isDigital ? Icons.account_balance_rounded : Icons.payments_rounded, color: color, size: 24)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(timeStr, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
                          Container(width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: theme.colorScheme.onSurface.withValues(alpha: 0.2), shape: BoxShape.circle)),
                          Text(mode.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_f.format(amount), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
                    Text('COLLECTED', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: color.withValues(alpha: 0.5), letterSpacing: 1)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(ThemeData theme) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), shape: BoxShape.circle),
        child: Icon(Icons.receipt_long_outlined, size: 60, color: AppColors.primary.withValues(alpha: 0.2))),
      const SizedBox(height: 24),
      Text('No history yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface.withValues(alpha: 0.35))),
      const SizedBox(height: 8),
      Text('Collections will appear here', style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.2))),
    ]));
  }

  void _showFilter(ThemeData theme) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 48, height: 5, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 28),
          Align(alignment: Alignment.centerLeft, child: Text('Filter', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
          const SizedBox(height: 24),
          Row(
            children: [
              _pill('all', 'All Types', Icons.all_inclusive_rounded),
              const SizedBox(width: 10),
              _pill('cash', 'Cash', Icons.payments_rounded),
              const SizedBox(width: 10),
              _pill('digital', 'Digital', Icons.phone_android_rounded),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _pill(String value, String label, IconData icon) {
    final sel = _filter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () { setState(() => _filter = value); Navigator.pop(context); },
        child: AnimatedContainer(
          duration: 200.ms,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: sel ? AppColors.primary : AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: sel ? AppColors.primary : AppColors.primary.withValues(alpha: 0.08), width: sel ? 1.5 : 1),
          ),
          child: Column(children: [
            Icon(icon, size: 22, color: sel ? Colors.white : AppColors.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.primary.withValues(alpha: 0.5))),
          ]),
        ),
      ),
    );
  }
}
