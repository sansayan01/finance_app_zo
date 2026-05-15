import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/staff_providers.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';

class DailySummaryPage extends ConsumerStatefulWidget {
  final DateTime? date;
  const DailySummaryPage({super.key, this.date});

  @override
  ConsumerState<DailySummaryPage> createState() => _DailySummaryPageState();
}

class _DailySummaryPageState extends ConsumerState<DailySummaryPage> {
  late DateTime _selectedDate;
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.date ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white70 : Colors.black87),
        ),
        title: const Text('Daily Summary', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today_rounded, color: isDark ? Colors.white70 : Colors.black87),
            onPressed: _selectDate,
          ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(user.id, theme, isDark),
    );
  }

  Widget _buildContent(String staffId, ThemeData theme, bool isDark) {
    final summaryAsync = ref.watch(dailySummaryProvider((staffId: staffId, date: _selectedDate)));

    return summaryAsync.when(
      data: (summary) => _buildSummaryCards(summary, theme, isDark),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err', style: TextStyle(color: theme.colorScheme.error))),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> summary, ThemeData theme, bool isDark) {
    return RefreshIndicator(
      onRefresh: () async { ref.invalidate(staffProfileProvider); await Future.delayed(const Duration(milliseconds: 500)); },
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
        children: [
          _buildDateHeader(theme, isDark),
          const SizedBox(height: 16),
          _buildCollectionSummary(summary, theme, isDark),
          const SizedBox(height: 16),
          _buildPaymentModeBreakdown(summary, theme, isDark),
          const SizedBox(height: 16),
          _buildVisitSummary(summary, theme, isDark),
          const SizedBox(height: 16),
          _buildPerformanceMetrics(summary, theme, isDark),
          const SizedBox(height: 16),
          _buildCollectionsList(summary['recent_collections'] as List?, theme, isDark),
        ].animate(interval: 60.ms).fadeIn().slideY(begin: 0.04, end: 0),
        ),
      ),
    );
  }

  Widget _buildDateHeader(ThemeData theme, bool isDark) {
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    final dateStr = DateFormat('EEEE, MMMM d, y').format(_selectedDate);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primary, AppColors.accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
            child: Icon(isToday ? Icons.today_rounded : Icons.history_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isToday ? 'Today\'s Summary' : 'Summary Report', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                Text(dateStr, style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
              ],
            ),
          ),
          if (!isToday)
            TextButton(
              onPressed: () => setState(() => _selectedDate = DateTime.now()),
              style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.white.withValues(alpha: 0.15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Today', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildCollectionSummary(Map<String, dynamic> summary, ThemeData theme, bool isDark) {
    final totalCollected = summary['total_collected'] as double? ?? 0.0;
    final targetAmount = summary['target_amount'] as double? ?? 0.0;
    final progress = targetAmount > 0 ? (totalCollected / targetAmount).clamp(0.0, 1.0) : 0.0;

    return _buildSection(theme, isDark,
      title: 'Collection Summary',
      icon: Icons.payments_rounded,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildMetric(theme, 'Collected', _currencyFormat.format(totalCollected), Icons.payments_rounded, AppColors.success)),
              Container(width: 1, height: 50, color: theme.dividerColor.withValues(alpha: 0.2)),
              Expanded(child: _buildMetric(theme, 'Target', _currencyFormat.format(targetAmount), Icons.flag_rounded, AppColors.primary)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress, minHeight: 10,
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(progress >= 1.0 ? AppColors.success : AppColors.primary),
            ),
          ),
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerRight, child: Text('${(progress * 100).toStringAsFixed(1)}% achieved', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)))),
        ],
      ),
    );
  }

  Widget _buildMetric(ThemeData theme, String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: color)),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 10)),
      ],
    );
  }

  Widget _buildPaymentModeBreakdown(Map<String, dynamic> summary, ThemeData theme, bool isDark) {
    final cash = summary['cash_collected'] as double? ?? 0.0;
    final digital = summary['digital_collected'] as double? ?? 0.0;
    final total = cash + digital;
    final cashPct = total > 0 ? cash / total : 0.0;
    final digitalPct = total > 0 ? digital / total : 0.0;

    return _buildSection(theme, isDark,
      title: 'Payment Breakdown',
      icon: Icons.account_balance_wallet_rounded,
      child: Column(
        children: [
          _buildModeRow(theme, 'Cash', cash, cashPct, AppColors.success, Icons.payments_rounded, isDark),
          const SizedBox(height: 12),
          _buildModeRow(theme, 'Digital', digital, digitalPct, AppColors.info, Icons.phone_android_rounded, isDark),
        ],
      ),
    );
  }

  Widget _buildModeRow(ThemeData theme, String label, double amount, double pct, Color color, IconData icon, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500))),
            Text(_currencyFormat.format(amount), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: pct, minHeight: 6,
            backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color)),
        ),
      ],
    );
  }

  Widget _buildVisitSummary(Map<String, dynamic> summary, ThemeData theme, bool isDark) {
    final totalVisits = summary['total_visits'] as int? ?? 0;
    final successfulVisits = summary['successful_visits'] as int? ?? 0;
    final successRate = totalVisits > 0 ? (successfulVisits / totalVisits * 100).toStringAsFixed(0) : '0';

    return _buildSection(theme, isDark,
      title: 'Visit Summary',
      icon: Icons.route_rounded,
      child: Row(
        children: [
          Expanded(child: _buildVisitMetric(theme, totalVisits.toString(), 'Total', Icons.place_rounded, AppColors.primary)),
          Container(width: 1, height: 50, color: theme.dividerColor.withValues(alpha: 0.2)),
          Expanded(child: _buildVisitMetric(theme, successfulVisits.toString(), 'Completed', Icons.check_circle_rounded, AppColors.success)),
          Container(width: 1, height: 50, color: theme.dividerColor.withValues(alpha: 0.2)),
          Expanded(child: _buildVisitMetric(theme, '$successRate%', 'Success', Icons.trending_up_rounded, Colors.greenAccent)),
        ],
      ),
    );
  }

  Widget _buildVisitMetric(ThemeData theme, String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: color)),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 10)),
      ],
    );
  }

  Widget _buildPerformanceMetrics(Map<String, dynamic> summary, ThemeData theme, bool isDark) {
    final collectionCount = summary['collection_count'] as int? ?? 0;
    final streakDays = summary['streak_days'] as int? ?? 0;

    return _buildSection(theme, isDark,
      title: 'Performance',
      icon: Icons.speed_rounded,
      child: Column(
        children: [
          _metaRow(theme, Icons.receipt_long_rounded, 'Collections Made', collectionCount.toString(), null),
          const Divider(height: 20),
          _metaRow(theme, Icons.local_fire_department_rounded, 'Current Streak', '$streakDays days', Colors.orangeAccent),
        ],
      ),
    );
  }

  Widget _metaRow(ThemeData theme, IconData icon, String label, String value, Color? highlight) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: (highlight ?? AppColors.primary).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: highlight ?? AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: highlight)),
      ],
    );
  }

  Widget _buildCollectionsList(List? collections, ThemeData theme, bool isDark) {
    if (collections == null || collections.isEmpty) return const SizedBox.shrink();
    return _buildSection(theme, isDark,
      title: 'Recent Collections',
      icon: Icons.history_rounded,
      trailing: TextButton(onPressed: () => context.push('/staff/history'), child: const Text('View All', style: TextStyle(fontSize: 12))),
      child: Column(
        children: collections.take(5).map((c) {
          final item = c as Map<String, dynamic>;
          final time = item['collection_time'] as String?;
          final timeStr = time != null ? DateFormat.jm().format(DateTime.parse(time)) : '';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.payments_rounded, size: 18, color: AppColors.success),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['member_name'] ?? 'Unknown', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      Text(timeStr, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
                    ],
                  ),
                ),
                Text(_currencyFormat.format(item['amount_collected'] ?? 0), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: AppColors.success)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSection(ThemeData theme, bool isDark, {required String title, required IconData icon, required Widget child, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.05), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Theme.of(context).brightness),
      ), child: child!),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

