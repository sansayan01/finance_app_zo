import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/core/constants/app_colors.dart';
import 'package:microflow_pro/core/constants/app_spacing.dart';
import '../../data/providers/customer_notifications_providers.dart';
import '../../data/providers/customer_member_provider.dart';
import '../widgets/customer_notification_tile.dart';
import '../widgets/customer_empty_state.dart';

class CustomerNotificationsPage extends ConsumerStatefulWidget {
  const CustomerNotificationsPage({super.key});

  @override
  ConsumerState<CustomerNotificationsPage> createState() =>
      _CustomerNotificationsPageState();
}

class _CustomerNotificationsPageState
    extends ConsumerState<CustomerNotificationsPage>
    with TickerProviderStateMixin {
  late AnimationController _staggerController;
  late List<AnimationController> _itemControllers;
  bool _staggerPlayed = false;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _itemControllers = [];
  }

  @override
  void dispose() {
    _staggerController.dispose();
    for (final c in _itemControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _initStaggerAnimations(int count) {
    for (final c in _itemControllers) {
      c.dispose();
    }
    _itemControllers = List.generate(
      count,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _playStagger() {
    if (_staggerPlayed || _itemControllers.isEmpty) return;
    _staggerPlayed = true;
    for (int i = 0; i < _itemControllers.length; i++) {
      Future.delayed(Duration(milliseconds: 60 * i), () {
        if (mounted && i < _itemControllers.length) {
          _itemControllers[i].forward();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final notificationsAsync = ref.watch(customerNotificationsProvider);
    final unreadAsync = ref.watch(customerUnreadCountProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Column(
        children: [
          // ── Gradient Header ──
          _buildHeader(context, isDark, unreadAsync),
          // ── Body ──
          Expanded(
            child: notificationsAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: isDark ? AppColors.primaryDark : AppColors.primary,
                ),
              ),
              error: (e, _) => _buildErrorState(context, isDark, e),
              data: (notifications) {
                if (notifications.isEmpty) {
                  return CustomerEmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'No Notifications',
                    subtitle: 'You\'re all caught up!',
                  );
                }

                // Initialize stagger animations for this count
                if (_itemControllers.length != notifications.length) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() {
                      _staggerPlayed = false;
                      _initStaggerAnimations(notifications.length);
                    });
                    _playStagger();
                  });
                } else if (!_staggerPlayed) {
                  _playStagger();
                }

                return RefreshIndicator(
                  color: isDark ? AppColors.primaryDark : AppColors.primary,
                  backgroundColor:
                      isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  onRefresh: () async {
                    _staggerPlayed = false;
                    ref.invalidate(customerNotificationsProvider);
                    ref.invalidate(customerUnreadCountProvider);
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.xxl,
                    ),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      final item = CustomerNotificationTile(
                        notification: notification,
                        onTap: !notification.isRead
                            ? () {
                                ref
                                    .read(
                                        notificationMarkReadProvider.notifier)
                                    .markAsRead(notification.id);
                              }
                            : null,
                      );

                      if (index < _itemControllers.length) {
                        return AnimatedBuilder(
                          animation: _itemControllers[index],
                          builder: (context, child) {
                            final opacity =
                                Curves.easeOut.transform(
                                    _itemControllers[index].value);
                            final slide =
                                (1 - _itemControllers[index].value) * 30;
                            return Opacity(
                              opacity: opacity,
                              child: Transform.translate(
                                offset: Offset(0, slide),
                                child: child,
                              ),
                            );
                          },
                          child: Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _buildNotificationCard(
                              context,
                              isDark,
                              item,
                            ),
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _buildNotificationCard(context, isDark, item),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    AsyncValue<int> unreadAsync,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.surfaceDark, AppColors.cardDark]
              : AppColors.premiumGradient,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row: back + title + unread badge + mark all read
              Row(
                children: [
                  // Back button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.fillDark
                              : Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        unreadAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (count) {
                            if (count <= 0) return const SizedBox.shrink();
                            return Text(
                              '$count unread notification${count == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : Colors.white.withValues(alpha: 0.75),
                                fontWeight: FontWeight.w400,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  // Mark All Read button
                  _buildMarkAllReadButton(context, isDark),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarkAllReadButton(BuildContext context, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          final customerId = ref.read(currentCustomerIdSyncProvider);
          if (customerId != null) {
            ref
                .read(notificationMarkReadProvider.notifier)
                .markAllAsRead(customerId);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? AppColors.primaryDark.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.3),
              width: 1.2,
            ),
            color: isDark
                ? AppColors.primaryDark.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.done_all_rounded,
                size: 16,
                color: isDark
                    ? AppColors.primaryDark
                    : Colors.white.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 6),
              Text(
                'Mark All Read',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.primaryDark
                      : Colors.white.withValues(alpha: 0.9),
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    bool isDark,
    Widget child,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: isDark
            ? Border.all(
                color: AppColors.separatorDark.withValues(alpha: 0.5),
                width: 0.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : AppColors.primary.withValues(alpha: 0.04),
            blurRadius: isDark ? 8 : 12,
            offset: const Offset(0, 2),
            spreadRadius: isDark ? 0 : 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, bool isDark, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? AppColors.errorDark.withValues(alpha: 0.12)
                    : AppColors.error.withValues(alpha: 0.08),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: isDark ? AppColors.errorDark : AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Please pull to refresh and try again',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Private animated widget for staggered item animations.
