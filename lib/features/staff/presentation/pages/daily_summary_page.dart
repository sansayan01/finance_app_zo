import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/providers/staff_providers.dart';
import '../../../../providers/supabase_provider.dart';

class DailySummaryPage extends ConsumerStatefulWidget {
  final DateTime? date;

  const DailySummaryPage({super.key, this.date});

  @override
  ConsumerState<DailySummaryPage> createState() => _DailySummaryPageState();
}

class _DailySummaryPageState extends ConsumerState<DailySummaryPage> {
  late DateTime _selectedDate;
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.date ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareSummary,
          ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : _buildSummaryContent(user.id, theme),
    );
  }

  Widget _buildSummaryContent(String staffId, ThemeData theme) {
    final summaryAsync = ref.watch(dailySummaryProvider((staffId: staffId, date: _selectedDate)));

    return summaryAsync.when(
      data: (summary) => _buildSummaryCards(summary, theme),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> summary, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateHeader(theme),
          const SizedBox(height: 16),
          _buildCollectionSummary(summary, theme),
          const SizedBox(height: 16),
          _buildPaymentModeBreakdown(summary, theme),
          const SizedBox(height: 16),
          _buildVisitSummary(summary, theme),
          const SizedBox(height: 16),
          _buildPerformanceMetrics(summary, theme),
          const SizedBox(height: 16),
          _buildCollectionsList(summary['recent_collections'] as List?, theme),
        ],
      ),
    );
  }

  Widget _buildDateHeader(ThemeData theme) {
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    final dateStr = DateFormat('EEEE, MMMM d, y').format(_selectedDate);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isToday ? Icons.today : Icons.history,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isToday ? 'Today\'s Summary' : 'Summary Report',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!isToday)
              TextButton(
                onPressed: () {
                  setState(() => _selectedDate = DateTime.now());
                },
                child: const Text('Today'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionSummary(Map<String, dynamic> summary, ThemeData theme) {
    final totalCollected = summary['total_collected'] as double? ?? 0.0;
    final targetAmount = summary['target_amount'] as double? ?? 0.0;
    final progress = targetAmount > 0 ? (totalCollected / targetAmount).clamp(0.0, 1.0) : 0.0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Collection Summary',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSummaryMetric(
                  theme,
                  'Total Collected',
                  currencyFormat.format(totalCollected),
                  Icons.payments,
                  Colors.green,
                ),
              ),
              Container(
                height: 60,
                width: 1,
                color: theme.dividerColor,
              ),
              Expanded(
                child: _buildSummaryMetric(
                  theme,
                  'Target',
                  currencyFormat.format(targetAmount),
                  Icons.flag,
                  theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildProgressBar(theme, progress),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toStringAsFixed(1)}% of target achieved',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(ThemeData theme, double progress) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 12,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(
          progress >= 1.0 ? Colors.green : theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildPaymentModeBreakdown(Map<String, dynamic> summary, ThemeData theme) {
    final cash = summary['cash_collected'] as double? ?? 0.0;
    final digital = summary['digital_collected'] as double? ?? 0.0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Mode Breakdown',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildModeRow(theme, 'Cash', cash, Colors.green, Icons.money),
          const SizedBox(height: 12),
          _buildModeRow(theme, 'Digital (UPI/Card)', digital, Colors.blue, Icons.phone_android),
        ],
      ),
    );
  }

  Widget _buildModeRow(ThemeData theme, String label, double amount, Color color, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              Text(
                currencyFormat.format(amount),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVisitSummary(Map<String, dynamic> summary, ThemeData theme) {
    final totalVisits = summary['total_visits'] as int? ?? 0;
    final successfulVisits = summary['successful_visits'] as int? ?? 0;
    final distanceTraveled = summary['distance_traveled'] as double? ?? 0.0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Visit Summary',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildVisitMetric(theme, 'Total Visits', totalVisits.toString(), Icons.place),
              ),
              Expanded(
                child: _buildVisitMetric(theme, 'Successful', successfulVisits.toString(), Icons.check_circle),
              ),
              Expanded(
                child: _buildVisitMetric(theme, 'Distance', '${distanceTraveled.toStringAsFixed(1)} km', Icons.route),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisitMetric(ThemeData theme, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPerformanceMetrics(Map<String, dynamic> summary, ThemeData theme) {
    final collectionCount = summary['collection_count'] as int? ?? 0;
    final avgCollectionTime = summary['avg_collection_time'] as int? ?? 0;
    final streakDays = summary['streak_days'] as int? ?? 0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Metrics',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildMetricRow(
            theme,
            Icons.receipt_long,
            'Collections Made',
            collectionCount.toString(),
          ),
          const Divider(height: 24),
          _buildMetricRow(
            theme,
            Icons.timer,
            'Avg. Time per Collection',
            '$avgCollectionTime min',
          ),
          const Divider(height: 24),
          _buildMetricRow(
            theme,
            Icons.local_fire_department,
            'Current Streak',
            '$streakDays days',
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: highlight ? Colors.orange : theme.colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: theme.textTheme.bodyMedium),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: highlight ? Colors.orange : null,
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionsList(List? collections, ThemeData theme) {
    if (collections == null || collections.isEmpty) {
      return const SizedBox.shrink();
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Collections',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  context.push('/staff/history');
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...collections.take(5).map((c) => _buildCollectionItem(c as Map<String, dynamic>, theme)),
        ],
      ),
    );
  }

  Widget _buildCollectionItem(Map<String, dynamic> collection, ThemeData theme) {
    final time = collection['collection_time'] as String?;
    final timeStr = time != null
        ? DateFormat.jm().format(DateTime.parse(time))
        : '';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Colors.green.withValues(alpha: 0.1),
        child: const Icon(Icons.payments, color: Colors.green, size: 20),
      ),
      title: Text(collection['member_name'] ?? 'Unknown'),
      subtitle: Text(timeStr),
      trailing: Text(
        currencyFormat.format(collection['amount_collected'] ?? 0),
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.green,
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _shareSummary() {
    // Implement share functionality
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
