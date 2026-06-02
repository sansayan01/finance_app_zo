import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:microflow_pro/core/constants/app_colors.dart';
import 'package:microflow_pro/core/constants/app_spacing.dart';
import 'package:microflow_pro/core/widgets/shimmer_card.dart';
import '../../data/models/customer_notification_model.dart';
import '../../data/providers/customer_connection_provider.dart';
import '../../data/providers/customer_notifications_providers.dart';
import '../../data/providers/customer_member_provider.dart';
import '../../data/providers/customer_realtime_providers.dart';
import '../widgets/customer_notification_tile.dart';
import '../widgets/customer_empty_state.dart';

enum _NotificationFilter { all, unread, emi, savings, system }

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
  late AnimationController _pulseController;
  _NotificationFilter _filter = _NotificationFilter.all;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _staggerController.forward();
    });
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  bool _matchesFilter(CustomerNotificationModel n) {
    switch (_filter) {
      case _NotificationFilter.all:
        return true;
      case _NotificationFilter.unread:
        return !n.isRead;
      case _NotificationFilter.emi:
        return n.type == 'payment_due' || n.type == 'emi_reminder';
      case _NotificationFilter.savings:
        return n.type == 'savings_update';
      case _NotificationFilter.system:
        return n.type == 'general' ||
            n.type == 'kyc_update' ||
            n.type == 'system';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    ref.watch(realtimeNotificationsProvider);
    final notificationsAsync = ref.watch(customerNotificationsProvider);
    final unreadAsync = ref.watch(customerUnreadCountProvider);

    // Auto-retry when connectivity is restored
    ref.listen<AsyncValue<bool>>(isOnlineProvider, (prev, next) {
      final wasOffline = prev?.valueOrNull == false;
      final isOnline = next.valueOrNull == true;
      if (isOnline && wasOffline) {
        ref.invalidate(customerNotificationsProvider);
        ref.invalidate(customerUnreadCountProvider);
      }
    });

    return Scaffold(
      extendBody: true,
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Column(
        children: [
          _buildHeader(context, isDark, unreadAsync),
          _buildFilterChips(isDark),
          Expanded(
            child: notificationsAsync.when(
              loading: () => _buildShimmer(isDark),
              error: (e, _) => _buildErrorState(context, isDark, e),
              data: (notifications) {
                final filtered =
                    notifications.where(_matchesFilter).toList();

                if (notifications.isEmpty) {
                  return const CustomerEmptyState(
                    icon: Icons.celebration_rounded,
                    title: "You're all caught up",
                    subtitle:
                        'No notifications right now. We\'ll let you know when something arrives.',
                  );
                }

                if (filtered.isEmpty) {
                  return const CustomerEmptyState(
                    icon: Icons.filter_alt_off_rounded,
                    title: 'Nothing here',
                    subtitle:
                        'No notifications match this filter. Try switching to All.',
                  );
                }

                return RefreshIndicator(
                  color: isDark ? AppColors.primaryDark : AppColors.primary,
                  backgroundColor:
                      isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  onRefresh: () async {
                    _staggerController
                      ..reset()
                      ..forward();
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
                      AppSpacing.xxl + AppSpacing.lg,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final notification = filtered[index];
                      final delay = (index * 0.07).clamp(0.0, 0.85);
                      final animation = CurvedAnimation(
                        parent: _staggerController,
                        curve: Interval(delay, (delay + 0.35).clamp(0.0, 1.0),
                            curve: Curves.easeOutCubic),
                      );

                      final tile = CustomerNotificationTile(
                        notification: notification,
                        onTap: !notification.isRead
                            ? () {
                                ref
                                    .read(notificationMarkReadProvider.notifier)
                                    .markAsRead(notification.id);
                              }
                            : null,
                      );

                      Widget card = Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _buildNotificationCard(context, isDark, tile),
                      );

                      // Swipe-to-mark-read for unread items
                      if (!notification.isRead) {
                        card = Dismissible(
                          key: ValueKey('notif_${notification.id}'),
                          direction: DismissDirection.endToStart,
                          background: Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.success.withValues(alpha: 0.15),
                                    AppColors.success.withValues(alpha: 0.35),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.done_all_rounded,
                                      color: AppColors.success, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Mark read',
                                    style: TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          confirmDismiss: (_) async {
                            ref
                                .read(notificationMarkReadProvider.notifier)
                                .markAsRead(notification.id);
                            return false; // we just mark read, don't actually remove
                          },
                          child: card,
                        );
                      }

                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.12),
                            end: Offset.zero,
                          ).animate(animation),
                          child: card,
                        ),
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

  // ─── Shimmer loading ───────────────────────────────────────────────────
  Widget _buildShimmer(bool isDark) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.sm),
        child: ShimmerCard(height: 88, borderRadius: 20),
      ),
    );
  }

  // ─── Filter chips ──────────────────────────────────────────────────────
  Widget _buildFilterChips(bool isDark) {
    final chips = <(_NotificationFilter, String, IconData)>[
      (_NotificationFilter.all, 'All', Icons.all_inbox_rounded),
      (_NotificationFilter.unread, 'Unread', Icons.mark_email_unread_rounded),
      (_NotificationFilter.emi, 'EMI', Icons.payment_rounded),
      (_NotificationFilter.savings, 'Savings', Icons.savings_rounded),
      (_NotificationFilter.system, 'System', Icons.settings_rounded),
    ];

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (value, label, icon) = chips[i];
          final selected = _filter == value;
          return GestureDetector(
            onTap: () => setState(() => _filter = value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: selected
                    ? LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.accent,
                        ],
                      )
                    : null,
                color: selected
                    ? null
                    : (isDark
                        ? AppColors.fillDark
                        : AppColors.fillLight),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04)),
                  width: 0.5,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: selected
                        ? Colors.white
                        : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                      color: selected
                          ? Colors.white
                          : (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight),
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

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    AsyncValue<int> unreadAsync,
  ) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF1A1F3A), Color(0xFF151A30)]
                : [AppColors.primary, AppColors.accent],
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
          child: Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 0.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    unreadAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (count) {
                        if (count <= 0) {
                          return Text(
                            "You're all caught up",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }
                        return Text(
                          '$count unread notification${count == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              unreadAsync.maybeWhen(
                data: (count) => _buildMarkAllReadButton(context, isDark, count),
                orElse: () => _buildMarkAllReadButton(context, isDark, 0),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildMarkAllReadButton(BuildContext context, bool isDark, int unread) {
    final hasUnread = unread > 0;
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: hasUnread
            ? () {
                final customerId = ref.read(currentCustomerIdSyncProvider);
                if (customerId != null) {
                  ref
                      .read(notificationMarkReadProvider.notifier)
                      .markAllAsRead(customerId);
                }
              }
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: hasUnread ? 0.35 : 0.15),
              width: 1.2,
            ),
            color: Colors.white.withValues(alpha: hasUnread ? 0.12 : 0.05),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.done_all_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: hasUnread ? 0.95 : 0.45),
              ),
              const SizedBox(width: 6),
              Text(
                'Mark All Read',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      Colors.white.withValues(alpha: hasUnread ? 0.95 : 0.45),
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!hasUnread) return button;

    // Subtle pulse when unread > 0
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulseController.value);
        final scale = 1.0 + 0.025 * t;
        return Transform.scale(scale: scale, child: child);
      },
      child: button,
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    bool isDark,
    Widget child,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardDark.withValues(alpha: 0.85)
            : AppColors.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
          width: 0.5,
        ),
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
