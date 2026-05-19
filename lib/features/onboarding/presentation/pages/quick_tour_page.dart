import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/tour_provider.dart';
import '../../data/tour_steps.dart';
import '../widgets/tour_overlay.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// A full-screen overlay page that shows the quick tour.
/// Can be shown as a dialog/overlay on top of the dashboard,
/// or navigated to directly.
class QuickTourPage extends ConsumerWidget {
  /// If true, navigates back on completion. If false, just removes itself.
  final VoidCallback? onComplete;

  const QuickTourPage({super.key, this.onComplete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tourState = ref.watch(tourControllerProvider);
    final user = ref.watch(currentUserProvider);
    final steps = getTourSteps(user?.role);

    // If tour is done, don't show anything
    if (tourState.status == TourStatus.completed ||
        tourState.status == TourStatus.skipped) {
      // Schedule callback after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onComplete?.call();
      });
      return const SizedBox.shrink();
    }

    final currentStep = tourState.currentStep.clamp(0, steps.length - 1);

    return TourOverlay(
      step: steps[currentStep],
      currentIndex: currentStep,
      totalSteps: steps.length,
      onNext: () => ref.read(tourControllerProvider.notifier).nextStep(),
      onBack: () => ref.read(tourControllerProvider.notifier).previousStep(),
      onSkip: () => ref.read(tourControllerProvider.notifier).skipTour(),
      onFinish: () => ref.read(tourControllerProvider.notifier).completeTour(),
    );
  }
}

/// Shows the quick tour as an overlay on top of the current screen.
/// Call this from the dashboard's initState or a post-frame callback.
void showQuickTour(BuildContext context, WidgetRef ref) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (ctx) => _TourOverlayWrapper(
      onDismiss: () => entry.remove(),
    ),
  );

  overlay.insert(entry);

  // Start the tour
  ref.read(tourControllerProvider.notifier).startTour();
}

/// Wrapper that listens to tour state and removes itself when done.
class _TourOverlayWrapper extends ConsumerWidget {
  final VoidCallback onDismiss;

  const _TourOverlayWrapper({required this.onDismiss});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tourState = ref.watch(tourControllerProvider);
    final user = ref.watch(currentUserProvider);
    final steps = getTourSteps(user?.role);

    if (tourState.status == TourStatus.completed ||
        tourState.status == TourStatus.skipped) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onDismiss());
      return const SizedBox.shrink();
    }

    if (tourState.status != TourStatus.active) {
      return const SizedBox.shrink();
    }

    final currentStep = tourState.currentStep.clamp(0, steps.length - 1);

    return TourOverlay(
      step: steps[currentStep],
      currentIndex: currentStep,
      totalSteps: steps.length,
      onNext: () => ref.read(tourControllerProvider.notifier).nextStep(),
      onBack: () => ref.read(tourControllerProvider.notifier).previousStep(),
      onSkip: () => ref.read(tourControllerProvider.notifier).skipTour(),
      onFinish: () => ref.read(tourControllerProvider.notifier).completeTour(),
    );
  }
}
