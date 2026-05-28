import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/providers/staff_providers.dart';

class BreakCard extends ConsumerStatefulWidget {
  const BreakCard({super.key});

  @override
  ConsumerState<BreakCard> createState() => _BreakCardState();
}

class _BreakCardState extends ConsumerState<BreakCard> {
  bool _isLoading = false;

  Future<void> _handleBreak() async {
    HapticFeedback.mediumImpact();
    final profile = await ref.read(staffProfileProvider.future);
    if (profile == null) return;

    final repo = ref.read(staffRepositoryProvider);

    setState(() => _isLoading = true);
    try {
      final currentBreak = await repo.getCurrentBreak(profile.id);
      if (currentBreak != null) {
        await repo.endBreak(profile.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Break ended'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2)),
          );
        }
      } else {
        await repo.startBreak(staffId: profile.id, breakType: 'lunch');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Break started'),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 2)),
          );
        }
      }
      ref.invalidate(currentActivityProvider(profile.id));
      ref.invalidate(recentActivitiesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(staffProfileProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();
        return StreamBuilder<Map<String, dynamic>?>(
          stream: Stream.periodic(const Duration(seconds: 10), (_) => null)
              .asyncMap((_) async {
            final repo = ref.read(staffRepositoryProvider);
            return repo.getCurrentBreak(profile.id);
          }),
          initialData: null,
          builder: (context, snapshot) {
            final currentBreak = snapshot.data;
            final isOnBreak = currentBreak != null;

            return GlassCard(
              padding: const EdgeInsets.all(16),
              borderColor: isOnBreak
                  ? Colors.orangeAccent.withValues(alpha: 0.3)
                  : null,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isOnBreak
                          ? Colors.orangeAccent.withValues(alpha: 0.2)
                          : AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isOnBreak
                          ? Icons.free_breakfast_rounded
                          : Icons.coffee_outlined,
                      color:
                          isOnBreak ? Colors.orangeAccent : AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOnBreak ? 'On Break' : 'Take a Break',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          isOnBreak
                              ? 'Tap to resume work'
                              : 'Tap when taking a break',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleBreak,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOnBreak
                            ? Colors.orangeAccent.withValues(alpha: 0.2)
                            : AppColors.primary.withValues(alpha: 0.1),
                        foregroundColor:
                            isOnBreak ? Colors.orangeAccent : AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(
                              isOnBreak ? 'End' : 'Start',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
