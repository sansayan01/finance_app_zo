import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../data/providers/customer_loans_providers.dart';
import '../../data/models/customer_loan_model.dart';
import '../widgets/customer_loan_card.dart';
import '../widgets/customer_empty_state.dart';

class CustomerLoansPage extends ConsumerStatefulWidget {
  const CustomerLoansPage({super.key});

  @override
  ConsumerState<CustomerLoansPage> createState() => _CustomerLoansPageState();
}

class _CustomerLoansPageState extends ConsumerState<CustomerLoansPage>
    with TickerProviderStateMixin {
  String _filter = 'all';
  late final AnimationController _staggerController;
  late final AnimationController _headerController;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;

  double _previousOutstanding = 0;
  double _targetOutstanding = 0;

  static const _filterOptions = [
    ('all', 'All', Icons.layers_rounded),
    ('active', 'Active', Icons.play_circle_fill_rounded),
    ('completed', 'Closed', Icons.check_circle_rounded),
    ('overdue', 'Overdue', Icons.warning_amber_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerFade = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    ));
    _headerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _headerController.dispose();
    super.dispose();
  }

  void _scheduleStagger(double outstanding) {
    if (_targetOutstanding == outstanding && _staggerController.value > 0) {
      return;
    }
    _previousOutstanding = _targetOutstanding;
    _targetOutstanding = outstanding;
    _staggerController.reset();
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _staggerController.forward();
    });
  }

  /// Indian-style currency: ₹12,34,567 / ₹1.23 L / ₹1.23 Cr
  String _formatCurrency(double value) {
    if (value.abs() >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(2)} Cr';
    }
    if (value.abs() >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(2)} L';
    }
    final n = value.round();
    final s = n.toString();
    if (s.length <= 3) return '₹$s';
    final last3 = s.substring(s.length - 3);
    final rest = s.substring(0, s.length - 3);
    final buf = StringBuffer();
    for (int i = 0; i < rest.length; i++) {
      buf.write(rest[i]);
      final remaining = rest.length - i - 1;
      if (remaining > 0 && remaining % 2 == 0) buf.write(',');
    }
    return '₹${buf.toString()},$last3';
  }

  DateTime? _nextEmiDate(List<CustomerLoanModel> loans) {
    final now = DateTime.now();
    final upcoming = loans
        .where((l) => l.status == 'active' && l.firstEmiDate != null)
        .map((l) => l.firstEmiDate!)
        .where((d) => d.isAfter(now.subtract(const Duration(days: 1))))
        .toList()
      ..sort((a, b) => a.compareTo(b));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  String _formatLongDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loansAsync = ref.watch(customerLoansProvider);

    final headerGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF1A1F3A), Color(0xFF151A30)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : AppColors.primaryGradient;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      extendBody: true,
      body: AuroraBackground(
        child: loansAsync.when(
          loading: () => _buildLoadingState(theme, isDark, headerGradient),
          error: (e, _) => _buildErrorState(theme, isDark, e, headerGradient),
          data: (loans) {
            final summary = CustomerLoanSummary.fromLoans(loans);
            final filtered = _filterLoans(loans);
            final nextEmi = _nextEmiDate(loans);

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scheduleStagger(summary.totalOutstanding);
            });

            return _buildContent(
              theme,
              isDark,
              headerGradient,
              summary,
              filtered,
              nextEmi,
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    ThemeData theme,
    bool isDark,
    LinearGradient headerGradient,
    CustomerLoanSummary summary,
    List<CustomerLoanModel> filtered,
    DateTime? nextEmi,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(customerLoansProvider);
      },
      color: AppColors.primary,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: _buildGradientHeader(
              theme,
              isDark,
              headerGradient,
              summary,
              nextEmi,
            ),
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _headerFade,
              child: _buildFilterChips(theme, isDark),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    'Your Loans',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${filtered.length} ${filtered.length == 1 ? 'loan' : 'loans'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight)
                          .withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: CustomerEmptyState(
                icon: _filterIcon,
                title: 'No Loans Found',
                subtitle: _filterEmptyMessage,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, 110,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final delay = (index * 0.07).clamp(0.0, 0.9);
                    return AnimatedBuilder(
                      animation: _staggerController,
                      builder: (context, child) {
                        final progress = ((_staggerController.value - delay) /
                                (1 - delay))
                            .clamp(0.0, 1.0);
                        final eased = Curves.easeOutCubic.transform(progress);
                        return Opacity(
                          opacity: eased,
                          child: Transform.translate(
                            offset: Offset(0, 24 * (1 - eased)),
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: CustomerLoanCard(
                          loan: filtered[index],
                          onTap: () => context.push(
                            '/customer/loans/${filtered[index].id}',
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGradientHeader(
    ThemeData theme,
    bool isDark,
    LinearGradient gradient,
    CustomerLoanSummary summary,
    DateTime? nextEmi,
  ) {
    final mq = MediaQuery.of(context);

    return FadeTransition(
      opacity: _headerFade,
      child: SlideTransition(
        position: _headerSlide,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            mq.padding.top + AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'My Loans',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  _HeaderPill(
                    icon: Icons.account_balance_rounded,
                    label: '${summary.activeLoans} active',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              Text(
                'Total Outstanding',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: _previousOutstanding,
                  end: summary.totalOutstanding,
                ),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return Text(
                    _formatCurrency(value),
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              Text(
                'Disbursed ${_formatCurrency(summary.totalDisbursed)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Next EMI',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      nextEmi != null
                          ? _formatLongDate(nextEmi)
                          : 'No upcoming EMI',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme, bool isDark) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        itemCount: _filterOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final (key, label, icon) = _filterOptions[index];
          final selected = _filter == key;
          final color = _colorForFilter(key, isDark);

          return GestureDetector(
            onTap: () => setState(() => _filter = key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: isDark ? 0.18 : 0.12)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.035)),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? color.withValues(alpha: 0.45)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.05)),
                  width: selected ? 1.2 : 0.6,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 15,
                    color: selected
                        ? color
                        : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: selected
                          ? color
                          : (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _colorForFilter(String key, bool isDark) {
    switch (key) {
      case 'active':
        return isDark ? AppColors.successDark : AppColors.success;
      case 'completed':
        return isDark ? AppColors.primaryDark : AppColors.primary;
      case 'overdue':
        return isDark ? AppColors.errorDark : AppColors.error;
      default:
        return isDark ? AppColors.accentDark : AppColors.accent;
    }
  }

  IconData get _filterIcon {
    return switch (_filter) {
      'active' => Icons.play_circle_fill_rounded,
      'completed' => Icons.check_circle_rounded,
      'overdue' => Icons.warning_amber_rounded,
      _ => Icons.account_balance_rounded,
    };
  }

  String get _filterEmptyMessage {
    return switch (_filter) {
      'active' => 'You have no active loans at the moment.',
      'completed' => 'No closed loans to show yet.',
      'overdue' => 'Great news! No overdue loans.',
      _ => 'You don\'t have any loans yet.',
    };
  }

  List<CustomerLoanModel> _filterLoans(List<CustomerLoanModel> loans) {
    return switch (_filter) {
      'active' => loans.where((l) => l.status == 'active').toList(),
      'completed' => loans
          .where((l) => l.status == 'completed' || l.status == 'closed')
          .toList(),
      'overdue' => loans.where((l) => l.isOverdue).toList(),
      _ => loans,
    };
  }

  Widget _buildLoadingState(
      ThemeData theme, bool isDark, LinearGradient gradient) {
    return Column(
      children: [
        _buildGradientHeader(
          theme,
          isDark,
          gradient,
          CustomerLoanSummary(
            activeLoans: 0,
            totalOutstanding: 0,
            totalDisbursed: 0,
          ),
          null,
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            itemCount: 4,
            itemBuilder: (_, __) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: ShimmerCard(height: 140, borderRadius: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(
    ThemeData theme,
    bool isDark,
    Object error,
    LinearGradient gradient,
  ) {
    return Column(
      children: [
        _buildGradientHeader(
          theme,
          isDark,
          gradient,
          CustomerLoanSummary(
            activeLoans: 0,
            totalOutstanding: 0,
            totalDisbursed: 0,
          ),
          null,
        ),
        Expanded(
          child: CustomerEmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Couldn\'t load loans',
            subtitle: 'Pull down to retry, or tap the button below.',
            ctaLabel: 'Retry',
            onCtaTap: () => ref.invalidate(customerLoansProvider),
          ),
        ),
      ],
    );
  }
}

/// Frosted circular back/header button.
class _CircleIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  State<_CircleIconButton> createState() => _CircleIconButtonState();
}

class _CircleIconButtonState extends State<_CircleIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _pressed
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(widget.icon, color: Colors.white, size: 20),
      ),
    );
  }
}

/// Compact frosted pill used in the gradient header.
class _HeaderPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeaderPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
