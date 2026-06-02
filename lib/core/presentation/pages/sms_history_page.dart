// lib/core/presentation/pages/sms_history_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../providers/supabase_provider.dart';
import '../../widgets/glass_card.dart';

final smsHistoryProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final res = await client
      .from('sms_notifications')
      .select('id, recipient_phone, recipient_name, message, status, platform, created_at, sent_by')
      .order('created_at', ascending: false)
      .limit(200);
  return List<Map<String, dynamic>>.from(res as List);
});

class SmsHistoryPage extends ConsumerStatefulWidget {
  const SmsHistoryPage({super.key});

  @override
  ConsumerState<SmsHistoryPage> createState() => _SmsHistoryPageState();
}

class _SmsHistoryPageState extends ConsumerState<SmsHistoryPage> {
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final history = ref.watch(smsHistoryProvider);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('SMS History'),
        centerTitle: false,
      ),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 48, color: theme.colorScheme.error.withValues(alpha: 0.7)),
                const SizedBox(height: 12),
                Text('Failed to load SMS history', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '$e',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Check that the sms_notifications table exists and that RLS allows your session to read it.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sms_failed_outlined,
                        size: 48,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text('No SMS history yet', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Messages you send will appear here. If you expected to see entries, check that the sms_notifications table exists in Supabase.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          }
          final filtered = _statusFilter == 'all'
              ? rows
              : rows.where((r) => r['status'] == _statusFilter).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['all', 'sent', 'failed', 'skipped'].map((s) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(s),
                          selected: _statusFilter == s,
                          onSelected: (_) => setState(() => _statusFilter = s),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (_, i) => _row(theme, filtered[i]),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: filtered.length,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(ThemeData theme, Map<String, dynamic> row) {
    final status = (row['status'] as String?) ?? 'unknown';
    final color = switch (status) {
      'sent' => Colors.green,
      'failed' => Colors.red,
      'skipped' => Colors.orange,
      _ => Colors.grey,
    };
    final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '');
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (row['recipient_name'] as String?) ?? (row['recipient_phone'] as String?) ?? '—',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                createdAt == null
                    ? '—'
                    : DateFormat('dd MMM, HH:mm').format(createdAt.toLocal()),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            (row['message'] as String?) ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
