import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../providers/new_user_provider.dart';
import '../providers/user_list_provider.dart';

/// Per-user audit drilldown — fetches `activity_logs` rows filtered by
/// `user_id` and renders them as a timeline.
class UserAuditPage extends ConsumerStatefulWidget {
  final String userId;
  const UserAuditPage({super.key, required this.userId});

  @override
  ConsumerState<UserAuditPage> createState() => _UserAuditPageState();
}

class _UserAuditPageState extends ConsumerState<UserAuditPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final repo = ref.read(userRepositoryProvider);
    _future = repo.getActivityLogsForUser(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(userDetailsProvider(widget.userId));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 20),
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: profileAsync.when(
                        data: (p) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Audit Trail',
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            Text(
                              p?.fullName ?? 'Unknown user',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      onPressed: () => setState(_refresh),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(child: Text('Error: ${snap.error}'));
                    }
                    final logs = snap.data ?? const [];
                    if (logs.isEmpty) return _buildEmpty(theme);
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      itemCount: logs.length,
                      itemBuilder: (context, i) {
                        final log = logs[i];
                        return _LogTile(
                          log: log,
                          isFirst: i == 0,
                          isLast: i == logs.length - 1,
                        )
                            .animate()
                            .fadeIn(duration: 300.ms, delay: (30 * i).ms)
                            .slideX(begin: 0.04, end: 0);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off_rounded,
              size: 56,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('No activity yet',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Actions performed by this user will appear here.',
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final Map<String, dynamic> log;
  final bool isFirst;
  final bool isLast;
  const _LogTile({
    required this.log,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = (log['type'] ?? 'userAction').toString();
    final action = (log['action'] ?? '').toString();
    final details = (log['details'] ?? '').toString();
    final tsRaw = log['timestamp']?.toString();
    final ts = tsRaw != null ? DateTime.tryParse(tsRaw) : null;

    final color = _colorFor(type);
    final icon = _iconFor(type);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline rail
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 12,
                  color: isFirst
                      ? Colors.transparent
                      : theme.dividerColor.withValues(alpha: 0.4),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Icon(icon, color: color, size: 14),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : theme.dividerColor.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            action.isEmpty ? '(unknown action)' : action,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (ts != null)
                          Text(
                            DateFormat('MMM d, HH:mm').format(ts.toLocal()),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                      ],
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        details,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontSize: 12, height: 1.4),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _typeLabel(type),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: color,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'systemUpdate':
        return 'SYSTEM';
      case 'securityAlert':
        return 'SECURITY';
      case 'financialTransaction':
        return 'FINANCIAL';
      case 'authAction':
        return 'AUTH';
      default:
        return 'USER ACTION';
    }
  }

  IconData _iconFor(String t) {
    switch (t) {
      case 'systemUpdate':
        return Icons.settings_rounded;
      case 'securityAlert':
        return Icons.shield_rounded;
      case 'financialTransaction':
        return Icons.payments_rounded;
      case 'authAction':
        return Icons.login_rounded;
      default:
        return Icons.touch_app_rounded;
    }
  }

  Color _colorFor(String t) {
    switch (t) {
      case 'systemUpdate':
        return AppColors.primary;
      case 'securityAlert':
        return AppColors.error;
      case 'financialTransaction':
        return AppColors.success;
      case 'authAction':
        return AppColors.orange;
      default:
        return AppColors.accent;
    }
  }
}
