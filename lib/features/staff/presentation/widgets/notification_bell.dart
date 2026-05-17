import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/providers/staff_providers.dart';

class NotificationBell extends ConsumerWidget {
  final double size;

  const NotificationBell({super.key, this.size = 22});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final countAsync = ref.watch(unreadNotificationCountProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () => context.push('/notifications'),
          icon: Icon(Icons.notifications_outlined,
              size: size, color: Colors.white.withValues(alpha: 0.85)),
          splashColor: Colors.white.withValues(alpha: 0.1),
          highlightColor: Colors.white.withValues(alpha: 0.05),
        ),
        countAsync.when(
          data: (count) {
            if (count <= 0) return const SizedBox.shrink();
            return Positioned(
              right: 6,
              top: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: theme.scaffoldBackgroundColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.redAccent.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: count > 99 ? 7 : 9,
                      fontWeight: FontWeight.w800,
                      height: 1),
                ),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
