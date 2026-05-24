import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/shimmer_card.dart';
import '../../data/providers/customer_member_provider.dart';
import '../../data/providers/customer_feedback_providers.dart';
import '../../data/models/customer_feedback_model.dart';
import '../widgets/customer_empty_state.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Feedback Type Option (shared by page & card)
// ══════════════════════════════════════════════════════════════════════════════

class _FeedbackTypeOption {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final Color darkColor;

  const _FeedbackTypeOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.darkColor,
  });
}

const _feedbackTypes = [
  _FeedbackTypeOption(
    value: 'complaint',
    label: 'Complaint',
    icon: Icons.report_problem_rounded,
    color: Color(0xFFEF4444),
    darkColor: Color(0xFFF28B8B),
  ),
  _FeedbackTypeOption(
    value: 'suggestion',
    label: 'Suggestion',
    icon: Icons.lightbulb_rounded,
    color: Color(0xFFF59E0B),
    darkColor: Color(0xFFF4C45E),
  ),
  _FeedbackTypeOption(
    value: 'appreciation',
    label: 'Appreciation',
    icon: Icons.favorite_rounded,
    color: Color(0xFF10B981),
    darkColor: Color(0xFF52D1A4),
  ),
  _FeedbackTypeOption(
    value: 'other',
    label: 'Other',
    icon: Icons.more_horiz_rounded,
    color: Color(0xFF6366F1),
    darkColor: Color(0xFF7E89F1),
  ),
];

class CustomerFeedbackPage extends ConsumerStatefulWidget {
  const CustomerFeedbackPage({super.key});

  @override
  ConsumerState<CustomerFeedbackPage> createState() =>
      _CustomerFeedbackPageState();
}

class _CustomerFeedbackPageState extends ConsumerState<CustomerFeedbackPage>
    with TickerProviderStateMixin {
  late final AnimationController _staggerController;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;

  // ── Form state ──
  String? _selectedType;
  int _rating = 0;
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  static const _maxMessageLength = 500;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _headerFade = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOutCubic),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOutCubic),
    ));
    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _selectedType != null &&
      _messageController.text.trim().isNotEmpty &&
      !_isSubmitting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final feedbacksAsync = ref.watch(customerFeedbackProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Column(
        children: [
          _buildGradientHeader(context, isDark, theme),
          Expanded(
            child: feedbacksAsync.when(
              loading: () => ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  ShimmerCard(height: 380, borderRadius: 20),
                  SizedBox(height: AppSpacing.lg),
                  ShimmerCard(height: 120, borderRadius: 18),
                  SizedBox(height: AppSpacing.sm),
                  ShimmerCard(height: 120, borderRadius: 18),
                ],
              ),
              error: (e, _) => CustomerEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Failed to load feedback history',
                subtitle: e.toString(),
                ctaLabel: 'Retry',
                onCtaTap: () => ref.invalidate(customerFeedbackProvider),
              ),
              data: (feedbacks) {
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(customerFeedbackProvider),
                  color: AppColors.primary,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      // ── Compose section ──
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                          child: _buildComposeSection(isDark, theme),
                        ),
                      ),

                      // ── Divider ──
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.lg),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 0.5,
                                  color: (isDark
                                          ? Colors.white
                                          : Colors.black)
                                      .withValues(alpha: isDark ? 0.06 : 0.04),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md),
                                child: Text(
                                  'Your Feedback History',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.textTertiaryDark
                                        : AppColors.textTertiaryLight,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 0.5,
                                  color: (isDark
                                          ? Colors.white
                                          : Colors.black)
                                      .withValues(alpha: isDark ? 0.06 : 0.04),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Past feedback list or empty state ──
                      if (feedbacks.isEmpty)
                        SliverToBoxAdapter(
                          child: CustomerEmptyState(
                            icon: Icons.rate_review_rounded,
                            title: 'No Feedback Yet',
                            subtitle:
                                'Share your experience with us. Your feedback helps us improve.',
                          ),
                        )
                      else
                        SliverList.builder(
                          itemCount: feedbacks.length,
                          itemBuilder: (context, index) {
                            final delay = (index * 0.08).clamp(0.0, 0.6);
                            final animation = CurvedAnimation(
                              parent: _staggerController,
                              curve: Interval(
                                  delay, delay + 0.4,
                                  curve: Curves.easeOutCubic),
                            );

                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.12),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.xs,
                                  ),
                                  child: _FeedbackCard(
                                    feedback: feedbacks[index],
                                    isDark: isDark,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                      // Bottom spacing
                      const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.xxl),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Gradient Header ────────────────────────────────────────────────────

  Widget _buildGradientHeader(
      BuildContext context, bool isDark, ThemeData theme) {
    return FadeTransition(
      opacity: _headerFade,
      child: SlideTransition(
        position: _headerSlide,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF1A1040),
                      const Color(0xFF0F1115),
                    ]
                  : [
                      AppColors.primary,
                      AppColors.accent,
                    ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _HeaderIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.of(context).pop(),
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Feedback',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Help us serve you better',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Compose Section ────────────────────────────────────────────────────

  Widget _buildComposeSection(bool isDark, ThemeData theme) {
    return GlassCard(
      elevated: true,
      borderRadius: 20,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.premiumGradient,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_note_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Text(
                'Share Your Feedback',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Type selector (2x2 grid) ──
          Text(
            'Feedback Type',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 2.4,
            children: _feedbackTypes.map((type) {
              final isSelected = _selectedType == type.value;
              final color = isDark ? type.darkColor : type.color;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedType = type.value);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: isDark ? 0.15 : 0.08)
                        : (isDark ? AppColors.fillDark : AppColors.fillLight),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? color.withValues(alpha: 0.5)
                          : (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: isDark ? 0.06 : 0.04),
                      width: isSelected ? 1.5 : 0.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        type.icon,
                        size: 18,
                        color: isSelected
                            ? color
                            : (isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        type.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? color
                              : (isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Star rating ──
          Text(
            'Rating',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _StarRating(
            rating: _rating,
            isDark: isDark,
            onRatingChanged: (value) => setState(() => _rating = value),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Subject field (optional) ──
          _FeedbackTextField(
            controller: _subjectController,
            label: 'Subject (Optional)',
            hint: 'Brief summary of your feedback',
            icon: Icons.subject_rounded,
            isDark: isDark,
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Message field with character count ──
          _FeedbackTextField(
            controller: _messageController,
            label: 'Message',
            hint: 'Tell us about your experience...',
            icon: Icons.message_rounded,
            maxLines: 4,
            maxLength: _maxMessageLength,
            isDark: isDark,
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Submit button ──
          _GradientButton(
            label: 'Submit Feedback',
            icon: Icons.send_rounded,
            isLoading: _isSubmitting,
            enabled: _canSubmit,
            onTap: _handleSubmit,
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_canSubmit) return;

    HapticFeedback.mediumImpact();
    final customerId = ref.read(currentCustomerIdSyncProvider);
    if (customerId == null) return;

    setState(() => _isSubmitting = true);

    final success = await ref
        .read(createFeedbackProvider.notifier)
        .submitFeedback(
          customerId: customerId,
          type: _selectedType!,
          subject: _subjectController.text.trim().isEmpty
              ? null
              : _subjectController.text.trim(),
          message: _messageController.text.trim(),
          rating: _rating > 0 ? _rating : null,
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      // Reset form
      setState(() {
        _selectedType = null;
        _rating = 0;
        _subjectController.clear();
        _messageController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Feedback submitted successfully'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to submit feedback. Please try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Header Icon Button
// ══════════════════════════════════════════════════════════════════════════════

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Star Rating Widget
// ══════════════════════════════════════════════════════════════════════════════

class _StarRating extends StatefulWidget {
  final int rating;
  final bool isDark;
  final ValueChanged<int> onRatingChanged;

  const _StarRating({
    required this.rating,
    required this.isDark,
    required this.onRatingChanged,
  });

  @override
  State<_StarRating> createState() => _StarRatingState();
}

class _StarRatingState extends State<_StarRating>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  int? _animatingIndex;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _handleTap(int index) {
    HapticFeedback.selectionClick();
    setState(() => _animatingIndex = index);
    _bounceController.forward(from: 0).then((_) {
      widget.onRatingChanged(index + 1);
      setState(() => _animatingIndex = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final isSelected = index < widget.rating;
        final isAnimating = _animatingIndex == index;

        return GestureDetector(
          onTap: () => _handleTap(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedBuilder(
              animation: _bounceController,
              builder: (context, child) {
                final scale = isAnimating
                    ? 1.0 + (0.3 * _bounceController.value) -
                        (0.3 * _bounceController.value * 2 *
                            (_bounceController.value - 0.5).abs())
                    : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      isSelected
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 36,
                      color: isSelected
                          ? const Color(0xFFF59E0B)
                          : (widget.isDark
                              ? AppColors.textTertiaryDark
                                  .withValues(alpha: 0.4)
                              : AppColors.textTertiaryLight
                                  .withValues(alpha: 0.4)),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Feedback Text Field
// ══════════════════════════════════════════════════════════════════════════════

class _FeedbackTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final int? maxLength;
  final bool isDark;
  final ValueChanged<String>? onChanged;

  const _FeedbackTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.maxLength,
    required this.isDark,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.fillDark : AppColors.fillLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              width: 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: maxLines > 1
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: AppSpacing.md,
                  top: maxLines > 1 ? AppSpacing.md + 2 : 0,
                ),
                child: Icon(icon,
                    size: 20,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: maxLines,
                  maxLength: maxLength,
                  onChanged: onChanged,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm + 4,
                      vertical: maxLines > 1 ? AppSpacing.md : AppSpacing.md,
                    ),
                  ),
                ),
              ),
              if (maxLength != null)
                Padding(
                  padding: EdgeInsets.only(
                    right: AppSpacing.md,
                    top: maxLines > 1 ? AppSpacing.md + 2 : 0,
                  ),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      final count = value.text.length;
                      return Text(
                        '$count/$maxLength',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: count > maxLength!
                              ? AppColors.error
                              : (isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Gradient Button
// ══════════════════════════════════════════════════════════════════════════════

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final bool enabled;
  final VoidCallback onTap;

  const _GradientButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = !enabled || isLoading;

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDisabled
                ? [
                    AppColors.primary.withValues(alpha: 0.4),
                    AppColors.accent.withValues(alpha: 0.4),
                  ]
                : AppColors.premiumGradient,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDisabled
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: enabled ? 1 : 0.7),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Feedback Card (past feedback item)
// ══════════════════════════════════════════════════════════════════════════════

class _FeedbackCard extends StatelessWidget {
  final CustomerFeedbackModel feedback;
  final bool isDark;

  const _FeedbackCard({
    required this.feedback,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeOption = _feedbackTypes.cast<_FeedbackTypeOption?>().firstWhere(
          (t) => t!.value == feedback.type,
          orElse: () => _feedbackTypes.last,
        );
    final typeColor = isDark ? typeOption!.darkColor : typeOption!.color;

    final statusType = switch (feedback.status) {
      'new' => StatusType.completed,
      'in_review' => StatusType.pending,
      'resolved' => StatusType.active,
      _ => StatusType.standard,
    };

    return GlassCard(
      borderRadius: 18,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: type icon + subject + status badge ──
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: typeColor.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: Icon(typeOption.icon, size: 18, color: typeColor),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feedback.subject?.isNotEmpty == true
                          ? feedback.subject!
                          : feedback.typeLabel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      feedback.typeLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: typeColor.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: feedback.statusLabel,
                type: statusType,
              ),
            ],
          ),

          // ── Rating stars ──
          if (feedback.rating != null && feedback.rating! > 0) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            Row(
              children: List.generate(5, (i) {
                return Icon(
                  i < feedback.rating!
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 16,
                  color: i < feedback.rating!
                      ? const Color(0xFFF59E0B)
                      : (isDark
                          ? AppColors.textTertiaryDark.withValues(alpha: 0.3)
                          : AppColors.textTertiaryLight.withValues(alpha: 0.3)),
                );
              }),
            ),
          ],

          // ── Message preview ──
          if (feedback.message.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm + 4),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : AppColors.primary)
                    .withValues(alpha: isDark ? 0.03 : 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (isDark ? Colors.white : AppColors.primary)
                      .withValues(alpha: isDark ? 0.04 : 0.08),
                  width: 0.5,
                ),
              ),
              child: Text(
                feedback.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          // ── Date ──
          if (feedback.createdAt != null) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 12,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDate(feedback.createdAt!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) {
      return 'Today at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) {
      return 'Yesterday at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${days[dt.weekday - 1]}, ${dt.day}/${dt.month}/${dt.year}';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

