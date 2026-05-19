import 'package:shared_preferences/shared_preferences.dart';

/// Manages quick-tour state (completion, skip, role-specific flags).
class TourService {
  static const _tourCompletedKey = 'quick_tour_completed';
  static const _tourSkippedKey = 'quick_tour_skipped';

  final SharedPreferences _prefs;

  TourService(this._prefs);

  /// Whether the user has completed or skipped the tour.
  bool get isTourDone =>
      _prefs.getBool(_tourCompletedKey) == true ||
      _prefs.getBool(_tourSkippedKey) == true;

  /// Mark tour as completed.
  Future<void> completeTour() async {
    await _prefs.setBool(_tourCompletedKey, true);
  }

  /// Mark tour as skipped (user can replay from settings).
  Future<void> skipTour() async {
    await _prefs.setBool(_tourSkippedKey, true);
  }

  /// Reset tour so it shows again (for "Replay Tour" in settings).
  Future<void> resetTour() async {
    await _prefs.remove(_tourCompletedKey);
    await _prefs.remove(_tourSkippedKey);
  }
}
