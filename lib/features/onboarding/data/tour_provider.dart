import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tour_service.dart';

/// Provides the TourService instance.
final tourServiceProvider = Provider<TourService>((ref) {
  // This will be overridden at app startup with the actual SharedPreferences.
  throw UnimplementedError('tourServiceProvider must be overridden');
});

/// Whether the quick tour should be shown (first-time user).
final shouldShowTourProvider = Provider<bool>((ref) {
  final service = ref.watch(tourServiceProvider);
  return !service.isTourDone;
});

/// Notifier to control tour state changes from UI.
final tourControllerProvider =
    StateNotifierProvider<TourController, TourState>((ref) {
  final service = ref.watch(tourServiceProvider);
  return TourController(service);
});

enum TourStatus { idle, active, completed, skipped }

class TourState {
  final TourStatus status;
  final int currentStep;
  final int totalSteps;

  const TourState({
    this.status = TourStatus.idle,
    this.currentStep = 0,
    this.totalSteps = 5,
  });

  TourState copyWith({TourStatus? status, int? currentStep, int? totalSteps}) {
    return TourState(
      status: status ?? this.status,
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
    );
  }
}

class TourController extends StateNotifier<TourState> {
  final TourService _service;

  TourController(this._service) : super(const TourState());

  void startTour() {
    state = state.copyWith(status: TourStatus.active, currentStep: 0);
  }

  void nextStep() {
    if (state.currentStep >= state.totalSteps - 1) {
      completeTour();
    } else {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  void completeTour() {
    _service.completeTour();
    state = state.copyWith(status: TourStatus.completed);
  }

  void skipTour() {
    _service.skipTour();
    state = state.copyWith(status: TourStatus.skipped);
  }

  void resetTour() {
    _service.resetTour();
    state = const TourState(status: TourStatus.idle);
  }

  /// Whether the tour has been completed or skipped (persisted).
  bool get isTourDone => _service.isTourDone;
}
