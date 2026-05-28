// ignore_for_file: deprecated_member_use
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../branch_manager/data/providers/branch_scoped_providers.dart';
import '../../data/providers/staff_branch_providers.dart';

class StaffUserHubPage extends ConsumerStatefulWidget {
  const StaffUserHubPage({super.key});

  @override
  ConsumerState<StaffUserHubPage> createState() => _StaffUserHubPageState();
}

class _StaffUserHubPageState extends ConsumerState<StaffUserHubPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _activeFilter = 0;

  final List<Map<String, dynamic>> _filters = [
    {'label': 'All', 'icon': Icons.people_rounded},
    {'label': 'Active', 'icon': Icons.check_circle_rounded},
    {'label': 'Inactive', 'icon': Icons.pause_circle_rounded},
    {'label': 'New This Month', 'icon': Icons.person_add_rounded},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final branchAsync = ref.watch(staffBranchIdProvider);

    if (branchAsync.isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final branchId = branchAsync.valueOrNull;

    if (branchId == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('No branch assigned',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Contact your admin to assign a branch.',
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    final membersAsync = ref.watch(branchMembersProvider(branchId));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _AuroraBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              _buildAppBar(theme, isDark, membersAsync),
              // Hero section
              _buildHero(theme, isDark, membersAsync),
              const SizedBox(height: 18),
              // Stats rail
              membersAsync.when(
                data: (members) => _StatsRail(members: members),
                loading: () => const _StatsRailSkeleton(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 18),
              // Search bar
              _buildSearchBar(theme, isDark),
              const SizedBox(height: 14),
              // Filter chips
              _buildFilterChips(theme, isDark),
              const SizedBox(height: 8),
              // Member list
              Expanded(child: _buildMemberList(theme, isDark, membersAsync)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // App Bar
  // ---------------------------------------------------------------------------

  Widget _buildAppBar(
      ThemeData theme,
      bool isDark,
      AsyncValue<List<Map<String, dynamic>>> membersAsync) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
            onPressed: () => context.go('/staff'),
          ),
          Expanded(
            child: Text(
              'User Hub',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ),
          membersAsync.when(
            data: (members) => Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.16),
                    theme.colorScheme.secondary.withValues(alpha: 0.10),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.groups_2_rounded,
                      size: 15, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    '${members.length}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'total',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary
                          .withValues(alpha: 0.75),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 220.ms).scale(
                begin: const Offset(0.85, 0.85),
                end: const Offset(1, 1),
                curve: Curves.easeOutBack),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero Section
  // ---------------------------------------------------------------------------

  Widget _buildHero(
      ThemeData theme, bool isDark, AsyncValue<List<Map<String, dynamic>>> membersAsync) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BRANCH MEMBERS',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.2,
                    fontSize: 10,
                    color: theme.colorScheme.primary,
                  ),
                ).animate().fadeIn(duration: 350.ms).slideX(begin: -0.1, end: 0),
                const SizedBox(height: 4),
                ShaderMask(
                  shaderCallback: (rect) => LinearGradient(
                    colors: [
                      theme.colorScheme.onSurface,
                      theme.colorScheme.primary,
                    ],
                  ).createShader(rect),
                  child: Text(
                    'Member Hub',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.4,
                      fontSize: 32,
                      color: Colors.white,
                    ),
                  ),
                ).animate().fadeIn(delay: 80.ms).slideX(begin: -0.05, end: 0),
                const SizedBox(height: 4),
                Text(
                  'Your branch members, at a glance',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.7),
                  ),
                ).animate().fadeIn(delay: 160.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search Bar (admin-style)
  // ---------------------------------------------------------------------------

  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.04),
              blurRadius: 18,
              offset: const Offset(0, 6),
              spreadRadius: -8,
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(Icons.search_rounded,
                size: 20,
                color: theme.textTheme.bodySmall?.color
                    ?.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Search members by name or phone...',
                  hintStyle: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.6),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.cancel_rounded, size: 18),
                color:
                    theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 280.ms).slideY(begin: 0.1, end: 0);
  }

  // ---------------------------------------------------------------------------
  // Filter Chips
  // ---------------------------------------------------------------------------

  Widget _buildFilterChips(ThemeData theme, bool isDark) {
    final primary = theme.colorScheme.primary;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        physics: const BouncingScrollPhysics(),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isActive = _activeFilter == index;
          return InkWell(
            onTap: () => setState(() => _activeFilter = index),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient: isActive
                    ? LinearGradient(
                        colors: [primary, primary.withValues(alpha: 0.8)],
                      )
                    : null,
                color: isActive ? null : primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? Colors.transparent
                      : primary.withValues(alpha: 0.20),
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                          spreadRadius: -3,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filter['icon'] as IconData,
                    size: 14,
                    color: isActive ? Colors.white : primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    filter['label'] as String,
                    style: TextStyle(
                      color: isActive ? Colors.white : primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(
                  delay: Duration(milliseconds: 50 * index), duration: 300.ms)
              .slideY(
                  begin: 0.1,
                  end: 0,
                  delay: Duration(milliseconds: 50 * index),
                  duration: 300.ms,
                  curve: Curves.easeOutCubic);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Member List
  // ---------------------------------------------------------------------------

  Widget _buildMemberList(ThemeData theme, bool isDark,
      AsyncValue<List<Map<String, dynamic>>> membersAsync) {
    return membersAsync.when(
      data: (members) {
        final filtered = _applyFilters(members);
        if (filtered.isEmpty) {
          return _buildEmptyState(theme, isDark);
        }
        return RefreshIndicator(
          onRefresh: () async {
            final branchId =
                ref.read(staffBranchIdProvider).valueOrNull;
            if (branchId != null) {
              ref.invalidate(branchMembersProvider(branchId));
              ref.invalidate(branchMemberCountProvider(branchId));
            }
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MemberCard(
                  member: filtered[index],
                  index: index,
                ),
              );
            },
          ),
        );
      },
      loading: () => ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (_, __) => _SkeletonCard(),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: 6,
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.error.withValues(alpha: 0.18),
                      AppColors.error.withValues(alpha: 0.05),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.18)),
                ),
                child: const Icon(Icons.error_outline_rounded,
                    size: 38, color: AppColors.error),
              )
                  .animate()
                  .scale(
                      duration: 350.ms,
                      curve: Curves.easeOutBack,
                      begin: const Offset(0.6, 0.6),
                      end: const Offset(1, 1))
                  .fadeIn(),
              const SizedBox(height: 18),
              Text(
                'Something went wrong',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 6),
              Text(
                e.toString(),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
              ).animate().fadeIn(delay: 160.ms),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty State
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    final primary = theme.colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primary.withValues(alpha: 0.18),
                    primary.withValues(alpha: 0.05),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: primary.withValues(alpha: 0.18)),
              ),
              child: Icon(
                _searchQuery.isNotEmpty
                    ? Icons.search_off_rounded
                    : Icons.people_outline_rounded,
                size: 38,
                color: primary,
              ),
            )
                .animate()
                .scale(
                    duration: 350.ms,
                    curve: Curves.easeOutBack,
                    begin: const Offset(0.6, 0.6),
                    end: const Offset(1, 1))
                .fadeIn(),
            const SizedBox(height: 18),
            Text(
              _searchQuery.isNotEmpty ? 'No members found' : 'No members yet',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : 'Members will appear here once added to your branch',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 13,
                height: 1.4,
              ),
            ).animate().fadeIn(delay: 160.ms),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filter Logic
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> members) {
    var filtered = members;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((m) {
        final name = (m['full_name'] as String? ?? '').toLowerCase();
        final phone = (m['phone'] as String? ?? '').toLowerCase();
        return name.contains(q) || phone.contains(q);
      }).toList();
    }

    // Tab filter
    switch (_activeFilter) {
      case 1: // Active
        filtered = filtered
            .where((m) => (m['status'] ?? 'active') == 'active')
            .toList();
        break;
      case 2: // Inactive
        filtered = filtered
            .where((m) => (m['status'] ?? 'active') != 'active')
            .toList();
        break;
      case 3: // New This Month
        final now = DateTime.now();
        filtered = filtered.where((m) {
          final created = m['created_at'] as String?;
          if (created == null) return false;
          final date = DateTime.tryParse(created);
          if (date == null) return false;
          return date.month == now.month && date.year == now.year;
        }).toList();
        break;
    }

    return filtered;
  }
}

// =============================================================================
// STATS RAIL (horizontal scrollable stat tiles)
// =============================================================================

class _StatsRail extends StatelessWidget {
  final List<Map<String, dynamic>> members;
  const _StatsRail({required this.members});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final total = members.length;
    final active =
        members.where((m) => (m['status'] ?? 'active') == 'active').length;
    final inactive = total - active;
    final thisMonth = members.where((m) {
      final created = m['created_at'] as String?;
      if (created == null) return false;
      final date = DateTime.tryParse(created);
      if (date == null) return false;
      final now = DateTime.now();
      return date.month == now.month && date.year == now.year;
    }).length;

    final tiles = <_StatTileData>[
      _StatTileData(
        label: 'Total',
        value: total,
        icon: Icons.people_alt_rounded,
        color: primary,
        gradient: AppColors.premiumGradient,
      ),
      _StatTileData(
        label: 'Active',
        value: active,
        icon: Icons.check_circle_rounded,
        color: isDark ? AppColors.successDark : AppColors.success,
      ),
      _StatTileData(
        label: 'Inactive',
        value: inactive,
        icon: Icons.pause_circle_rounded,
        color: isDark ? AppColors.warningDark : AppColors.orange,
      ),
      _StatTileData(
        label: 'New',
        value: thisMonth,
        icon: Icons.person_add_rounded,
        color: const Color(0xFF667EEA),
      ),
    ];

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        physics: const BouncingScrollPhysics(),
        itemBuilder: (ctx, i) => _StatTile(data: tiles[i], index: i),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: tiles.length,
      ),
    );
  }
}

class _StatsRailSkeleton extends StatelessWidget {
  const _StatsRailSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base =
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (_, __) => Container(
          width: 138,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: 4,
      ),
    );
  }
}

class _StatTileData {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final List<Color>? gradient;
  _StatTileData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.gradient,
  });
}

class _StatTile extends StatelessWidget {
  final _StatTileData data;
  final int index;
  const _StatTile({required this.data, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: 138,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: data.gradient != null
              ? [
                  data.gradient![0].withValues(alpha: isDark ? 0.18 : 0.10),
                  data.gradient![1].withValues(alpha: isDark ? 0.10 : 0.06),
                ]
              : [
                  data.color.withValues(alpha: isDark ? 0.15 : 0.10),
                  data.color.withValues(alpha: isDark ? 0.06 : 0.04),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: data.color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: data.color.withValues(alpha: isDark ? 0.10 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(data.icon, color: data.color, size: 16),
              ),
              const Spacer(),
              _CountUp(
                target: data.value,
                duration: Duration(milliseconds: 700 + index * 80),
                builder: (v) => Text(
                  v.toString(),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: data.color,
                    letterSpacing: -1,
                    fontSize: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            data.label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color:
                  theme.textTheme.bodySmall?.color?.withValues(alpha: 0.85),
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 18,
            child: _MiniSparkline(
              color: data.color,
              seed: data.label.codeUnitAt(0) + data.value,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: (60 * index).ms, duration: 350.ms)
        .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic);
  }
}

class _MiniSparkline extends StatelessWidget {
  final Color color;
  final int seed;
  const _MiniSparkline({required this.color, required this.seed});

  @override
  Widget build(BuildContext context) {
    final rng = math.Random(seed);
    final pts = List.generate(12, (_) => 0.3 + rng.nextDouble() * 0.7);
    return CustomPaint(
      painter: _SparklinePainter(points: pts, color: color),
      size: Size.infinite,
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;
  _SparklinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final dx = size.width / (points.length - 1);
    final path = Path();
    final fill = Path();
    for (int i = 0; i < points.length; i++) {
      final x = i * dx;
      final y = size.height - points[i] * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        final prevX = (i - 1) * dx;
        final prevY = size.height - points[i - 1] * size.height;
        final cpx = (prevX + x) / 2;
        path.cubicTo(cpx, prevY, cpx, y, x, y);
        fill.cubicTo(cpx, prevY, cpx, y, x, y);
      }
    }
    fill
      ..lineTo(size.width, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.30),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fill, fillPaint);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.95);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}

// =============================================================================
// MEMBER CARD (GlassCard-based, matches admin _UserRow style)
// =============================================================================

class _MemberCard extends StatelessWidget {
  final Map<String, dynamic> member;
  final int index;
  const _MemberCard({required this.member, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final name = member['full_name'] as String? ?? 'Unknown';
    final phone = member['phone'] as String?;
    final status = member['status'] as String? ?? 'active';
    final isActive = status == 'active';
    final totalLoans = (member['total_loans'] as int?) ?? 0;
    final totalSavings = (member['total_savings'] as num?)?.toDouble() ?? 0;
    final profileId = member['profile_id'] as String?;
    final avatarUrl = member['avatar_url'] as String?;
    final f = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

    final avatarColor = isActive
        ? const Color(0xFF667EEA)
        : (isDark ? Colors.grey.shade600 : Colors.grey.shade400);

    return GlassCard(
      padding: const EdgeInsets.all(14),
      onTap: () {
        if (profileId != null) {
          context.go('/staff/user-hub/$profileId');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This member has no linked user account')),
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar (image or gradient circle with initials + glow)
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      avatarColor.withValues(alpha: 0.85),
                      avatarColor.withValues(alpha: 0.35),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: avatarColor.withValues(alpha: 0.30),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                      ? Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          width: 48,
                          height: 48,
                          errorBuilder: (_, __, ___) => _buildInitialAvatar(avatarColor, name),
                        )
                      : _buildInitialAvatar(avatarColor, name),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _StatusBadge(isActive: isActive),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (phone != null && phone.isNotEmpty)
                          _MutedChip(
                            icon: Icons.phone_rounded,
                            text: phone,
                          ),
                        if (totalLoans > 0)
                          _MutedChip(
                            icon: Icons.account_balance_rounded,
                            text: '$totalLoans loans',
                          ),
                        if (totalSavings > 0)
                          _MutedChip(
                            icon: Icons.savings_rounded,
                            text: f.format(totalSavings),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Chevron
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 40 * index.clamp(0, 15)),
          duration: 300.ms,
        )
        .slideX(
          begin: 0.03,
          end: 0,
          delay: Duration(milliseconds: 40 * index.clamp(0, 15)),
        );
  }

  Widget _buildInitialAvatar(Color avatarColor, String name) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            avatarColor.withValues(alpha: 0.95),
            avatarColor.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? 'ACTIVE' : 'INACTIVE',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

}

class _MutedChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MutedChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 10.5,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6)),
        const SizedBox(width: 3),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// SKELETON CARD
// =============================================================================

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base =
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

// =============================================================================
// AURORA BACKDROP
// =============================================================================

class _AuroraBackdrop extends StatelessWidget {
  final Widget child;
  const _AuroraBackdrop({required this.child});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;
    return Stack(
      children: [
        Positioned(
          top: -160,
          right: -120,
          child: Container(
            width: 420,
            height: 420,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  primary.withValues(alpha: 0.10),
                  primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -120,
          left: -80,
          child: Container(
            width: 360,
            height: 360,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  secondary.withValues(alpha: 0.08),
                  secondary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 220,
          left: -60,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.success.withValues(alpha: 0.05),
                  AppColors.success.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

// =============================================================================
// COUNT-UP ANIMATION
// =============================================================================

class _CountUp extends StatefulWidget {
  final int target;
  final Duration duration;
  final Widget Function(int value) builder;

  const _CountUp({
    required this.target,
    required this.duration,
    required this.builder,
  });

  @override
  State<_CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<_CountUp>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _previousTarget = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: widget.duration);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _CountUp old) {
    super.didUpdateWidget(old);
    if (old.target != widget.target) {
      _previousTarget = old.target;
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final value = _previousTarget +
            ((widget.target - _previousTarget) * _controller.value).round();
        return widget.builder(value);
      },
    );
  }
}
