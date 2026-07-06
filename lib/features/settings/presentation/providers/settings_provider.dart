import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../../data/providers/activity_log_repository_provider.dart';
import '../../data/models/activity_log_model.dart';

class SystemSettings {
  final double defaultLoanInterest;
  final double defaultSavingsYield;
  final double latePenaltyPercentage;
  final bool enableNotifications;
  final bool biometricAuth;
  final String currency;

  SystemSettings({
    this.defaultLoanInterest = 12.0,
    this.defaultSavingsYield = 8.5,
    this.latePenaltyPercentage = 2.0,
    this.enableNotifications = true,
    this.biometricAuth = false,
    this.currency = 'INR',
  });

  SystemSettings copyWith({
    double? defaultLoanInterest,
    double? defaultSavingsYield,
    double? latePenaltyPercentage,
    bool? enableNotifications,
    bool? biometricAuth,
    String? currency,
  }) {
    return SystemSettings(
      defaultLoanInterest: defaultLoanInterest ?? this.defaultLoanInterest,
      defaultSavingsYield: defaultSavingsYield ?? this.defaultSavingsYield,
      latePenaltyPercentage:
          latePenaltyPercentage ?? this.latePenaltyPercentage,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      biometricAuth: biometricAuth ?? this.biometricAuth,
      currency: currency ?? this.currency,
    );
  }
}

class SystemSettingsNotifier extends StateNotifier<SystemSettings> {
  final Ref _ref;
  SystemSettingsNotifier(this._ref) : super(SystemSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      defaultLoanInterest: prefs.getDouble('defaultLoanInterest') ?? 12.0,
      defaultSavingsYield: prefs.getDouble('defaultSavingsYield') ?? 8.5,
      latePenaltyPercentage: prefs.getDouble('latePenaltyPercentage') ?? 2.0,
      enableNotifications: prefs.getBool('enableNotifications') ?? true,
      biometricAuth: prefs.getBool('biometricAuth') ?? false,
    );
  }

  Future<void> updateLoanInterest(double value) async {
    _log('Loan Interest', '${state.defaultLoanInterest}%', '$value%');
    state = state.copyWith(defaultLoanInterest: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('defaultLoanInterest', value);
  }

  Future<void> updateSavingsYield(double value) async {
    _log('Savings Yield', '${state.defaultSavingsYield}%', '$value%');
    state = state.copyWith(defaultSavingsYield: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('defaultSavingsYield', value);
  }

  Future<void> updatePenalty(double value) async {
    _log('Late Penalty', '${state.latePenaltyPercentage}%', '$value%');
    state = state.copyWith(latePenaltyPercentage: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('latePenaltyPercentage', value);
  }

  Future<void> toggleNotifications(bool value) async {
    state = state.copyWith(enableNotifications: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableNotifications', value);
  }

  Future<void> toggleBiometric(bool value) async {
    if (value) {
      final auth = LocalAuthentication();
      final canAuth =
          await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (canAuth) {
        try {
          final didAuth = await auth.authenticate(
            localizedReason: 'Authenticate to enable Biometric Login',
          );
          if (!didAuth) return; // User cancelled, do not toggle
        } catch (_) {
          return; // Error or cancelled
        }
      } else {
        return; // Not supported
      }
    }

    state = state.copyWith(biometricAuth: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometricAuth', value);
  }

  void _log(String param, String oldVal, String newVal) {
    _ref.read(activityLogRepositoryProvider).log(
          action: 'System Parameter Updated',
          details: 'Changed $param from $oldVal to $newVal',
          type: ActivityType.systemUpdate,
        );
  }
}

final settingsProvider =
    StateNotifierProvider<SystemSettingsNotifier, SystemSettings>((ref) {
  return SystemSettingsNotifier(ref);
});
