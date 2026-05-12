import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../data/providers/collection_providers.dart';

class OverdueListPage extends ConsumerStatefulWidget {
  const OverdueListPage({super.key});

  @override
  ConsumerState<OverdueListPage> createState() => _OverdueListPageState();
}

class _OverdueListPageState extends ConsumerState<OverdueListPage> {
  String _filter = 'all';
  String _sort = 'days';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(overdueEmisProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white70 : Colors.black87),
        ),
        title: const Text('Overdue', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        centerTitle: false,
        actions: [
          _chip(theme, Icons.filter_alt_rounded, _filter == 'all' ? 'All' : _filter, () => _sheet(theme, true)),
          const SizedBox(width: 4),
          _chip(theme, Icons.sort_rounded, _sort == 'days' ? 'Days' : _sort == 'amount' ? '\$' : 'A-Z', () => _sheet(theme, false)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(overdueEmisProvider);
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: state.when(
          data: (raw) {
            final items = _sortBy(_filterBy(raw));
            if (items.isEmpty) {
              return _empty(theme, isDark);
            }
            return Column(
              children: [
                _dangerMeter(theme, items, isDark),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _card(items[i], theme, isDark, i),
                  ),
                ),
              ],
            );
          },
          loading: () => ListView.builder(itemCount: 4, itemBuilder: (_, __) => const Padding(padding: EdgeInsets.fromLTRB(20, 8, 20, 0), child: ShimmerCard(height: 130))),
          error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: theme.colorScheme.error))),
        ),
      ),
    );
  }

  Widget _chip(ThemeData theme, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primary.withValues(alpha: 0.1))),
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

  Widget _dangerMeter(ThemeData theme, List<Map<String, dynamic>> items, bool isDark) {
    double total = 0;
    int maxDays = 0, critical = 0;
    for (final i in items) {
      total += (i['emi'] as num? ?? 0).toDouble();
      final d = i['days_overdue'] as int? ?? 0;
      if (d > maxDays) {
        maxDays = d;
      }
      if (d > 30) {
        critical++;
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: AppColors.error.withValues(alpha: isDark ? 0.2 : 0.08), blurRadius: 30, offset: const Offset(0, 12)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background Gradient
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark 
                  ? [const Color(0xFF2C1616), const Color(0xFF1A1A1A)] 
                  : [AppColors.error.withValues(alpha: 0.08), Colors.white],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RISK OVERVIEW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.error, letterSpacing: 1.5)),
                        const SizedBox(height: 4),
                        Text('₹${_fmt(total)}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, letterSpacing: -1)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: Text('$critical CRITICAL', style: const TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _meterSubItem(theme, '${items.length}', 'PENDING', isDark),
                    _meterSubItem(theme, '$maxDays', 'MAX DAYS', isDark),
                    _meterSubItem(theme, '${((critical/items.length.clamp(1, 1000))*100).toStringAsFixed(0)}%', 'RISK %', isDark),
                  ],
                ),
                const SizedBox(height: 24),
                // Risk Bar
                Row(
                  children: [
                    _riskSegment(AppColors.error, 0.4, 'HIGH'),
                    const SizedBox(width: 4),
                    _riskSegment(AppColors.warning, 0.3, 'MED'),
                    const SizedBox(width: 4),
                    _riskSegment(AppColors.info, 0.3, 'LOW'),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Last updated 2 mins ago • Trends are up by 12%', style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface.withValues(alpha: 0.3), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _riskSegment(Color color, double flex, String label) {
    return Expanded(
      flex: (flex * 100).toInt(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 8,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)]),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _meterSubItem(ThemeData theme, String val, String label, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface.withValues(alpha: 0.4), letterSpacing: 0.5)),
      ],
    );
  }

  Widget _card(Map<String, dynamic> c, ThemeData theme, bool isDark, int i) {
    final days = c['days_overdue'] as int? ?? 0;
    final amount = (c['emi'] as num? ?? 0).toDouble();
    final name = c['member_name'] as String? ?? 'Unknown';
    final loan = c['loan_number'] as String? ?? 'N/A';
    final phone = c['member_phone'] as String?;
    final color = days > 30 ? AppColors.error : (days > 15 ? AppColors.warning : (days > 7 ? AppColors.orange : AppColors.info));
    final pct = (days / 90).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C24) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.04), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Left indicator bar
          Positioned(left: 0, top: 0, bottom: 0, child: Container(width: 6, color: color)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(width: 56, height: 56, child: CircularProgressIndicator(value: pct, strokeWidth: 4, backgroundColor: color.withValues(alpha: 0.1), valueColor: AlwaysStoppedAnimation<Color>(color))),
                        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('$days', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18, height: 1)),
                          Text('days', style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w800, height: 1)),
                        ]),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.badge_rounded, size: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                              const SizedBox(width: 4),
                              Text(loan, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color, height: 1.1)),
                        Text('EMI DUE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: color.withValues(alpha: 0.6), letterSpacing: 1)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _btn(theme, Icons.phone_rounded, 'CALL', AppColors.primary, true, () => _call(phone))),
                    const SizedBox(width: 8),
                    Expanded(child: _btn(theme, Icons.map_rounded, 'VISIT', AppColors.info, true, () => _visit())),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _btn(theme, Icons.payments_rounded, 'COLLECT', color, false, () {
                        HapticFeedback.mediumImpact();
                        context.push('/staff/collection/${c['loan_id']}', extra: c);
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: (i * 80).ms).slideX(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _btn(ThemeData theme, IconData icon, String label, Color color, bool outlined, VoidCallback onTap) {
    return SizedBox(
      height: 46,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 16),
              label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color.withValues(alpha: 0.25)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            )
          : ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 16),
              label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
            ),
    );
  }

  Widget _empty(ThemeData theme, bool isDark) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.06), shape: BoxShape.circle),
        child: Icon(Icons.check_circle_outline_rounded, size: 64, color: AppColors.success.withValues(alpha: 0.3))),
      const SizedBox(height: 24),
      Text('All Clear!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface.withValues(alpha: 0.35))),
      const SizedBox(height: 8),
      Text('No overdue collections', style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.2))),
    ]));
  }

  List<Map<String, dynamic>> _filterBy(List<Map<String, dynamic>> items) {
    if (_filter == 'all') {
      return items;
    }
    return items.where((c) {
      final d = c['days_overdue'] as int? ?? 0;
      if (_filter == '1-7') {
        return d >= 1 && d <= 7;
      }
      if (_filter == '8-15') {
        return d >= 8 && d <= 15;
      }
      if (_filter == '16-30') {
        return d >= 16 && d <= 30;
      }
      if (_filter == '30+') {
        return d > 30;
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> _sortBy(List<Map<String, dynamic>> items) {
    final list = List<Map<String, dynamic>>.from(items);
    if (_sort == 'days') {
      list.sort((a, b) => (b['days_overdue'] as int? ?? 0).compareTo(a['days_overdue'] as int? ?? 0));
    } else if (_sort == 'amount') {
      list.sort((a, b) => (b['emi'] as num? ?? 0).compareTo(a['emi'] as num? ?? 0));
    } else if (_sort == 'name') {
      list.sort((a, b) => (a['member_name'] as String? ?? '').compareTo(b['member_name'] as String? ?? ''));
    }
    return list;
  }

  void _sheet(ThemeData theme, bool isFilter) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
        decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(36))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 48, height: 5, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 28),
          Align(alignment: Alignment.centerLeft, child: Text(isFilter ? 'Filter' : 'Sort', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: isFilter
                ? [
                    _pill('all', 'All', Icons.all_inclusive_rounded),
                    _pill('1-7', '1-7 Days', Icons.looks_one_rounded),
                    _pill('8-15', '8-15 Days', Icons.looks_two_rounded),
                    _pill('16-30', '16-30 Days', Icons.looks_3_rounded),
                    _pill('30+', '30+ Days', Icons.warning_rounded),
                  ]
                : [
                    _sortPill('days', 'Most Overdue', Icons.calendar_today_rounded),
                    _sortPill('amount', 'Highest Amount', Icons.payments_rounded),
                    _sortPill('name', 'Alphabetical', Icons.sort_by_alpha_rounded),
                  ],
          ),
        ]),
      ),
    );
  }

  Widget _pill(String value, String label, IconData icon) {
    final sel = _filter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filter = value);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? AppColors.primary : AppColors.primary.withValues(alpha: 0.08), width: sel ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: sel ? Colors.white : AppColors.primary.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.primary.withValues(alpha: 0.5))),
        ]),
      ),
    );
  }

  Widget _sortPill(String value, String label, IconData icon) {
    final sel = _sort == value;
    return GestureDetector(
      onTap: () {
        setState(() => _sort = value);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? AppColors.primary : AppColors.primary.withValues(alpha: 0.08), width: sel ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: sel ? Colors.white : AppColors.primary.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.primary.withValues(alpha: 0.5))),
        ]),
      ),
    );
  }

  void _call(String? phone) async {
    if (phone != null && phone.isNotEmpty) {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    }
  }

  void _visit() {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Route added to Planner'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(label: 'GO', onPressed: () => context.push('/staff/router')),
      ),
    );
  }

  String _fmt(double n) => n >= 100000 ? '${(n / 100000).toStringAsFixed(1)}L' : (n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}K' : n.toStringAsFixed(0));
}
