import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../../providers/supabase_provider.dart';

final trialInfoProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final client = ref.read(supabaseClientProvider);
  final orgId = ref.read(currentOrgIdOrThrowProvider);
  try {
    return client.from('organizations').select('status, trial_ends_at, created_at').eq('id', orgId).single();
  } catch (_) {
    return null;
  }
});

class TrialBanner extends ConsumerWidget {
  const TrialBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trialAsync = ref.watch(trialInfoProvider);
    return trialAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        if (data == null) return const SizedBox.shrink();
        final status = data['status'] as String? ?? '';
        final trialEndStr = data['trial_ends_at'] as String?;
        if (status != 'trial' || trialEndStr == null) return const SizedBox.shrink();

        final trialEnd = DateTime.tryParse(trialEndStr);
        if (trialEnd == null) return const SizedBox.shrink();
        final now = DateTime.now();
        final daysLeft = trialEnd.difference(now).inDays;

        if (daysLeft < 0) {
          return _buildBanner(daysLeft, context, 'Trial Expired', 'Your trial has ended. Upgrade to continue.', Colors.red);
        }
        if (daysLeft <= 3) {
          return _buildBanner(daysLeft, context, '$daysLeft days left', 'Your trial ends soon. Upgrade to keep using MicroFlow Pro.', AppColors.warning);
        }
        return _buildBanner(daysLeft, context, '$daysLeft days left in trial', 'Explore all features free for $daysLeft more days.', AppColors.primary);
      },
    );
  }

  Widget _buildBanner(int daysLeft, BuildContext context, String title, String message, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.04)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(daysLeft <= 3 ? Icons.warning_amber_rounded : Icons.info_outline_rounded, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
                const SizedBox(height: 2),
                Text(message, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Upgrade', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
