import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/staff_providers.dart';
import '../../data/providers/collection_providers.dart';

class StaffTargetsPage extends ConsumerStatefulWidget {
  const StaffTargetsPage({super.key});

  @override
  ConsumerState<StaffTargetsPage> createState() => _StaffTargetsPageState();
}

class _StaffTargetsPageState extends ConsumerState<StaffTargetsPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'daily';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded,
              color: isDark ? Colors.white70 : Colors.black87),
        ),
        title: const Text('Targets',
            style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todayTargetProvider);
          ref.invalidate(todayCollectionStatsProvider);
          ref.invalidate(staffStreakProvider);
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPeriodSelector(theme, isDark),
              const SizedBox(height: 24),
              if (_selectedPeriod == 'daily') _buildDailyTarget(theme, isDark),
              if (_selectedPeriod == 'weekly')
                _buildWeeklyTarget(theme, isDark),
              if (_selectedPeriod == 'monthly')
                _buildMonthlyTarget(theme, isDark),
              const SizedBox(height: 24),
              _buildTargetHistory(theme, isDark),
              const SizedBox(height: 24),
              _buildStreakSection(theme, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(ThemeData theme, bool isDark) {
    return Row(
      children: ['daily', 'weekly', 'monthly'].map((period) {
        final isSelected = _selectedPeriod == period;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(period.capitalize(),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : null)),
            selected: isSelected,
            selectedColor: AppColors.primary,
            backgroundColor: isDark ? const Color(0xFF1E1E2D) : Colors.white,
            onSelected: (_) => setState(() => _selectedPeriod = period),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDailyTarget(ThemeData theme, bool isDark) {
    final targetAsync = ref.watch(todayTargetProvider);
    final streakAsync = ref.watch(staffStreakProvider);

    return targetAsync.when(
      data: (target) {
        if (target == null) return _buildEmptyTarget(theme, isDark);
        return streakAsync.when(
          data: (streak) {
            final progress = target.progress;
            final remaining = target.targetAmount - target.achievedAmount;
            final pct = (progress * 100).toStringAsFixed(1);

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: progress >= 1.0
                      ? [Colors.green.shade600, Colors.teal.shade700]
                      : [AppColors.primary, AppColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: (progress >= 1.0 ? Colors.green : AppColors.primary)
                        .withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Today\'s Target',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      if (progress >= 1.0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.celebration,
                                  size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text('Achieved!',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildCircularProgress(progress, 140, theme),
                  const SizedBox(height: 20),
                  Text('$pct% Complete',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(
                    '₹${target.achievedAmount.toStringAsFixed(0)} of ₹${target.targetAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14),
                  ),
                  if (remaining > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.trending_up_rounded,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.8)),
                          const SizedBox(width: 8),
                          Text('₹${remaining.toStringAsFixed(0)} remaining',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _buildEmptyTarget(theme, isDark),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildEmptyTarget(theme, isDark),
    );
  }

  Widget _buildWeeklyTarget(ThemeData theme, bool isDark) {
    final profileAsync = ref.watch(staffProfileProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile == null) return _buildEmptyTarget(theme, isDark);
        final weeklyTarget = profile.dailyCollectionTarget * 7;
        final today = DateTime.now();
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        final daysInWeek = today.weekday;
        final projectedTarget = profile.dailyCollectionTarget * daysInWeek;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_view_week_rounded,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('This Week',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (i) {
                  final date = startOfWeek.add(Duration(days: i));
                  final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  final isPast =
                      date.isBefore(today.add(const Duration(days: 1)));
                  final isToday = date.day == today.day;
                  return Column(
                    children: [
                      Text(dayLabels[i],
                          style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4))),
                      const SizedBox(height: 4),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isToday
                              ? AppColors.primary
                              : (isPast
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : Colors.transparent),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  isToday ? FontWeight.w800 : FontWeight.w500,
                              color: isToday
                                  ? Colors.white
                                  : (isPast
                                      ? AppColors.primary
                                      : theme.colorScheme.onSurface
                                          .withValues(alpha: 0.3)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatChip(theme, 'Target',
                      '₹${weeklyTarget.toStringAsFixed(0)}', AppColors.primary),
                  _buildStatChip(
                      theme,
                      'Projected',
                      '₹${projectedTarget.toStringAsFixed(0)}',
                      AppColors.accent),
                  _buildStatChip(
                      theme, 'Days', '$daysInWeek/7', Colors.greenAccent),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildEmptyTarget(theme, isDark),
    );
  }

  Widget _buildMonthlyTarget(ThemeData theme, bool isDark) {
    final profileAsync = ref.watch(staffProfileProvider);
    final todayAsync = ref.watch(todayCollectionStatsProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile == null) return _buildEmptyTarget(theme, isDark);
        final monthlyTarget = profile.monthlyCollectionTarget;
        final daysInMonth = DateTime.now().month < 12
            ? DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day
            : DateTime(DateTime.now().year, 12, 31).day;
        final dayOfMonth = DateTime.now().day;

        return todayAsync.when(
          data: (todayStats) {
            final todayCollected =
                (todayStats['total_collected'] as num?)?.toDouble() ?? 0;
            final projectedMonthly = (monthlyTarget / daysInMonth) * dayOfMonth;
            final monthlyProgress =
                (todayCollected / monthlyTarget).clamp(0.0, 1.0);

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05)),
                boxShadow: [
                  BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.4 : 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_month_rounded,
                          size: 20, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Text('This Month',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildCircularProgress(monthlyProgress, 100, theme),
                  const SizedBox(height: 16),
                  Text('${(monthlyProgress * 100).toStringAsFixed(1)}%',
                      style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900, color: AppColors.accent),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text(
                      '₹${(monthlyTarget * monthlyProgress).toStringAsFixed(0)} of ₹${monthlyTarget.toStringAsFixed(0)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6)),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMonthlyStat(
                            theme,
                            'Day',
                            '$dayOfMonth/$daysInMonth',
                            Icons.calendar_today_rounded),
                        _buildMonthlyStat(
                            theme,
                            'Target',
                            '₹${monthlyTarget.toStringAsFixed(0)}',
                            Icons.flag_rounded),
                        _buildMonthlyStat(
                            theme,
                            'Proj.',
                            '₹${projectedMonthly.toStringAsFixed(0)}',
                            Icons.trending_up_rounded),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildEmptyTarget(theme, isDark),
    );
  }

  Widget _buildCircularProgress(double progress, double size, ThemeData theme) {
    return Center(
      child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                  width: size,
                  height: size,
                  child: CircularProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    strokeWidth: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 1.0 ? Colors.greenAccent : Colors.white),
                  )),
              Text('${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.22,
                      fontWeight: FontWeight.w900)),
            ],
          )),
    );
  }

  Widget _buildStatChip(
      ThemeData theme, String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 10)),
      ],
    );
  }

  Widget _buildMonthlyStat(
      ThemeData theme, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: AppColors.accent),
        const SizedBox(height: 4),
        Text(value,
            style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800, color: AppColors.accent)),
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 10)),
      ],
    );
  }

  Widget _buildTargetHistory(ThemeData theme, bool isDark) {
    final trendAsync = ref.watch(weeklyTrendProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Recent Performance',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          trendAsync.when(
            data: (trend) {
              if (trend.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                      child: Text('No data yet',
                          style: TextStyle(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4)))),
                );
              }
              final dailyTarget = trend.fold<double>(
                      0,
                      (s, e) =>
                          s + ((e['amount'] as num?)?.toDouble() ?? 0.0)) /
                  trend.length.clamp(1, 7);
              return Column(
                children: trend.reversed
                    .take(4)
                    .toList()
                    .asMap()
                    .entries
                    .map((entry) {
                  final i = entry.key;
                  final day = entry.value;
                  final amount = (day['amount'] as num?)?.toDouble() ?? 0;
                  final label =
                      i == 0 ? 'Today' : (i == 1 ? 'Yesterday' : '$i days ago');
                  final pct = dailyTarget > 0
                      ? (amount / dailyTarget).clamp(0.0, 1.0)
                      : 0.0;
                  return Column(
                    children: [
                      if (i > 0) const Divider(height: 20),
                      _buildHistoryRow(
                          theme,
                          label,
                          '₹${amount.toStringAsFixed(0)}',
                          '₹${dailyTarget.toStringAsFixed(0)}',
                          pct),
                    ],
                  );
                }).toList(),
              );
            },
            loading: () => const SizedBox(
                height: 60,
                child:
                    Center(child: CircularProgressIndicator(strokeWidth: 2))),
            error: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: Text('Could not load',
                      style: TextStyle(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4)))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(ThemeData theme, String label, String achieved,
      String target, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            Text('$achieved / $target',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? Colors.greenAccent : AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildStreakSection(ThemeData theme, bool isDark) {
    final streakAsync = ref.watch(staffStreakProvider);

    return streakAsync.when(
      data: (streak) {
        if (streak == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade400, Colors.orange.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_fire_department_rounded,
                      color: Colors.white, size: 28),
                  const SizedBox(width: 8),
                  Text('${streak.currentStreak}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DAY',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      Text('STREAK',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events,
                      color: Colors.yellow.shade200, size: 18),
                  const SizedBox(width: 6),
                  Text('Best: ${streak.longestStreak} days',
                      style: const TextStyle(color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(7, (i) {
                  final date = DateTime.now().subtract(Duration(days: 6 - i));
                  final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  final lastDate = streak.lastCollectionDate;
                  final isActive = lastDate != null &&
                      !date.isAfter(DateTime(
                          lastDate.year, lastDate.month, lastDate.day));
                  return Column(
                    children: [
                      Text(dayNames[date.weekday - 1],
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 10)),
                      const SizedBox(height: 4),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isActive
                              ? Icon(Icons.check,
                                  color: Colors.orange.shade700, size: 14)
                              : Text('${date.day}',
                                  style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.6),
                                      fontSize: 10)),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildEmptyTarget(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.flag_outlined,
                size: 48,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Text('No target data',
                style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
          ],
        ),
      ),
    );
  }
}

extension _StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
