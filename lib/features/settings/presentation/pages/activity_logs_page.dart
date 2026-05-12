import '../../../../core/widgets/shimmer_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/models/activity_log_model.dart';
import '../../data/providers/activity_logs_provider.dart';

class ActivityLogsPage extends ConsumerWidget {
  const ActivityLogsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(activityLogsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () => context.pop(),
                ),
                title: Text(
                  'Activity Logs',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                centerTitle: true,
                floating: true,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'System Audit Trail',
                        style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Monitoring all administrative and financial actions.',
                        style:
                            theme.textTheme.bodySmall?.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              logsAsync.when(
                data: (logs) => SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _LogItem(
                              log: logs[index],
                              isFirst: index == 0,
                              isLast: index == logs.length - 1)
                          .animate()
                          .fadeIn(delay: (50 * index).ms)
                          .slideX(begin: 0.05, end: 0),
                      childCount: logs.length,
                    ),
                  ),
                ),
                loading: () => SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, __) => const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: ShimmerCard(height: 100),
                      ),
                      childCount: 5,
                    ),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Center(child: Text('Error loading logs: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogItem extends StatelessWidget {
  final ActivityLogModel log;
  final bool isFirst;
  final bool isLast;

  const _LogItem(
      {required this.log, required this.isFirst, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color typeColor;
    IconData typeIcon;

    switch (log.type) {
      case ActivityType.systemUpdate:
        typeColor = Colors.blue;
        typeIcon = Icons.settings_suggest_outlined;
        break;
      case ActivityType.securityAlert:
        typeColor = Colors.red;
        typeIcon = Icons.security_rounded;
        break;
      case ActivityType.financialTransaction:
        typeColor = Colors.green;
        typeIcon = Icons.account_balance_wallet_outlined;
        break;
      case ActivityType.userAction:
        typeColor = Colors.orange;
        typeIcon = Icons.person_outline_rounded;
        break;
      case ActivityType.authAction:
        typeColor = Colors.purple;
        typeIcon = Icons.vpn_key_rounded;
        break;
    }

    return IntrinsicHeight(
      child: Row(
        children: [
          // Timeline Column
          SizedBox(
            width: 40,
            child: Column(
              children: [
                if (!isFirst)
                  Container(
                      width: 2,
                      height: 12,
                      color: typeColor.withValues(alpha: 0.2)),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: typeColor.withValues(alpha: 0.2)),
                  ),
                  child: Icon(typeIcon, size: 16, color: typeColor),
                ),
                if (!isLast)
                  Expanded(
                      child: Container(
                          width: 2, color: typeColor.withValues(alpha: 0.2))),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            log.action,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3),
                          ),
                        ),
                        Text(
                          DateFormat('HH:mm').format(log.timestamp),
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      log.details,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4)),
                          child: const Icon(Icons.person,
                              size: 12, color: AppColors.primary),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          log.userName,
                          style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary),
                        ),
                        const Spacer(),
                        Text(
                          DateFormat('MMM dd').format(log.timestamp),
                          style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.4)),
                        ),
                      ],
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
}
